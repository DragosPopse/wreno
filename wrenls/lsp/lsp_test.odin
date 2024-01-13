package lsp

import tests "core:testing"
import "core:fmt"
import "core:os"
import "core:io"
import "core:encoding/json"

@test
test_send :: proc(T: ^tests.T) {
    writer := os.stream_from_handle(os.stdout)
    msg: Response_Message
    msg.jsonrpc = "2.0.0"
    msg.id = 1
    msg.result = Initialize_Result {
        capabilities = Server_Capabilities {
            workspaceSymbolProvider = true,
        },
    }
    ok := send(msg, writer)
    fmt.printf("\n") // Send prints to stdout and it doesn't newline
    tests.expect(T, ok, "Failed to send message")
}