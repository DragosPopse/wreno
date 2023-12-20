package wren

import "core:strings"
import "core:fmt"
import "core:strconv"
import "core:unicode"
import "core:unicode/utf8"

Token_Kind :: enum {
	Error,
	Left_Paren,
	Right_Paren,
	Left_Bracket,
	Right_Bracket,
	Left_Brace,
	Right_Brace,
	Colon,
	Dot,
	Dot_Dot,
	Dot_Dot_Dot,
	Comma,
	Star,
	Slash,
	Percent,
	Hash,
	Plus,
	Minus,
	Lt_Lt,
	Gt_Gt,
	Pipe,
	Pipe_Pipe,
	Caret,
	Amp,
	Amp_Amp,
	Bang,
	Tilde,
	Question,
	Eq,
	Lt,
	Gt,
	Lt_Eq,
	Gt_Eq,
	Eq_Eq,
	Bang_Eq,

	Break,
	Continue,
	Class,
	Construct,
	Else,
	False,
	For,
	Foreign,
	If,
	Import,
	As,
	In,
	Is,
	Null,
	Return,
	Static,
	Super,
	This,
	True,
	Var,
	While,

	Field,
	Static_Field,
	Name,
	Number,
	
	// A string literal without any interpolation, or the last section of a
	// string following the last interpolated expression.
	String,
	
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
	Interpolation,
	
	Line,

	// Note(Dragos): we'll try to add comments as tokens too, will be useful
	Comment,
	
	EOF,
}

Token :: struct {
	kind : Token_Kind,
	text : string,       // Points directly into the source
	line : int,          // 1-based line where the token appears
	value: Value,        // The parsed value if the token is a literal
}

default_token :: proc() -> Token {
	return Token {
		kind  = .Error,
		line  = 0,
		value = UNDEFINED_VAL,
	}
}

