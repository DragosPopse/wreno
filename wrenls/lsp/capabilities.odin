package lsp

import "core:encoding/json"

Workspace_Edit_Client_Capabilities :: struct {
	/**
	 * The client supports versioned document changes in `Workspace_Edit`s
	 */
	document_changes: Maybe(bool) `json:"documentChanges"`,
	/**
	 * The resource operations the client supports. Clients should at least
	 * support 'create', 'rename' and 'delete' files and folders.
	 *
	 * @since 3.13.0
	 */
	resource_operations: Maybe([]string) `json:"resourceOperations""`, // Todo(Dragos): Turn this into an enum on parse
	/**
	 * The failure handling strategy of a client if applying the workspace edit
	 * fails.
	 *
	 * @since 3.13.0
	 */
	failure_handling: Maybe(string) `json"failureHandling"`,
	/**
	 * Whether the client normalizes line endings to the client specific
	 * setting.
	 * If set to `true` the client will normalize line ending characters
	 * in a workspace edit to the client specific new line character(s).
	 *
	 * @since 3.16.0
	 */
	normalizes_line_endings: Maybe(bool) `json:"normalizesLineEndings"`,
	/**
	 * Whether the client in general supports change annotations on text edits,
	 * create file, rename file and delete file changes.
	 *
	 * @since 3.16.0
	 */
	change_annotation_support: Maybe(struct {
		/**
		 * Whether the client groups edits with equal labels into tree nodes,
		 * for instance all edits labelled with "Changes in Strings" would
		 * be a tree node.
		 */
		groups_on_label: Maybe(bool) `json"groupsOnLabel"`,
	}) `json:"changeAnnotationSupport"`
}

Did_Change_Configuration_Client_Capabilities :: struct {
	/**
	 * Did change configuration notification supports dynamic registration.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,
}

Did_Change_Watched_Files_Client_Capabilities :: struct {
	/**
	 * Did change watched files notification supports dynamic registration.
	 * Please note that the current protocol doesn't support static
	 * configuration for file changes from the server side.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,
	/**
	 * Whether the client has support for relative patterns
	 * or not.
	 *
	 * @since 3.17.0
	 */
	relative_pattern_support: Maybe(bool) `json:"relativePatternSupport"`,
}

Workspace_Symbol_Client_Capabilities :: struct {
	/**
	 * Symbol request supports dynamic registration.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,

	/**
	 * Specific capabilities for the `Symbol_Kind` in the `workspace/symbol`
	 * request.
	 */
	symbol_kind: Maybe(struct {
		/**
		 * The symbol kind values the client supports. When this
		 * property exists the client also guarantees that it will
		 * handle values outside its set gracefully and falls back
		 * to a default value when unknown.
		 *
		 * If this property is not present the client only supports
		 * the symbol kinds from `File` to `Array` as defined in
		 * the initial version of the protocol.
		 */
		value_set: Maybe([]Symbol_Kind) `json"valueSet"`,
	}) `json:"symbolKind"`,

	/**
	 * The client supports tags on `Symbol_Information` and `Workspace_Symbol`.
	 * Clients supporting tags have to handle unknown tags gracefully.
	 *
	 * @since 3.16.0
	 */
	tag_support: Maybe(struct {
		/**
		 * The tags supported by the client.
		 */
		value_set: []Symbol_Tag,
	}) `json:"tagSupport"`,

	/**
	 * The client support partial workspace symbols. The client will send the
	 * request `workspaceSymbol/resolve` to the server to resolve additional
	 * properties.
	 *
	 * @since 3.17.0 - proposedState
	 */
	resolve_support: Maybe(struct {
		/**
		 * The properties that a client can resolve lazily. Usually
		 * `location.range`
		 */
		properties: []string,
	}) `json:"resolveSupport"`,
}

Execute_Command_Client_Capabilities :: struct {
	/**
	 * Execute command supports dynamic registration.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,
}

Semantic_Tokens_Workspace_Client_Capabilities :: struct {
	/**
	 * Whether the client implementation supports a refresh request sent from
	 * the server to the client.
	 *
	 * Note that this event is global and will force the client to refresh all
	 * semantic tokens currently shown. It should be used with absolute care
	 * and is useful for situation where a server for example detect a project
	 * wide change that requires such a calculation.
	 */
	refresh_support: Maybe(bool) `json:"refreshSupport"`,
}

