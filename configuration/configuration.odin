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
    defer delete(config_path)

    log.info("Loading configuration file", config_path)
    if data, ok := os.read_entire_file(config_path); ok {
        defer delete(data)
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
    defer delete(config_path)

    log.info("Saving configuration to", config_path)
    encoded, err := json.marshal(config, ENCODING_OPTIONS)
    defer delete(encoded)
    if err != nil {
        log.error("Unable to encode configuration", err)
        return
    }

    if os.write_entire_file(config_path, encoded) {
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

    current_dir := os.get_current_directory()
    defer delete(current_dir)

    font_fullpath := ""
    exe_path := filepath.dir(os.args[0])
    defer delete(exe_path)

    abs_path, abs_path_ok := filepath.abs(exe_path)
    if !abs_path_ok {
        log.error("Unable to resolve absolute path of executable, using current directory as fallback")
        abs_path = strings.clone(exe_path)
    }
    defer delete(abs_path)
    
    when ODIN_OS == .Windows {
        font_fullpath = fmt.aprintf("%v\\%v", abs_path, "assets\\fonts\\default.ttf")
        defer delete(font_fullpath)
    }
    else when ODIN_OS == .Linux {
        font_fullpath = fmt.aprintf("%v/%v", abs_path, "assets/fonts/default.ttf")
        defer delete(font_fullpath)
    }
    
    config.font.name = strings.clone_to_cstring(font_fullpath)

    return config
}