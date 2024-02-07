package lsp

import "core:encoding/json"
import "core:io"
import "core:log"
import "core:mem"

// Note(Dragos): This callback will evolve as we need features. Ideally we want the main server to just register callbacks in the lsp package.
//  so we'd need a better naming convention for being able to create both clients and servers with this pattern
// Note(Dragos): we want to remove the writer dependency probably. 
// Note(Dragos): we need to handle errors too
Request_Callback :: #type proc(id: Request_Id, params: any, writer: io.Writer)

Notification_Callback :: #type proc(params: any)


Request_Info :: struct {
	params: typeid,
	result: typeid,
	callback: Request_Callback,
}

Notification_Info :: struct {
	params: typeid,
	callback: Notification_Callback,
}

request_map := map[string]Request_Info {
	"initialize" = {
		params = Initialize_Params,
		result = Initialize_Result,
	},
}

notification_map := map[string]Notification_Info {
	"initialized" = {
		
	},
}

register_request_callback :: proc(method: string, callback: Request_Callback) -> (ok: bool) {
	info := (&request_map[method]) or_return
	info.callback = callback
	return true
}

log_json_message :: proc(msg: json.Object) {
	opts: json.Marshal_Options
	opts.pretty = true
	data, err := json.marshal(msg, opts, context.temp_allocator)
	if err == nil {
		log.infof("Received message: %v", transmute(string)data)
	} else {
		log.warnf("Failed to log a received message: %v", err)
	}
	
}

handle_json_message :: proc(msg: json.Object, writer: io.Writer) {
	method := msg["method"].(string)
	if request_info, is_request := request_map[method]; is_request {
		if request_info.callback != nil {
			msg_id, has_id := msg["id"]
			if !has_id {
				log.errorf("Failed to retrieve request id for method `%s`", method)
			}
			id: Request_Id
			#partial switch v in msg_id {
			case string: id = v
			case i64: id = v
			case: log.error("Failed to cast the request id"); return
			}
			params: any
			if unmarshal, has_unmarshal := unmarshal_map[request_info.params]; has_unmarshal {
				json_params := msg["params"]
				params = unmarshal(json_params)
			}
			request_info.callback(id, params, writer)
			
		}
	}

	log_json_message(msg)
}