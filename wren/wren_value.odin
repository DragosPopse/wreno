package wren

// This defines the built-in types and their core representations in memory.
// Since Wren is dynamically typed, any variable can hold a value of any type,
// and the type can change at runtime. Implementing this efficiently is
// critical for performance.
//
// The main type exposed by this is [Value]. A C variable of that type is a
// storage location that can hold any Wren value. The stack, module variables,
// and instance fields are all implemented in C as variables of type Value.
//
// The built-in types for booleans, numbers, and null are unboxed: their value
// is stored directly in the Value, and copying a Value copies the value. Other
// types--classes, instances of classes, functions, lists, and strings--are all
// reference types. They are stored on the heap and the Value just stores a
// pointer to it. Copying the Value copies a reference to the same object. The
// Wren implementation calls these "Obj", or objects, though to a user, all
// values are objects.
//
// There is also a special singleton value "undefined". It is used internally
// but never appears as a real value to a user. It has two uses:
//
// - It is used to identify module variables that have been implicitly declared
//   by use in a forward reference but not yet explicitly declared. These only
//   exist during compilation and do not appear at runtime.
//
// - It is used to represent unused map entries in an ObjMap.
//
// There are two supported Value representations. The main one uses a technique
// called "NaN tagging" (explained in detail below) to store a number, any of
// the value types, or a pointer, all inside one double-precision floating
// point number. A larger, slower, Value type that uses a struct to store these
// is also supported, and is useful for debugging the VM.
//
// The representation is controlled by the `WREN_NAN_TAGGING` define. If that's
// defined, Nan tagging is used.


// An IEEE 754 double-precision float is a 64-bit value with bits laid out like:
//
// 1 Sign bit
// | 11 Exponent bits
// | |          52 Mantissa (i.e. fraction) bits
// | |          |
// S[Exponent-][Mantissa------------------------------------------]
//
// The details of how these are used to represent numbers aren't really
// relevant here as long we don't interfere with them. The important bit is NaN.
//
// An IEEE double can represent a few magical values like NaN ("not a number"),
// Infinity, and -Infinity. A NaN is any value where all exponent bits are set:
//
//  v--NaN bits
// -11111111111----------------------------------------------------
//
// Here, "-" means "doesn't matter". Any bit sequence that matches the above is
// a NaN. With all of those "-", it obvious there are a *lot* of different
// bit patterns that all mean the same thing. NaN tagging takes advantage of
// this. We'll use those available bit patterns to represent things other than
// numbers without giving up any valid numeric values.
//
// NaN values come in two flavors: "signalling" and "quiet". The former are
// intended to halt execution, while the latter just flow through arithmetic
// operations silently. We want the latter. Quiet NaNs are indicated by setting
// the highest mantissa bit:
//
//             v--Highest mantissa bit
// -[NaN      ]1---------------------------------------------------
//
// If all of the NaN bits are set, it's not a number. Otherwise, it is.
// That leaves all of the remaining bits as available for us to play with. We
// stuff a few different kinds of things here: special singleton values like
// "true", "false", and "null", and pointers to objects allocated on the heap.
// We'll use the sign bit to distinguish singleton values from pointers. If
// it's set, it's a pointer.
//
// v--Pointer or singleton?
// S[NaN      ]1---------------------------------------------------
//
// For singleton values, we just enumerate the different values. We'll use the
// low bits of the mantissa for that, and only need a few:
//
//                                                 3 Type bits--v
// 0[NaN      ]1------------------------------------------------[T]
//
// For pointers, we are left with 51 bits of mantissa to store an address.
// That's more than enough room for a 32-bit address. Even 64-bit machines
// only actually use 48 bits for addresses, so we've got plenty. We just stuff
// the address right into the mantissa.
//
// Ta-da, double precision numbers, pointers, and a bunch of singleton values,
// all stuffed into a single 64-bit sequence. Even better, we don't have to
// do any masking or work to extract number values: they are unmodified. This
// means math on numbers is fast.
when NAN_TAGGING {
	Value :: u64

	// A mask that selects the sign bit
	SIGN_BIT :: u64(1) << 63

	// The bits must be set in order to indicate a quiet NaN
	QNAN :: u64(0x7ffc000000000000)

	// Masks out the tag bits used to identify the singleton value
	MASK_TAG :: 7

	// Tag values for the different singleton values
	TAG_NAN       :: 0
	TAG_NULL      :: 1
	TAG_FALSE     :: 2
	TAG_TRUE      :: 3
	TAG_UNDEFINED :: 4
	TAG_UNUSED2   :: 5
	TAG_UNUSED3   :: 6
	TAG_UNUSED4   :: 7

	NULL_VAL :: Value(QNAN | TAG_FALSE)
	FALSE_VAL :: Value(QNAN | TAG_FALSE)
	TRUE_VAL :: Value(QNAN | TAG_TRUE)
	UNDEFINED_VAL :: Value(QNAN | TAG_UNDEFINED)

	// If the NaN bits are set, it's not a number
	value_is_num :: proc(value: Value) -> bool {
		return (value & QNAN) != QNAN
	}

	// An object pointer is a NaN with a set sign bit
	value_is_obj :: proc(value: Value) -> bool {
		return (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT)
	}

	value_is_false :: proc(value: Value) -> bool {
		return value == FALSE_VAL
	}

	value_is_true :: proc(value: Value) -> bool {
		return value == TRUE_VAL
	}

	value_is_null :: proc(value: Value) -> bool {
		return value == NULL_VAL
	}

	value_is_undefined :: proc(value: Value) -> bool {
		return value == UNDEFINED_VAL
	}

} else {
	Value_Kind :: enum {
		False,
		Null,
		Num,
		True,
		Undefined,
		Obj,
	}

	Value :: struct {
		kind: Value_Kind,
		as: struct #raw_union {
			num: f64,
			obj: ^Obj,
		}
	}

	NULL_VAL      := Value {Value_Kind.Null, {}}
	FALSE_VAL     := Value {Value_Kind.False, {}}
	TRUE_VAL      := Value {Value_Kind.True, {}}
	UNDEFINED_VAL := Value {Value_Kind.Undefined, {}}

	value_is_num :: proc(value: Value) -> bool {
		return value.kind == .Num
	}

	// An object pointer is a NaN with a set sign bit
	value_is_obj :: proc(value: Value) -> bool {
		return value.kind == .Obj
	}

	value_is_false :: proc(value: Value) -> bool {
		return value.kind == .False
	}

	value_is_true :: proc(value: Value) -> bool {
		return value.kind == .True
	}

	value_is_null :: proc(value: Value) -> bool {
		return value.kind == .Null
	}

	value_is_undefined :: proc(value: Value) -> bool {
		return value.kind == .Undefined
	}
}

