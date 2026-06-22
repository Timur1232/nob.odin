package examples

import "core:strings"
import nob "../../"
import "core:fmt"
import "core:os"

cmd_echo :: proc(cmd: ^nob.Cmd) {
    append(cmd, "echo")
    append(cmd, "aboba")
}

simple_slice_example :: proc() {
    fmt.println("Simple slice example")
    if !nob.cmd_run_slice({ "echo", "aboba" }) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
    fmt.println()
}

simple_cmd_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Simple cmd example")
    cmd_echo(cmd)
    if !nob.cmd_run(cmd) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
    fmt.println()
}

simple_redirect_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Simple redirect example")

    stdout_sb: strings.Builder
    strings.builder_init(&stdout_sb, context.temp_allocator)
    defer free_all(context.temp_allocator)

    cmd_echo(cmd)

    if !nob.cmd_run(cmd, stdout = &stdout_sb) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }

    fmt.print("Collected stdout:", strings.to_string(stdout_sb))
    fmt.println()
}

async_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Async example")
    procs: nob.Procs
    for i in 1..=2 {
        append(cmd, "sleep")
        append(cmd, fmt.tprint(i))
        if !nob.cmd_run(cmd, async = &procs) {
            nob.log(.Error, "Command started unsuccessfuly")
        }
    }
    if !nob.procs_wait(&procs) {
        nob.log(.Error, "Process waiting ended unsuccessfuly")
    }
        fmt.println()
}

async_output_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Async output example")
    procs: nob.Procs
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, async = &procs) {
        nob.log(.Error, "Command started unsuccessfuly")
    }
    if !nob.procs_wait(&procs) {
        nob.log(.Error, "Process waiting ended unsuccessfuly")
    }
    fmt.println()
}

async_redirect_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Async output example")

    stdout_sb: strings.Builder
    strings.builder_init(&stdout_sb, context.allocator)
    defer strings.builder_destroy(&stdout_sb)

    procs: nob.Procs
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, async = &procs, stdout = &stdout_sb) {
        nob.log(.Error, "Command started unsuccessfuly")
    }
    if !nob.procs_wait(&procs) {
        nob.log(.Error, "Process waiting ended unsuccessfuly")
    }

    fmt.println("Collected stdout:", strings.to_string(stdout_sb))
}

no_output_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("No output example")
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, stdout = nil) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
    fmt.println()
}

custom_program_dir :: "test/"
custom_program_out :: "test"
custom_program_path :: custom_program_dir + custom_program_out
build_custom_program :: proc(cmd: ^nob.Cmd) {
    if nob.needs_rebuild(custom_program_path, custom_program_dir + "main.odin") {
        nob.log(.Info, "Rebuilding custom program")
        append(cmd, "odin")
        append(cmd, "build")
        append(cmd, custom_program_dir)
        append(cmd, "-out:" + custom_program_path)
        if !nob.cmd_run(cmd) {
            nob.log(.Error, "Command executed unsuccessfuly")
            return
        }
    }
}

cmd_append_custom_program :: proc(cmd: ^nob.Cmd) {
    append(cmd, "./" + custom_program_path)
}

file_redirect_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("File redirect example")

    out_file_path :: "test-file.txt"

    file, create_err := os.create(out_file_path)
    if create_err != nil {
        nob.log(.Error, "Ubable to open file for redirect example. Error: %v", create_err)
        return
    }
    defer os.close(file)

    build_custom_program(cmd)

    cmd_append_custom_program(cmd)
    if !nob.cmd_run(cmd, stdout = file) {
        nob.log(.Error, "Command executed unsuccessfuly")
        return
    }

    _, seek_err := os.seek(file, 0, .Start)
    if seek_err != nil {
        nob.log(.Error, "Unable to seek file. Error: %v", seek_err)
        return
    }

    contents, read_err := os.read_entire_file(file, context.temp_allocator)
    defer free_all(context.temp_allocator)
    if read_err != nil {
        nob.log(.Error, "Unable to read from file. Error: %v", read_err)
        return
    }

    fmt.println("File contents:", string(contents))
}

stdin_string_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Stdin string example")

    build_custom_program(cmd)

    cmd_append_custom_program(cmd)
    append(cmd, "-stdio")

    if !nob.cmd_run(cmd , stdin = "Hello from parent program") {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
}

main :: proc() {
    cmd: nob.Cmd

    simple_slice_example()

    simple_cmd_example(&cmd)

    simple_redirect_example(&cmd)

    async_example(&cmd)

    async_output_example(&cmd)

    async_redirect_example(&cmd)

    no_output_example(&cmd)

    file_redirect_example(&cmd)

    stdin_string_example(&cmd)
}
