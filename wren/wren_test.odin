//+private
package wren

import "core:testing"
import "core:fmt"
import "core:runtime"
import "core:intrinsics"

@test
test_vm :: proc(T: ^testing.T) {
	vm := vm_new()
	defer if vm != nil do vm_free(vm)
	testing.expect(T, vm != nil, "Failed to create the vm")
}

@test
test_map :: proc(T: ^testing.T) {
	vm := vm_new()
	defer if vm != nil do vm_free(vm)
	testing.expect(T, vm != nil, "Failed to create the vm")
	m := map_make(vm)
	testing.expect(T, m != nil, "Failed to create the map")
	string_key := string_make_from_odin_string(vm, "Hellope")
	string_key_copy := string_make_from_odin_string(vm, "Hellope")
	string_key_unknown := string_make_from_odin_string(vm, "Not Cool")
	key_unknown := to_value(string_key_unknown)
	key_copy := to_value(string_key_copy)
	key := to_value(string_key)
	num_val := f64(15)
	value := to_value(num_val)
	map_set(vm, m, key, value)
	testing.expect_value(T, m.count, 1)
	{
		val := map_get(m, key_copy)
		val_num := to_number(val)
		testing.expect_value(T, val_num, 15)
	}
	{
		val := map_get(m, key_unknown)
		testing.expect(T, value_is_undefined(val), "Found value where we shouldn't")
	}
}