Obj_Type :: enum {
	Class,
	Closure,
	Fiber,
	Fn,
	Foreign,
	Instance,
	List,
	Map,
	Module,
	Range,
	String,
	Upvalue,
}

// Note(Dragos): Could this all be a big tagged union?

// Base struct for all heap allocated objects
Obj :: struct {
	type     : Obj_Type,
	is_dark  : bool,
	class_obj: ^Obj_Class,   // The object's class
	next     : ^Obj,         // The next object in the linked list of all currently allocated objects
}

// Heap allocated string object
// Note(Dragos): figure out how to handle strings as non-null terminated, might be easier and nicer
// Note(Dragos): Could this just be a raw builtin.string ?
Obj_String :: struct {
	obj : Obj,
	text: string,
}

// The dynamically allocated data structure for a variable that has been used
// by a closure. Whenever a function accesses a variable declared in an
// enclosing function, it will get to it through this.
//
// An upvalue can be either "closed" or "open". An open upvalue points directly
// to a [Value] that is still stored on the fiber's stack because the local
// variable is still in scope in the function where it's declared.
//
// When that local variable goes out of scope, the upvalue pointing to it will
// be closed. When that happens, the value gets copied off the stack into the
// upvalue itself. That way, it can have a longer lifetime than the stack
// variable.
Obj_Upvalue :: struct {
	obj   : Obj,            // The object header. Note that upvalues have this because they are garbage collected, but they are not first class wren objects
	value : ^Value,         // Pointer to the variable this upvalue is referencing
	closed: Value,          // If the upvalue is closed (the local variable it was pointing to has been popped off the stack), then the closed-over value will be hoisted out of the stack into here. [value] will then be changed to point to this
	next  : ^Obj_Upvalue,   // Open upvalues are stored in a linked list by the fiber, this points to the next upvalue in that list
}

// The type of a primitive function.
//
// Primitives are similar to foreign functions, but have more direct access to
// VM internals. It is passed the arguments in [args]. If it returns a value,
// it places it in `args[0]` and returns `true`. If it causes a runtime error
// or modifies the running fiber, it returns `false`.
Primitive :: #type proc "c" (vm: ^VM, args: [^]Value) -> bool // Note(Dragos): we need to make this odin nice

