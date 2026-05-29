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
    home := os.get_env("HOME", context.temp_allocator)
    ROOT_DIR = fmt.aprintf("{}/.config/", home)
}
else when ODIN_OS == .Windows {
    homedrive := os.get_env("HOMEDRIVE", context.temp_allocator)
    homepath := os.get_env("HOMEPATH", context.temp_allocator)
    ROOT_DIR = fmt.aprintf("{}{}\\AppData\\Local\\", homedrive, homepath)
}
    app_directory, alloc_err := filepath.join({ROOT_DIR, DATA_DIR}, context.temp_allocator)
    if alloc_err != nil {
        log.error("Failed to create app directory path:", alloc_err)
        return
    }

    if err := os.make_directory(app_directory); err != nil && err != .Exist {
        log.error("Unable to create app directory:", err)
    }
}

path :: proc(paths: []string) -> string
{
    prefix := []string{ROOT_DIR, DATA_DIR}
    fullpath := slice.concatenate([][]string{prefix, paths}, context.temp_allocator)
    p, err := filepath.join(fullpath, context.temp_allocator)
    if err != nil {
        log.error("Failed to create full path for ", paths, ": ", err)
        return ""
    }
    return p
}

cleanup :: proc()
{
    delete(ROOT_DIR)
}
