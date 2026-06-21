package examples

import nob "../"
import "core:fmt"

simple_slice_example :: proc() {
    fmt.println("Simple slice example")
    if !nob.cmd_run_slice({ "echo", "aboba" }) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
}

simple_cmd_example :: proc(cmd: ^nob.Cmd) {
    fmt.println("Simple cmd example")
    append(cmd, "echo")
    append(cmd, "aboba")
    if !nob.cmd_run(cmd) {
        nob.log(.Error, "Command executed unsuccessfuly")
    }
}

simple_redirect_example :: proc(cmd: ^nob.Cmd, stdout: ^string) {
    fmt.println("Simple redirect example")
    append(cmd, "echo")
    append(cmd, "aboba")
    if !nob.cmd_run(cmd, stdout = stdout) {
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

main :: proc() {
    defer free_all(context.temp_allocator)

    simple_slice_example()
    fmt.println()

    cmd: nob.Cmd
    simple_cmd_example(&cmd)
    fmt.println()

    stdout: string
    defer delete(stdout)
    simple_redirect_example(&cmd, &stdout)
    fmt.print("Collected stdout:", stdout)
    fmt.println()

    async_example(&cmd)
}
