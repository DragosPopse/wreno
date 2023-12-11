package wren

import "core:strings"
import "core:mem"

// Heap allocated string object
// Note(Dragos): figure out how to handle strings as non-null terminated, might be easier and nicer
// Note(Dragos): Could this just be a raw builtin.string ?
String :: struct {
	#subtype obj: Object,
	hash        : u32,
	text        : string,
}

// FNV-1a hash. See: http://www.isthe.com/chongo/tech/comp/fnv/
hash_text :: proc(text: string) -> u32 {
	hash := u32(2166136261)
	for i in 0..<len(text) {
		hash ~= u32(text[i])
		hash *= 16777619
	}
	return hash
}

@private
string_calculate_hash :: proc(str: ^String) {
	str.hash = hash_text(str.text)
}

// Todo(Dragos): The String.text should be allocated inline with String
// Note(Dragos): We are also experimenting with not having null-terminated strings. This could potentailly not be good if we want other people to use our implementation from C with no additional changes to their code. We'll see
string_make_from_odin_string :: proc(vm: ^VM, odin_string: string) -> ^String {
	str := new(String, vm.config.allocator)
	object_init(vm, str, .String, vm.string_class)
	str.text = strings.clone(odin_string, vm.config.allocator) // Todo(Dragos): This isn't quite right atm, we'll need to change this
	string_calculate_hash(str)
	return str
}