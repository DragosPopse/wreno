package lsp

import "core:encoding/json"

// Note(Dragos): I'd like to have the params be an `any` type, and do some allocation magic on them so we can remove some boilerplate
Request_Callback :: #type proc(id: Request_Id, params: json.Value)

request_map: map[string]Request_Callback