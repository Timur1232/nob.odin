package build

import nob "../../"
import "core:os"
import "core:fmt"

out_name :: "main"

main :: proc() {
    defer free_all(context.temp_allocator)

    cmd: nob.Cmd
    sources, err := os.read_directory_by_path("src", 0, context.temp_allocator)
    assert(err == nil)

    // `needs_rebuild()` for incremental compilation
    if nob.needs_rebuild(fmt.tprintf("./%v", out_name), sources) {
        append(&cmd, "odin")
        append(&cmd, "build", "src")
        append(&cmd, fmt.tprintf("-out:%v", out_name))

        if !nob.cmd_run(&cmd) { // or use `cmd_run_slice()` version without cmd object
            nob.log(.Error, "Unable to build project")
            os.exit(1)
        }
    }

    if len(os.args) > 1 && os.args[1] == "-run" { // or use `core:flags` module
        // `cmd` automaticly cleared when `reset` parameter is true (default)
        append(&cmd, fmt.tprintf("./%v", out_name))
        if !nob.cmd_run(&cmd) {
            nob.log(.Error, "Unable to run project")
            os.exit(1)
        }
    }
}
