package wrenls

import "core:net"
import "core:encoding/json"
import "../wren"

import "core:fmt"
import "core:log"
import "core:io"
import "core:os"
import "core:thread"
import "core:sync"
import "core:strings"
import "core:strconv"



running := false // Note(Dragos): Move this somewhere else probably. A Server struct maybe?

main :: proc() {
	fmt.printf("Starting Odin Language Server\n")
	// Note(Dragos): Temporary reader/writer/logger initialization. We need to figure out how to make this properly threaded
	reader, reader_ok := io.to_reader(os.stream_from_handle(os.stdin))
	writer, writer_ok := io.to_writer(os.stream_from_handle(os.stdout))
	lsp_log: LSP_Logger
	lsp_log.writer = writer
	logger := lsp_logger(&lsp_log)
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

Request_Id :: union {
	string,
	i64,
}

Request :: struct {
	id: Request_Id,
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

Header :: struct {
	content_length: int,
	content_type: string,
}

parse_header :: proc(reader: io.Reader) -> (header: Header, ok: bool) {	
	sb := strings.builder_make(context.temp_allocator)
	found_content_length := false
	sb_writer := strings.to_writer(&sb)
	// A tee reader will write to Writer what it reads from Reader
	tee_reader_data: io.Tee_Reader
	tee_reader_data.r = reader
	tee_reader_data.w = sb_writer // Every time we read, the string builder will be populated. This is, therefore, a populist pattern
	tee_reader := io.tee_reader_to_reader(&tee_reader_data)
	for {
		strings.builder_reset(&sb)
		for ch, _, err := io.read_rune(tee_reader); ch != '\n'; ch, _, err = io.read_rune(tee_reader) {
			if err != nil {
				log.error("Failed to read delimiter <newline>, got %v", err)
				return {}, false
			}
		}
		message := strings.to_string(sb)
		if len(message) < 2 || message[len(message) - 2] != '\r' {
			log.error("No carriage return in header")
			return {}, false
		}
		if len(message) == 2 {
			assert(message == "\r\n", "Expected the header to end in CRLF")
			break
		}
		
		index := strings.last_index_byte(message, ':')
		if index == -1 {
			log.error("Failed to find semicolon in message %s", message)
			break
		}
		header_name := message[:index]
		header_value := message[len(header_name) + 2 : len(message) - 2]
		switch header_name {
		case "Content-Length":
			if len(header_value) == 0 {
				log.error("Header %s has no value", header_name)
				return {}, false
			}
			value, value_parsed := strconv.parse_int(header_value)
			if !value_parsed {
				log.error("Failed to parse content length value")
				return {}, false
			}
			header.content_length = value
			found_content_length = true
		case "Content-Type":
			if len(header_value) == 0 {
				log.error("Header %s has no value", header_name)
				return {}, false
			}
			header.content_type = header_value
		}
	}
	return header, found_content_length
}

// Note(Dragos): These things will be put in different files, maybe even packages
// Note(Dragos): This project will eventually be split into jsonrpc, lsp, wrenls packages. 
// Note(Dragos): Aim to publish jsonrpc and lsp as individual packages. 

