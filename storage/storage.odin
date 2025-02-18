package storage

import "core:os"
import "core:fmt"
import "core:path/filepath"
import "core:slice"
import "core:log"

DATA_DIR :: "torta"
ROOT_DIR : string

init :: proc()
{
when ODIN_OS == .Linux {
    home := os.get_env("HOME")
    defer delete(home)
    ROOT_DIR = fmt.aprintf("{}/.local/", home)
}
else when ODIN_OS == .Windows {
    homedrive := os.get_env("HOMEDRIVE")
    homepath := os.get_env("HOMEPATH")
    defer delete(homedrive)
    defer delete(homepath)
    ROOT_DIR = fmt.aprintf("{}{}\\AppData\\Local\\", homedrive, homepath)
}
    app_directory := filepath.join({ROOT_DIR, DATA_DIR})
    defer delete(app_directory)
    
    if err := os.make_directory(app_directory); err != nil && err != .Exist {
        log.error("Unable to create app directory:", err)
    }
}

path :: proc(paths: []string) -> string
{
    prefix := []string{ROOT_DIR, DATA_DIR}
    fullpath := slice.concatenate([][]string{prefix, paths})
    defer delete(fullpath)
    return filepath.join(fullpath) 
}

cleanup :: proc()
{
    delete(ROOT_DIR)
}
