package wren

import "core:fmt"

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
    next_token0(p)

    return prev
}

consume_comments :: proc(p: ^Parser2) {
    for p.curr.kind == .Comment {
        
    }
}

expect_token :: proc(p: ^Parser2, kind: Token_Kind) -> Token {
    prev := p.curr
    if prev.kind != kind {
        expected := token_string(kind)
        got := token_string(prev)
        parse_err(p, prev.pos, "expected '%s', got '%s'", expected, got)
    }
    advance_token(p)
    return prev
}

peek_token :: proc(p: ^Parser2, lookahead := 0) -> Token {
    prev_parser := p^
    p.peeking = true
    defer {
        p^ = prev_parser
        p.peeking = false
    }
    p.t.err = nil
    for i := 0; i <= lookahead; i += 1 {
        advance_token(p)
    }
    return p.curr
}

peek_token_kind :: proc(p: ^Parser2, kind: Token_Kind, lookahead := 0) -> bool {
    prev_parser := p^
    p.peeking = true
    defer {
        p^ = prev_parser
        p.peeking = false
    }
    p.t.err = nil
    for i in 0..=lookahead {
        advance_token(p)
    }

    return p.curr.kind == kind
}

expect_newline :: proc(p: ^Parser2, kind: Token_Kind) -> Token {
    line := expect_token(p, .Line)
    // Consume all subsequent lines
    for p.curr.kind == .Line do advance_token(p)
    return line
}

consume_newlines :: proc(p: ^Parser2) {
    for p.curr.kind == .Line do advance_token(p)
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
    
    advance_token(p)
    for p.curr.kind != .EOF {
        consume_newlines(p)
        stmt := parse_stmt(p)
        append(&file.stmts, stmt)
    }
}

parse_class_decl :: proc(p: ^Parser2) -> (class_decl: ^Class_Stmt) {
    class_tok := expect_token(p, .Class)
    class_name := expect_token(p, .Name)
    superclass_name: Maybe(Token)
    if allow_token(p, .Is) {
        superclass_name = expect_token(p, .Name)
    }
    body := parse_class_body(p)
    class_decl = node_new_from_pos(Class_Stmt, class_tok.pos, token_end_pos(body.close))
    class_decl.keyword = class_tok
    class_decl.name = class_name
    class_decl.superclass = superclass_name
    class_decl.body = body
    
    return class_decl
}

parse_class_body :: proc(p: ^Parser2) -> (body: ^Class_Body_Stmt) {
    open := expect_token(p, .Left_Brace)
    consume_newlines(p)
    methods := make([dynamic]^Any_Method_Definition_Stmt, context.allocator)
    for token := peek_token(p); token.kind != .Right_Brace; token = peek_token(p) {
        method := parse_any_method_decl(p)
        append(&methods, method)
    }
    close := expect_token(p, .Right_Brace)
    body = node_new_from_pos(Class_Body_Stmt, open.pos, token_end_pos(close))
    body.open = open
    body.close = close
    body.methods = methods[:]
    return body
}

parse_any_method_decl :: proc(p: ^Parser2) -> (method_decl: ^Any_Method_Definition_Stmt) {
    tok := peek_token(p)
    #partial switch tok.kind {
    case .Name: // setter, getter, or normal method
        name := expect_token(p, .Name)
        next := peek_token(p)
        #partial switch next.kind {
        case .Eq: // setter
            op := expect_token(p, .Eq)
            
        case .Left_Brace: // getter
        }
    case .Left_Bracket: // subscript or subscript assignment

    case:
        parse_err(p, tok.pos, "Expected beginning of a method declaration, found '%v'", tok.text)
    }
    return method_decl
}

parse_block_stmt :: proc(p: ^Parser2) -> (block: ^Block_Stmt) {
    return block
}

parse_def_params_stmt :: proc(p: ^Parser2) -> (params: ^Definition_Params_Stmt) {

    return params
}

parse_stmt :: proc(p: ^Parser2) -> (stmt: ^Stmt) {
    #partial switch p.curr.kind {
    case .Class:
        class_tok := expect_token(p, .Class)
        class_name := expect_token(p, .Name)
        superclass_name: Maybe(Token)
        
        if allow_token(p, .Is) {
            superclass_name = expect_token(p, .Name)
        }
        open := expect_token(p, .Left_Brace)
        consume_newlines(p)
        for token := peek_token(p); token.kind != .Right_Brace; token = peek_token(p) {
            #partial switch token.kind {
            case .Name,
                 .Star,
                 .Slash,
                 .Percent: // Method TODO(Dragos): Should operator overload have a different "signature kind"?
                
            case .Plus,
                 .Minus: // Method too, but they also allow to be unary
                
                
            case .Construct: // Constructor
            }
        }
        close := expect_token(p, .Right_Brace)
        class_stmt := node_new_from_pos(Class_Stmt, class_tok.pos, close.pos, context.allocator)
        class_stmt.keyword = class_tok
        class_stmt.name = class_name
        class_stmt.superclass = superclass_name
        fmt.printf("Found class %v\n", class_stmt)
        return class_stmt
    }

    return nil
}