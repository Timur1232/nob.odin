package nob

Cmd :: [dynamic]string

Null :: distinct struct{}
Stdio_Redirect :: union {
    ^strings.Builder,
    ^os.File,
}

Proc_String_Redirect :: struct {
    file_r: ^os.File,
    file_w: ^os.File,
    sb: ^strings.Builder,
}

Proc :: struct {
    using os_process: os.Process,
    stdout: Proc_String_Redirect,
    stderr: Proc_String_Redirect,
}
Procs :: [dynamic]Proc

cmd_run_dynamic_array :: proc(
    cmd: ^Cmd,
    reset := true,
    async: ^Procs = nil,
    stdout: Stdio_Redirect = os.stdout,
    stderr: Stdio_Redirect = os.stderr,
    workdir := "",
) -> (
    ok: bool
) {
    ok = cmd_run_slice(cmd[:], async = async, stdout = stdout, stderr = stderr, workdir = workdir)
    if reset {
        clear(cmd)
    }
    return
}

cmd_run_slice :: proc(
    cmd: []string,
    async: ^Procs = nil,
    stdout: Stdio_Redirect = os.stdout,
    stderr: Stdio_Redirect = os.stderr,
    workdir := "",
) -> (
    ok: bool
) {
    if len(workdir) > 0 {
        log(.Info, "WORKDIR: %v", workdir)
    }
    log(.Info, "CMD: %v", cmd)

    desc: os.Process_Desc
    desc.command = cmd
    desc.working_dir = workdir

    process, proc_err := create_process(desc, stdout, stderr)
    if proc_err != nil {
        log(.Error, "Unable to create process. Error: %v", proc_err)
        return false
    }

    if async == nil {
        defer {
            os.close(process.stdout.file_r)
            os.close(process.stderr.file_r)
        }
        defer if v, ok := stdout.(^os.File); ok && v != os.stdout {
            os.close(v)
        }
        defer if v, ok := stderr.(^os.File); ok && v != os.stderr {
            os.close(v)
        }

        state, err := pipe_to_string_and_wait(process)
        if err != nil {
            return false
        }

        if !state.success {
            log(.Error, "Process ended unsuccessfuly. Exit code: %v", state.exited)
            return false
        }
    } else {
        append(async, process)
    }

    return true
}

cmd_run :: proc{
    cmd_run_dynamic_array,
    cmd_run_slice,
}

procs_wait :: proc(procs: ^Procs, allocator := context.temp_allocator) -> (ok: bool) {
    count := len(procs^)
    log(.Info, "Waiting on %v processes", count)
    ok = true
    for count > 0 {
        i: int
        for i < count {
            p := procs[i]
            state, err := pipe_to_string_and_wait(p, timeout = time.Millisecond*16, allocator = allocator)
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

                os.close(p.stdout.file_r)
                os.close(p.stderr.file_r)
                if p.stdout.file_w != os.stdout {
                    os.close(p.stdout.file_w)
                }
                if p.stderr.file_w != os.stderr {
                    os.close(p.stderr.file_w)
                }
            } else {
                i += 1
            }
        }
    }
    return
}

log :: proc(level: logm.Level, fmt: string, args: ..any, location := #caller_location) {
    context.logger = runtime.Logger{ logger_proc, nil, .Debug, nil }
    logm.logf(level, fmt, ..args, location = location)
}

// When ext = "" then all files whould be checked
needs_rebuild :: proc{
    needs_rebuild_by_file_info,
    needs_rebuild_by_path,
    needs_rebuild1_by_path,
    needs_rebuild1_by_time,
}

// When ext = "" then all files whould be checked
needs_rebuild_by_file_info :: proc(out_path: string, source_fis: []os.File_Info, ext := ".odin") -> bool {
    if !os.exists(out_path) {
        return true
    }

    out_write_time, err := os.last_write_time_by_name(out_path)
    if err != nil {
        log(.Error, "Unable to read last write time for out file %v", out_path)
        return false
    }

    for fi in source_fis {
        if len(ext) == 0 || ext == filepath.ext(fi.name) {
            if needs_rebuild1_by_time(out_write_time, fi.modification_time) {
                return true
            }
        }
    }

    return false
}

