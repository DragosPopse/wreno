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
	fn             : ^Fn,                              // The function being compiled
	constants      : ^Map,                             // The constants for the function being compiled
	is_initializer : bool,                             // Whether or not the compiler is for a constructor initializer
	num_attributes : int,                              // The num of attributes seen while parsing. We track this separately as compile time attributes are not stored, so we can't rely on attributes.count to enforce an error message when attributes are used anywhere other than methods or classes
	attributes     : ^Map,                             // Attributes for the next class or method
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
	compiler.fn = fn_make(parser.vm, parser.module, compiler.num_locals)
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
error :: proc(compiler: ^Compiler, format: string, args: ..any) {
	token := compiler.parser.previous
	if token.kind == .Error do return // If the parse error was caused by an error token, the lexer has already reported it
	if token.kind == .Line {
		print_error(compiler.parser, token.pos.line, "Error at newline", format, args)
	} else if token.kind == .EOF {
		print_error(compiler.parser, token.pos.line, "Error at end of file", format, args)
	} else {
		label := fmt.tprintf("Error at '%s'", token.text)
		print_error(compiler.parser, token.pos.line, label, format, args)
	}
}

// Add [constant] to the constant pool and returns it's index
@private
add_constant :: proc(compiler: ^Compiler, constant: Value) -> int {
	if compiler.parser.has_errors do return -1
	// see if we already have a constant for the value, and reuse it if so
	if compiler.constants != nil {
		existing := map_get(compiler.constants, constant)
		if is_number(existing) do return cast(int)to_number(existing)
	}
	if len(compiler.fn.constants) < cast(int)MAX_CONSTANTS {
		if is_object(constant) do push_root(compiler.parser.vm, to_object(constant))
		append(&compiler.fn.constants, constant)
		if is_object(constant) do pop_root(compiler.parser.vm)
		if compiler.constants == nil {
			compiler.constants = map_make(compiler.parser.vm)
		}
		map_set(compiler.parser.vm, compiler.constants, constant, to_value(cast(f64)len(compiler.fn.constants) - 1))
	} else {
		error(compiler, "A function may only contain %d unique constants.", MAX_CONSTANTS)
	}
	return len(compiler.fn.constants) - 1
}

// Create a new local variable with [name]. Assuems the current scope is local and the name is unique
@private
add_local :: proc(compiler: ^Compiler, name: string) -> int {
	local := &compiler.locals[compiler.num_locals]
	local.name = name
	local.is_upvalue = false
	local.depth = compiler.scope_depth
	compiler.num_locals += 1
	return compiler.num_locals - 1
}

// Declares a variable in the current scope whose name is the given token.
//
// If [token] is `NULL`, uses the previously consumed token. Returns its symbol.
@private
compiler_declare_variable :: proc(compiler: ^Compiler, token: ^Token) {
	if token == nil {
		unimplemented("token = &compiler->parser->previous")
	}
	if len(token.text) > MAX_VARIABLE_NAME {
		error(compiler, "Variable name cannot be longer than %d characters.", MAX_VARIABLE_NAME)
	}

	// top level module scope
	if compiler.scope_depth == -1 {
		line := -1
		unimplemented()
	}
}

compile :: proc(vm: ^VM, module: ^Module, source: string, is_expression: bool, print_errors: bool) -> ^Fn {
	source := source
	// skip utf-8 BOM
	if utf8.rune_at(source, 0) == utf8.RUNE_BOM {
		w := utf8.rune_size(utf8.RUNE_BOM)
		source = source[w:]
	}

	unimplemented()
}

// Emits one single-byte argument. Returns it's index
@private
emit_byte :: proc(compiler: ^Compiler, byte: byte) -> int {
	append(&compiler.fn.code, byte)
	// Assume the instruction is assocciated with the most recently consumed token
	append(&compiler.fn.debug.source_lines, compiler.parser.previous.pos.line)
	return len(compiler.fn.code) - 1
}

// Emits one bytecode instruction
@private
emit_op :: proc(compiler: ^Compiler, instruction: Code) {
	emit_byte(compiler, auto_cast instruction)
	
	// keep track of the stack's high water mark
	compiler.num_slots += stack_effects[instruction]
	if compiler.num_slots > compiler.fn.max_slots {
		compiler.fn.max_slots = compiler.num_slots
	}
}

// Emits one 16-bit argument, written big endian
@private
emit_short :: proc(compiler: ^Compiler, arg: i16) {
	emit_byte(compiler, byte((arg >> 8) & 0xFF))
	emit_byte(compiler, byte(arg & 0xFF))
} 

// Note(Dragos): I'm not sure if this abstraction is gonna do any good. 
// Emits one bytecode instruction followed by a 8-bit argument. Returns the index of the argument in bytecode
@private
emit_byte_arg :: proc(compiler: ^Compiler, instruction: Code, arg: byte) -> int {
	emit_op(compiler, instruction)
	return emit_byte(compiler, arg)
}

@private
emit_short_arg :: proc(compiler: ^Compiler, instruction: Code, arg: i16) {
	emit_op(compiler, instruction)
	emit_short(compiler, arg)
}

// Emits [instruction] followed by a placeholder for a jump offset. 
// The placeholder can be patched by calling [jump_patch]. 
// Returns the index of the placeholder
@private
emit_jump :: proc(compiler: ^Compiler, instruction: Code) -> int {
	emit_op(compiler, instruction)
	emit_byte(compiler, 0xff)
	return emit_byte(compiler, 0xff) - 1
}

// Creates a new constant for the current value and emits the bytecode to load
// it from the constant table.
@private
emit_constant :: proc(compiler: ^Compiler, value: Value) {
	constant := add_constant(compiler, value)
	emit_short_arg(compiler, .CONSTANT, cast(i16)constant)
}