package wren

import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

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

Token_Kind :: enum {
	ERROR,
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
	module      : ^Module,                          // The module being parsed
	source      : string,                           // The source code being parsed
	token_start : int,                              // The beginning of the currently-being-lexed token in [source]
	ch          : rune,
	offset      : int,
	read_offset : int,
	line_offset : int,
	line_count  : int,
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
lex_error :: proc(parser: ^Parser, format: string, args: ..any) {
	print_error(parser, parser.line_count, "Error", format, args)
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

// Is valid non-initial identifier character
@private
is_name :: proc(c: rune) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

@private
is_digit :: proc(c: rune) -> bool {
	return c >= '0' && c <= '9'
}

compile :: proc(vm: ^VM, module: ^Module, source: string, is_expression: bool, print_errors: bool) -> ^Fn {
	source := source
	// skip utf-8 BOM
	if utf8.rune_at(source, 0) == utf8.RUNE_BOM {
		w := utf8.rune_size(utf8.RUNE_BOM)
		source = source[w:]
	}
	parser: Parser
	parser.vm           = vm
	parser.module       = module
	parser.source       = source
	parser.line_count = 1
	parser.num_parens   = 0
	parser.print_errors = print_errors

	parser.next.kind = .ERROR
	parser.next.value = UNDEFINED_VAL
	
	unimplemented()
}

@private
advance_rune :: proc(p: ^Parser) {
	if p.read_offset < len(p.source) {
		p.offset = p.read_offset
		if p.ch == '\n' {
			p.line_offset = p.offset
			p.line_count += 1
		}
		r, w := rune(p.source[p.read_offset]), 1
		switch {
		case r == 0: lex_error(p, "Illegal character NUL")
		case r >= utf8.RUNE_SELF:
			r, w = utf8.decode_rune_in_string(p.source[p.read_offset:])
			if r == utf8.RUNE_ERROR && w == 1 {
				lex_error(p, "Illegal UTF-8 encoding")
			} else if r == utf8.RUNE_BOM && p.offset > 0 {
				lex_error(p, "Illegal byte order mask")
			}
		}
		p.read_offset += w
		p.ch = r
	} else {
		p.offset = len(p.source)
		if p.ch == '\n' {
			p.line_offset = p.offset
			p.line_count += 1
		}
		p.ch = -1
	}
}

match_char :: proc(parser: ^Parser, c: rune) -> bool {
	if peek_rune(parser) != c do return false
	advance_rune(parser)
	return true
}

@private
make_token :: proc(parser: ^Parser, kind: Token_Kind) {
	parser.next.kind = kind
	//Todo(Dragos): figure out token.text
	parser.next.line = parser.line_offset
	parser.next.text = parser.source[parser.token_start:parser.offset]
	if kind == .LINE do parser.next.line -= 1
}

// If current == [c], make a token of type [two], else [one]
@private
two_char_token :: proc(parser: ^Parser, c: rune, two: Token_Kind, one: Token_Kind) {
	make_token(parser, two if match_char(parser, c) else one)
}

@private
peek_rune :: proc(p: ^Parser, offset := 0) -> rune {
	if p.read_offset + offset < len(p.source) {
		return utf8.rune_at_pos(p.source, p.read_offset + offset)
	}
	return 0
}

@private
peek_byte :: proc(p: ^Parser, offset := 0) -> byte {
	if p.read_offset + offset < len(p.source) {
		return p.source[p.read_offset + offset]
	}
	return 0
}

@private
next_token :: proc(parser: ^Parser) {
	parser.previous, parser.current = parser.current, parser.next
	if parser.next.kind == .EOF do return
	if parser.current.kind == .EOF do return
	parser.token_start = parser.offset
	for parser.offset < len(parser.source) {
		advance_rune(parser)
		c := parser.ch
		switch c {
		case '(':
			// If we are inside an interpolated expr, count the unmatched "("
			if parser.num_parens > 0 do parser.parens[parser.num_parens - 1] += 1
			make_token(parser, .LEFT_PAREN)
			return // Note(Dragos): in a multipass compiler, we would store these in an array

		case ')':
			if parser.num_parens > 0 {
				parser.parens[parser.num_parens - 1] -= 1
				if parser.parens[parser.num_parens - 1] == 0 {
					// This is the final ')', so the interpolation expr has ended, thus beginning the next seection of the template string
					parser.num_parens -= 1
					read_string(parser)
					return
				}
				make_token(parser, .RIGHT_PAREN)
				return
			}
		case '[':
			make_token(parser, .LEFT_BRACKET)
			return
		case ']':
			make_token(parser, .RIGHT_BRACKET)
			return
		case '{':
			make_token(parser, .LEFT_BRACE)
			return
		case '}':
			make_token(parser, .RIGHT_BRACE)
			return
		case ':':
			make_token(parser, .COLON)
			return
		case ',':
			make_token(parser, .COMMA)
			return
		case '*':
			make_token(parser, .STAR)
			return
		case '%':
			make_token(parser, .PERCENT)
		case '#':
			// ignore shebang on the first line
			if parser.line_count == 1 && peek_byte(parser) == '!' && peek_byte(parser, 1) == '/' {
				skip_line_comment(parser)
				break
			}
			make_token(parser, .HASH)
			return
		case '^':
			make_token(parser, .CARET)
			return
		case '+':
			make_token(parser, .PLUS)
			return
		case '-':
			make_token(parser, .MINUS)
			return
		case '~':
			make_token(parser, .TILDE)
			return
		case '?':
			make_token(parser, .QUESTION)
			return
		case '|':
			two_char_token(parser, '|', .PIPEPIPE, .PIPE)
			return
		case '&':
			two_char_token(parser, '&', .AMPAMP, .AMP)
			return
		case '=':
			two_char_token(parser, '=', .EQEQ, .EQ)
			return
		case '!':
			two_char_token(parser, '=', .BANGEQ, .BANG)
			return
		case '.':
			if match_char(parser, '.') {
				two_char_token(parser, '.', .DOTDOTDOT, .DOTDOT)
				return
			}
			make_token(parser, .DOT)
			return
		case '/':
			if match_char(parser, '/') {
				skip_line_comment(parser)
				break
			}
			if match_char(parser, '*') {
				skip_line_comment(parser)
				break
			}
			make_token(parser, .SLASH)
			return
		case '<':
			if match_char(parser, '<') do make_token(parser, .LTLT)
			else do two_char_token(parser, '=', .LTEQ, .LT)
			return
		case '>':
			if match_char(parser, '>') do make_token(parser, .GTGT)
			else do two_char_token(parser, '=', .GTEQ, .GT)
			return
		case '\n':
			make_token(parser, .LINE)
			return
		case ' ', '\r', '\t':
			// Skip forward until we run out of whitespace
			for c := peek_byte(parser); c == ' ' || c == '\r' || c == '\t'; c = peek_byte(parser) {
				advance_rune(parser)
			}
		case '"':
			if peek_byte(parser) == '"' && peek_byte(parser, 1) == '"' {
				read_raw_string(parser)
				return
			}
			read_string(parser)
			return
		case '_':
			read_name(parser, .STATIC_FIELD if peek_byte(parser) == '_' else .FIELD, c)
		case '0':
			if peek_byte(parser) == 'x' {
				read_hex_number(parser)
				return
			}
			read_number(parser)
			return
		case:
			if is_name(c) {
				read_name(parser, .NAME, c)
			} else if is_digit(c) {
				read_number(parser)
			} else {
				if c >= 32 && c <= 126 {
					lex_error(parser, "Invalid character '%c'.", c)
				} else {
					// Note(Dragos): This isn't entirely accurate anymore, since we are trying to utf8 decode it... let's see how things behave in testing
					// Don't show non-ASCII values since we didn't UTF-8 decode the
					// bytes. Since there are no non-ASCII byte values that are
					// meaningful code units in Wren, the lexer works on raw bytes,
					// even though the source code and console output are UTF-8.
					lex_error(parser, "Invalid byte 0x%x.", u8(c))
				}
				parser.next.kind = .ERROR
			}
			return
		}
	}
	// If we get here, we're out of source, so just make EOF tokens
	parser.token_start = parser.offset // Note(Dragos): is this correct?
	make_token(parser, .EOF)
}

@private
skip_line_comment :: proc(parser: ^Parser) {

}

@private
read_raw_string :: proc(parser: ^Parser) {

}

@private
read_name :: proc(parser: ^Parser, kind: Token_Kind, first_char: rune) {

}

@private
read_hex_number :: proc(parser: ^Parser) {

}

@private
read_number :: proc(parser: ^Parser) {

}

@private
read_string :: proc(parser: ^Parser) {

}