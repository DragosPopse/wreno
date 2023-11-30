package wren

// This file contains all compile time configurations available. Example: `odin build wren -define:WREN_NAN_TAGGING=false`

NAN_TAGGING              :: #config(WREN_NAN_TAGGING, true)                // Use NaN tagging as the internal wren.Value representation
DEBUG_GC_STRESS          :: #config(WREN_DEBUG_GC_STRESS, false)           // Stress test GC. Perform a collection before every allocation. Useful to ensure that memory is always correctly reachable
DEBUG_TRACE_MEMORY       :: #config(WREN_DEBUG_TRACE_MEMORY, false)        // Log memory operations as they occur
DEBUG_TRACE_GC           :: #config(WREN_DEBUG_TRACE_GC, false)            // Log garbage collections as they occur
DEBUG_DUMP_COMPILED_CODE :: #config(WREN_DEBUG_DUMP_COMPILED_CODE, false)  // Print out the compiled bytecode of each function
DEBUG_TRACE_INSTRUCTIONS :: #config(WREN_DEBUG_TRACE_INSTRUCTIONS, false)  // Trace each instruction as it's executed