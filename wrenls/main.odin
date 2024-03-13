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
	caps: lsp.Server_Capabilities
	
	caps.text_document_sync = {
		open_close = true,
		change = .Full,
		save = {include_text = true},
	}

	caps.workspace_symbol_provider = true
	caps.definition_provider = true
	caps.hover_provider = true

	caps.semantic_tokens_provider = {
		full = true,
	}

	result = lsp.Initialize_Result {
		capabilities = caps,
	}

	client_info := params.client_info.? or_else {}
	client_name := client_info.name
	client_version := client_info.version.? or_else "<undefined>"
	client_root_path := params.root_path.? or_else ""
	log.infof("Initialized the language server for '%v'@%v at workspace path '%v'", client_name, client_version, client_root_path)
	return
}

initialized :: proc(params: lsp.Initialized_Params) {
	log.infof("Received initialized notification.")
}

document_open :: proc(params: lsp.Did_Open_Text_Document_Params) {
	log.infof("Text document %v has been opened containing text\n%s", params.text_document.uri, params.text_document.text)
}

logger: lsp.Logger

server := lsp.Server {
	callbacks = {
		on_initialize = initialize,
		on_initialized = initialized,
		on_document_open = document_open,
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
