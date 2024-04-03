package wren

// TODO(Dragos): Write the compiler as it is in the C code, then modify it to build an AST



Parser2 :: struct {
    file: ^File,
    t: Tokenizer,
    warn: Error_Handler,
    err: Error_Handler,
    
    prev: Token, // previous token
    curr: Token, // current token

    error_count: int,
    warning_count: int,

    peeking: bool,
}

zero_parser :: #force_inline proc(p: ^Parser2) {
    p.prev = {}
    p.curr = {}
    p.t = {}
}

parse_err :: proc(p: ^Parser2, pos: Token_Pos, msg: string, args: ..any) {
    if p.err != nil {
        p.err(pos, msg, ..args)
    }
    p.error_count += 1
}

parse_warn :: proc(p: ^Parser2, pos: Token_Pos, msg: string, args: ..any) {
    if p.warn != nil {
        p.warn(pos, msg, ..args)
    }
    p.warning_count += 1
}

// TODO(Dragos): We need to test this for strings and raw strings
token_end_pos :: proc(tok: Token) -> Token_Pos {
    pos := tok.pos
    pos.offset += len(tok.text)
    if tok.kind == .Comment {
        if tok.text[:2] != "/*" {
            pos.column += len(tok.text)
        } else {
            for i := 0; i < len(tok.text); i += 1 {
                c := tok.text[i]
                if c == '\n' {
                    pos.line += 1
                    pos.column = 1
                } else {
                    pos.column += 1
                }
            }
        }
    } else {
        pos.column += len(tok.text)
    }
    return pos
}

default_parser :: proc() -> Parser2 {
    return Parser2 {
        err = default_error_handler,
        warn = default_error_handler,
    }
}

next_token0 :: proc(p: ^Parser2) -> (not_eof: bool) {
    p.curr, not_eof = scan(&p.t)
    return not_eof
}

// TODO(Dragos): Improve this
consume_comment_groups :: proc(p: ^Parser2, prev: Token) {
    for p.curr.kind == .Comment {
        next_token0(p)
    }
}

advance_token :: proc(p: ^Parser2) -> Token {
    p.prev = p.curr
    prev := p.prev
    if next_token0(p) {
        consume_comment_groups(p, prev)
    }
    return prev
}

expect_token :: proc(p: ^Parser2, kind: Token_Kind, msg: string) -> Token {
    prev := p.curr
    if prev.kind != kind {
        expected := token_string(kind)
        got := token_string(prev)
        parse_err(p, prev.pos, "expected '%s', got '%s'", expected, got)
    }
    advance_token(p)
    return prev
}

expect_token_after :: proc(p: ^Parser2, kind: Token_Kind, msg: string) -> Token {
    prev := p.curr
    if prev.kind != kind {
        expected := token_string(kind)
        got := token_string(prev)
        parse_err(p, prev.pos, "expected '%s' after %s, got '%s'", expected, msg, got)
    }
    advance_token(p)
    return prev
}

allow_token :: proc(p: ^Parser2, kind: Token_Kind) -> bool {
    if p.curr.kind == kind {
        advance_token(p)
        return true
    }
    return false
}

end_of_line_pos :: proc(p: ^Parser2, tok: Token) -> Token_Pos {
    offset := clamp(tok.pos.offset, 0, len(p.t.source) - 1)
    s := p.t.source[offset:]
    pos := tok.pos
    pos.column -= 1
    for len(s) != 0 && s[0] != 0 && s[0] != '\n' {
        s = s[1:]
        pos.column += 1
    }
    return pos
}

parser_parse_file :: proc(p: ^Parser2, file: ^File) {
    zero_parser(p)
    p.file = file
    p.t.err = p.err
    tokenizer_init(&p.t)
    p.t.source = file.src
    p.t.file = file.path
}