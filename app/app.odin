package app

import "../view"
import "../state"
import "../configuration"
import "../storage"
import "../errors"
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

    configuration.init()

    log_level := runtime.Logger_Level.Debug when ODIN_DEBUG else runtime.Logger_Level.Info
    logfile, err := create_log_file()
    if err != nil {
        log.errorf("Unable to open log file %v", err)
        return
    }
    logger := log.create_file_logger(logfile, log_level)
    defer log.destroy_file_logger(logger)
    context.logger = logger

    log.info("Starting Torta...")
    
    load_success := configuration.load()
    state.init()
    view.init()

    if !load_success {
        errors.raise(.CONFIG_LOAD_ERROR)
    }

    target_fps := configuration.config.fps

    draw_options := view.DrawOptions{}
    time_waited := 0 * time.Second

    for !view.should_close() {
        update := false
        update ||= state.read_new_data()
        update ||= view.event_pending()

        if time_waited >= 1 * time.Second {
            if view.view_state_.in_settings {
                draw_options += { .Force_Port_Update }
            }
            time_waited = 0
        }

        // Update twice juuuust in case
        for i in 0 ..< 2 {
            if  update ||
                .Force_Port_Update in draw_options {
                backend.draw(view.draw, draw_options)
            }

            draw_options -= { .Force_Port_Update }
            sleep_duration := 1000 / time.Duration(target_fps) * time.Millisecond
            time.sleep(sleep_duration)
            time_waited += sleep_duration
        }
    }

    view.close()
    state.cleanup()
    configuration.cleanup()
}

create_log_file :: proc() -> (fd: ^os.File, err: os.Error)
{
    dateBuf := make([]u8, 32, context.temp_allocator)
    now := time.now()
    date := time.to_string_yyyy_mm_dd(now, dateBuf)
    builder : strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    strings.write_string(&builder, date)
    strings.write_string(&builder, ".log")

    base_dir := storage.path({"logs"})

    os.make_directory(base_dir)

    fp := storage.path({"logs", strings.to_string(builder)})

    return os.open(fp, os.O_WRONLY | os.O_APPEND | os.O_CREATE, os.Permissions_Read_Write_All)
}

