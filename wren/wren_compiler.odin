package wren

import "core:unicode"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"

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

// The maximum distance a CODE_JUMP or CODE_JUMP_IF instruction can move the
// instruction pointer.
MAX_JUMP :: max(u16)

// The maximum depth that interpolation can nest. For example, this string has
// three levels:
//
//      "outside %(one + "%(two + "%(three)")")"
MAX_INTERPOLATION_NESTING :: 8

Token_Kind :: enum {
	LEFT_PAREN,
	RIGHT_PAREN,
	LEFT_BRACKET,
	RIGHT_BRACKET,
	LEFT_BRACE,
	RIGHT_BRACE,
	COLON,
	DOT,
	DOTDOT,
	DOTDOTDOT,
	COMMA,
	STAR,
	SLASH,
	PERCENT,
	HASH,
	PLUS,
	MINUS,
	LTLT,
	GTGT,
	PIPE,
	PIPEPIPE,
	CARET,
	AMP,
	AMPAMP,
	BANG,
	TILDE,
	QUESTION,
	EQ,
	LT,
	GT,
	LTEQ,
	GTEQ,
	EQEQ,
	BANGEQ,

	BREAK,
	CONTINUE,
	CLASS,
	CONSTRUCT,
	ELSE,
	FALSE,
	FOR,
	FOREIGN,
	IF,
	IMPORT,
	AS,
	IN,
	IS,
	NULL,
	RETURN,
	STATIC,
	SUPER,
	THIS,
	TRUE,
	VAR,
	WHILE,

	FIELD,
	STATIC_FIELD,
	NAME,
	NUMBER,
	
	// A string literal without any interpolation, or the last section of a
	// string following the last interpolated expression.
	STRING,
	
	// A portion of a string literal preceding an interpolated expression. This
	// string:
	//
	//     "a %(b) c %(d) e"
	//
	// is tokenized to:
	//
	//     TOKEN_INTERPOLATION "a "
	//     TOKEN_NAME          b
	//     TOKEN_INTERPOLATION " c "
	//     TOKEN_NAME          d
	//     TOKEN_STRING        " e"
	INTERPOLATION,
	
	LINE,
	
	ERROR,
	EOF,
}

Token :: struct {
	kind : Token_Kind,
	text : string,       // Points directly into the source
	line : int,          // 1-based line where the token appears
	value: Value,        // The parsed value if the token is a literal
}

Parser :: struct {
	vm          : ^VM,
	module      : ^Module,                      // The module being parsed
	sourcce     : string,                           // The source code being parsed
	token_start : string,                           // The beginning of the currently-being-lexed token in [source]
	current_char: string,                           // The current character being lexed in [source] Note(dragos): this could be an int for the position?
	current_line: int,                              // The 1-based line number of [current_char]
	next        : Token,                            // Upcoming token
	current     : Token,                            // Most recently lexed token
	previous    : Token,                            // Most recently consumed/advanced token
	parens      : [MAX_INTERPOLATION_NESTING]int,   // Tracks the lexing state when tokenizing interpolated strings
	num_parens  : int,
	print_errors: bool,                             // Print to stderr or discard
	has_errors  : bool,                             // Syntax or compile error occured
}

Class_Info :: struct {
	name             : ^String,       // The name of the class
	class_attributes : ^Map,          // Attributes for the class itself
	method_attributes: ^Map,          // Attributes for methods in this class
	fields           : [dynamic]string,   // Symbol table for the fields of the class
	methods          : [dynamic]int,      // Symbols for the methods defined by the class. Used to detect duplicate method definitions
	static_methods   : [dynamic]int,
	is_foreign       : bool,              // True if the class being compiled is a foreign class
	in_static        : bool,              // True if the current method being compiled is static
	signature        : ^Signature,        //The signature of the method being compiled
}

