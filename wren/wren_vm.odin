package wren

import "core:runtime"

MAX_TEMP_ROOTS :: 8  // The maximum number of temporary objects that can be made visible to the gc at one time

// A handle to a value, basically just a linked list of extra GC roots.
//
// Note that even non-heap-allocated values can be stored here.
Handle :: struct {
	value: Value,
	prev : ^Handle,
	next : ^Handle,
}

VM :: struct {
	bool_class     : ^Obj_Class,
	class_class    : ^Obj_Class,
	fiber_class    : ^Obj_Class,
	fn_class       : ^Obj_Class,
	list_class     : ^Obj_Class,
	map_class      : ^Obj_Class,
	null_class     : ^Obj_Class,
	num_class      : ^Obj_Class,
	object_class   : ^Obj_Class,
	range_class    : ^Obj_Class,
	string_class   : ^Obj_Class,
	fiber          : ^Obj_Fiber,             // Fiber currently running
	modules        : ^Obj_Map,               // Loaded modules. Each key is an Obj_String (except for the main module, whose key is null) for the module's name and the value is the Obj_Module for the module
	last_module    : ^Obj_Module,            // The most recently imported module. The module whose code has most recently finished executing. Not treated like a gc root since the module is already in [modules]
	bytes_allocated: int,                    // The number of bytes that are known to be currently allocated. Includes all memory that was proven live after the last GC, as well as any new bytes that were allocated since then. Does not include bytes for objects that were freed since the last GC
	next_gc        : int,                    // The number of total allocated bytes that will trigger the next GC
	first          : ^Obj,                   // The first object in the linked list of all currently allocated objects
	gray           : [dynamic]^Obj,          // The gray set for the garbage collector. This is the stack of unprocessed objects while a garbage collection pass in in process. Note(Dragos): This is a stack, we can make it a [dynamic]^Obj
	temp_roots     : [MAX_TEMP_ROOTS]^Obj,   // The list of temp roots. This is for temp or new objects that are not otherwise reachable but should not be collected. They are organized as a stack of pointers stored in this array. This implies that temporary roots need to have stack semantics: only the most recently pushed object can be released
	num_temp_roots : int,
	handles        : ^Handle,                // Pointer to the first node in the linked list of active handles or nil if there are none
	api_stack      : [^]Value,               // Pointer to the bottom of the range of stack slots available for use from the C API. During a foreign method, this will be in the stack of the fiber that is executing a method. If not in a foreign method, this is initially nil. If the user requests slots by calling wren.ensure_slots(), a stack is ccreated and this is initialized
	config         : Config,
	compiler       : ^Compiler,              // compiler and debugger data. The compiler that is currently compiling code. This is used so tthat heap alloc objects used by the compiler can be found if a gc is kicked off in the middle of a compile.
	method_names   : [dynamic]string,        // There is a single global symbol table for all method names of all classes. Method calls are dispatched directly by index in this table
}

// Use the VM allocator to allocate a new object T
vm_allocate :: proc(vm: ^VM, $T: typeid) -> ^T {
	return new(T, vm.config.allocator)
}

push_root :: proc(vm: ^VM, obj: ^Obj, loc := #caller_location) {
	assert(obj != nil, "Can't root nil")
	assert(vm.num_temp_roots < MAX_TEMP_ROOTS, "Too many temporary roots")
	vm.temp_roots[vm.num_temp_roots] = obj
	vm.num_temp_roots += 1
}

pop_root :: proc(vm: ^VM, loc := #caller_location) {
	assert(vm.num_temp_roots > 0, "No temporary roots to be released")
	vm.num_temp_roots -= 1
}

@(deferred_out = pop_root)
temp_root :: proc(vm: ^VM, obj: ^Obj, loc := #caller_location) -> (^VM, runtime.Source_Code_Location) {
	push_root(vm, obj, loc)
	return vm, loc
} 

// Note(Dragos): Maybe we can make this more odin-nice
get_slot_count :: proc(vm: ^VM) -> int {
	return int(uintptr(vm.fiber.stack_top) - uintptr(vm.api_stack)) if vm.api_stack != nil else 0
}