package lsp

import "core:unicode/utf8"
import "core:strings"
import "core:strconv"
import "core:fmt"

uri_is_file :: proc(uri: string) -> bool {
    return strings.has_prefix(uri, "file:")
}

uri_to_filepath :: proc(uri: string, allocator := context.allocator) -> (path: string, ok: bool) {
    assert(uri_is_file(uri), "uri_to_filepath: URI is not a file")
    builder := strings.builder_make(allocator)
    starts := "file:///"
    start_index := len(starts)
    uri := uri[start_index:]
    for i := 0; i < len(uri); i += 1 {
        c := uri[i]
        if c == '%' { // Decode the %. It's an escape character followed by 2 HEX digits
            if i + 2 < len(uri) {
                v, ok := strconv.parse_i64_of_base(uri[i + 1 : i + 3], 16)
                if !ok {
                    strings.builder_destroy(&builder)
                    return
                }
                strings.write_byte(&builder, cast(byte)v)
            } else {
                strings.builder_destroy(&builder)
                return
            }
        } else {
            strings.write_byte(&builder, uri[i])
        }
    }
    return strings.to_string(builder), true
}