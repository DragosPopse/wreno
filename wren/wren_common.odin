package wren

// Note(Dragos): Lots of these maxes could potentially be ignored with odin, as strings can be allocated using temp_allocator and we got arenas around

// The maximum number of module-level variables that may be defined at one time.
// This limitation comes from the 16 bits used for the arguments to
// `CODE_LOAD_MODULE_VAR` and `CODE_STORE_MODULE_VAR`.
MAX_MODULE_VARS :: max(u16)

// The maximum number of arguments that can be passed to a method. Note that
// this limitation is hardcoded in other places in the VM, in particular, the
// `CODE_CALL_XX` instructions assume a certain maximum number.
MAX_PAREMETERS :: 16

// The maximum name of a method, not including the signature. This is an
// arbitrary but enforced maximum just so we know how long the method name
// strings need to be in the parser.
MAX_METHOD_NAME :: 64

// The maximum length of a method signature. Signatures look like:
//
//     foo        // Getter.
//     foo()      // No-argument method.
//     foo(_)     // One-argument method.
//     foo(_,_)   // Two-argument method.
//     init foo() // Constructor initializer.
//
// The maximum signature length takes into account the longest method name, the
// maximum number of parameters with separators between them, "init ", and "()".
MAX_METHOD_SIGNATURE :: MAX_METHOD_NAME + (MAX_PAREMETERS * 2) + 6

// The maximum length of an identifier. The only real reason for this limitation
// is so that error messages mentioning variables can be stack allocated.
MAX_VARIABLE_NAME :: 64

// The maximum number of fields a class can have, including inherited fields.
// This is explicit in the bytecode since `CODE_CLASS` and `CODE_SUBCLASS` take
// a single byte for the number of fields. Note that it's 255 and not 256
// because creating a class takes the *number* of fields, not the *highest
// field index*.
MAX_FIELDS :: 255

Error_Type :: enum {
	Compile    ,  // Syntax/resolution error detected at compile time
	Runtime    ,  // Runtime error
	Stack_Trace,  // One entry of a runtime error's stack trace
}

Type :: enum {
	Bool,
	Num,
	Foreign,
	List,
	Map,
	Null,
	String,
}

Interpret_Result :: enum {
	Success,
	Compile_Error,
	Runtime_Error,
}
