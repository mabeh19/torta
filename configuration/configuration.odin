package configuration

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"
import "core:log"
import "core:time"

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
    renderer: cstring,
    font: FontSettings
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
    renderer = "opengl",
    font = {
        name = "assets/fonts/default.ttf",
        size = 12,
    },
}

ENCODING_OPTIONS := json.Marshal_Options {
    pretty = true,
    use_spaces = true,
}

config := Configuration{}

load :: proc()
{
    config_path := storage.path({FILE_NAME})
    defer delete(config_path)
    
    log.info("Loading configuration file", config_path)
    if data, ok := os.read_entire_file(config_path); ok {
        defer delete(data)
        if err := json.unmarshal(data, &config); err != nil {
            log.error("Unable to parse configuration file:", err)
        }
        else {
            return
        }
    }

    // no file exists, so we grab a default config
    log.warn("No configuration file found, using default configuration")
    config = DEFAULT_CONFIG

    // Immediately save configuration to path
    save()
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
    delete(config.renderer)
    delete(config.defaultPortSettings.port)
}
