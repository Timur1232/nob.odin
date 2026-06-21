package nob // for same namespace

import "core:fmt"

examples_dir :: "examples/"

build_example_dir :: "build_example/"
api_examples_dir :: "api_examples/"

main :: proc() {
    cmd: Cmd
    append(&cmd, "odin")
    append(&cmd, "run")
    append(&cmd, ".")
    append(&cmd, "--", "-run")

    fmt.println("Build example")

    if !cmd_run(&cmd, workdir = examples_dir + build_example_dir) {
        log(.Error, "Unable to run build example")
    }

    fmt.println("--------------------------------------")

    append(&cmd, "odin")
    append(&cmd, "run")
    append(&cmd, ".")

    fmt.println("API example")

    if !cmd_run(&cmd, workdir = examples_dir + api_examples_dir) {
        log(.Error, "Unable to run api examples")
    }
}
