package nob

import "base:runtime"
import logm "core:log"
import "core:fmt"
import "core:os"
import "core:time"

log_level_str :: proc(level: runtime.Logger_Level) -> string {
    switch level {
    case .Debug:   return "[DEBUG]"
    case .Info:    return "[INFO]"
    case .Warning: return "[WARNING]"
    case .Error:   return "[ERROR]"
    case .Fatal:   return "[FATAL]"
    }
    unreachable()
}

logger_proc :: proc(data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
    level_str := log_level_str(level)
    fmt.println(level_str, text)
}

log :: proc(level: logm.Level, fmt: string, args: ..any, location := #caller_location) {
    context.logger = runtime.Logger{ logger_proc, nil, .Debug, nil }
    logm.logf(level, fmt, ..args, location = location)
}

Cmd :: [dynamic]string

Null :: distinct struct{}
Stdio_Redirect :: union {
    Null, // No output
    ^string,
    ^os.File,
}

Proc :: struct {
    using os_process: os.Process,
}
Procs :: [dynamic]Proc

cmd_run_dynamic_array :: proc(cmd: ^Cmd, reset := true, async: ^Procs = nil, stdout: Stdio_Redirect = nil, stderr: Stdio_Redirect = nil, allocator := context.temp_allocator) -> (ok: bool) {
    ok = cmd_run_slice(cmd^[:], async, stdout, stderr, allocator)
    if reset {
        clear(cmd)
    }
    return
}

cmd_run_slice :: proc(cmd: []string, async: ^Procs = nil, stdout: Stdio_Redirect = nil, stderr: Stdio_Redirect = nil, allocator := context.temp_allocator) -> (ok: bool) {
    log(.Info, "CMD: %v", cmd)

    desc: os.Process_Desc
    desc.command = cmd

    current_workdir, dir_err := os.get_working_directory(allocator)
    defer delete(current_workdir, allocator)
    if dir_err != nil {
        log(.Error, "Unable to get current working directory: %v", dir_err)
        return false
    }
    desc.working_dir = current_workdir

    _, stdout_is_str := stdout.(^string)
    _, stderr_is_str := stderr.(^string)

    if stdout_file, ok := stdout.(^os.File); ok {
        desc.stdout = stdout_file
    }
    if stderr_file, ok := stderr.(^os.File); ok {
        desc.stderr = stderr_file
    }

    stdout_exec: []byte
    stderr_exec: []byte
    defer {
        delete(stdout_exec)
        delete(stderr_exec)
    }

    if async == nil {
        state: os.Process_State
        err: os.Error

        state, stdout_exec, stderr_exec, err = os.process_exec(desc, allocator)
        if err != nil {
            log(.Error, "Unable to start process: %v", err)
            return false
        }
        if !state.success {
            log(.Error, "Process ended unsuccessfuly. Exit code: %v", state.exit_code)
            return false
        }

        if stdout == nil {
            fmt.print(string(stdout_exec))
        } else if stdout_str, stdout_is_string := stdout.(^string); stdout_is_string {
            if stdout_str != nil {
                stdout_str^ = string(stdout_exec)
                stdout_exec = nil
            }
        }

        if stderr == nil {
            fmt.print(string(stderr_exec))
        } else if stderr_str, stderr_is_string := stderr.(^string); stderr_is_string {
            if stderr_str != nil {
                stderr_str^ = string(stderr_exec)
                stderr_exec = nil
            }
        }
    } else {
        process: Proc

        if desc.stdout == nil {
            desc.stdout = os.stdout
        }
        if desc.stderr == nil {
            desc.stderr = os.stderr
        }

        if stdout_is_str || stderr_is_str {
            log(.Warning, "Redirecting to string for stdout and stderr in async mode is ignored for now")
        }

        os_process, err := os.process_start(desc)
        if err != nil {
            log(.Error, "Unable to start process: %v", err)
            return false
        }
        process.os_process = os_process
        append(async, process)
        log(.Info, "PID: %v", process.pid)
    }

    return true
}

cmd_run :: proc{
    cmd_run_dynamic_array,
    cmd_run_slice,
}

procs_wait :: proc(procs: ^Procs) -> (ok: bool) {
    count := len(procs^)
    log(.Info, "Waiting on %v processes", count)
    ok = true
    for count > 0 {
        i: int
        for i < count {
            p := procs[i]
            state, err := os.process_wait(p, time.Millisecond*16)
            if err != nil && err != .Timeout {
                log(.Error, "Error during waiting on proc %v", p)
                ok = false
            }
            if state.exited {
                if !state.success {
                    log(.Error, "Process ended unsuccessfuly. Exit code: %v", state.exit_code)
                    ok = false
                } else {
                    log(.Info, "Process %v ended successfuly", p.pid)
                }
                count -= 1
                unordered_remove(procs, i)
            } else {
                i += 1
            }
        }
    }
    return
}