Tokenizer :: struct {
	vm         : ^VM,                              // a vm is required to allocate Token.value when needed
	module     : ^Module,                          // module being tokenized
	source     : string,
	ch         : rune,                             // the most recent rune
	offset     : int,                              // offset of [ch]
	read_offset: int,                              // the next rune offset
	line_offset: int,
	line_count : int,
	parens     : [MAX_INTERPOLATION_NESTING]int,   // Tracks the lexing state when tokenizing interpolated strings
	num_parens : int,
	tokens     : [dynamic]Token,
	has_errors : bool,
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

@private
skip_whitespace :: proc(t: ^Tokenizer) {
	for do switch t.ch {
	case ' ',  '\t', '\r': advance_rune(t)
	case                 : return
	}
}

@private
lex_error :: proc(t: ^Tokenizer, format: string, args: ..any) {
	//print_error(parser, parser.line_count, "Error", format, args)
	fmt.print("Lexing Error: ", "")
	fmt.printf(format, args)
	fmt.println()
}

@private
advance_rune :: proc(t: ^Tokenizer) {
	if t.read_offset < len(t.source) {
		t.offset = t.read_offset
		if t.ch == '\n' {
			t.line_offset = t.offset
			t.line_count += 1
		}
		r, w := rune(t.source[t.read_offset]), 1
		switch {
		case r == 0: lex_error(t, "Illegal character NUL")
		case r >= utf8.RUNE_SELF:
			r, w = utf8.decode_rune_in_string(t.source[t.read_offset:])
			if r == utf8.RUNE_ERROR && w == 1 {
				lex_error(t, "Illegal UTF-8 encoding")
			} else if r == utf8.RUNE_BOM && t.offset > 0 {
				lex_error(t, "Illegal byte order mask")
			}
		}
		t.read_offset += w
		t.ch = r
	} else {
		t.offset = len(t.source)
		if t.ch == '\n' {
			t.line_offset = t.offset
			t.line_count += 1
		}
		t.ch = -1
	}
}

@private
advance_if_next :: proc(t: ^Tokenizer, next_c: rune) -> bool {
	if cast(rune)peek_byte(t) != next_c do return false
	advance_rune(t)
	return true
}

Keyword :: struct {
	identifier: string,
	token_kind: Token_Kind,
}

keywords := [?]Keyword {
	{"break", .Break},
	{"continue", .Continue},
	{"class", .Class},
	{"construct", .Construct},
	{"else", .Else},
	{"false", .False},
	{"for", .For},
	{"foreign", .Foreign},
	{"if", .If},
	{"import", .Import},
	{"as", .As},
	{"in", .In},
	{"is", .Is},
	{"null", .Null},
	{"return", .Return},
	{"static", .Static},
	{"super", .Super},
	{"this", .This},
	{"true", .True},
	{"var", .Var},
	{"while", .While},
}


@private
peek_byte :: proc(t: ^Tokenizer, offset := 0) -> byte {
	if t.read_offset + offset < len(t.source) {
		return t.source[t.read_offset + offset]
	}
	return 0
}

@private
scan_comment :: proc(t: ^Tokenizer) -> string {
	offset := t.offset
	advance_rune(t)
	general: {
		if t.ch == '/' || t.ch == '!' {
			for peek_byte(t) != '\n' && t.ch >= 0 {
				advance_rune(t)
			}
			break general
		}
		advance_rune(t)
		nest := 1
		for t.ch >= 0 && nest > 0 {
			ch := t.ch
			advance_rune(t)
			if ch == '/' && t.ch == '*' {
				nest += 1
			}
			if ch == '*' && t.ch == '/' {
				nest -= 1
				advance_rune(t)
				if nest == 0 do break general
			}
		}
		lex_error(t, "Comment not terminated.")
	}
	lit := t.source[offset : t.offset]
	
	// Strip CR for line comments
	for len(lit) > 2 && lit[1] == '/' && lit[len(lit) - 1] == '\r' {
		lit = lit[:len(lit) - 1]
	}
	return lit
}

@private
scan_maybe_two_char_token :: proc(t: ^Tokenizer, next_c: rune, if_next_match: Token_Kind, if_next_not_match: Token_Kind) -> Token_Kind {
	if cast(rune)peek_byte(t) == next_c {
		advance_rune(t)
		return if_next_match
	}
	return if_next_not_match
}

scan :: proc(t: ^Tokenizer) -> (token: Token, ok: bool) {
	advance_rune(t) // Note(Dragos): Should we only advance rune when at the beginning of it? Let's see later...
	skip_whitespace(t)
	offset := t.offset
	token = default_token()
	ch := t.ch
	if ch == -1 {
		token.kind = .EOF
		token.line = t.line_count
		token.text = "<eof>"
		token.value = UNDEFINED_VAL
		return token, false
	}

	switch ch {
	case:
		if is_name(ch) {
			token.text, token.kind = scan_name(t)
		} else if is_digit(ch) {
			token.text, token.value = scan_number(t)
			token.kind = .Number
		}

	case '(':
		if t.num_parens > 0 do t.parens[t.num_parens - 1] += 1
		token.kind = .Left_Paren
		token.line = t.line_count
		token.text = t.source[offset:t.read_offset]
	case ')':
		if t.num_parens > 0 {
			t.parens[t.num_parens - 1] -= 1
			if t.parens[t.num_parens - 1] == 0 {
				// The interpolation expr has ended, thus beginning the next section of the template string
				t.num_parens -= 1
				scan_string(t)
				return token, true // Todo(dragos): make this correct
			}
			token.kind = .Right_Paren
		}
	case '[': token.kind = .Left_Bracket
	case ']': token.kind = .Right_Bracket
	case '{': token.kind = .Left_Brace
	case '}': token.kind = .Right_Brace
	case ':': token.kind = .Colon
	case ',': token.kind = .Comma
	case '*': token.kind = .Star
	case '%': token.kind = .Percent
	case '#':
		// ignore shebang on the first line
		if t.line_count == 1 && peek_byte(t) == '!' && peek_byte(t, 1) == '/' {
			token.text = scan_comment(t)
			token.kind = .Comment
			break
		}
		token.kind = .Hash

	case '^': token.kind = .Caret
	case '+': token.kind = .Plus
	case '-': token.kind = .Minus
	case '~': token.kind = .Tilde
	case '?': token.kind = .Question
	case '|': token.kind = scan_maybe_two_char_token(t, '|', .Pipe_Pipe, .Pipe)
	case '&': token.kind = scan_maybe_two_char_token(t, '&', .Amp_Amp, .Amp)
	case '=': token.kind = scan_maybe_two_char_token(t, '=', .Eq_Eq, .Eq)
	case '!': token.kind = scan_maybe_two_char_token(t, '=', .Bang_Eq, .Bang)

	case '.':
		token.kind = .Dot
		if peek_byte(t) == '.' {
			advance_rune(t)
			token.kind = scan_maybe_two_char_token(t, '.', .Dot_Dot_Dot, .Dot_Dot)
		}

	case '/': // Note(dragos): simplify this...
		token.kind = .Slash
		next := peek_byte(t)
		if next == '/' || next == '*' {
			when !BLOCK_COMMENT_LINE_AT_END {
				line := t.line_count
				defer token.line = line
			}
			token.text = scan_comment(t) // Note(Dragos): Do we want the line of a block comment to be the one declared on, or the last one?
			token.kind = .Comment
			
		}

	case '<':
		if advance_if_next(t, '<') do token.kind = .Lt_Lt
		else do token.kind = scan_maybe_two_char_token(t, '=', .Lt_Eq, .Lt)

	case '>':
		if advance_if_next(t, '>') do token.kind = .Gt_Gt
		else do token.kind = scan_maybe_two_char_token(t, '=', .Gt_Eq, .Gt)
	
	case '"':
		token.kind = .String
		if peek_byte(t) == '"' && peek_byte(t, 1) == '"' {
			// Todo(dragos): scan_raw_string
		} else {
			token.text = scan_string(t)
		}
	
	case '\n':
		token.kind = .Line // Note(Dragos): How is this handled in comment blocks?
	}
	
	if token.text == "" {
		token.text = t.source[offset:t.read_offset]
	}
	if token.line == 0 {
		token.line = t.line_count
	}
	
	return token, true
}


// Todo(Dragos): allocate the name in the vm at some point
@private
scan_name :: proc(t: ^Tokenizer) -> (name: string, kind: Token_Kind) {
	offset := t.offset
	kind = .Name
	if t.ch == '_' {
		kind = .Field
		if peek_byte(t) == '_' do kind = .Static_Field
	}
	for is_name(t.ch) || is_digit(t.ch) do advance_rune(t)
	name = t.source[offset : t.offset]
	for keyword in keywords do if keyword.identifier == name {
		return name, keyword.token_kind // Note(dragos): should we return the name in source here, or the keyword directly?
	}
	// Todo(Dragos): assign the "value" of the token aswell
	return name, kind
}

@private
scan_number :: proc(t: ^Tokenizer) -> (text: string, value: Value) {
	offset := t.offset
	for is_digit(t.ch) do advance_rune(t)
	if t.ch == '.' && is_digit(cast(rune)peek_byte(t, 1)) {
		advance_rune(t)
		for is_digit(t.ch) do advance_rune(t)
	}
	if t.ch == 'e' || t.ch == 'E' {
		advance_rune(t)
		if t.ch == '-' || t.ch == '+' do advance_rune(t)
		if !is_digit(t.ch) do lex_error(t, "Undetermined scientific notation.")
		for is_digit(t.ch) do advance_rune(t)
	}
	// Todo(dragos): handle scientific. Handle minus (or not, it's an operator?). Convert the token to a Value literal
	return t.source[offset : t.offset], UNDEFINED_VAL
}

// Note(Dragos): Should this be allocated by the vm?
@private
scan_string :: proc(t: ^Tokenizer) -> (text: string) {
	advance_rune(t)
	offset := t.offset
	for {
		ch := t.ch
		if ch == '\n' || ch < 0 {
			lex_error(t, "String was not terminated.")
			break
		}
		
		if ch == '"' {
			break
		}
		if ch == '\\' {
			// Todo(dragos): scan escapes
		}
		if ch == '%' {
			// Todo(Dragos): interpolation
		}
		advance_rune(t)
	}
	return t.source[offset : t.offset]
}