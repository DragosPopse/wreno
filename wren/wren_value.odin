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
	value_is_num :: proc "contextless" (value: Value) -> bool {
		return (value & QNAN) != QNAN
	}

	// An object pointer is a NaN with a set sign bit
	value_is_obj :: proc "contextless" (value: Value) -> bool {
		return (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT)
	}

	value_is_false :: proc "contextless" (value: Value) -> bool {
		return value == FALSE_VAL
	}

	value_is_true :: proc "contextless" (value: Value) -> bool {
		return value == TRUE_VAL
	}

	value_is_null :: proc "contextless" (value: Value) -> bool {
		return value == NULL_VAL
	}

	value_is_undefined :: proc "contextless" (value: Value) -> bool {
		return value == UNDEFINED_VAL
	}

	value_as_object :: proc "contextless" (value: Value) -> ^Object {
		return cast(^Object)cast(uintptr)(value & ~(SIGN_BIT | QNAN))
	}

	value_as_bool :: proc "contextless" (value: Value) -> bool {
		return value == TRUE_VAL
	}

	values_same :: proc "contextless" (a, b: Value) -> bool {
		return a == b
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

	value_is_num :: proc "contextless" (value: Value) -> bool {
		return value.kind == .Num
	}

	// An object pointer is a NaN with a set sign bit
	value_is_obj :: proc "contextless" (value: Value) -> bool {
		return value.kind == .Obj
	}

	value_is_false :: proc "contextless" (value: Value) -> bool {
		return value.kind == .False
	}

	value_is_true :: proc "contextless" (value: Value) -> bool {
		return value.kind == .True
	}

	value_is_null :: proc "contextless" (value: Value) -> bool {
		return value.kind == .Null
	}

	value_is_undefined :: proc "contextless" (value: Value) -> bool {
		return value.kind == .Undefined
	}
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


Call_Frame :: struct {
	ip         : ^byte,          // Pointer to the current (really next-to-be-executed) instruction in the function's bytecode. Note(Dragos): Can this be an index in the [dynamic]byte? Or a [^]?
	closure    : ^Closure,   // The closure being executed
	stack_start: ^Value,         // Pointer to the first stack slot used by this call frame. This will contain the receiver, followed by the function's parameters, then local variables and temporaries
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
		closure: ^Closure,
	}
}

Foreign_Method_Fn :: #type proc "c"() // Todo(Implement)


object_to_value :: proc(obj: ^Object) -> Value {
	when NAN_TAGGING {
		return Value(SIGN_BIT | QNAN | cast(u64)uintptr(obj))
	} else {
		value: Value
		value.type = .Obj
		value.as.obj = obj
		return value
	}
}

values_equal :: proc(a, b: Value) -> bool {
	if values_same(a, b) do return true
	
	// If we get here, it's only possible for 2 heap-allocated immutable objects to be equal
	if !value_is_obj(a) || !value_is_obj(b) do return false
	a_obj := value_as_object(a)
	b_obj := value_as_object(b)
	if a_obj.type != b_obj.type do return false
	#partial switch a_obj.type {
	case .Range: 
		a_range := cast(^Range)a_obj
		b_range := cast(^Range)b_obj
		return a_range.from == b_range.from && a_range.to == b_range.to && a_range.is_inclusive == b_range.is_inclusive
	case .String:
		a_str := cast(^String)a_obj
		b_str := cast(^String)b_obj
		return a_str.text == b_str.text
	}

	return false
}



new_single_class :: proc(vm: ^VM, num_fields: int, name: ^String) -> ^Class {
	class_obj := vm_allocate(vm, Class)
	object_init(vm, &class_obj.obj, .Class, nil)
	class_obj.num_fields = num_fields
	class_obj.name       = name
	class_obj.attributes = NULL_VAL
	push_root(vm, &class_obj.obj)
	class_obj.methods = make([dynamic]Method, vm.config.allocator)
	pop_root(vm)
	return class_obj
}

bind_superclass :: proc(vm: ^VM, subclass, superclass: ^Class) {
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
bind_method :: proc(vm: ^VM, class_obj: ^Class, symbol: int, method: Method) {
	if symbol >= len(class_obj.methods) {
		resize(&class_obj.methods, symbol + 1)
	}
	class_obj.methods[symbol] = method
}

new_class :: proc(vm: ^VM, superclass: ^Class, num_fields: int, name: ^String) {
	unimplemented()
}