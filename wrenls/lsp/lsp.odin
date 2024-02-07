/*
	This file will try to enclose all the lsp protocol specs. 
	Note(Dragos): try to document this as needed, as we go
	The aim should be to finally separate this in it's own package
	Note(Dragos): it seems that the types are also defined by name, should we keep it? e.g. CompletionOptions vs Completion_Options
	Note(Dragos): In addition, should the properties be snake_case in our code and then marshal them to camelCase later?
	Note(dragos): should we enclose `:?` types into `Maybe` types?
*/
package lsp

VERSION_MAJ :: 3
VERSION_MIN :: 17
VERSION_STR :: "3.17"

import "core:io"
import "core:encoding/json"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:log"
import "core:os"

Type_Hierarchy_Item :: struct {
	// todo
}

Request_Id :: union {
	string,
	i64,
}


Symbol_Tag :: enum {
	Deprecated = 1,
}

Header :: struct {
	content_length: int,
	content_type: string,
}

URI :: string
Document_Uri :: string

Package :: struct {
	name         : string,
	base         : string,
	base_original: string,
	original     : string,
}

// Note(Dragos): This is not defined by LSP per se. What should we do?
Request_Type :: enum {
	Initialize,
	Initialized,
	Shutdown,
	Exit,
	Did_Open,
	Did_Change,
	Did_Close,
	Did_Save,
	Definition,
	Completion,
	Signature_Help,
	Document_Symbol,
	Semantic_Tokens_Full,
	Semantic_Tokens_Range,
	Format_Document,
	Hover,
	Cancel_Request,
	Inlay_Hint,
}


/*
RequestInfo :: struct {
	root:     json.Value,
	params:   json.Value,
	document: ^Document,
	id:       RequestId,
	config:   ^common.Config,
	writer:   ^Writer,
	result:   common.Error,
}
*/


Diagnostic_Severity :: enum {
	Error       = 1,
	Warning     = 2,
	Information = 3,
	Hint        = 4,
}

Position :: struct {
	line     : int,
	character: int,
}

Range :: struct {
	start: Position,
	end  : Position,
}

Location :: struct {
	uri  : string,
	range: Range,
}

Diagnostic :: struct {
	range   : Range,
	severity: Diagnostic_Severity,
	code    : string,
	message : string,
}



Save_Options :: struct {
	includeText: bool,
}

Text_Document_Sync_Options :: struct {
	openClose: bool,
	change   : int,
	save     : Save_Options,
}

// Note(Dragos): this extends WorkDoneProgressOptions. Should we add that? OLS doesn't. Test later
Completion_Options :: struct {
	resolveProvider  : bool,
	triggerCharacters: []string,
	completionItem   : struct {
		labelDetailsSupport: bool,
	}
}

Signature_Help_Options :: struct {
	triggerCharacters  : []string,
	retriggerCharacters: []string,
}

Semantic_Tokens_Legend :: struct {
	tokenTypes    : []string,
	tokenModifiers: []string,
}

Semantic_Tokens_Options :: struct {
	legend: Semantic_Tokens_Legend,
	range : bool,
	full  : bool,
}

Document_Link_Options :: struct {
	resolveProvider: bool,
}

// Note(Dragos): We'll leave the names not snake_case to see if it works, then we'll do some json:"_" magic
Server_Capabilities :: struct {
	textDocumentSync          : Text_Document_Sync_Options,
	definitionProvider        : bool,
	completionProvider        : Completion_Options,
	signatureHelpProvider     : Signature_Help_Options,
	semanticTokensProvider    : Semantic_Tokens_Options,
	documentSymbolProvider    : bool,
	hoverProvider             : bool,
	documentFormattingProvider: bool,
	inlayHintProvider         : bool,
	renameProvider            : bool,
	referenceProvider         : bool,
	workspaceSymbolProvider   : bool,
	documentLinkProvider      : Document_Link_Options,
}

Server_Info :: struct {
	name   : string,
	version: string,
}



Completion_Item_Kind :: enum {
	Text          = 1,
	Method        = 2,
	Function      = 3,
	Constructor   = 4,
	Field         = 5,
	Variable      = 6,
	Class         = 7,
	Interface     = 8,
	Module        = 9,
	Property      = 10,
	Unit          = 11,
	Value         = 12,
	Enum          = 13,
	Keyword       = 14,
	Snippet       = 15,
	Color         = 16,
	File          = 17,
	Reference     = 18,
	Folder        = 19,
	Enum_Member    = 20,
	Constant      = 21,
	Struct        = 22,
	Event         = 23,
	Operator      = 24,
	TypeParameter = 25,
}

Completion_Item :: struct {
	label: string,
	kind: Completion_Item_Kind,
}

Completion_List :: struct {
	isIncomplete: bool,
	items: []Completion_Item,
}

Signature_Information :: struct {
	label        : string,
	documentation: string,
	parameters   : []Parameter_Information,
}

