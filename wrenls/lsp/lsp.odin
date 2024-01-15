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

Notification_Publish_Diagnostics_Params :: struct {
	uri        : string,
	diagnostics: []Diagnostic,
}

Notification_Logging_Params :: struct {
	type   : Diagnostic_Severity,
	message: string,
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

Initialize_Result :: struct {
	capabilities: Server_Capabilities,
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

Workspace_Symbol_Params :: struct {
	query: string,
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


Notification_Message :: struct {
	jsonrpc: string,
	method : string,
	params : Notification_Params,
}

Notification_Params :: union {
	Notification_Logging_Params,
	Notification_Publish_Diagnostics_Params,
}

Response_Message :: struct {
	jsonrpc: string,
	id     : Request_Id,
	result : Response_Params,	
}

Response_Params :: union {
	Initialize_Result,
	rawptr,
	Location,
	[]Location,
	Completion_List,
	Signature_Help,
	[]Document_Symbol,
	Semantic_Tokens,
	Hover,
	[]Text_Edit,
	[]Inlay_Hint,
	[]Document_Link,
	[]Workspace_Symbol,
	Workspace_Edit,
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

parse_body :: proc(reader: io.Reader, header: Header, allocator := context.allocator) -> (json.Value, bool) {
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
	return value, true
}
