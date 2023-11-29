package wren

import "core:testing"
import "core:fmt"

@test
test_vm :: proc(T: ^testing.T) {
	fmt.printf("Hello\n")
}