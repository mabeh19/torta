package configuration

import "core:path/slashpath"
import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"
import "core:log"
import "core:time"
import "core:strings"
import mem "core:mem/virtual"

import "../serial"
import "../storage"

LOCAL_TEST :: #config(LOCAL_TEST, false)

FILE_NAME :: "config.json"

FontSettings :: struct {
    name: cstring,
    size: int
}

Configuration :: struct {
    pollingPeriod: time.Duration,
    historyLength: int,
    infiniteHistory: bool,
    defaultPortSettings: serial.PortSettings,
    saveLatestPortSettings: bool,
    renderer: cstring,
    font: FontSettings,
    fps: int,
}

DEFAULT_CONFIG := Configuration {
    pollingPeriod = 10,
    historyLength = 32768,
    infiniteHistory = false,
    defaultPortSettings = {
        baudrate = 115200,
        parity = 'n',
        stopBits = 1,
        blocking = false,
    },
    saveLatestPortSettings = true,
    renderer = "opengl",
    font = {
        name = "",
        size = 12,
    },
    fps = 20
}

ENCODING_OPTIONS :: json.Marshal_Options {
    pretty = true,
    use_spaces = true,
}

config_allocator := mem.Arena{}
config := Configuration{}

init :: proc()
{
    err := mem.arena_init_growing(&config_allocator)
}

load :: proc() -> bool
{
    config_path := storage.path({FILE_NAME})

    log.info("Loading configuration file", config_path)
    if data, read_err := os.read_entire_file(config_path, context.temp_allocator); read_err == nil {
        if err := json.unmarshal(data, &config, allocator = mem.arena_allocator(&config_allocator)); err != nil {
            log.error("Unable to parse configuration file:", err, " falling back to default")
            config = get_default_config()
            return false
        }
        else {
            return true
        }
        
    }

    // no file exists, so we grab a default config
    log.warn("No configuration file found, using default configuration")
    config = get_default_config()

    // Immediately save configuration to path
    save()

    return true
}

save :: proc() 
{
    config_path := storage.path({FILE_NAME})

    log.info("Saving configuration to", config_path)
    encoded, err := json.marshal(config, ENCODING_OPTIONS, context.temp_allocator)
    if err != nil {
        log.error("Unable to encode configuration", err)
        return
    }

    if os.write_entire_file(config_path, encoded) == nil {
        log.info("Configuration saved!")
    }
    else {
        log.error("Unable to save configuration to", config_path)
    }
}

cleanup :: proc()
{
    mem.arena_destroy(&config_allocator)
}

get_default_config :: proc() -> Configuration
{
    config := DEFAULT_CONFIG

    current_dir, err := os.get_working_directory(allocator = context.temp_allocator)
    if err != nil {
        return {}
    }

    font_fullpath := ""
    exe_path := filepath.dir(os.args[0])

    abs_path, abs_path_err := filepath.abs(exe_path, allocator = context.temp_allocator)
    if abs_path_err != nil {
        log.error("Unable to resolve absolute path of executable, using current directory as fallback")
        abs_path = strings.clone(exe_path)
    }

    when ODIN_OS == .Windows {
        font_fullpath = fmt.aprintf("%v\\%v", abs_path, "assets\\fonts\\default.ttf", allocator = context.temp_allocator)
    }
    else when ODIN_OS == .Linux {
        font_fullpath = fmt.aprintf("%v/%v", abs_path, "assets/fonts/default.ttf", allocator = context.temp_allocator)
    }
    
    config.font.name = strings.clone_to_cstring(font_fullpath, allocator = mem.arena_allocator(&config_allocator))

    return config
}
