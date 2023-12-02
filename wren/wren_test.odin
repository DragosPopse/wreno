package wren

import "core:testing"
import "core:fmt"
import "core:runtime"
import "core:intrinsics"

@test
test_vm :: proc(T: ^testing.T) {

}

@test
test_map :: proc(T: ^testing.T) {
	m: map[Value]Value
	val: Value = 21 // First key
	str := new(String)
	mi := runtime.map_info(type_of(m))
	raw_map := transmute(^runtime.Raw_Map)&m
	str.text = "Hellope"
	runtime.__dynamic_map_set(raw_map, mi, runtime.default_hasher_string(raw_data(str.text), runtime.map_seed(raw_map^)), raw_data(str.text), &val)
}