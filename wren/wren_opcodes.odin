package wren

Code :: enum u8 {
	CONSTANT          ,   // Load the constant at index [arg]
	NULL              ,   // Push null onto the stack
	FALSE             ,   // Push false onto the stack
	TRUE              ,   // Push true onto the stack
	LOAD_LOCAL_0      ,   // Push value in the local slot 0
	LOAD_LOCAL_1      ,   // Push value in the local slot 1
	LOAD_LOCAL_2      ,   // Push value in the local slot 2
	LOAD_LOCAL_3      ,   // Push value in the local slot 3
	LOAD_LOCAL_4      ,   // Push value in the local slot 4
	LOAD_LOCAL_5      ,   // Push value in the local slot 5
	LOAD_LOCAL_6      ,   // Push value in the local slot 6
	LOAD_LOCAL_7      ,   // Push value in the local slot 7
	LOAD_LOCAL_8      ,   // Push value in the local slot 8
	LOAD_LOCAL        ,   // Push the value in local slot [arg]
	STORE_LOCAL       ,   // Stores the top of the stack in local slot [arg], does not pop it
	LOAD_UPVALUE      ,   // pushes the value in upvalue [arg]
	STORE_UPVALUE     ,   // Stores the top of the stack in upvalue [arg], does not pop it
	LOAD_MODULE_VAR   ,   // Pushes the value of the top level variable in slot [arg]
	STORE_MODULE_VAR  ,   // stores the top of the stack in top level variable slot [arg], does not pop it
	LOAD_FIELD_THIS   ,   // Pushes the value of the field in slot [arg] of the received of the current function. This is used for regular field accesses on "this" directly in methods. This intstruction is faster than the more general LOAD_FIELD instruction
	STORE_FIELD_THIS  ,   // Stores the top of the stack in field slot [arg] in the receiver of the current value. Does not pop the value, this instruction is faster than the more general LOAD_FIELD instruction
	LOAD_FIELD        ,   // Pops an instance and pushes the value of the field in slot [arg] of it
	STORE_FIELD       ,   // Pops an instance and stores the subsequent top of stack in field slot [arg] in it. Does not pop the value 
	POP               ,   // Pop and discard the top of the stack
	CALL_0            ,   // Invoke the method with symbol [arg], with 0  arguments (not including the receiver)
	CALL_1            ,   // Invoke the method with symbol [arg], with 1  arguments (not including the receiver)
	CALL_2            ,   // Invoke the method with symbol [arg], with 2  arguments (not including the receiver)
	CALL_3            ,   // Invoke the method with symbol [arg], with 3  arguments (not including the receiver)
	CALL_4            ,   // Invoke the method with symbol [arg], with 4  arguments (not including the receiver)
	CALL_5            ,   // Invoke the method with symbol [arg], with 5  arguments (not including the receiver)
	CALL_6            ,   // Invoke the method with symbol [arg], with 6  arguments (not including the receiver)
	CALL_7            ,   // Invoke the method with symbol [arg], with 7  arguments (not including the receiver)
	CALL_8            ,   // Invoke the method with symbol [arg], with 8  arguments (not including the receiver)
	CALL_9            ,   // Invoke the method with symbol [arg], with 9  arguments (not including the receiver)
	CALL_10           ,   // Invoke the method with symbol [arg], with 10 arguments (not including the receiver)
	CALL_11           ,   // Invoke the method with symbol [arg], with 11 arguments (not including the receiver)
	CALL_12           ,   // Invoke the method with symbol [arg], with 12 arguments (not including the receiver)
	CALL_13           ,   // Invoke the method with symbol [arg], with 13 arguments (not including the receiver)
	CALL_14           ,   // Invoke the method with symbol [arg], with 14 arguments (not including the receiver)
	CALL_15           ,   // Invoke the method with symbol [arg], with 15 arguments (not including the receiver)
	CALL_16           ,   // Invoke the method with symbol [arg], with 16 arguments (not including the receiver)
	SUPER_0           ,   // Invoke the superclass method with symbol [arg], with 0  arguments (not including the receiver)
	SUPER_1           ,   // Invoke the superclass method with symbol [arg], with 1  arguments (not including the receiver)
	SUPER_2           ,   // Invoke the superclass method with symbol [arg], with 2  arguments (not including the receiver)
	SUPER_3           ,   // Invoke the superclass method with symbol [arg], with 3  arguments (not including the receiver)
	SUPER_4           ,   // Invoke the superclass method with symbol [arg], with 4  arguments (not including the receiver)
	SUPER_5           ,   // Invoke the superclass method with symbol [arg], with 5  arguments (not including the receiver)
	SUPER_6           ,   // Invoke the superclass method with symbol [arg], with 6  arguments (not including the receiver)
	SUPER_7           ,   // Invoke the superclass method with symbol [arg], with 7  arguments (not including the receiver)
	SUPER_8           ,   // Invoke the superclass method with symbol [arg], with 8  arguments (not including the receiver)
	SUPER_9           ,   // Invoke the superclass method with symbol [arg], with 9  arguments (not including the receiver)
	SUPER_10          ,   // Invoke the superclass method with symbol [arg], with 10 arguments (not including the receiver)
	SUPER_11          ,   // Invoke the superclass method with symbol [arg], with 11 arguments (not including the receiver)
	SUPER_12          ,   // Invoke the superclass method with symbol [arg], with 12 arguments (not including the receiver)
	SUPER_13          ,   // Invoke the superclass method with symbol [arg], with 13 arguments (not including the receiver)
	SUPER_14          ,   // Invoke the superclass method with symbol [arg], with 14 arguments (not including the receiver)
	SUPER_15          ,   // Invoke the superclass method with symbol [arg], with 15 arguments (not including the receiver)
	SUPER_16          ,   // Invoke the superclass method with symbol [arg], with 16 arguments (not including the receiver)
	JUMP              ,   // Jump the instruction pointer [arg] forward
	LOOP              ,   // Jump the instruction pointer [arg] backward
	JUMP_IF           ,   // Pop and if not truthy then jump the instruction pointer [arg] forward
	AND               ,   // If the top of the stack is false, jump [arg] forward. Otherwise, pop and continue
	OR                ,   // If the top of the stack is non-false, jump [arg] forward. Otherwise, pop and continue
	CLOSE_UPVALUE     ,   // Close the upvalue for the local on the top of the stack, then pop it
	RETURN            ,   // Exit the current function and return the value of the top of the stack
	CLOSURE           ,   // Creates a closure for the function stored in [arg] in the constant table. Following the function argument is a number of arguments, 2 for each upvalue. The first is true if the variable being captured is local (as opposed to upvalue), and the second is the index of the local upvalue being captured. Pushes the created closure
	CONSTRUCT         ,   // Creates a new instance of a class. Assumes the class object is in slot 0, and replaces it with the new uninitialized instance of that class. This opcode is only emitted by the compiler-generated constructor metaclass method
	FOREIGN_CONSTRUCT ,   // Creates a new instance of a foreign class. Assumes the class object is in slot zero, and replaces it with the new uninitialized instance of that class. This opcode is only emitted by the compiler-generated constructor metaclass methods
	CLASS             ,   // Creates a class. Top of stack is the superclass. Bellow that is a string for the name of the class. Byte [arg] is the number of fields in the class
	END_CLASS         ,   // Ends the class. Atm the stack contains the class and the ClassAttributes (or null)
	FOREIGN_CLASS     ,   // Creates a foreign class. Top of the stack is the superclass. Below that is a string for the name of the class
	METHOD_INSTANCE   ,   // Define a method for symbol [arg]. The class receiving the method is popped off the stack, then the function defining the body is popped. If a foreign method is being defined, the "function" will be a string identifying the foreign method. Otherwise, it will be a function or closure
	METHOD_STATIC     ,   // Define a method for symbol [arg]. The class whose metaclass will receive the method is popped off the stack, then the funcction defining the body is popped. If a foreign method is being defined, the "function" will be a string identifying the foreign method. Otherwise, it will be a function or closure
	END_MODULE        ,   // This is executed at the end of the module's body. Pushes NULL onto the stack as the "return value" of the import statement and stores the module as the most recently imported one
	IMPORT_MODULE     ,   // Import a module whose name is the string stored at [arg] in the constant table. Pushes NULL onto the stack so that the fiber for the imported module can replace that with a dummy value when it returns. (Fibers always return a value when resuming a caller.)
	IMPORT_VARIABLE   ,   // Import a variable from the most recently imported module. The name of the variable to import is at [arg] in the constant table. Pushes the loaded variable's value.
	END               ,   // This pseudo-instruction indicates the end of the bytecode, It should always be preceded by a RETURN, so is never actually executed.
}

