package errors

import ev "../event"

Error :: enum {
    CONFIG_LOAD_ERROR
}

raised := ev.new(Error, "Error Raised")

runtime_errors := bit_set[Error]{}

raise :: proc(err: Error)
{
    runtime_errors += {err}
    ev.signal(&raised, err)
}

is_raised :: proc(err: Error) -> bool
{
    return err in runtime_errors
}