Code_Lens_Workspace_Client_Capabilities :: struct {
	/**
	 * Whether the client implementation supports a refresh request sent from the
	 * server to the client.
	 *
	 * Note that this event is global and will force the client to refresh all
	 * code lenses currently shown. It should be used with absolute care and is
	 * useful for situation where a server for example detect a project wide
	 * change that requires such a calculation.
	 */
	refresh_support: Maybe(bool) `json:"refreshSupport"`,
}

/**
 * Client workspace capabilities specific to inline values.
 *
 * @since 3.17.0
 */
Inline_Value_Workspace_Client_Capabilities :: struct {
	/**
	 * Whether the client implementation supports a refresh request sent from
	 * the server to the client.
	 *
	 * Note that this event is global and will force the client to refresh all
	 * inline values currently shown. It should be used with absolute care and
	 * is useful for situation where a server for example detect a project wide
	 * change that requires such a calculation.
	 */
	refresh_support: Maybe(bool) `json:"refreshSupport"`,
}

Inlay_Hint_Workspace_Client_Capabilities :: struct {
	/**
	 * Whether the client implementation supports a refresh request sent from
	 * the server to the client.
	 *
	 * Note that this event is global and will force the client to refresh all
	 * inlay hints currently shown. It should be used with absolute care and
	 * is useful for situation where a server for example detects a project wide
	 * change that requires such a calculation.
	 */
	refresh_support: Maybe(bool) `json:"refreshSupport"`,
}

/**
 * Workspace client capabilities specific to diagnostic pull requests.
 *
 * @since 3.17.0
 */
Diagnostic_Workspace_Client_Capabilities :: struct {
	/**
	 * Whether the client implementation supports a refresh request sent from
	 * the server to the client.
	 *
	 * Note that this event is global and will force the client to refresh all
	 * pulled diagnostics currently shown. It should be used with absolute care
	 * and is useful for situation where a server for example detects a project
	 * wide change that requires such a calculation.
	 */
	refresh_support: Maybe(bool) `json:"refreshSupport"`,
}

Text_Document_Sync_Client_Capabilities :: struct {
	/**
	 * Whether text document synchronization supports dynamic registration.
	 */
	 dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,
	 
	/**
	 * The client supports sending will save notifications.
	 */
	 will_save: Maybe(bool) `json:"willSave"`,

	/**
	 * The client supports sending a will save request and
	 * waits for a response providing text edits which will
	 * be applied to the document before it is saved.
	 */
	will_save_wait_until: Maybe(bool) `json:"willSaveWaitUntil"`,

	/**
	 * The client supports did save notifications.
	 */
	did_save: Maybe(bool) `json:"didSave"`,
}

