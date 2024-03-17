package lsp

Semantic_Tokens_Options :: struct {
	legend: Semantic_Tokens_Legend,
	range : bool,
	full  : bool,
}

Semantic_Token_Type_String :: distinct string
Semantic_Token_Modifier_String :: distinct string

Semantic_Token_Type :: enum u32 {
	Namespace,
	/**
	 * Represents a generic type. Acts as a fallback for types which
	 * can't be mapped to a specific type like class or enum.
	 */
	Type,
	Class,
	Enum,
	Interface,
	Struct,
	Type_Parameter,
	Parameter,
	Variable,
	Property,
	Enum_Member,
	Event,
	Function,
	Method,
	Macro,
	Keyword,
	Modifier,
	Comment,
	String,
	Number,
	Regexp,
	Operator,
	/**
	 * @since 3.17.0
	 */
	Decorator,
}

semantic_token_type_strings := [Semantic_Token_Type]Semantic_Token_Type_String {
	.Namespace      = "namespace",
	.Type           = "type",
	.Class          = "class",
	.Enum           = "enum",
	.Interface      = "interface",
	.Struct         = "struct",
	.Type_Parameter = "typeParameter",
	.Parameter      = "parameter",
	.Variable       = "variable",
	.Property       = "property",
	.Enum_Member    = "enumMember",
	.Event          = "event",
	.Function       = "function",
	.Method         = "method",
	.Macro          = "macro",
	.Keyword        = "keyword",
	.Modifier       = "modifier",
	.Comment        = "comment",
	.String         = "string",
	.Number         = "number",
	.Regexp         = "regexp",
	.Operator       = "operator",
	.Decorator      = "decorator",
}

Semantic_Token_Types :: bit_set[Semantic_Token_Type]

Semantic_Token_Modifier :: enum u32 {
	Declaration,
	Definition,
	Readonly,
	Static,
	Deprecated,
	Abstract,
	Async,
	Modification,
	Documentation,
	Default_Library,
}

Semantic_Token_Modifiers :: bit_set[Semantic_Token_Modifier; u32]

semantic_token_modifier_strings := [Semantic_Token_Modifier]Semantic_Token_Modifier_String {
	.Declaration     = "declaration",
	.Definition      = "definition",
	.Readonly        = "readonly",
	.Static          = "static",
	.Deprecated      = "deprecated",
	.Abstract        = "abstract",
	.Async           = "async",
	.Modification    = "modification",
	.Documentation   = "documentation",
	.Default_Library = "defaultLibrary",
}

Token_Encoder :: struct {
	token_set: Semantic_Token_Types,
	modifier_set: Semantic_Token_Modifiers,

	token_types: []Semantic_Token_Type,
	token_type_strings: []Semantic_Token_Type_String,
	token_indices: [Semantic_Token_Type]int,

	token_modifiers: []Semantic_Token_Modifier,
	token_modifier_strings: []Semantic_Token_Modifier_String,
	token_modifier_indices: [Semantic_Token_Modifier]int,
}

token_encoder_init :: proc(encoder: ^Token_Encoder, token_set: Semantic_Token_Types, modifier_set: Semantic_Token_Modifiers) {
	for token in Semantic_Token_Type do if token in token_set {
		
	}
}



Encoded_Token :: struct {
    delta_line: int,
    delta_start_char: int,
    token_type: Semantic_Token_Type, // TODO(Dragos): This kinda works because we are passing all the possible tokens on the usercode server side. What if we don't do that? 
    token_modifiers: Semantic_Token_Modifiers,
}

Semantic_Tokens :: struct {
	/**
	 * An optional result ID. If provided and clients support delta updating,
	 * the client will include the result ID in the next semantic token request.
	 * A server can then, instead of computing all semantic tokens again, simply
	 * send a delta.
	 */
	result_id: Maybe(string) `json:"resultId"`,

	/**
	 * The actual tokens.
	 */
	data: []u32,
}

Semantic_Tokens_Partial_Result :: struct {
	data: []u32,
}

