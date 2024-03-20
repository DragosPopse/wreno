package wrenls

import "core:net"
import "core:encoding/json"

import "core:fmt"
import "core:log"
import "core:io"
import "core:path/filepath"
import "core:os"
import "core:thread"
import "core:sync"
import "core:strings"
import "core:strconv"

import "lsp"
import "../wren"

running := false // Note(Dragos): Move this somewhere else probably. A Server struct maybe?

Wren_File :: struct {

}

wren_files: map[string]Wren_File

token_encoder: lsp.Token_Encoder

tokenizer_error_handler :: proc(t: ^wren.Tokenizer, format: string, args: ..any) {
	log.errorf(format, args)
}


initialize :: proc(id: lsp.Request_Id, params: lsp.Initialize_Params) -> (result: lsp.Initialize_Result, error: Maybe(lsp.Response_Error)) {
	caps: lsp.Server_Capabilities

	// TODO(Dragos): modify this to satisfy wren specs
	lsp.token_encoder_init(
		encoder = &token_encoder,
		token_set = {
			.Namespace,
			.Class,
			.Parameter,
			.Variable,
			.Method,
			.Keyword,
			.Number,
			.String,
		},
		modifier_set = {
			.Declaration,
			.Definition,
			.Static,
			.Deprecated,
		},
	)

	client_semantic_tokens, client_semantic_tokens_ok := params.capabilities.text_document.semantic_tokens.?
	
	if client_semantic_tokens_ok {
		token_types := client_semantic_tokens.token_types
		token_modifiers := client_semantic_tokens.token_modifiers
		log.infof("Client semtokens: %v", token_types)
		log.infof("Client tok mods: %v", token_modifiers)
	}

	caps.text_document_sync = {
		open_close = true,
		change = .Full,
		save = {include_text = true},
	}

	caps.workspace_symbol_provider = true
	caps.definition_provider = true
	caps.hover_provider = true

	token_types, token_modifiers := lsp.token_encoder_make_capability_slices(token_encoder, context.temp_allocator)
	
	log.infof("Server tokens: %v\n %#v", token_types, token_encoder.token_indices)
	log.infof("Server modifiers: %v\n %#v", token_modifiers, token_encoder.modifier_bits)
	log.infof("Example encoded modifiers %v == %b", lsp.Semantic_Token_Modifiers{.Static, .Declaration, .Deprecated}, lsp.encode_token_modifiers(token_encoder, {.Static, .Declaration, .Deprecated}))
	
	caps.semantic_tokens_provider = {
		full = true,
		legend = { // TODO: cannot slice enumerated arrays wtf
			token_types = token_types,
			token_modifiers = token_modifiers,
		},
	}
	
	caps.document_link_provider = { resolve_provider = false }

	completion_trigger_characters := []string {"."}
	signature_trigger_characters := []string {"(", ","}
	signature_retrigger_characters := []string {","} 

	result = lsp.Initialize_Result {
		capabilities = caps,
	}

	client_info := params.client_info.? or_else {}
	client_name := client_info.name
	client_version := client_info.version.? or_else "<undefined>"
	client_root_path := params.root_path.? or_else ""
	
	walk_workspace_folder_proc :: proc(info: os.File_Info, in_err: os.Errno, user_data: rawptr) -> (err: os.Errno, skip_dir: bool) {
		is_dir := info.is_dir
		fullpath := info.fullpath
		if is_dir do return
		file_ext := filepath.ext(fullpath)
		if file_ext == ".wren" {
			persistent_fullpath := strings.clone(fullpath, context.allocator)
			wren_files[persistent_fullpath] = Wren_File{}
			log.infof("Tracking wren file '%s' at path `%s`", info.name, filepath.dir(fullpath, context.temp_allocator))
		}
		return
	}

	filepath.walk(client_root_path, walk_workspace_folder_proc, nil)

	log.infof("Initialized the language server for '%v'@%v at workspace path '%v'", client_name, client_version, client_root_path)
	return
}

semantic_tokens_full :: proc(id: lsp.Request_Id, params: lsp.Semantic_Tokens_Params) -> (result: lsp.Semantic_Tokens, err: Maybe(lsp.Response_Error)) {
	log.infof("Requested semantic tokens for document %s", params.text_document.uri)
	document_path, document_path_ok := lsp.uri_to_filepath(params.text_document.uri, context.temp_allocator)
	log.infof("URI converted to %s", document_path)

	file_data, file_data_ok := os.read_entire_file(document_path, context.temp_allocator) // TODO(dragos): figure out a way to cache this. It will be quite inneficient to read the file every time

	source := transmute(string)file_data

	tokenizer := wren.default_tokenizer(source)
	
	tokenizer.err = tokenizer_error_handler
	
	for token in wren.scan(&tokenizer) {
		log.infof("Got token %v", token)
	}
	

	return result, nil
}

initialized :: proc(params: lsp.Initialized_Params) {
	log.infof("Received initialized notification.")
}

document_open :: proc(params: lsp.Did_Open_Text_Document_Params) {
	//log.infof("Text document %v has been opened containing text\n%s", params.text_document.uri, params.text_document.text)
}

logger: lsp.Logger

server := lsp.Server {
	callbacks = {
		on_initialize = initialize,
		on_initialized = initialized,
		on_document_open = document_open,
		on_semantic_tokens_full = semantic_tokens_full,
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
