/*
	This file will try to enclose all the lsp protocol specs. 
	Note(Dragos): try to document this as needed, as we go
	The aim should be to finally separate this in it's own package
	Note(Dragos): it seems that the types are also defined by name, should we keep it? e.g. CompletionOptions vs Completion_Options
	Note(Dragos): In addition, should the properties be snake_case in our code and then marshal them to camelCase later?
*/
package lsp

import "core:io"
import "core:encoding/json"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:log"

RequestId :: union {
	string,
	i64,
}

Header :: struct {
	content_length: int,
	content_type: string,
}

URI :: string
DocumentUri :: string

RequestType :: enum {
	Initialize,
	Initialized,
	Shutdown,
	Exit,
	DidOpen,
	DidChange,
	DidClose,
	DidSave,
	Definition,
	Completion,
	SignatureHelp,
	DocumentSymbol,
	SemanticTokensFull,
	SemanticTokensRange,
	FormatDocument,
	Hover,
	CancelRequest,
	InlayHint,
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


DiagnosticSeverity :: enum {
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
	severity: DiagnosticSeverity,
	code    : string,
	message : string,
}

NotificationPublishDiagnosticsParams :: struct {
	uri        : string,
	diagnostics: []Diagnostic,
}

NotificationLoggingParams :: struct {
	type   : DiagnosticSeverity,
	message: string,
}

NotificationParams :: union {
	NotificationLoggingParams,
	NotificationPublishDiagnosticsParams,
}

NotificationMessage :: struct {
	jsonrpc: string,
	method : string,
	params : NotificationParams,
}

SaveOptions :: struct {
	includeText: bool,
}

TextDocumentSyncOptions :: struct {
	openClose: bool,
	change   : int,
	save     : SaveOptions,
}

// Note(Dragos): this extends WorkDoneProgressOptions. Should we add that? OLS doesn't. Test later
CompletionOptions :: struct {
	resolveProvider  : bool,
	triggerCharacters: []string,
	completionItem   : struct {
		labelDetailsSupport: bool,
	}
}

SignatureHelpOptions :: struct {
	triggerCharacters  : []string,
	retriggerCharacters: []string,
}

SemanticTokensLegend :: struct {
	tokenTypes    : []string,
	tokenModifiers: []string,
}

SemanticTokensOptions :: struct {
	legend: SemanticTokensLegend,
	range : bool,
	full  : bool,
}

Document_Link_Options :: struct {
	resolveProvider: bool,
}

ServerCapabilities :: struct {
	textDocumentSync          : TextDocumentSyncOptions,
	definitionProvider        : bool,
	completionProvider        : CompletionOptions,
	signatureHelpProvider     : SignatureHelpOptions,
	semanticTokensProvider    : SemanticTokensOptions,
	documentSymbolProvider    : bool,
	hoverProvider             : bool,
	documentFormattingProvider: bool,
	inlayHintProvider         : bool,
	renameProvider            : bool,
	referenceProvider         : bool,
	workspaceSymbolProvider   : bool,
	documentLinkProvider      : Document_Link_Options,
}

ResponseInitializeParams :: struct {
	capabilities: ServerCapabilities,
}

CompletionItemKind :: enum {
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
	EnumMember    = 20,
	Constant      = 21,
	Struct        = 22,
	Event         = 23,
	Operator      = 24,
	TypeParameter = 25,
}

CompletionItem :: struct {
	label: string,
	kind: CompletionItemKind,
}

CompletionList :: struct {
	isIncomplete: bool,
	items: []CompletionItem,
}

SignatureInformation :: struct {
	label        : string,
	documentation: string,
	parameters   : []ParameterInformation,
}

ParameterInformation  :: struct {
	label: string,
}

SignatureHelp :: struct {
	signatures     : []SignatureInformation,
	activeSignature: int,
	activeParameter: int,
}

SymbolKind :: enum {
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
	EnumMember    = 22,
	Struct        = 23,
	Event         = 24,
	Operator      = 25,
	TypeParameter = 26,
}

DocumentSymbol :: struct {
	name: string,
	kind: SymbolKind,
	range: Range,
	selectionRange: Range,
	children: []DocumentSymbol,
}

SemanticTokens :: struct {
	data: []u32,
}

MarkupContent :: struct {
	kind : string,
	value: string,
}

Hover :: struct {
	contents: MarkupContent,
	range   : Range,
}

TextEdit :: struct {
	range  : Range,
	newText: string,
}

InsertReplaceEdit :: struct {
	insert : Range,
	newText: string,
	replace: Range,
}

InlayHintKind :: enum {
	Type      = 1,
	Parameter = 2,
}

InlayHint :: struct {
	position: Position,
	kind    : InlayHintKind,
	label   : string,
}

DocumentLinkClientCapabilities :: struct {
	tooltipSupport: bool,
}

TextDocumentIdentifier :: struct {
	uri: string,
}

DocumentLinkParams :: struct {
	textDocument: TextDocumentIdentifier,
}

DocumentLink :: struct {
	range  : Range,
	target : string,
	tooltip: string,
}

WorkspaceSymbolParams :: struct {
	query: string,
}

WorkspaceSymbol :: struct {
	name: string,
	kind: SymbolKind,
	location: Location,
}

TextDocumentItem :: struct {
	uri : string,
	text: string,
}

OptinalVersionedTextDocumentIdentifier :: struct {
	uri    : string,
	version: Maybe(int),
}

TextDocumentEdit :: struct {
	textDocument: OptinalVersionedTextDocumentIdentifier,
	edits: []TextEdit,
}

WorkspaceEdit :: struct {
	documentChanges: []TextDocumentEdit,
}

ResponseParams :: struct {
	ResponseInitializeParams,
	rawptr,
	Location,
	[]Location,
	CompletionList,
	SignatureHelp,
	[]DocumentSymbol,
	SemanticTokens,
	Hover,
	[]TextEdit,
	[]InlayHint,
	[]DocumentLink,
	[]WorkspaceSymbol,
	WorkspaceEdit,
}

ResponseMessage :: struct {
	jsonrpc: string,
	id: RequestId,
	result: ResponseParams,
}



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
	message := fmt.tprintf("%s", text) // Note(Dragos): do we need this???
	message_type: DiagnosticSeverity
	switch level {
	case .Debug:         message_type = .Hint
	case .Info:          message_type = .Information
	case .Warning:       message_type = .Warning
	case .Error, .Fatal: message_type = .Error
	}

	notif := NotificationMessage {
		jsonrpc = "2.0",
		method = "window/logMessage",
		params = NotificationLoggingParams {
			type = message_type,
			message = message,
		},
	}

	send_notification(notif, data.writer)
}

send_notification :: proc(notif: NotificationMessage, writer: io.Writer) -> bool {
	data, marshal_error := json.marshal(notif, {}, context.temp_allocator)
	header := fmt.tprintf("Content-Length: %v\r\n\r\n", len(data))
	if marshal_error != nil {
		return false
	}

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
