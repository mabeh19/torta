package bml_widget

import sdl "vendor:sdl2"
import mu "vendor:microui"

import "core:log"
import "core:c"
import "core:strings"
import "core:fmt"

import bml_proto  "../../../bml/protocol"
import bml_parser "../../../bml/parser"
import bml_types  "../../../bml/element"

when false 
{

FieldBuffer :: struct {
    inputBuffer: []u8,
    inputBufferLen: int,
    dataBuffer: []u8
}

Field :: struct {
    buffer: FieldBuffer,
    internal: bml_types.Field,
}

@private
buffers := map[string]Field{}


to_string :: proc(f: any) -> string
{
    return fmt.tprint(f)
}

drawCreator :: proc(ctx: ^mu.Context, proto: ^bml_proto.Protocol, packet: ^bml_parser.Packet) -> bool
{
    for f in proto.header {
        key := to_string(f)
        defer delete(key)
        switch t in f.type {
        case bml_types.BaseType:
            if buf, exists := buffers[key]; !exists {
                log.debug("Drawing field", f.name, " of size ", f.size, " type ", f.type)
                buf = {
                    buffer = {
                        inputBuffer = make([]u8, 100),
                        dataBuffer = make([]u8, t.size),
                    },
                    internal = f,
                }
                buffers[key] = buf
            }

            buf := &buffers[key]
            draw_field(ctx, buf) //t.type, f.name, buf.inputBuffer, &buf.inputBufferLen)
            //draw_int_field(ctx, f.name, buf.inputBuffer, &buf.inputBufferLen)
        case bml_types.ID:
            // TODO
        case bml_types.Fields:
            // TODO
        }
    }

    return .SUBMIT in mu.button(ctx, "Finish")
}

draw_field :: proc(ctx: ^mu.Context, field: ^Field) //type: typeid, name: string, buffer: []u8, buffer_len: ^int)
{
    switch field.internal.type.(bml_types.BaseType).type {
    case i64le, i64be, i32le, i32be, i16le, i16be, i8:
        draw_int_field(ctx, field) //name, buffer, buffer_len)

    case u64le, u64be, u32le, u32be, u16le, u16be, u8:
        draw_uint_field(ctx, field) //name, buffer, buffer_len)

    case f64le, f64be, f32le, f32be, f16le, f16be:
        draw_float_field(ctx, field) //name, buffer, buffer_len)
    }
}

draw_int_field :: proc(ctx: ^mu.Context, field: ^Field) // name: string, buffer: []u8, buffer_len: ^int)
{
    mu.layout_row(ctx, {150, -1})
    mu.label(ctx, name)
    if .SUBMIT in mu.textbox(ctx, buffer, buffer_len) {
        
    }
}

draw_uint_field :: proc(ctx: ^mu.Context, field: ^Field) //name: string, buffer: []u8, buffer_len: ^int)
{
    mu.layout_row(ctx, {150, -1})
    mu.label(ctx, name)
    if .SUBMIT in mu.textbox(ctx, buffer, buffer_len) {

    }
}

draw_float_field :: proc(ctx: ^mu.Context, field: ^Field) //name: string, buffer: []u8, buffer_len: ^int)
{
    mu.layout_row(ctx, {150, -1})
    mu.label(ctx, name)
    if .SUBMIT in mu.textbox(ctx, buffer, buffer_len) {

    }
}
}
