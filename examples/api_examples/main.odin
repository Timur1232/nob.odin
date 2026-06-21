package examples

import "core:strings"
import nob "../../"
import "core:fmt"

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

simple_redirect_example :: proc(cmd: ^nob.Cmd, stdout_sb: ^strings.Builder) {
    fmt.println("Simple redirect example")
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, stdout = stdout_sb) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
}

async_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Async example")
    procs: nob.Procs
    for i in 1..=3 {
        append(cmd, "sleep")
        append(cmd, fmt.tprint(i))
        if !nob.cmd_run(cmd, async = &procs) {
            nob.log(.Error, "Command started unsuccessfuly")
        }
    }
    if !nob.procs_wait(&procs) {
        nob.log(.Error, "Process waiting ended unsuccessfuly")
    }
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

async_redirect_example :: proc(cmd: ^nob.Cmd, stdout_sb: ^strings.Builder) {
    fmt.println("Async output example")
    procs: nob.Procs
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, async = &procs, stdout = stdout_sb) {
        nob.log(.Error, "Command started unsuccessfuly")
    }
    if !nob.procs_wait(&procs) {
        nob.log(.Error, "Process waiting ended unsuccessfuly")
    }
    fmt.println()
}

no_output_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("No output example")
    cmd_echo(cmd)
    if !nob.cmd_run(cmd, stdout = nil) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
}

main :: proc() {

    simple_slice_example()

    cmd: nob.Cmd

    simple_cmd_example(&cmd)

    stdout_sb: strings.Builder
    {
        strings.builder_init(&stdout_sb, context.temp_allocator)
        defer free_all(context.temp_allocator)

        simple_redirect_example(&cmd, &stdout_sb)

        fmt.print("Collected stdout:", strings.to_string(stdout_sb))
        fmt.println()
    }

    async_example(&cmd)

    async_output_example(&cmd)

    {
        strings.builder_init(&stdout_sb, context.allocator)
        defer strings.builder_destroy(&stdout_sb)

        async_redirect_example(&cmd, &stdout_sb)

        fmt.println("Collected stdout:")
        fmt.print(strings.to_string(stdout_sb))
        fmt.println()
    }

    no_output_example(&cmd)

}
