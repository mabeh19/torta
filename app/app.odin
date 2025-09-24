package app

import "../view"
import "../state"
import "../configuration"
import "../storage"
import backend "../view/backends/microui"

import ev "../event"
import pe "../process_events"

import "core:thread"
import "core:time"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "base:runtime"

run :: proc()
{
    storage.init()
    defer storage.cleanup()

    log_level := runtime.Logger_Level.Debug when ODIN_DEBUG else runtime.Logger_Level.Info
    logfile, err := create_log_file()
    if err != nil {
        log.errorf("Unable to open log file %v", err)
        return
    }
    defer os.close(logfile)
    logger := log.create_file_logger(logfile, log_level)
    context.logger = logger
    defer log.destroy_file_logger(logger)
    configuration.load()
    state.init()
    view.init()

when configuration.LOCAL_TEST {
    thread.create_and_start(proc() {
        iter := 0
        for {
            str : string = "this is a very long line of text that will surely cause a line break and fill a lot\n"
            msg := fmt.aprintf("[%v] %v", iter, str)
            defer delete(msg)
            ev.signal(&pe.dataReceivedEvent, transmute([]u8)msg)

            iter += 1
            time.sleep(20 * time.Millisecond)
        }
    })
}

    for !view.should_close() {
        ev.signal(&pe.frameUpdateEvent)
        backend.draw(view.draw)
    }

    view.close()
    state.cleanup()
    configuration.cleanup()
}

create_log_file :: proc() -> (fd: os.Handle, err: os.Error)
{
    dateBuf := make([]u8, 32)
    defer delete(dateBuf)
    now := time.now()
    date := time.to_string_yyyy_mm_dd(now, dateBuf)
    builder : strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    strings.write_string(&builder, date)
    strings.write_string(&builder, ".log")

    base_dir := storage.path({"logs"})
    defer delete(base_dir)

    os.make_directory(base_dir)

    fp := storage.path({"logs", strings.to_string(builder)})
    defer delete(fp)

when ODIN_OS == .Linux {
    accessFlags := os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
}
else when ODIN_OS == .Windows {
    accessFlags := 0
}
    return os.open(fp, os.O_WRONLY | os.O_APPEND | os.O_CREATE, accessFlags)
}

