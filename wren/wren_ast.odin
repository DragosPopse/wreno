package wren

import "core:mem"
import I "base:intrinsics"
import "core:os"

node_new_from_pos :: proc($T: typeid, pos, end: Token_Pos, allocator := context.allocator) -> ^T {
    n, _ := mem.new(T)
    n.pos = pos
    n.end = end
    n.derived = n

    // dummy checks
    base: ^Node = n
    _ = base

    when I.type_has_field(T, "derived_expr") do n.derived_expr = n
    when I.type_has_field(T, "derived_stmt") do n.derived_stmt = n

    return n
}

node_new :: proc($T: typeid, allocator := context.allocator) -> ^T {
    return node_new_from_pos(T, {}, {}, allocator)
}

Node :: struct {
    pos: Token_Pos,
    end: Token_Pos,
    derived: Any_Node,
}

File :: struct { // a module
    using node: Node,
    path: string,
    src: string,
    stmts: [dynamic]^Stmt,
}

file_new :: proc(path: string) -> ^File {
    src, src_ok := os.read_entire_file(path)
    if !src_ok do return nil
    file := node_new(File)
    file.path = path
    file.src = transmute(string)src
    file.stmts = make([dynamic]^Stmt, context.allocator)
    return file
}

Expr :: struct {
    using expr_base: Node,
    derived_expr: Any_Expr,
}

Unary_Expr :: struct {
    using node: Expr,
    op: Token,
    expr: ^Expr,
}

Binary_Expr :: struct {
    using node: Expr,
    left: ^Expr,
    op: Token,
    right: ^Expr,
}

Stmt :: struct {
    using stmt_base: Node,
    derived_stmt: Any_Stmt,
}

Var_Stmt :: struct {
    using node: Stmt,
    keyword: Token,
    name: Token,
    initializer: ^Expr,
}


Bad_Expr :: struct {
    using expr: Expr,
}

Bad_Stmt :: struct {
    using stmt: Stmt,
}

Any_Node :: union {
    ^File,
    ^Bad_Expr,

    ^Bad_Stmt,
    ^Var_Stmt,
}

Any_Expr :: union {
    ^Bad_Expr,
}

Any_Stmt :: union {
    ^Bad_Stmt,
    ^Var_Stmt,
}