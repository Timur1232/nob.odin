# nob.odin (WIP)

Simple utilities for running external commands for build recipes using just Odin compiler.

Inspired by [nob.h](https://github.com/tsoding/nob.h).

## Usage

See [run_examples.odin](https://github.com/Timur1232/nob.odin/blob/master/run_examples.odin) and [examples](https://github.com/Timur1232/nob.odin/tree/master/examples) for better understanding.

Bootstrap (no need to clone whole repo):

```sh
mkdir nob
wget https://raw.githubusercontent.com/Timur1232/nob.odin/refs/heads/master/nob.odin -o nob/nob.odin
```

Create build "script" file (from [build example](https://github.com/Timur1232/nob.odin/blob/master/examples/build_example/build.odin)):

```odin
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
```

And run it:

```sh
odin run build.odin -file -- -run
```

Run project root to run all examples (see [run_examples.odin](https://github.com/Timur1232/nob.odin/blob/master/run_examples.odin)):

```sh
odin run .
```