Completion_Client_Capabilities :: struct {
	/**
	 * Whether completion supports dynamic registration.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,
	
	/**
	 * The client supports the following `CompletionItem` specific
	 * capabilities.
	 */
	completion_item: Maybe(struct {
		/**
		 * Client supports snippets as insert text.
		 *
		 * A snippet can define tab stops and placeholders with `$1`, `$2`
		 * and `${3:foo}`. `$0` defines the final tab stop, it defaults to
		 * the end of the snippet. Placeholders with equal identifiers are
		 * linked, that is typing in one will update others too.
		 */
		snippet_support: Maybe(bool) `json:"snippetSupport"`,

		/**
		 * Client supports commit characters on a completion item.
		 */
		commit_characters_support: Maybe(bool) `json:"commitCharactersSupport"`,

		/**
		 * Client supports the follow content formats for the documentation
		 * property. The order describes the preferred format of the client.
		 */
		documentation_format: Maybe([]string) `json:"documentationFormat"`,

		/**
		 * Client supports the deprecated property on a completion item.
		 */
		deprecated_support: Maybe(bool) `json:"deprecatedSupport"`,

		/**
		 * Client supports the preselect property on a completion item.
		 */
		preselect_support: Maybe(bool) `json:"preselectSupport"`,

		/**
		 * Client supports the tag property on a completion item. Clients
		 * supporting tags have to handle unknown tags gracefully. Clients
		 * especially need to preserve unknown tags when sending a completion
		 * item back to the server in a resolve call.
		 *
		 * @since 3.15.0
		 */
		tag_support: Maybe(struct {
			value_set: Completion_Item_Tag `json:"valueSet"`,
		}) `json:"tagSupport"`,

		/**
		 * Client supports insert replace edit to control different behavior if
		 * a completion item is inserted in the text or should replace text.
		 *
		 * @since 3.16.0
		 */
		insert_replace_support: Maybe(bool) `json:"insertReplaceSupport"`,

		/**
		 * Indicates which properties a client can resolve lazily on a
		 * completion item. Before version 3.16.0 only the predefined properties
		 * `documentation` and `detail` could be resolved lazily.
		 *
		 * @since 3.16.0
		 */
		resolve_support: Maybe(struct {
			/**
			 * The properties that a client can resolve lazily.
			 */
			properties: []string,
		}) `json:"resolveSupport"`,

		/**
		 * The client supports the `insert_text_mode` property on
		 * a completion item to override the whitespace handling mode
		 * as defined by the client (see `Insert_Text_Mode`).
		 *
		 * @since 3.16.0
		 */
		insert_text_mode_support: Maybe(struct {
			value_set: []Insert_Text_Mode `json:"valueSet"`,
		}) `json:"insertTextModeSupport"`,

		/**
		 * The client has support for completion item label
		 * details (see also `Completion_Item_Label_Details`).
		 *
		 * @since 3.17.0
		 */
		label_details_support: Maybe(bool) `json:"labelDetailsSupport"`,
	}) `json:"completionItem"`,
	
	completion_item_kind: Maybe(struct {
		/**
		 * The completion item kind values the client supports. When this
		 * property exists the client also guarantees that it will
		 * handle values outside its set gracefully and falls back
		 * to a default value when unknown.
		 *
		 * If this property is not present the client only supports
		 * the completion items kinds from `Text` to `Reference` as defined in
		 * the initial version of the protocol.
		 */
		value_set: Maybe([]Completion_Item_Kind) `json:"valueSet"`,
	}) `json:"completionItemKind"`,

	/**
	 * The client supports to send additional context information for a
	 * `textDocument/completion` request.
	 */
	context_support: Maybe(bool) `json:"contextSupport"`,

	/**
	 * The client's default when the completion item doesn't provide a
	 * `insert_text_mode` property.
	 *
	 * @since 3.17.0
	 */
	insert_text_mode: Maybe(Insert_Text_Mode) `json:"insertTextMode"`,

	/**
	 * The client supports the following `Completion_List` specific
	 * capabilities.
	 *
	 * @since 3.17.0
	 */
	 completion_list: Maybe(struct {
		/**
		 * The client supports the following itemDefaults on
		 * a completion list.
		 *
		 * The value lists the supported property names of the
		 * `CompletionList.itemDefaults` object. If omitted
		 * no properties are supported.
		 *
		 * @since 3.17.0
		 */
		item_defaults: Maybe([]string) `json:"itemDefaults"`,
	 }) `json:"completionList"`,
}

Hover_Client_Capabilities :: struct {
	/**
	 * Whether hover supports dynamic registration.
	 */
	dynamic_registration: Maybe(bool) `json:"dynamicRegistration"`,

	/**
	 * Client supports the follow content formats if the content
	 * property refers to a `literal of type MarkupContent`.
	 * The order describes the preferred format of the client.
	 */
	content_format: Maybe([]string) `json:"contentFormat"`,
}

Signature_Help_Client_Capabilities :: struct {

}

Declaration_Client_Capabilities :: struct {

}

Definition_Client_Capabilities :: struct {

}

Type_Definition_Client_Capabilities :: struct {

}

Implementation_Client_Capabilities :: struct {

}

Reference_Client_Capabilities :: struct {

}

Document_Highlight_Client_Capabilities :: struct {

}

Document_Symbol_Client_Capabilities :: struct {

}

Code_Action_Client_Capabilities :: struct {

}

Document_Color_Client_Capabilities :: struct {

}

Document_Formatting_Client_Capabilities :: struct {

}

Document_Range_Formatting_Client_Capabilities :: struct {

}

Document_On_Type_Formatting_Client_Capabilities :: struct {

}

Rename_Client_Capabilities :: struct {

}

Publish_Diagnostics_Client_Capabilities :: struct {
	
}

Folding_Range_Client_Capabilities :: struct {
	
}

Selection_Range_Client_Capabilities :: struct {

}

