package wren

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

}

Compiler :: struct {
	
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