// The stack effect of each opcode. The index in the array is the opcode, and the value is the stack effect of that instruction
CODE_STACK_EFFECTS := [Code]int {
	.CONSTANT          = 1,
	.NULL              = 1,
	.FALSE             = 1,
	.TRUE              = 1,
	.LOAD_LOCAL_0      = 1,
	.LOAD_LOCAL_1      = 1,
	.LOAD_LOCAL_2      = 1,
	.LOAD_LOCAL_3      = 1,
	.LOAD_LOCAL_4      = 1,
	.LOAD_LOCAL_5      = 1,
	.LOAD_LOCAL_6      = 1,
	.LOAD_LOCAL_7      = 1,
	.LOAD_LOCAL_8      = 1,
	.LOAD_LOCAL        = 1,
	.STORE_LOCAL       = 0,
	.LOAD_UPVALUE      = 1,
	.STORE_UPVALUE     = 0,
	.LOAD_MODULE_VAR   = 1,
	.STORE_MODULE_VAR  = 0,
	.LOAD_FIELD_THIS   = 1,
	.STORE_FIELD_THIS  = 0,
	.LOAD_FIELD        = 0,
	.STORE_FIELD       = -1,
	.POP               = -1,
	.CALL_0            = 0,
	.CALL_1            = -1,
	.CALL_2            = -2,
	.CALL_3            = -3,
	.CALL_4            = -4,
	.CALL_5            = -5,
	.CALL_6            = -6,
	.CALL_7            = -7,
	.CALL_8            = -8,
	.CALL_9            = -9,
	.CALL_10           = -10,
	.CALL_11           = -11,
	.CALL_12           = -12,
	.CALL_13           = -13,
	.CALL_14           = -14,
	.CALL_15           = -15,
	.CALL_16           = -16,
	.SUPER_0           = 0,
	.SUPER_1           = -1,
	.SUPER_2           = -2,
	.SUPER_3           = -3,
	.SUPER_4           = -4,
	.SUPER_5           = -5,
	.SUPER_6           = -6,
	.SUPER_7           = -7,
	.SUPER_8           = -8,
	.SUPER_9           = -9,
	.SUPER_10          = -10,
	.SUPER_11          = -11,
	.SUPER_12          = -12,
	.SUPER_13          = -13,
	.SUPER_14          = -14,
	.SUPER_15          = -15,
	.SUPER_16          = -16,
	.JUMP              = 0,
	.LOOP              = 0,
	.JUMP_IF           = -1,
	.AND               = -1,
	.OR                = -1,
	.CLOSE_UPVALUE     = -1,
	.RETURN            = 0,
	.CLOSURE           = 1,
	.CONSTRUCT         = 0,
	.FOREIGN_CONSTRUCT = 0,
	.CLASS             = -1,
	.END_CLASS         = -2,
	.FOREIGN_CLASS     = -1,
	.METHOD_INSTANCE   = -2,
	.METHOD_STATIC     = -2,
	.END_MODULE        = 1,
	.IMPORT_MODULE     = 1,
	.IMPORT_VARIABLE   = 1,
	.END               = 0,
}