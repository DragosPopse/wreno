package wren

import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"

// Todo(Dragos): split the compiler into multiple passes: tokenizing, parsing, compiling

// The maximum number of local (i.e. not module level) variables that can be
// declared in a single function, method, or chunk of top level code. This is
// the maximum number of variables in scope at one time, and spans block scopes.
//
// Note that this limitation is also explicit in the bytecode. Since
// `CODE_LOAD_LOCAL` and `CODE_STORE_LOCAL` use a single argument byte to
// identify the local, only 256 can be in scope at one time.
MAX_LOCALS :: max(u8)

// The maximum number of upvalues (i.e. variables from enclosing functions)
// that a function can close over.
MAX_UPVALUES :: max(u8)

// The maximum number of distinct constants that a function can contain. This
// value is explicit in the bytecode since `CODE_CONSTANT` only takes a single
// two-byte argument.
MAX_CONSTANTS :: max(u16)

// The maximum distance a  or CODE_JUMP_IF instruction can move the
// instruction pointer.CODE_JUMP
MAX_JUMP :: max(u16)

// The maximum depth that interpolation can nest. For example, this string has
// three levels:
//
//      "outside %(one + "%(two + "%(three)")")"
MAX_INTERPOLATION_NESTING :: 8



Class_Info :: struct {
	name             : ^String,           // The name of the class
	class_attributes : ^Map,              // Attributes for the class itself
	method_attributes: ^Map,              // Attributes for methods in this class
	fields           : [dynamic]string,   // Symbol table for the fields of the class
	methods          : [dynamic]int,      // Symbols for the methods defined by the class. Used to detect duplicate method definitions
	static_methods   : [dynamic]int,
	is_foreign       : bool,              // True if the class being compiled is a foreign class
	in_static        : bool,              // True if the current method being compiled is static
	signature        : ^Signature,        //The signature of the method being compiled
}

Parser :: struct {
	t: Tokenizer,
	vm: ^VM,
	current: Token,
	next: Token,
	previous: Token,
}

Compiler :: struct {
	parser: ^Parser,
	parent         : ^Compiler,                        // The compiler for the function enclosing this one, or nil if it's the top level
	locals         : [MAX_LOCALS]Local,                // The currently in scope local variables
	num_locals     : int,
	upvalues       : [MAX_UPVALUES]Compiler_Upvalue,   // The upvalues that this function has captured from outer scopes, the count of them is stored in [num_upvalues]
	scope_depth    : int,                              // The current level of block scope nesting, where 0 is no nesting. -1 here means top level code is being compiled and there is no block scope in effect at all. Aany variables declared will be module-level
	num_slots      : int,                              // Number of slots (locals and temps) in use. We use this and max_slots to track the maximum number of additional slots a function may need while executing. When the funciton is called, the fiber will check to ensure it's stack has enough room to cover that worst case and grow the stack if needed. This value doesn't include parameters to the function, since those are already pushed onto the stack by the caller and tracked here, we don't need to double count them here.
	loop           : ^Loop,                            // The current innermost loop being compiled, or nil if not in a loop
	enclosing_class: ^Class_Info,                      // If this is a compiler for a method, keep track of the class enclosing it
	fn             : ^Fn,                              // The function being compiled
	constants      : ^Map,                             // The constants for the function being compiled
	is_initializer : bool,                             // Whether or not the compiler is for a constructor initializer
	num_attributes : int,                              // The num of attributes seen while parsing. We track this separately as compile time attributes are not stored, so we can't rely on attributes.count to enforce an error message when attributes are used anywhere other than methods or classes
	attributes     : ^Map,                             // Attributes for the next class or method
}

Precedence :: enum {
	None,
	Lowest,
	Assignment,    // =
	Conditional,   // ?:
	Logical_Or,    // ||
	Logical_And,   // &&
	Equality,      // == !=
	Is,            // is
	Comparison,    // < > <= >=
	Bitwise_Or,    // |
	Bitwise_Xor,   // ^
	Bitwise_And,   // &
	Bitwise_Shift, // << >>
	Range,         // .. ...
	Term,          // + -
	Factor,        // * / %
	Unary,         // unary - ! ~
	Call,          // . () []
	Primary,
}

Grammar_Fn :: #type proc(compiler: ^Compiler, can_assign: bool)
Signature_Fn :: #type proc(compiler: ^Compiler, signature: ^Signature)

Grammar_Rule :: struct {
	prefix: Grammar_Fn,
	infix: Grammar_Fn,
	method: Signature_Fn,
	precendence: Precedence,
	name: string,
}

RULE_UNUSED :: Grammar_Rule{}

RULE_PREFIX :: #force_inline proc(prefix: Grammar_Fn) -> Grammar_Rule {
	return {prefix, nil, nil, .None, ""}
}

RULE_INFIX :: #force_inline proc(prec: Precedence, fn: Grammar_Fn) -> Grammar_Rule {
	return {nil, fn, nil, prec, ""}
}

RULE_INFIX_OP :: #force_inline proc(prec: Precedence, name: string) -> Grammar_Rule {
	return {nil, infix_op, infix_signature, prec, name}
}

RULE_PREFIX_OP :: #force_inline proc(name: string) -> Grammar_Rule {
	return {unary_op, nil, unary_signature, .None, name}
}

RULE_OP :: #force_inline proc(name: string) -> Grammar_Rule {
	return {unary_op, infix_op, mixed_signature, .Term, name}
}