Parameter_Information  :: struct {
	label: string,
}

Signature_Help :: struct {
	signatures     : []Signature_Information,
	activeSignature: int,
	activeParameter: int,
}

Symbol_Kind :: enum {
	File          = 1,
	Module        = 2,
	Namespace     = 3,
	Package       = 4,
	Class         = 5,
	Method        = 6,
	Property      = 7,
	Field         = 8,
	Constructor   = 9,
	Enum          = 10,
	Interface     = 11,
	Function      = 12,
	Variable      = 13,
	Constant      = 14,
	String        = 15,
	Number        = 16,
	Boolean       = 17,
	Array         = 18,
	Object        = 19,
	Key           = 20,
	Null          = 21,
	Enum_Member    = 22,
	Struct        = 23,
	Event         = 24,
	Operator      = 25,
	Type_Parameter = 26,
}

Document_Symbol :: struct {
	name: string,
	kind: Symbol_Kind,
	range: Range,
	selection_range: Range `json:"selectionRange"`,
	children: []Document_Symbol,
}

Semantic_Tokens :: struct {
	data: []u32,
}

Markup_Content :: struct {
	kind : string,
	value: string,
}

Hover :: struct {
	contents: Markup_Content,
	range   : Range,
}

Text_Edit :: struct {
	range  : Range,
	new_text: string `json:"newText"`,
}

Insert_Replace_Edit :: struct {
	insert : Range,
	new_text: string `json:"newText"`,
	replace: Range,
}

Inlay_Hint_Kind :: enum {
	Type      = 1,
	Parameter = 2,
}

Inlay_Hint :: struct {
	position: Position,
	kind    : Inlay_Hint_Kind,
	label   : string,
}

Document_Link_Client_Capabilities :: struct {
	tooltip_support: bool `json:"tooltipSupport"`,
}

Text_Document_Identifier :: struct {
	uri: string,
}

Document_Link_Params :: struct {
	textDocument: Text_Document_Identifier,
}

Document_Link :: struct {
	range  : Range,
	target : string,
	tooltip: string,
}

Workspace_Symbol :: struct {
	name: string,
	kind: Symbol_Kind,
	location: Location,
}

Text_Document_Item :: struct {
	uri : string,
	text: string,
}

Optinal_Versioned_Text_Document_Identifier :: struct {
	uri    : string,
	version: Maybe(int),
}

Text_Document_Edit :: struct {
	textDocument: Optinal_Versioned_Text_Document_Identifier,
	edits: []Text_Edit,
}

Workspace_Edit :: struct {
	documentChanges: []Text_Document_Edit,
}




Error_Code :: enum {
	// Defined by JSON-RPC
	Parse_Error      = -32700,
	Invalid_Request  = -32600,
	Method_Not_Found = -32601,
	Invalid_Params   = -32602,
	Internal_Error   = -32603,

	/**
	 * This is the range of JSON-RPC reserved error codes.
	 * It doesn't denote a real error code. No LSP error codes should
	 * be defined between the start and end range. For backwards
	 * compatibility the `ServerNotInitialized` and the `UnknownErrorCode`
	 * are left in the range.
	 *
	 * @since 3.16.0
	 */
	JSONRPC_Reserved_Error_Range_Start = -32099,
	Server_Not_Initialized             = -32002,
	Unknown_Error_Code                 = -32001,
	JSONRPC_Reserved_Error_Range_End   = -32000,

	/**
	 * This is the start range of LSP reserved error codes.
	 * It doesn't denote a real error code.
	 *
	 * @since 3.16.0
	 */
	LSP_Reserved_Error_Range_Start = -32899,

	/**
	 * A request failed but it was syntactically correct, e.g the
	 * method name was known and the parameters were valid. The error
	 * message should contain human readable information about why
	 * the request failed.
	 *
	 * @since 3.17.0
	 */
	Request_Failed = -32803,

	/**
	 * The server cancelled the request. This error code should
	 * only be used for requests that explicitly support being
	 * server cancellable.
	 *
	 * @since 3.17.0
	 */
	Server_Cancelled = -32802,

	/**
	 * The server detected that the content of a document got
	 * modified outside normal conditions. A server should
	 * NOT send this error code if it detects a content change
	 * in it unprocessed messages. The result even computed
	 * on an older state might still be useful for the client.
	 *
	 * If a client decides that a result is not of any use anymore
	 * the client should cancel the request.
	 */
	Content_Modified = -32801,

	/**
	 * The client has canceled a request and a server has detected
	 * the cancel.
	 */
	Request_Cancelled = -32800,

	/**
	 * This is the end range of LSP reserved error codes.
	 * It doesn't denote a real error code.
	 *
	 * @since 3.16.0
	 */
	LSP_Reserved_Error_Range_End = -32800,
}



