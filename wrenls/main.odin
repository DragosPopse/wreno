package wrenls

import "core:net"
import "core:encoding/json"

import "core:fmt"
import "core:log"
import "core:io"
import "core:os"
import "core:thread"
import "core:sync"
import "core:strings"
import "core:strconv"

import "lsp"
import "../wren"

running := false // Note(Dragos): Move this somewhere else probably. A Server struct maybe?


initialize :: proc(id: lsp.Request_Id, params: lsp.Initialize_Params) -> (result: lsp.Initialize_Result, error: Maybe(lsp.Response_Error)) {
	result = lsp.Initialize_Result {
		capabilities = {
			semanticTokensProvider = {
				full = true,
				range = false, // Note(Dragos): I believe this requires some sort of incremental parsing
				legend = {}, // Note(Dragos): This needs to be filled in
			},
		},
	}

	client_info := params.client_info.? or_else {}
	client_name := client_info.name
	client_version := client_info.version.? or_else "<undefined>"
	client_root_path := params.root_path.? or_else ""
	log.infof("Initialized the language server for '%v'@%v at workspace path '%v'", client_name, client_version, client_root_path)
	return
}

logger: lsp.Logger

server := lsp.Server {
	callbacks = {
		on_initialize = initialize,
	},
}

main :: proc() {
	// Note(Dragos): Temporary reader/writer/logger initialization. We need to figure out how to make this properly threaded
	lsp.server_init_stdio(&server)
	lsp.logger_init(&logger, .Debug, server.write, server.write)
	running = true
	context.logger = logger
	context.assertion_failure_proc = lsp.default_assertion_failure_proc
	for lsp.poll_message(&server) {
		
		free_all(context.temp_allocator)
	}
}
