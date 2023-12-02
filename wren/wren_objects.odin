package wren


Object_Type :: enum {
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
Object :: struct {
	type     : Object_Type,
	is_dark  : bool,
	class_obj: ^Class,   // The object's class
	next     : ^Object,      // The next object in the linked list of all currently allocated objects
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
Upvalue :: struct {
	#subtype obj: Object,         // The object header. Note that upvalues have this because they are garbage collected, but they are not first class wren objects
	value       : ^Value,         // Pointer to the variable this upvalue is referencing
	closed      : Value,          // If the upvalue is closed (the local variable it was pointing to has been popped off the stack), then the closed-over value will be hoisted out of the stack into here. [value] will then be changed to point to this
	next        : ^Upvalue,   // Open upvalues are stored in a linked list by the fiber, this points to the next upvalue in that list
}

// A loaded module and the top-level variables it defines.
//
// While this is an Obj and is managed by the GC, it never appears as a
// first-class object in Wren.
Module :: struct {
	#subtype obj           : Object,
	variables     : [dynamic]Value,    // The currently defined top-level variables
	variable_names: [dynamic]string,   // Symbol table for the names of all module variables. Indexes here directly correspond to entries in [variables]
	name          : ^String,       // The name of the module
}

// A function object. It wraps and owns the bytecode and other debug information
// for a callable chunk of code.
//
// Function objects are not passed around and invoked directly. Instead, they
// are always referenced by an [Closure] which is the real first-class
// representation of a function. This isn't strictly necessary if they function
// has no upvalues, but lets the rest of the VM assume all called objects will
// be closures.
Fn :: struct {
	#subtype obj: Object,
	code        : [dynamic]byte,
	constants   : [dynamic]Value,
	module      : ^Module,      // The module where this function was defined
	max_slots   : int,              // The maximum number of stack slots this function may use
	num_upvalues: int,              // The number of upvalues this function closes over
	arity       : int,              // The number of parameters this function expects. Used to ensure that .call handles a mismatched number of parameters and arguments. This will only be set for fns, and not Obj_Fns that represent methods or scripts
	debug       : ^Fn_Debug,
}

// An instance of a first-class function and the environment it has closed over.
// Unlike [Obj_Fn], this has captured the upvalues that the function accesses.
Closure :: struct {
	#subtype obj     : Object,
	fn               : ^Fn,                 // The function that this closure is an instance of
	upvalues         : [dynamic]^Upvalue,   // The upvalues this function has closed over
}

// Tracks how this fiber has been invoked, aside from the ways that can be
// detected from the state of other fields in the fiber.
Fiber_State :: enum {
	Try  ,  // The fiber is being run from another fiber using a call to `try()`
	Root ,  // The fiber was directly invoked by `run_interpreter()`. This means it's the initial fiber used by a call to `wren.call()` or `wren.interpret()`
	Other,  // The fiber is invoked some other way. If [caller] is `NULL` then the fiber was invoked using `call()`. If [num_frames] is zero, then the fiber has finished running and is done. If [num_frames] is one and that frame's `ip` points to the first byte of code, the fiber has not been started yet.
}

Fiber :: struct {
	#subtype obj  : Object,
	stack         : ^Value,                 // The stack of value slots. This is used for holding local variables and temporaries while the fiber is executing. It is heap-allocated and grown as needed
	stack_top     : [^]Value,                 // A pointer to one past the top-most value of the stack
	stack_capacity: int,                    // The number of allocated slots in the stack array
	frames        : [dynamic]^Call_Frame,   // The stack of call frames. Grows as needed but never shrinks
	open_upvalues : ^Upvalue,           // Pointer to the first node in the linked list of open upvalues that are pointing to valeus still on the stack. The head of the list will be the upvalue closest to the top of the stack, and then the list works downwards
	caller        : ^Fiber,             // The fiber that ran this one. IF this fiber is yielded, control will resume to this one. May be nil
	error         : Value,                  // If the fiber failed because of a runtime error, this will contain the error object. Otherwise, it will be null 
	state         : Fiber_State
}

Class :: struct {
	#subtype obj: Object,
	superclass  : ^Class,
	num_fields  : int,               // The number of fields needed for an instance of this class, including all of its superclass fields
	methods     : [dynamic]Method,   // The table of methods that are defined in or inherited by this class. Methods are called by the symbol, and the symbol directly maps to an index in this table. This makes method calls fast at the expense of empty cells in the list of methods the class doesn't support. You can think of it as a hash table that never has collisions but has a really low load factor. Since methods are pretty small (just a type and a pointer), this should be a worthwhile trade-off
	name        : ^String,       // The name of the class
	attributes  : Value,             // The Class_Attributes for the class, if any
}

Foreign :: struct {
	#subtype obj: Object,
	data        : [^]byte,   // FLEXIBLE_ARRAY
}

Instance :: struct {
	#subtype obj: Object,
	fields      : [^]Value,   // FLEXIBLE_ARRAY
}

List :: struct {
	#subtype obj: Object,
	elements    : [dynamic]Value,   // The elements in the list
}

Range :: struct {
	#subtype obj: Object,
	from        : f64,
	to          : f64,
	is_inclusive: bool,   // True if [to] is included in the range
}

Map :: struct {
	#subtype obj: Object,
	count       : int,
	entries     : []Map_Entry,
}

object_init :: proc(vm: ^VM, obj: ^Object, type: Object_Type, class_obj: ^Class) {
	obj.type      = type
	obj.is_dark   = false
	obj.class_obj = class_obj
	obj.next      = vm.first
	vm.first      = obj
}

@private
object_hash :: proc(object: ^Object) -> u32 {
	#partial switch object.type {
	case .Class:
		return object_hash(&object.class_obj.name.obj) // Classes just use their name
	case .Fn:
		// allow bare minimum non-closure functions so that we can use a map to find existing constants in a function's constant table. This is only used internally. 
		// Since user code never sees a non-closure function, they cannot use them as map keys
		fn := cast(^Fn)object
		return hash_number(cast(f64)fn.arity) ~ hash_number(cast(f64)len(fn.code))
	case .Range:
		range := cast(^Range)object
		return hash_number(range.from) ~ hash_number(range.to)
	case .String:
		return (cast(^String)object).hash
	case: panic("Only immutable objects can be hashed.")
	}
	return 0
}