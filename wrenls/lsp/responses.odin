package lsp

import "core:encoding/json"

Response_Error :: struct {
	/**
	 * A number indicating the error type that occurred.
	 */
	code: Error_Code,

	/**
	 * A string providing a short description of the error.
	 */
	message: string,

	/**
	 * A primitive or structured value that contains additional
	 * information about the error. Can be omitted.
	 */
	data: Maybe(json.Value),
}

Response_Message :: struct {
	jsonrpc: string,

	/**
	 * The request id.
	 */
	id: Request_Id,

	/**
	 * The result of a request. This member is REQUIRED on success.
	 * This member MUST NOT exist if there was an error invoking the method.
	 */
	result: Response_Params,

	/**
	 * The error object in case a request fails.
	 */
	error: Maybe(Response_Error),
}

Initialize_Result :: struct {
	capabilities: Server_Capabilities,
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