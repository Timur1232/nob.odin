package main

import "core:fmt"
import "core:os"

main :: proc() {
    if len(os.args) > 1 && os.args[1] == "-stdio" {
        fmt.println("Waiting for input! (ctrl+d to stop if typing manually)")
        // Will stop reading on .EOF (usually `ctrl+d` in terminals if you type manually)
        input, err := os.read_entire_file(os.stdin, context.temp_allocator)
        if err != nil {
            fmt.println("Error! %v", err)
            os.exit(1)
        }
        fmt.println("Got this string:", string(input))
    } else {
        fmt.println("Hellope!")
    }
}
