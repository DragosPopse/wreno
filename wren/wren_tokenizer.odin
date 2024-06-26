package wren

import "core:strings"
import "core:fmt"
import "core:strconv"
import "core:unicode"
import "core:log"
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

	_Keyword_Begin,
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
	_Keyword_End,

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

tokens := [Token_Kind]string {
	.Error          = "Invalid",
	.Left_Paren     = "(",
	.Right_Paren    = ")",
	.Left_Bracket   = "[",
	.Right_Bracket  = "]",
	.Left_Brace     = "{",
	.Right_Brace    = "}",
	.Colon          = ":",
	.Dot            = ".",
	.Dot_Dot        = "..",
	.Dot_Dot_Dot    = "...",
	.Comma          = ",",
	.Star           = "*",
	.Slash          = "/",
	.Percent        = "%",
	.Hash           = "#",
	.Plus           = "+",
	.Minus          = "-",
	.Lt_Lt          = "<<",
	.Gt_Gt          = ">>",
	.Pipe           = "|",
	.Pipe_Pipe      = "||",
	.Caret          = "^",
	.Amp            = "&",
	.Amp_Amp        = "&&",
	.Bang           = "!",
	.Tilde          = "~",
	.Question       = "?",
	.Eq             = "=",
	.Lt             = "<",
	.Gt             = ">",
	.Lt_Eq          = "<=",
	.Gt_Eq          = ">=",
	.Eq_Eq          = "==",
	.Bang_Eq        = "!=",
	._Keyword_Begin = "",
	.Break          = "break",
	.Continue       = "continue",
	.Class          = "class",
	.Construct      = "construct",
	.Else           = "else",
	.False          = "false",
	.For            = "for",
	.Foreign        = "foreign",
	.If             = "if",
	.Import         = "import",
	.As             = "as",
	.In             = "in",
	.Is             = "is",
	.Null           = "null",
	.Return         = "return",
	.Static         = "static",
	.Super          = "super",
	.This           = "this",
	.True           = "true",
	.Var            = "var",
	.While          = "while",
	._Keyword_End   = "",
	.Field          = "field",
	.Static_Field   = "static field",
	.Name           = "name",
	.Number         = "number",
	.String         = "string",
	.Interpolation  = "interpolation",
	.Line           = "newline",
	.Comment        = "comment",
	.EOF            = "EOF",
}

token_to_string :: proc(tok: Token) -> string {
	return tokens[tok.kind]
}

token_kind_to_string :: proc(kind: Token_Kind) -> string {
	return tokens[kind]
}

token_string :: proc {
	token_to_string,
	token_kind_to_string,
}

/*
	Note(Dragos): Should the token have pos+end or just pos? Odin's tokenizer does just pos, and leaves the parser to have end of expressions. I don't really know.
	A single pos behaves well on trivial tokens, but becomes false on things like raw strings
	Note(Dragos): Raw strings and strings give us a pos that begins with the quotes. I don't think it should, but we will see
*/
Token :: struct {
	kind : Token_Kind,
	text : string,       // Points directly into the source
	pos  : Token_Pos,    // Position in source code
	value: Value,        // The parsed value if the token is a literal
}

Token_Pos :: struct {
	file  : string,
	offset: int,
	line  : int,
	column: int,
}

token_pos_relative :: proc(pos: Token_Pos, relative_to: Token_Pos) -> (result: Token_Pos) {
	result.line = pos.line - relative_to.line
	if pos.line == relative_to.line {
		result.column = pos.column - relative_to.column
	} else {
		result.column = pos.column
	}
	log.infof("pos relative_to %v %v", pos.column, relative_to.column)
	result.offset = pos.offset
	return result
}

default_token :: proc() -> Token {
	return Token {
		kind  = .Error,
		value = UNDEFINED_VAL,
	}
}

Tokenizer :: struct {
	file       : string,
	source     : string,
	ch         : rune,                             // the most recent rune
	offset     : int,                              // offset of [ch]
	read_offset: int,                              // the next rune offset
	line_offset: int,
	line_count : int,
	parens     : [MAX_INTERPOLATION_NESTING]int,   // Tracks the lexing state when tokenizing interpolated strings
	num_parens : int,
	error_count: int,
	err        : Error_Handler,
}

Error_Handler :: #type proc(pos: Token_Pos, format: string, args: ..any)

