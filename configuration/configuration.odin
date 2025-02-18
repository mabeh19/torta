package configuration

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"
import "core:log"
import "core:time"
import "../serial"

LOCAL_TEST :: #config(LOCAL_TEST, false)

DATA_DIR :: "torta"
ROOT_DIR : string
FILE_NAME :: "config.json"

Configuration :: struct {
    pollingPeriod: time.Duration,
    historyLength: int,
    infiniteHistory: bool,
    defaultPortSettings: serial.PortSettings,
    renderer: cstring,
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
}

ENCODING_OPTIONS := json.Marshal_Options {
    pretty = true,
    use_spaces = true,
}

config := Configuration{}

init :: proc() 
{
    when ODIN_OS == .Linux {
        home := os.get_env("HOME")
        defer delete(home)
        ROOT_DIR = fmt.aprintf("{}/.config/", home)
    }
    else when ODIN_OS == .Windows {
        homedrive := os.get_env("HOMEDRIVE")
        homepath := os.get_env("HOMEPATH")
        defer delete(homedrive)
        defer delete(homepath)
        ROOT_DIR = fmt.aprintf("{}{}\\AppData\\Local\\", homedrive, homepath)
    }
    log.info("Configuration root path:", ROOT_DIR)
}

load :: proc()
{
    if ROOT_DIR == {} {
        init()
    }

    config_path := filepath.join({ROOT_DIR, DATA_DIR, FILE_NAME})
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
    if ROOT_DIR == {} {
        init()
    }

    config_path := filepath.join({ROOT_DIR, DATA_DIR, FILE_NAME})
    defer delete(config_path)

    log.info("Saving configuration to", config_path)
    encoded, err := json.marshal(config, ENCODING_OPTIONS)
    if err != nil {
        log.error("Unable to encode configuration", err)
        return
    }

    if err := os.make_directory(config_path[:len(ROOT_DIR) + len(DATA_DIR)]); err != nil && err != .Exist {
        log.error("Unable to create app directory:", err)
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
    delete(ROOT_DIR)
}
