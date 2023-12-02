package wren

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