Linked_Editing_Range_Client_Capabilities :: struct {
	
}

Call_Hierarchy_Client_Capabilities :: struct {

}

Semantic_Tokens_Client_Capabilities :: struct {

}

Moniker_Client_Capabilities :: struct {

}

Type_Hierarchy_Client_Capabilities :: struct {

}

Inline_Value_Client_Capabilities :: struct {

}

Inlay_Hint_Client_Capabilities :: struct {

}

Diagnostic_Client_Capabilities :: struct {
	
}

/**
 * Text document specific client capabilities.
 */
Text_Document_Client_Capabilities :: struct {
	synchronization: Maybe(Text_Document_Sync_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/completion` request.
	 */
	completion: Maybe(Completion_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/hover` request.
	 */
	hover: Maybe(Hover_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/signatureHelp` request.
	 */
	signature_help: Maybe(Signature_Help_Client_Capabilities) `json:"signatureHelp"`,

	/**
	 * Capabilities specific to the `textDocument/declaration` request.
	 *
	 * @since 3.14.0
	 */
	declaration: Maybe(Declaration_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/definition` request.
	 */
	definition: Maybe(Definition_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/typeDefinition` request.
	 *
	 * @since 3.6.0
	 */
	type_definition: Type_Definition_Client_Capabilities `json:"typeDefinition"`,

	/**
	 * Capabilities specific to the `textDocument/implementation` request.
	 *
	 * @since 3.6.0
	 */
	implementation: Implementation_Client_Capabilities,

	/**
	 * Capabilities specific to the `textDocument/references` request.
	 */
	references: Maybe(Reference_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/documentHighlight` request.
	 */
	document_highlight: Maybe(Document_Highlight_Client_Capabilities) `json:"documentHighlight"`,

	/**
	 * Capabilities specific to the `textDocument/documentSymbol` request.
	 */
	document_symbol: Maybe(Document_Symbol_Client_Capabilities) `json:"documentSymbol"`,

	/**
	 * Capabilities specific to the `textDocument/codeAction` request.
	 */
	code_action: Maybe(Code_Action_Client_Capabilities) `json:"codeAction"`,

	/**
	 * Capabilities specific to the `textDocument/documentLink` request.
	 */
	document_link: Maybe(Document_Link_Client_Capabilities) `json:"documentLink"`,

	/**
	 * Capabilities specific to the `textDocument/documentColor` and the
	 * `textDocument/colorPresentation` request.
	 *
	 * @since 3.6.0
	 */
	color_provider: Maybe(Document_Color_Client_Capabilities) `json:"colorProvider"`,

	/**
	 * Capabilities specific to the `textDocument/formatting` request.
	 */
	formatting: Maybe(Document_Formatting_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/rangeFormatting` request.
	 */
	range_formatting: Maybe(Document_Range_Formatting_Client_Capabilities) `json:"rangeFormatting"`,

	/** request.
	 * Capabilities specific to the `textDocument/onTypeFormatting` request.
	 */
	on_type_formatting: Maybe(Document_On_Type_Formatting_Client_Capabilities) `json:"onTypeFormatting"`,

	/**
	 * Capabilities specific to the `textDocument/rename` request.
	 */
	rename: Maybe(Rename_Client_Capabilities),

	/**
	 * Capabilities specific to the `textDocument/publishDiagnostics`
	 * notification.
	 */
	publish_diagnostics: Maybe(Publish_Diagnostics_Client_Capabilities) `json:"publishDiagnostics"`,

	/**
	 * Capabilities specific to the `textDocument/foldingRange` request.
	 *
	 * @since 3.10.0
	 */
	folding_range: Maybe(Folding_Range_Client_Capabilities) `json:"foldingRange"`,

	/**
	 * Capabilities specific to the `textDocument/selectionRange` request.
	 *
	 * @since 3.15.0
	 */
	selection_range: Maybe(Selection_Range_Client_Capabilities) `json:"selectionRange"`,

	/**
	 * Capabilities specific to the `textDocument/linkedEditingRange` request.
	 *
	 * @since 3.16.0
	 */
	linked_editing_range: Maybe(Linked_Editing_Range_Client_Capabilities) `json:"linkedEditingRange"`,

	/**
	 * Capabilities specific to the various call hierarchy requests.
	 *
	 * @since 3.16.0
	 */
	call_hierarchy: Maybe(Call_Hierarchy_Client_Capabilities) `json:"callHierarchy"`,

	/**
	 * Capabilities specific to the various semantic token requests.
	 *
	 * @since 3.16.0
	 */
	semantic_tokens: Maybe(Semantic_Tokens_Client_Capabilities) `json:"semanticTokens"`,

	/**
	 * Capabilities specific to the `textDocument/moniker` request.
	 *
	 * @since 3.16.0
	 */
	moniker: Maybe(Moniker_Client_Capabilities),

	/**
	 * Capabilities specific to the various type hierarchy requests.
	 *
	 * @since 3.17.0
	 */
	type_hierarchy: Maybe(Type_Hierarchy_Client_Capabilities) `json:"typeHierarchy"`,

	/**
	 * Capabilities specific to the `textDocument/inlineValue` request.
	 *
	 * @since 3.17.0
	 */
	inline_value: Maybe(Inline_Value_Client_Capabilities) `json:"inlineValue"`,

	/**
	 * Capabilities specific to the `textDocument/inlayHint` request.
	 *
	 * @since 3.17.0
	 */
	inlay_hint: Maybe(Inlay_Hint_Client_Capabilities) `json:"inlayHint"`,

	/**
	 * Capabilities specific to the diagnostic pull model.
	 *
	 * @since 3.17.0
	 */
	diagnostic: Maybe(Diagnostic_Client_Capabilities),
}

Notebook_Document_Client_Capabilities :: struct {
	
}

Show_Message_Request_Client_Capabilities :: struct {

}

Show_Document_Client_Capabilities :: struct {

}

Regular_Expressions_Client_Capabilities :: struct {

}

Markdown_Client_Capabilities :: struct {

}

Client_Capabilities :: struct {
	/**
	 * Workspace specific client capabilities.
	 */
	workspace: struct {
		/**
		 * The client supports applying batch edits
		 * to the workspace by supporting the request
		 * 'workspace/applyEdit'
		 */
		apply_edit: bool `json:"applyEdit"`,
		/**
		 * Capabilities specific to `WorkspaceEdit`s
		 */
		workspace_edit: Workspace_Edit_Client_Capabilities `json:"workspaceEdit"`,
		/**
		 * Capabilities specific to the `workspace/didChangeConfiguration`
		 * notification.
		 */
		did_change_configuration: Did_Change_Configuration_Client_Capabilities `json:"didChangeConfiguration"`,
		/**
		 * Capabilities specific to the `workspace/didChangeWatchedFiles`
		 * notification.
		 */
		did_change_watched_files: Did_Change_Watched_Files_Client_Capabilities `json:"didChangeWatchedFiles"`,
		/**
		 * Capabilities specific to the `workspace/symbol` request.
		 */
		symbol: Workspace_Symbol_Client_Capabilities,
		/**
		 * Capabilities specific to the `workspace/executeCommand` request.
		 */
		execute_command: Execute_Command_Client_Capabilities `json:"executeCommand"`,
		/**
		 * The client has support for workspace folders.
		 *
		 * @since 3.6.0
		 */
		workspace_folders: bool `json:"workspaceFolders"`,
		/**
		 * The client supports `workspace/configuration` requests.
		 *
		 * @since 3.6.0
		 */
		configuration: bool,
		/**
		 * Capabilities specific to the semantic token requests scoped to the
		 * workspace.
		 *
		 * @since 3.16.0
		 */
		semantic_tokens: Semantic_Tokens_Workspace_Client_Capabilities `json:"semanticTokens"`,
		/**
		 * Capabilities specific to the code lens requests scoped to the
		 * workspace.
		 *
		 * @since 3.16.0
		 */
		code_lens: Code_Lens_Workspace_Client_Capabilities `json:"codeLens"`,
		/**
		 * The client has support for file requests/notifications.
		 *
		 * @since 3.16.0
		 */
		file_operations: struct {
			/**
			 * Whether the client supports dynamic registration for file
			 * requests/notifications.
			 */
			dynamic_registration: bool `json:"dynamicRegistration"`,
			/**
			 * The client has support for sending didCreateFiles notifications.
			 */
			did_create: bool `json:"didCreate"`,
			/**
			 * The client has support for sending willCreateFiles requests.
			 */
			will_create: bool `json:"willCreate"`,
			/**
			 * The client has support for sending didRenameFiles notifications.
			 */
			did_rename_file: bool `json:"didRenameFile"`,
			/**
			 * The client has support for sending willRenameFiles requests.
			 */
			will_rename_file: bool `json:"willRenameFile"`,
			/**
			 * The client has support for sending didDeleteFiles notifications.
			 */
			did_delete: bool `json:"didDelete"`,
			/**
			 * The client has support for sending willDeleteFiles requests.
			 */
			will_delete: bool `json:"willDelete"`,
		} `json:"fileOperations"`,
		/**
		 * Client workspace capabilities specific to inline values.
		 *
		 * @since 3.17.0
		 */
		inline_value: Inline_Value_Workspace_Client_Capabilities `json:"inlineValue"`,
		/**
		 * Client workspace capabilities specific to inlay hints.
		 *
		 * @since 3.17.0
		 */
		inlay_hint: Inlay_Hint_Workspace_Client_Capabilities `json:"inlayHint"`,
		/**
		 * Client workspace capabilities specific to diagnostics.
		 *
		 * @since 3.17.0.
		 */
		 diagnostics: Diagnostic_Workspace_Client_Capabilities,
	},
	/**
	 * Text document specific client capabilities.
	 */
	text_document: Text_Document_Client_Capabilities `json:"textDocument"`,
	/**
	 * Capabilities specific to the notebook document support.
	 *
	 * @since 3.17.0
	 */
	notebook_document: Notebook_Document_Client_Capabilities `json:"notebookDocument"`,
	/**
	 * Window specific client capabilities.
	 */
	window: struct {
		/**
		 * It indicates whether the client supports server initiated
		 * progress using the `window/workDoneProgress/create` request.
		 *
		 * The capability also controls Whether client supports handling
		 * of progress notifications. If set servers are allowed to report a
		 * `workDoneProgress` property in the request specific server
		 * capabilities.
		 *
		 * @since 3.15.0
		 */
		work_done_progress: bool `json:"workDoneProgress"`,
		/**
		 * Capabilities specific to the showMessage request
		 *
		 * @since 3.16.0
		 */
		show_message: Show_Message_Request_Client_Capabilities `json:"showMessage"`,
		/**
		 * Client capabilities for the show document request.
		 *
		 * @since 3.16.0
		 */
		show_document: Show_Document_Client_Capabilities `json:"showDocument"`,
	},
	/**
	 * General client capabilities.
	 *
	 * @since 3.16.0
	 */
	general: struct {
		/**
		 * Client capability that signals how the client
		 * handles stale requests (e.g. a request
		 * for which the client will not process the response
		 * anymore since the information is outdated).
		 *
		 * @since 3.17.0
		 */
		stale_request_support: struct {
			/**
			 * The client will actively cancel the request.
			 */
			cancel: bool,
			/**
			 * The list of requests for which the client
			 * will retry the request if it receives a
			 * response with error code `ContentModified``
			 */
			retry_on_content_modified: []string `json:"retryOnContentModified"`,
		} `json:"stateRequestSupport"`,
		/**
		 * Client capabilities specific to regular expressions.
		 *
		 * @since 3.16.0
		 */
		regular_expressions: Regular_Expressions_Client_Capabilities `json:"regularExpressions"`,
		/**
		 * Client capabilities specific to the client's markdown parser.
		 *
		 * @since 3.16.0
		 */
		markdown: Markdown_Client_Capabilities,
		/**
		 * The position encodings supported by the client. Client and server
		 * have to agree on the same position encoding to ensure that offsets
		 * (e.g. character position in a line) are interpreted the same on both
		 * side.
		 *
		 * To keep the protocol backwards compatible the following applies: if
		 * the value 'utf-16' is missing from the array of position encodings
		 * servers can assume that the client supports UTF-16. UTF-16 is
		 * therefore a mandatory encoding.
		 *
		 * If omitted it defaults to ['utf-16'].
		 *
		 * Implementation considerations: since the conversion from one encoding
		 * into another requires the content of the file / line the conversion
		 * is best done where the file is read which is usually on the server
		 * side.
		 *
		 * @since 3.17.0
		 */
		position_encodings: []string `json:"positionEncodings"`,
	},
	/**
	 * Experimental client capabilities.
	 */
	 experimental: Maybe(json.Value), // Note(Dragos): How do we encode this properly? maybe a map?
}