/**
 * Completion item tags are extra annotations that tweak the rendering of a
 * completion item.
 *
 * @since 3.15.0
 */
Completion_Item_Tag :: enum {
	/**
	 * Render a completion as obsolete, usually using a strike-out.
	 */
	Deprecated = 1,
}

/**
 * How whitespace and indentation is handled during completion
 * item insertion.
 *
 * @since 3.16.0
 */
Insert_Text_Mode :: enum {
	/**
	 * The insertion or replace strings is taken as it is. If the
	 * value is multi line the lines below the cursor will be
	 * inserted using the indentation defined in the string value.
	 * The client will not apply any kind of adjustments to the
	 * string.
	 */
	As_Is = 1,

	/**
	 * The editor adjusts leading whitespace of new lines so that
	 * they match the indentation up to the cursor of the line for
	 * which the item is accepted.
	 *
	 * Consider a line like this: <2tabs><cursor><3tabs>foo. Accepting a
	 * multi line completion item is indented using 2 tabs and all
	 * following lines inserted will be indented using 2 tabs as well.
	 */
	Adjust_Indentation = 2,
}

Prepare_Support_Default_Behavior :: enum {
	/**
	 * The client's default behavior is to select the identifier
	 * according to the language's syntax rule.
	 */
	Identifier = 1,
}

/**
 * The diagnostic tags.
 *
 * @since 3.15.0
 */
Diagnostic_Tag :: enum {
	/**
	 * Unused or unnecessary code.
	 *
	 * Clients are allowed to render diagnostics with this tag faded out
	 * instead of having an error squiggle.
	 */
	Unnecessary = 1,

	/**
	 * Deprecated or obsolete code.
	 *
	 * Clients are allowed to rendered diagnostics with this tag strike through.
	 */
	Deprecated = 2,
}

send :: proc(msg: any, writer: io.Writer) -> bool {
	data, marshal_error := json.marshal(msg, {}, context.temp_allocator)
	
	if marshal_error != nil {
		return false
	}

	header := fmt.tprintf("Content-Length: %v\r\n\r\n", len(data))
	
	if _, err := io.write_string(writer, header); err != nil {
		return false
	}

	if _, err := io.write_string(writer, transmute(string)data); err != nil {
		return false
	}

	return true
}


read_header :: proc(reader: io.Reader) -> (header: Header, ok: bool) {	
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

read_body :: proc(reader: io.Reader, header: Header, allocator := context.allocator) -> (json.Object, bool) {
	data := make([]u8, header.content_length, context.temp_allocator)
	if _, err := io.read(reader, data); err != nil {
		log.error("Failed to read body")
		return nil, false
	}
	value, parse_err := json.parse(data = data, parse_integers = true, allocator = allocator)
	if parse_err != nil {
		log.error("Failed to parse body")
		return nil, false
	}
	return value.(json.Object), true
}



server_init_stdio :: proc(s: ^Server) {
	s.read  = os.stream_from_handle(os.stdin)
	s.write = os.stream_from_handle(os.stdout)
	s.err   = os.stream_from_handle(os.stderr)
}

Server :: struct {
	read : io.Reader,
	write: io.Writer,
	err  : io.Writer,

	callbacks: struct {
		on_initialize : proc(id: Request_Id, params: Initialize_Params) -> (result: Initialize_Result, error: Maybe(Response_Error)),
		on_initialized: proc(params: Initialized_Params)
	}
}


poll_message :: proc(s: ^Server) -> bool {
	header, header_ok := read_header(s.read)
	content_data := make([]u8, header.content_length, context.temp_allocator)
	if _, err := io.read(s.read, content_data); err != nil {
		log.error("Failed to read the message body")
		return false
	}

	pm: Partial_Message
	pm_parse_err := json.unmarshal(content_data, &pm, allocator = context.temp_allocator)
	if pm_parse_err != nil {
		log.errorf("Failed to partially parse the message: %v", pm_parse_err)
		return false
	}

	method := pm.method
	id := pm.id
	callbacks := &s.callbacks

	switch method {
	case "initialize":
		msg: Request_Message(Initialize_Params)
		msg_parse_err := json.unmarshal(content_data, &msg, allocator = context.temp_allocator)
		if msg_parse_err != nil {
			log.errorf("Failed to parse parameters for message %s. Error %v", method, msg_parse_err)
			return false
		}
		on_initialize := callbacks.on_initialize
		if on_initialize != nil {
			result, err := on_initialize(id, msg.params)
			response: Response_Message
			response.jsonrpc = "2.0.0"
			response.id = id
			response.result = result
			send(response, s.write)
		}
	}


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
	msg_id, has_id := msg["id"]
	id: Request_Id
	if has_id do #partial switch v in msg_id {
	case string: id = v
	case i64: id = v
	case: log.error("Failed to cast the request id"); return
	}
	
	switch method {
	case "initialize":
		
	}


	log_json_message(msg)
}