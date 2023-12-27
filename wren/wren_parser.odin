package wren

Parser :: struct {
	vm          : ^VM,
	module      : ^Module,                          // The module being parsed
	next        : Token,                            // Upcoming token
	current     : Token,                            // Most recently lexed token
	previous    : Token,                            // Most recently consumed/advanced token
	print_errors: bool,                             // Print to stderr or discard
	has_errors  : bool,                             // Syntax or compile error occured
}
