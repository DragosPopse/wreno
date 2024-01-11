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
	fmt.printf("Starting Odin Language Server\n")
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
		// Consume requests
	}
}

Request :: struct {
	id: lsp.RequestId,
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
	request_data := cast(^Request_Thread_Data)data
	
	for running {
		context.logger = request_data.logger

	}
}




// Note(Dragos): These things will be put in different files, maybe even packages
// Note(Dragos): This project will eventually be split into jsonrpc, lsp, wrenls packages. 
// Note(Dragos): Aim to publish jsonrpc and lsp as individual packages. 

