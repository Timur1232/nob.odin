# nob.odin (WIP)

Simple utilities for running external commands for build recipes using just Odin compiler.

Inspired by [nob.h](https://github.com/tsoding/nob.h).

## Usage

Clone repo inside your project directory:

```sh
git clone https://github.com/nob.odin.git nob
```

Alternatively you can download only `nob.odin` file and use `package nob` for build recipe:

```sh
wget https://raw.githubusercontent.com/Timur1232/nob.odin/refs/heads/master/nob.odin
```

Create build "script" file:

```odin
package build
import "nob"
import "core:os"
import "core:fmt"

out_name :: "main"

main :: proc() {
    defer free_all(context.temp_allocator)

    cmd: nob.Cmd
    append(&cmd, "odin")
    append(&cmd, "build", "src")
    append(&cmd, fmt.tprintf("-out:%v", out_name))
    if !nob.cmd_run(&cmd) { // or use cmd_run_slice version without cmd object
        nob.log(.Error, "Unable to build project")
        os.exit(1)
    }

    if len(os.args) > 1 && os.args[1] == "-run" { // or use core:flags module
        append(&cmd, fmt.tprintf("./%v", out_name)) // cmd automaticly cleared on when reset parameter is true (default)
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


