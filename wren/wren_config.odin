package wren

import "core:mem"
import "core:fmt"

NAN_TAGGING               :: #config(WREN_NAN_TAGGING, true)                             // Use NaN tagging as the internal wren.Value representation
DEBUG_GC_STRESS           :: #config(WREN_DEBUG_GC_STRESS, false)                        // Stress test GC. Perform a collection before every allocation. Useful to ensure that memory is always correctly reachable
DEBUG_TRACE_MEMORY        :: #config(WREN_DEBUG_TRACE_MEMORY, false)                     // Log memory operations as they occur
DEBUG_TRACE_GC            :: #config(WREN_DEBUG_TRACE_GC, false)                         // Log garbage collections as they occur
DEBUG_DUMP_COMPILED_CODE  :: #config(WREN_DEBUG_DUMP_COMPILED_CODE, false)               // Print out the compiled bytecode of each function
DEBUG_TRACE_INSTRUCTIONS  :: #config(WREN_DEBUG_TRACE_INSTRUCTIONS, false)               // Trace each instruction as it's executed
DEFAULT_INITIAL_HEAP_SIZE :: #config(WREN_DEFAULT_INITIAL_HEAP_SIZE, 10 * mem.Megabyte)  // Used to determine the initial heap size in wren.default_config
DEFAULT_MIN_HEAP_SIZE     :: #config(WREN_DEFAULT_MIN_HEAP_SIZE, 1 * mem.Megabyte)       // Used to determine the minimum heap size in wren.default_config
DEFAULT_HEAP_GROWTH_PERCENT :: #config(WREN_DEFAULT_HEAP_GROWTH_PERCENT, 50)             // Used to determine the amount of memory to be allocated on the next growth in wren.default_config


Error_Proc :: #type proc(vm: ^VM, type: Error_Type, module: string, line: int, message: string)
Write_Proc :: #type proc(vm: ^VM, text: string)

Config :: struct {
	allocator          : mem.Allocator,   // The allocator wren uses for GC. It must be able to allocate, reallocate, and free memory.
	error              : Error_Proc,      // Proc used to display errors
	write              : Write_Proc,      // Proc used by System.print is called or other related functions
	initial_heap_size  : int,             // Allocation before triggering the first GC. If 0, defaults to DEFAULT_INITIAL_HEAP_SIZE
	min_heap_size      : int,             // After a collection occurs, the threshold for the next collection is determined based on the number of bytes remaining in use. This allows us to shrink the memory usage after reclaiming a large amount of memory. This ensures that the heap does not get too small. If 0, defaults to 1MB
	heap_growth_percent: int,             // Settings this to a smaller number wastes less memoryh, but triggers more frequent garbage collections
	user_data          : rawptr,          // User defined data associated with the VM
}

default_config :: proc() -> (config: Config) {
	config.allocator           = context.allocator
	config.initial_heap_size   = DEFAULT_INITIAL_HEAP_SIZE
	config.min_heap_size       = DEFAULT_MIN_HEAP_SIZE
	config.heap_growth_percent = DEFAULT_HEAP_GROWTH_PERCENT
	config.error               = default_error_proc
	return config
}

// Todo(dragos): does this need to newline?
default_write_proc :: proc(vm: ^VM, text: string) {
	fmt.print(text)
}

// Todo(dragos): make this better
// Todo(dragos): should this use Config.write?
default_error_proc :: proc(vm: ^VM, type: Error_Type, module: string, line: int, message: string) {
	fmt.printf("%v:%v %v\n", type, line, message)
}