// Stores debugging information for a function used for things like stack
// traces.
// Note(dragos): can we replace TBuffers with [dynamic]T? 
Fn_Debug :: struct {
	name        : string,         // The name of the function, owned by Fn_Debug
	source_lines: [dynamic]int,   // An array of line numbers. There is one element in this array for each bytecode in the function's bytecode array. The value of that element is the line in the source code that generated that instruction. 
}

// A loaded module and the top-level variables it defines.
//
// While this is an Obj and is managed by the GC, it never appears as a
// first-class object in Wren.
Obj_Module :: struct {
	obj           : Obj,
	variables     : [dynamic]Value,    // The currently defined top-level variables
	variable_names: [dynamic]string,   // Symbol table for the names of all module variables. Indexes here directly correspond to entries in [variables]
	name          : ^Obj_String,       // The name of the module
}

// A function object. It wraps and owns the bytecode and other debug information
// for a callable chunk of code.
//
// Function objects are not passed around and invoked directly. Instead, they
// are always referenced by an [Obj_Closure] which is the real first-class
// representation of a function. This isn't strictly necessary if they function
// has no upvalues, but lets the rest of the VM assume all called objects will
// be closures.
Obj_Fn :: struct {
	obj         : Obj,
	code        : [dynamic]byte,
	constants   : [dynamic]Value,
	module      : ^Obj_Module,      // The module where this function was defined
	max_slots   : int,              // The maximum number of stack slots this function may use
	num_upvalues: int,              // The number of upvalues this function closes over
	arity       : int,              // The number of parameters this function expects. Used to ensure that .call handles a mismatched number of parameters and arguments. This will only be set for fns, and not Obj_Fns that represent methods or scripts
	debug       : ^Fn_Debug,
}

// An instance of a first-class function and the environment it has closed over.
// Unlike [Obj_Fn], this has captured the upvalues that the function accesses.
Obj_Closure :: struct {
	obj     : Obj,
	fn      : ^Obj_Fn,                 // The function that this closure is an instance of
	upvalues: [dynamic]^Obj_Upvalue,   // The upvalues this function has closed over
}

Call_Frame :: struct {
	ip         : ^byte,          // Pointer to the current (really next-to-be-executed) instruction in the function's bytecode. Note(Dragos): Can this be an index in the [dynamic]byte? Or a [^]?
	closure    : ^Obj_Closure,   // The closure being executed
	stack_start: ^Value,         // Pointer to the first stack slot used by this call frame. This will contain the receiver, followed by the function's parameters, then local variables and temporaries
}

// Tracks how this fiber has been invoked, aside from the ways that can be
// detected from the state of other fields in the fiber.
Fiber_State :: enum {
	Try  ,  // The fiber is being run from another fiber using a call to `try()`
	Root ,  // The fiber was directly invoked by `run_interpreter()`. This means it's the initial fiber used by a call to `wren.call()` or `wren.interpret()`
	Other,  // The fiber is invoked some other way. If [caller] is `NULL` then the fiber was invoked using `call()`. If [num_frames] is zero, then the fiber has finished running and is done. If [num_frames] is one and that frame's `ip` points to the first byte of code, the fiber has not been started yet.
}

Obj_Fiber :: struct {
	obj           : Obj,
	stack         : ^Value,                 // The stack of value slots. This is used for holding local variables and temporaries while the fiber is executing. It is heap-allocated and grown as needed
	stack_top     : [^]Value,                 // A pointer to one past the top-most value of the stack
	stack_capacity: int,                    // The number of allocated slots in the stack array
	frames        : [dynamic]^Call_Frame,   // The stack of call frames. Grows as needed but never shrinks
	open_upvalues : ^Obj_Upvalue,           // Pointer to the first node in the linked list of open upvalues that are pointing to valeus still on the stack. The head of the list will be the upvalue closest to the top of the stack, and then the list works downwards
	caller        : ^Obj_Fiber,             // The fiber that ran this one. IF this fiber is yielded, control will resume to this one. May be nil
	error         : Value,                  // If the fiber failed because of a runtime error, this will contain the error object. Otherwise, it will be null 
	state         : Fiber_State
}

Method_Kind :: enum {
	Primitive    ,  // A primitive method implemented in C/Odin in the VM. Unlike foreign methods, this can directly manipulate the fiber's stack
	Function_Call,  // A primitive that handles .call on Fn
	Foreign      ,  // A externally defined C method
	Block        ,  // A normal user-defined method
	None         ,  // No method for the given symbol
}

