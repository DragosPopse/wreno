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

main :: proc() {
	// fmt.printf("Starting Odin Language Server\n") // For history. This has caused a weeklong connection crash because i forgot that stdio is reserved. OK
	// Note(Dragos): Temporary reader/writer/logger initialization. We need to figure out how to make this properly threaded
	reader, reader_ok := io.to_reader(os.stream_from_handle(os.stdin))
	writer, writer_ok := io.to_writer(os.stream_from_handle(os.stdout))
	lsp_log: lsp.LSP_Logger
	lsp_log.writer = writer
	logger := lsp.lsp_logger(&lsp_log)
	assert(reader_ok, "Cannot create reader")
	assert(writer_ok, "Cannot create writer")
	running = true

	request_thread_data := Request_Thread_Data {
		reader = reader,// Note(Dragos): Need to figure out storage of these
		writer = writer,
		logger = logger,
	}

	request_thread := thread.create_and_start_with_data(&request_thread_data, request_thread_main)
	for running {
		context.logger = logger
		context.assertion_failure_proc = lsp.default_assertion_failure_proc
		sync.sema_wait(&requests_sem)
		// Consume requests

		// Note(Dragos) from ols: why do we need this temp request things? Doesn't seem to make much sense
		temp_requests := make([dynamic]Request, 0, context.temp_allocator)
		sync.mutex_lock(&requests_mutex)
			for req in requests {
				append(&temp_requests, req)		
			}

			request_index := 0
			for ; request_index < len(temp_requests); request_index += 1 {
				request := temp_requests[request_index]
				root := request.value.(json.Object)
				method := root["method"].(json.String)
				if method == "initialize" {
					client_params := root["params"].(json.Object)
					client_info := client_params["clientInfo"].(json.Object)
					client_name := client_info["name"].(json.String)
					client_version := client_info["version"].(json.String)
					client_root_path := client_params["rootPath"].(json.String) // note(dragos): this can be null if the file is open without a folder?
					client_root_uri := client_params["rootUri"].(json.String)
					// Todo(Dragos): lsp.Client_Capabilities
					
					response: lsp.Response_Message
					response.jsonrpc = "2.0.0"
					response.id = root["id"].(json.Integer)
					response.result = lsp.Initialize_Result {
						capabilities = {
							semanticTokensProvider = {
								full = true,
								range = false, // Note(Dragos): I believe this requires some sort of incremental parsing
								legend = {}, // Note(Dragos): This needs to be filled in
							},
						},
					}
					lsp.send(response, writer)
					
					log.infof("Initialized the language server for '%v'@%v at workspace path '%v'\n", client_name, client_version, client_root_path)
					assert(false, "HAHAHHAHAHAH")
				}
				json.destroy_value(request.value) // Note(Dragos): Figure out a better allocation method.
			}

			for i := 0; i < request_index; i += 1 {
				pop_front(&requests)
			}
		sync.mutex_unlock(&requests_mutex)	

		if request_index != len(temp_requests) {
			sync.sema_post(&requests_sem)
		}

		free_all(context.temp_allocator) // Note(Dragos): Is the temp allocator thread_local? I believe so
	}
}

Request :: struct {
	id: lsp.Request_Id,
	value: json.Value,
	is_notification: bool,
}

requests: [dynamic]Request
requests_sem: sync.Sema
requests_mutex: sync.Mutex

Request_Thread_Data :: struct {
	reader: io.Reader,
	writer: io.Writer,
	logger: log.Logger,
}

request_thread_main :: proc(data: rawptr) {
	data := cast(^Request_Thread_Data)data
	
	for running {
		context.logger = data.logger
		context.assertion_failure_proc = lsp.default_assertion_failure_proc // Note(Dragos): Figure out a way to set this in a single place.
		header, header_ok := lsp.parse_header(data.reader)
		if !header_ok {
			log.error("Failed to read and parse header")
			return
		}
		body, body_ok := lsp.parse_body(data.reader, header)
		if !body_ok {
			log.error("Failed to read and parse body")
			return // Note(Dragos): These returns seem...crashful
		}

		root, root_is_object := body.(json.Object)
		if !root_is_object {
			log.error("No root object")
			return
		}

		id: lsp.Request_Id
		id_value, id_value_exists := root["id"]
		if id_value_exists {
			#partial switch v in id_value {
			case json.String:  id = v
			case json.Integer: id = v
			case:              id = 0
			}
		}

		if sync.guard(&requests_mutex) {
			method := root["method"].(json.String)
			if method == "$/cancelRequest" {
				// Todo(Dragos): handle cancels
			} else {
				append(&requests, Request{id = id, value = root})
				sync.sema_post(&requests_sem)
			}
		}

		free_all(context.temp_allocator)
	}
}