default_error_handler :: proc(pos: Token_Pos, format: string, args: ..any) {
	fmt.eprintf("%s(%d:%d): ", pos.file, pos.line, pos.column)
	fmt.eprintf(format, ..args)
	fmt.eprintf("\n")
}

tokenizer_init :: proc(t: ^Tokenizer) {
	t.line_count = 1
	t.ch = ' '
}

default_tokenizer :: proc(source: string) -> (t: Tokenizer) {
	tokenizer_init(&t)
	t.source = source
	t.err = default_error_handler
	return t
}

offset_to_pos :: proc(t: ^Tokenizer, offset: int) -> (pos: Token_Pos) {
	pos.offset = offset
	pos.line = t.line_count
	pos.column = offset - t.line_offset + 1
	pos.file = t.file
	return pos
}

// Is valid non-initial identifier character
@private
is_name :: #force_inline proc(c: rune) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

@private
is_digit :: #force_inline proc(c: rune) -> bool {
	return c >= '0' && c <= '9'
}

@private
is_hex_digit :: #force_inline proc(c: rune) -> bool {
	switch c {
	case '0'..='9', 'a'..='f', 'A'..='F': return true
	}
	return false
}

@private
skip_whitespace :: proc(t: ^Tokenizer) {
	for do switch t.ch {
	case ' ',  '\t', '\r': advance_rune(t)
	case                 : return
	}
}

// TODO(Dragos): I only use this for a quick hack for scanning a number. FIX
@private
is_whitespace_or_lf :: proc(r: rune) -> bool {
	switch r {
	case ' ', '\t', '\r', '\n': return true
	}
	return false
}

// TODO(DRAGOS): ADD PROPER ERROR HANDLING PROCEDURES. NO PRINTF NONSENSE

