package lsp

import "core:runtime"
import "core:strings"
import "core:log"
import "core:fmt"
import "core:io"
import "core:os"

LSP_Logger :: struct {
	writer: io.Writer,
}

lsp_logger :: proc(logger: ^LSP_Logger, 
	lowest: log.Level = .Debug, 
	opts: log.Options = log.Default_Console_Logger_Opts
) -> log.Logger {
	return {
		lsp_logger_proc,
		logger,
		lowest,
		opts,
	}
}

lsp_logger_proc :: proc(
	data: rawptr, 
	level: log.Level, 
	text: string, 
	options: log.Options, 
	location :=  #caller_location
) {
	data := cast(^LSP_Logger)data
	message := text
	message_type: Diagnostic_Severity
	switch level {
	case .Debug:         message_type = .Hint
	case .Info:          message_type = .Information
	case .Warning:       message_type = .Warning
	case .Error, .Fatal: message_type = .Error
	}

	notif := Notification_Message {
		jsonrpc = "2.0",
		method = "window/logMessage",
		params = Notification_Logging_Params {
			type = message_type,
			message = message,
		},
	}

	send(notif, data.writer)
}


write_caller_location :: proc(sb: ^strings.Builder, loc: runtime.Source_Code_Location) {
	strings.write_string(sb, loc.file_path)
	when ODIN_ERROR_POS_STYLE == .Default {
		strings.write_byte(sb, '(')
		strings.write_u64(sb, u64(loc.line))
		strings.write_byte(sb, ':')
		strings.write_u64(sb, u64(loc.column))
		strings.write_byte(sb, ')')
	} else when ODIN_ERROR_POS_STYLE == .Unix {
		strings.write_byte(sb, ':')
		write_u64(sb, u64(loc.line))
		strings.write_byte(sb, ':')
		write_u64(sb, u64(loc.column))
		strings.write_byte(sb, ':')
	} else {
		#panic("unhandled ODIN_ERROR_POS_STYLE")
	}
}

default_assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
	sb := strings.builder_make(context.temp_allocator)
	when !ODIN_DISABLE_ASSERT {
		write_caller_location(&sb, loc)
		strings.write_string(&sb, " ")
	}
	strings.write_string(&sb, prefix)
	if len(message) > 0 {
		strings.write_string(&sb, ": ")
		strings.write_string(&sb, message)
	}
	//strings.write_byte(&sb, '\n')
	notif := Notification_Message {
		jsonrpc = "2.0",
		method = "window/logMessage",
		params = Notification_Logging_Params {
			type = .Error,
			message = strings.to_string(sb),
		},
	}
	send(notif, os.stream_from_handle(os.stderr))
	runtime.trap() // Note(Dragos): Instead of trapping, maybe we can send an error and shut down the server?
}