// Todo(Dragos): Turn this into tagged union nicety
Method :: struct {
	kind: Method_Kind,
	as: struct #raw_union {
		primitive: Primitive,
		foreign_fn: Foreign_Method_Fn,
		closure: ^Obj_Closure,
	}
}

Foreign_Method_Fn :: #type proc "c"() // Todo(Implement)

Obj_Class :: struct {
	obj       : Obj,
	superclass: ^Obj_Class,
	num_fields: int,               // The number of fields needed for an instance of this class, including all of its superclass fields
	methods   : [dynamic]Method,   // The table of methods that are defined in or inherited by this class. Methods are called by the symbol, and the symbol directly maps to an index in this table. This makes method calls fast at the expense of empty cells in the list of methods the class doesn't support. You can think of it as a hash table that never has collisions but has a really low load factor. Since methods are pretty small (just a type and a pointer), this should be a worthwhile trade-off
	name      : ^Obj_String,       // The name of the class
	attributes: Value,             // The Class_Attributes for the class, if any
}

Obj_Foreign :: struct {
	obj : Obj,
	data: [^]byte,   // FLEXIBLE_ARRAY
}

Obj_Instance :: struct {
	obj   : Obj,
	fields: [^]Value,   // FLEXIBLE_ARRAY
}

Obj_List :: struct {
	obj     : Obj,
	elements: [dynamic]Value,   // The elements in the list
}

Map_Entry :: struct {
	key  : Value,   // The entry's key, or UNDEFINED_VAL if the entry is not in use
	value: Value,   // The value associated with the key. If the key is UNDEFINED_VAL, this will be false to indicate an open available entry or true to indicate a tombstone -- an entry that has previously in use but was then deleted
}

// Note(Dragos): Make this odin nice
// Could this be a map[Value]Value? I'm not entirely sure but we can give it a shot
Obj_Map :: struct {
	obj     : Obj,
	capacity: u32,            // The number of entries allocated
	count   : u32,            // The number of entries in the map
	entries : [^]Map_Entry,   // Pointer to contiguous array of [capacity] entries
}

Obj_Range :: struct {
	obj         : Obj,
	from        : f64,
	to          : f64,
	is_inclusive: bool,   // True if [to] is included in the range
}

object_to_value :: proc(obj: ^Obj) -> Value {
	when NAN_TAGGING {
		return Value(SIGN_BIT | QNAN | cast(u64)uintptr(obj))
	} else {
		value: Value
		value.type = .Obj
		value.as.obj = obj
		return value
	}
}

init_obj :: proc(vm: ^VM, obj: ^Obj, type: Obj_Type, class_obj: ^Obj_Class) {
	obj.type      = type
	obj.is_dark   = false
	obj.class_obj = class_obj
	obj.next      = vm.first
	vm.first      = obj
}

new_single_class :: proc(vm: ^VM, num_fields: int, name: ^Obj_String) -> ^Obj_Class {
	class_obj := vm_allocate(vm, Obj_Class)
	init_obj(vm, &class_obj.obj, .Class, nil)
	class_obj.num_fields = num_fields
	class_obj.name       = name
	class_obj.attributes = NULL_VAL
	push_root(vm, &class_obj.obj)
	class_obj.methods = make([dynamic]Method, vm.config.allocator)
	pop_root(vm)
	return class_obj
}

bind_superclass :: proc(vm: ^VM, subclass, superclass: ^Obj_Class) {
	assert(superclass != nil, "Must have superclass")
	subclass.superclass = superclass
	if subclass.num_fields != -1 {
		subclass.num_fields += superclass.num_fields
	} else {
		assert(superclass.num_fields == 0, "A foreign class cannot inherit from a class with fields")
	}

	// Inherit methods from its superclass
	for method, i in superclass.methods {
		bind_method(vm, subclass, i, method) 
	}
}

// Note(Dragos): This isn't the greatest I believe, especially in combination with how it's used in wren.bind_superclass
bind_method :: proc(vm: ^VM, class_obj: ^Obj_Class, symbol: int, method: Method) {
	if symbol >= len(class_obj.methods) {
		resize(&class_obj.methods, symbol + 1)
	}
	class_obj.methods[symbol] = method
}

new_class :: proc(vm: ^VM, superclass: ^Obj_Class, num_fields: int, name: ^Obj_String) {
	unimplemented()
}