@private
lex_error :: proc(t: ^Tokenizer, offset: int, format: string, args: ..any) {
	t.error_count += 1
	if t.err != nil {
		pos := offset_to_pos(t, offset)
		t.err(pos, format, ..args)
	}
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
		case r == 0: lex_error(t, t.offset, "Illegal character NUL")
		case r >= utf8.RUNE_SELF:
			r, w = utf8.decode_rune_in_string(t.source[t.read_offset:])
			if r == utf8.RUNE_ERROR && w == 1 {
				lex_error(t, t.offset, "Illegal UTF-8 encoding")
			} else if r == utf8.RUNE_BOM && t.offset > 0 {
				lex_error(t, t.offset, "Illegal byte order mask")
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
		lex_error(t, offset, "Comment not terminated.")
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

scan2 :: proc(t: ^Tokenizer) -> (token: Token, ok: bool) {
	skip_whitespace(t)
	start_offset := t.offset
	token = default_token()
	is_trivial := true
	switch t.ch {
	case '^': token.kind = .Caret
	case '+': token.kind = .Plus
	case '-': token.kind = .Minus
	case '~': token.kind = .Tilde
	case '?': token.kind = .Question
	case: is_trivial     = false
	}
	return
}

scan :: proc(t: ^Tokenizer) -> (token: Token, ok: bool) {
	skip_whitespace(t)
	offset := t.offset
	token = default_token()
	ch := t.ch
	if ch == -1 {
		token.kind = .EOF
		token.pos = offset_to_pos(t, t.offset)
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

	case ')':
		if t.num_parens > 0 {
			t.parens[t.num_parens - 1] -= 1
			if t.parens[t.num_parens - 1] == 0 {
				advance_rune(t)
				// The interpolation expr has ended, thus beginning the next section of the template string
				t.num_parens -= 1
				token.pos = offset_to_pos(t, offset)
				token.text, token.kind = scan_string(t)
				return token, true // Todo(dragos): make this correct
			}
		}
		token.kind = .Right_Paren

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
			token.pos = offset_to_pos(t, offset)
			token.text = scan_raw_string(t)
			advance_rune(t)
			advance_rune(t)
			advance_rune(t)
		} else {
			//token.pos = offset_to_pos(t, offset)
			advance_rune(t)
			token.text, token.kind = scan_string(t)
		}
	
	case '\n':
		token.kind = .Line // Note(Dragos): How is this handled in comment blocks?
	}
	
	if token.text == "" {
		token.text = t.source[offset : t.read_offset]
		// Note(dragos): every token is responsible for advancing itself. When token.text == "", we assume that there is 1 rune that we need to pass so that the next scan is fresh. This holds true for trivial tokens like single or 2char tokens.
		advance_rune(t)
	}
	if token.pos == {} {
		token.pos = offset_to_pos(t, offset)
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

	// Todo(dragos): Handle hex. assign token.value literal 
@private
scan_number :: proc(t: ^Tokenizer) -> (text: string, value: Value) {
	offset := t.offset
	is_hex := false
	if t.ch == '0' {
		next := cast(rune)peek_byte(t)
		switch next {
		case 'x', 'X':
			is_hex = true
			advance_rune(t)
			advance_rune(t)
		case '.':
		case: // TODO(DRAGOS): figure out a better way to handle 0. This seems a bit of a hack right now
			if !is_whitespace_or_lf(auto_cast peek_byte(t)) {
				lex_error(t, offset, "Expected either '.' or 'x' for a number literal starting with 0")
			}
			
		}
	}

	is_digit := is_digit if !is_hex else is_hex_digit
	
	for is_digit(t.ch) do advance_rune(t)
	if !is_hex {
		if t.ch == '.' && is_digit(cast(rune)peek_byte(t)) {
			advance_rune(t)
			for is_digit(t.ch) do advance_rune(t)
		}
		if t.ch == 'e' || t.ch == 'E' {
			advance_rune(t)
			if t.ch == '-' || t.ch == '+' do advance_rune(t)
			if !is_digit(t.ch) do lex_error(t, offset, "Undetermined scientific notation.")
			for is_digit(t.ch) do advance_rune(t)
		}
	}
	return t.source[offset : t.offset], UNDEFINED_VAL
}

// Note(Dragos): Should this be allocated by the vm?
// TODO(Dragos): Add some asserts on the raw advance_rune(t) calls
@private
scan_string :: proc(t: ^Tokenizer) -> (text: string, kind: Token_Kind) {
	offset := t.offset
	kind = .String
	end_minus := 1
	for {
		ch := t.ch
		if ch == '\n' || ch < 0 {
			lex_error(t, t.offset, "String was not terminated.")
			break
		}
		
		if ch == '"' {
			advance_rune(t)
			break
		}
		if ch == '\\' { // Note(Dragos): Scanning doesn't *copy* the string, so we can only check if its correct the escape
			advance_rune(t)
			switch t.ch {
			case '"': // todo the rest
			}
			break
		}
		if ch == '%' {
			if t.num_parens < MAX_INTERPOLATION_NESTING {
				advance_rune(t)
				if t.ch != '(' do lex_error(t, t.offset, "Expected '(' after '%%'.")
				advance_rune(t)
				t.parens[t.num_parens] = 1
				t.num_parens += 1
				kind = .Interpolation
				end_minus = 2
				break
			}
			lex_error(t, t.offset, "Interpolation may only nest %d levels deep.", MAX_INTERPOLATION_NESTING)
		}
		advance_rune(t)
	}
	return t.source[offset : t.offset - end_minus], kind
}

@private
scan_raw_string :: proc(t: ^Tokenizer) -> (text: string) {
	advance_rune(t)
	advance_rune(t)
	advance_rune(t)
	offset := t.offset

	for {
		advance_rune(t)
		if t.ch == -1 {
			lex_error(t, t.offset, "Unterminated raw string.")
			break
		}
		c := t.ch
		c1 := peek_byte(t)
		c2 := peek_byte(t, 1)
		if c == '"' && c1 == '"' && c2 == '"' do break

	}
	return t.source[offset : t.offset] // We will add 3 to get the entire token. We need to check this if it's correct
}

// Break a token that spans across multiple lines into multiple tokens. It's useful for the LSP
// This will return a slice of tokens that all share the same type. 
// TODO(DRAGOS): figure out the columns properly now. It's not enough to break by line. The columns need to match too now
break_multiline_token :: proc(token: Token, allocator := context.allocator) -> (tokens: []Token) {
	parts := strings.split(token.text, "\n", context.temp_allocator)
	tokens = make([]Token, len(parts))
	for part, i in parts {
		token := token
		//log.infof("pos.line i result: %v %v %v", token.pos.line, i, token.pos.line + i)
		token.pos.line += i // TODO(Dragos): change the rest of the positions.
		token.text = part
		if i != 0 do token.pos.column = 1 // TODO(Dragos): This is a hack that assumes the multiline token starts at 0 again. It should work fine, but it's wonky
		tokens[i] = token
		//log.infof("Appended token: %v", tokens[i])
	}
	return tokens
}