// When ext = "" then all files whould be checked
needs_rebuild_by_path :: proc(out_path: string, source_paths: []string, ext := ".odin") -> bool {
    if !os.exists(out_path) {
        return true
    }

    out_write_time, err := os.last_write_time_by_name(out_path)
    if err != nil {
        log(.Error, "Unable to read last write time for out file %v", out_path)
        return false
    }

    for p in source_paths {
        if len(ext) == 0 || ext == filepath.ext(p) {
            source_write_time, source_err := os.last_write_time_by_name(p)
            if source_err != nil {
                log(.Error, "Unable to read last write time for source file %v", p, source_err)
                return false
            }
            if needs_rebuild1_by_time(out_write_time, source_write_time) {
                return true
            }
        }
    }

    return false
}

needs_rebuild1_by_path :: proc(out_path: string, source_path: string) -> bool {
    if !os.exists(out_path) {
        return true
    }

    out_write_time, out_err := os.last_write_time_by_name(out_path)
    if out_err != nil {
        log(.Error, "Unable to read last write time for out file %v. Error: %v", out_path, out_err)
        return false
    }

    source_write_time, source_err := os.last_write_time_by_name(source_path)
    if source_err != nil {
        log(.Error, "Unable to read last write time for source file %v", source_path, source_err)
        return false
    }

    return needs_rebuild1_by_time(out_write_time, source_write_time)
}

needs_rebuild1_by_time :: proc(out_write_time: time.Time, source_write_time: time.Time) -> bool {
    diff := time.diff(out_write_time, source_write_time)
    return diff >= 0
}

@(private="file")
pipe_to_string_and_wait :: proc(
    process: Proc,
    timeout := os.TIMEOUT_INFINITE,
    allocator := context.temp_allocator,
) -> (
    state: os.Process_State,
    err: os.Error,
) {
    if err = pipe_to_string(process.stdout, allocator); err != nil {
        return
    }
    if err = pipe_to_string(process.stderr, allocator); err != nil {
        return
    }

    state, err = os.process_wait(process, timeout)

    if err != nil && err != .Timeout {
        log(.Error, "Unable to wait on process. Error: %v", err)
        state, _ = os.process_wait(process, timeout = 0)
        if !state.exited {
            _ = os.process_kill(process)
            state, _ = os.process_wait(process)
        }
        return
    }

    return
}

@(private="file")
@(require_results)
redirect :: proc(process: ^Proc, stdio: Stdio_Redirect) -> (stdio_w: ^os.File, err: os.Error) {
    switch v in stdio {
    case nil: stdio_w = nil
    case ^os.File: stdio_w = v
    case ^strings.Builder:
        stdio_r: ^os.File
        stdio_r, stdio_w = os.pipe() or_return
        process.stdout.file_r = stdio_r
        process.stdout.file_w = stdio_w
        process.stdout.sb = v
    }
    return
}

@(private="file")
@(require_results)
create_process :: proc(
    desc: os.Process_Desc,
    stdout_redir: Stdio_Redirect,
    stderr_redir: Stdio_Redirect,
    loc := #caller_location,
) -> (
    process: Proc,
    err: os.Error
) {
    assert(desc.stdout == nil, "Cannot redirect stdout when it's being captured", loc)
    assert(desc.stderr == nil, "Cannot redirect stderr when it's being captured", loc)

    stdout_w := redirect(&process, stdout_redir) or_return
    stderr_w := redirect(&process, stderr_redir) or_return

    defer if stdout_w != os.stdout {
        os.close(stdout_w)
    }
    defer if stderr_w != os.stderr {
        os.close(stderr_w)
    }
    desc := desc
    desc.stdout = stdout_w
    desc.stderr = stderr_w

    os_process := os.process_start(desc) or_return
    process.os_process = os_process

    return
}

@(private="file")
pipe_to_string :: proc(
    str_redir: Proc_String_Redirect,
    allocator := context.temp_allocator
) -> (
    err: os.Error
) {
    if str_redir.sb == nil || str_redir.file_w == nil || str_redir.file_r == nil {
        return
    }

    file_r := str_redir.file_r
    sb := str_redir.sb

    buf: [1024]u8 = ---

    done, has_data: bool
    for err == nil && !done {
        n := 0

        if !done {
            has_data, err = os.pipe_has_data(file_r)
            if has_data {
                n, err = os.read(file_r, buf[:])
            }

            switch err {
            case nil:
                strings.write_bytes(sb, buf[:n])
            case .EOF, .Broken_Pipe:
                done = true
                err = nil
            }
        }
    }

    return
}

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

import "base:runtime"
import logm "core:log"
import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"
import "core:path/filepath"