Compiler :: struct {
	parser         : ^Parser,
	parent         : ^Compiler,                        // The compiler for the function enclosing this one, or nil if it's the top level
	locals         : [MAX_LOCALS]Local,                // The currently in scope local variables
	num_locals     : int,
	upvalues       : [MAX_UPVALUES]Compiler_Upvalue,   // The upvalues that this function has captured from outer scopes, the count of them is stored in [num_upvalues]
	scope_depth    : int,                              // The current level of block scope nesting, where 0 is no nesting. -1 here means top level code is being compiled and there is no block scope in effect at all. Aany variables declared will be module-level
	num_slots      : int,                              // Number of slots (locals and temps) in use. We use this and max_slots to track the maximum number of additional slots a function may need while executing. When the funciton is called, the fiber will check to ensure it's stack has enough room to cover that worst case and grow the stack if needed. This value doesn't include parameters to the function, since those are already pushed onto the stack by the caller and tracked here, we don't need to double count them here.
	loop           : ^Loop,                            // The current innermost loop being compiled, or nil if not in a loop
	enclosing_class: ^Class_Info,                      // If this is a compiler for a method, keep track of the class enclosing it
	fn             : ^Fn,                          // The function being compiled
	constants      : ^Map,                         // The constants for the function being compiled
	is_initializer : bool,                             // Whether or not the compiler is for a constructor initializer
	num_attributes : int,                              // The num of attributes seen while parsing. We track this separately as compile time attributes are not stored, so we can't rely on attributes.count to enforce an error message when attributes are used anywhere other than methods or classes
	attributes     : ^Map,                         // Attributes for the next class or method
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

Keyword :: struct {
	identifier: string,
	token_kind: Token_Kind,
}

keywords := [?]Keyword {
	{"break", .BREAK},
	{"continue", .CONTINUE},
	{"class", .CLASS},
	{"construct", .CONSTRUCT},
	{"else", .ELSE},
	{"false", .FALSE},
	{"for", .FOR},
	{"foreign", .FOREIGN},
	{"if", .IF},
	{"import", .IMPORT},
	{"as", .AS},
	{"in", .IN},
	{"is", .IS},
	{"null", .NULL},
	{"return", .RETURN},
	{"static", .STATIC},
	{"super", .SUPER},
	{"this", .THIS},
	{"true", .TRUE},
	{"var", .VAR},
	{"while", .WHILE},
}

@private
compiler_init :: proc(compiler: ^Compiler, parser: ^Parser, parent: ^Compiler, is_method: bool) {
	compiler.parser = parser
	compiler.parent = parent
	compiler.loop = nil
	compiler.enclosing_class = nil
	compiler.is_initializer = false

	compiler.fn = nil
	compiler.constants = nil
	compiler.attributes = nil

	parser.vm.compiler = compiler

	// Declare a local slot for either the closure or method receiver so that we
  	// don't try to reuse that slot for a user-defined local variable. For
  	// methods, we name it "this", so that we can resolve references to that like
  	// a normal variable. For functions, they have no explicit "this", so we use
  	// an empty name. That way references to "this" inside a function walks up
  	// the parent chain to find a method enclosing the function whose "this" we
  	// can close over.
	compiler.num_locals = 1
	compiler.num_slots = compiler.num_locals

	if is_method {
		compiler.locals[0].name = "this"
	}

	compiler.locals[0].depth = -1
	compiler.locals[0].is_upvalue = false

	if parent == nil {
		compiler.scope_depth = -1 // Compiling top level code
	} else {
		compiler.scope_depth = 0 // The initial scope is local scope
	}

	compiler.num_attributes = 0
	compiler.attributes = map_make(parser.vm)
	unimplemented()
}

@private
disallow_attributes :: proc(compiler: ^Compiler) {

}

@private
add_to_attribute_group :: proc(compiler: ^Compiler, group, key, value: Value) {

}

@private
emit_class_attributes :: proc(compiler: ^Compiler, class_info: ^Class_Info) {

}

@private
copy_method_attributes :: proc(compiler: ^Compiler, is_foreign: bool, is_static: bool, full_signature: string) {

}

@private
print_error :: proc(parser: ^Parser, line: int, label: string, format: string, args: ..any) {
	parser.has_errors = true
	if !parser.print_errors do return
	if parser.vm.config.error == nil do return
	module_name := parser.module.name.text if parser.module.name.text != "" else "<invalid>"
	err_string := fmt.tprintf(format, args)
	err_string = fmt.tprintf("%s: %s", label, err_string)
	parser.vm.config.error(parser.vm, .Compile, module_name, line, err_string)
}

@private
lex_error :: proc(parser: ^Parser, format: string, args: ..any) {
	print_error(parser, parser.current_line, "Error", format, args)
}

@private
error :: proc(compiler: ^Compiler, format: string, args: ..any) {
	token := compiler.parser.previous
	if token.kind == .ERROR do return // If the parse error was caused by an error token, the lexer has already reported it
	if token.kind == .LINE {
		print_error(compiler.parser, token.line, "Error at newline", format, args)
	} else if token.kind == .EOF {
		print_error(compiler.parser, token.line, "Error at end of file", format, args)
	} else {
		label := fmt.tprintf("Error at '%s'", token.text)
		print_error(compiler.parser, token.line, label, format, args)
	}
}

// Add [constant] to the constant pool and returns it's index
@private
add_constant :: proc(compiler: ^Compiler, constant: Value) -> int {
	if compiler.parser.has_errors do return -1
	// see if we already have a constant for the value, and reuse it if so
	if compiler.constants != nil {
		existing := map_get(compiler.constants, constant)
		if value_is_num(existing) do return cast(int)to_number(existing)
	}
	if len(compiler.fn.constants) < cast(int)MAX_CONSTANTS {
		if value_is_obj(constant) do push_root(compiler.parser.vm, to_object(constant))
		append(&compiler.fn.constants, constant)
		if value_is_obj(constant) do pop_root(compiler.parser.vm)
		if compiler.constants == nil {
			compiler.constants = map_make(compiler.parser.vm)
		}
		map_set(compiler.parser.vm, compiler.constants, constant, to_value(cast(f64)len(compiler.fn.constants) - 1))
	} else {
		error(compiler, "A function may only contain %d unique constants.", MAX_CONSTANTS)
	}
	return len(compiler.fn.constants) - 1
}

// Is valid non-initial identifier character
@private
is_name :: proc(c: rune) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

@private
is_digit :: proc(c: rune) -> bool {
	return c >= '0' && c <= '9'
}