rules := #partial [Token_Kind]Grammar_Rule {
	.Left_Paren    = RULE_PREFIX(grouping),
	.Right_Paren   = RULE_UNUSED,
	.Left_Bracket  = {list, subscript, subscript_signature, .Call, ""},
	.Right_Bracket = RULE_UNUSED,
	.Left_Brace    = RULE_PREFIX(map_lit),
	.Right_Brace   = RULE_UNUSED,
	.Colon         = RULE_UNUSED,
	.Dot           = RULE_INFIX(.Call, call),
	.Dot_Dot       = RULE_INFIX_OP(.Range, ".."),
	.Dot_Dot_Dot   = RULE_INFIX_OP(.Range, "..."),
}

Scope :: enum {
	Local  ,  // Local in the current function
	Upvalue,  // Local variable declared in an enclosing function
	Module ,  // Top level module variable
}

// Reference to a variable and the scope where it is defined, this contains enough information to emit correct code to load or store the variable
Variable :: struct {
	index: int,     // Stack slot, upvalue slot, or module symbol defining the variable
	scope: Scope,   // Where the variable is declared
}



Local :: struct {
	name      : string,   // Points directly into the original source code string
	depth     : int,      // The depth of the scope chain that this variable was declared in. Zero is the outermost scope, parameters for a metod, or the first local block in top level code. One is the scope within that, etc.
	is_upvalue: bool,     // If this local is being used as an upvalue
}

Compiler_Upvalue :: struct {
	is_local: bool,   // Is this capturing a local variable from the enclosing function? False if it's capturing an upvalue
	index   : int,    // The index of the local or upvalue being captured in the enclosing function
}

// Bookkeeping information for the current loop being compiled
Loop :: struct {
	start      : int,     // Index of the instruction that the loop should jump back to
	exit_jump  : int,     // Index of the argument for the Code.JUMP_IF instruction used to exit the loop. Stores so we can patch it once we know where the loop ends
	body       : int,     // Index of the first instruction of the body of the loop
	scope_depth: int,     // Depth of the scope(s) that need to be exited if a break is hit inside the loop
	enclosing  : ^Loop,   // The loop enclosing this one, or nil if this is the outermost loop
}

// The different signature syntaxes for different kind of methods
Signature_Kind :: enum {
	Method          ,  // A name followed by paranthesized parameter list. Also used for binary operators
	Getter          ,  // Just a name, also used for unary operators
	Setter          ,  // A name followed by "="
	Subscript       ,  // A square bracketed paramter list
	Subscript_Setter,  // A square bracketed parameter list followed by "="
	Initializer     ,  // A constructor initializer function. This has a distinct signature to prevent it from being invoked directly outside of the constructor of the metaclass
}

Signature :: struct {
	name : string,
	kind : Signature_Kind,
	arity: int,
}

next_token :: proc(p: ^Parser) {
	p.previous = p.current
	p.current = p.next
	if p.next.kind == .EOF do return
	if p.current.kind == .EOF do return
	p.next, _ = scan(&p.t)
}

compiler_init :: proc(c: ^Compiler, p: ^Parser, parent: ^Compiler, is_method: bool) {
	c.parser = p
	c.parent = parent
	p.vm.compiler = c
	c.num_locals = 1
	c.num_slots = c.num_locals
	if is_method {
		c.locals[0].name = "this"
	}
	c.locals[0].depth = -1
	c.locals[0].is_upvalue = false

	if parent == nil { // Compiling top-level code, so the initial scope is module-level
		c.scope_depth = -1
	} else { // The initial scope for functions and methods is local scope
		c.scope_depth = 0
	}

	/// TODO(Dragos): Figure out the vm into all this single pass mess.
	//c.attributes = map_make(vm)
	//c.fn = fn_make(vm, module, compiler.num_locals)
}

compile :: proc(vm: ^VM, module: ^Module, source: string, is_expression: bool) -> ^Fn {
	p: Parser
	p.t = default_tokenizer(source)
	next_token(&p)
	next_token(&p)
	
	num_existing_variables := len(module.variables)

	c: Compiler
	compiler_init(&c, &p, nil, false)

	if is_expression {
		
	}


	return nil
}

expression :: proc(c: ^Compiler) {
	parse_precedence(c, .Lowest)
}

parse_precedence :: proc(c: ^Compiler, prec: Precedence) {
	next_token(c.parser)
	prefix := rules[c.parser.previous.kind].prefix
	if prefix == nil {
		fmt.eprintf("Expected expression\n") // TODO(DRAGOS): FIX ERRORING
		return
	}
	// Track if the precendence of the surrounding expression is low enough to
 	// allow an assignment inside this one. We can't compile an assignment like
 	// a normal expression because it requires us to handle the LHS specially --
 	// it needs to be an lvalue, not an rvalue. So, for each of the kinds of
 	// expressions that are valid lvalues -- names, subscripts, fields, etc. --
 	// we pass in whether or not it appears in a context loose enough to allow
 	// "=". If so, it will parse the "=" itself and handle it appropriately.
	can_assign := prec <= .Conditional
}

grouping :: proc(c: ^Compiler, can_assign: bool) {

}

list :: proc(c: ^Compiler, can_assign: bool) {

}

map_lit :: proc(c: ^Compiler, can_assign: bool) {
	
}

unary_op :: proc(c: ^Compiler, can_assign: bool) {

}

subscript :: proc(c: ^Compiler, can_assign: bool) {

}

subscript_signature :: proc(c: ^Compiler, sig: ^Signature) {

}

infix_op :: proc(c: ^Compiler, can_assign: bool) {

}

infix_signature :: proc(c: ^Compiler, sig: ^Signature) {

}

mixed_signature :: proc(c: ^Compiler, sig: ^Signature) {

}

unary_signature :: proc(c: ^Compiler, sig: ^Signature) {

}



call :: proc(c: ^Compiler, can_assign: bool) {

}