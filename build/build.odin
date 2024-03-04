package bitflight_build

import "core:fmt"
import "build"
import "core:os"
import "core:strings"
import "core:path/filepath"


// FILL THESE IN TO YOUR DESIRE. These are only needed if you plan on not modifying the generated build system too much

OUT_DIR :: "./out"

//

CURRENT_PLATFORM :: build.Platform{ODIN_OS, ODIN_ARCH}

Project_Kind :: enum {
	Wren,
	Lang_Server,
}

Project_Specific :: struct {
	src: string,
	exe_name: string,
	target_prefix: string,
}

project_specifics := [Project_Kind]Project_Specific {
	.Wren = {
		src = "./wren",
		exe_name = "wren",
		target_prefix = "w",
	},
	.Lang_Server = {
		src = "./wrenls",
		exe_name = "wrenls",
		target_prefix = "ls",
	},
}

project: build.Project

run_target :: proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
	target := cast(^Target)target
	specific := project_specifics[target.project_kind]
	odin_build: build.Odin_Config
	odin_build.platform = target.platform
	odin_build.build_mode = .EXE
	exe_name := specific.exe_name
	exe_extension: string
	#partial switch target.platform.os {
	case .Windows:
		exe_extension = ".exe"
	case: // Other platforms don't need extension right now.
	}
	odin_build.out_file = fmt.tprintf("%s%s", exe_name, exe_extension)

	odin_build.out_dir = build.trelpath(target, fmt.tprintf("./%s/%s", OUT_DIR, target.name))

	odin_build.src_path = build.trelpath(target, specific.src)


	switch target.build_type {
	case .Debug:
		odin_build.opt = .None
		odin_build.flags += {
			.Debug,
			.Use_Separate_Modules,
		}

	case .Release:
		odin_build.opt = .Speed
	}

	odin_build.timings.mode = .Basic

	switch run_mode {
	case .Build: // Build your executable, you can add post/pre-build commands here, like copying files
		/* todo(dragos): this prints jank, it must be a problem in the arg parsing. Fix it
		for arg in args do if flag, is_flag := arg.(build.Flag_Arg); is_flag {
			switch flag.key {
			case "-time": odin_build.timings.mode = .Basic
			case "-time2": odin_build.timings.mode = .Advanced
			}
		}*/
		build.odin(target, .Build, odin_build) or_return
		return true
	
	case .Dev: // Generate config for the debugger, language server settings, etc
		build.generate_odin_devenv(target, odin_build, args) or_return
		return true
	
	case .Help: // Displays information about the current target
		return false // Mode is not implemented
	}

	return false // We should never get here
}

Target :: struct {
	using target: build.Target,
	project_kind: Project_Kind,
	build_type: Build_Type,
}

Build_Type :: enum {
	Debug,
	Release,
}

targets := [?]Target {
	{
		project_kind = .Wren,
		target = {
			name = "deb",
		},
		build_type = .Debug,
	},
	{
		project_kind = .Wren,
		target = {
			name = "rel",
		},
		build_type = .Release,
	},

	{
		project_kind = .Lang_Server,
		target = {
			name = "deb",
		},
		build_type = .Debug,
	},
	{
		project_kind = .Lang_Server,
		target = {
			name = "rel",
		},
		build_type = .Release,
	},
}

@init
_ :: proc() {
	target_name :: #force_inline proc(project_kind: Project_Kind, name: string) -> string {
		return fmt.aprintf("%s%s", project_specifics[project_kind].target_prefix, name)
	}
	context.allocator = context.temp_allocator
	project.name = "wren"
	
	for &target in targets {
		target.name = target_name(target.project_kind, target.name)
		target.platform = CURRENT_PLATFORM
		build.add_target(&project, &target, run_target)
	}
}

main :: proc() {
	context.allocator = context.temp_allocator
	info: build.Cli_Info
	info.project = &project
	info.default_target = &targets[0]
	build.run_cli(info, os.args)
}