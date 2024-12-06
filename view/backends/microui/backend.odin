package backend

import "core:os"
import "core:log"
import "core:time"

import sdl "vendor:sdl2"
import mu "vendor:microui"

import ev "../../../event"
import ue "../../../user_events"
import "../../../configuration"

BACKGROUND :: mu.Color{90, 95, 100, 255}
WIDTH  :: 800
HEIGHT :: 600
DEFAULT_RENDERER : cstring : "opengl"
SUPPORTED_RENDERERS :: []cstring{
    "opengl",
    "opengl2",
    "direct3d",
    "software",
}

@private
mu_ctx := mu.Context{}


state := struct {
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    atlas_texture: ^sdl.Texture,
    should_close: bool,
}{}


get_ctx :: proc() -> ^mu.Context 
{
    return &mu_ctx
}

window_height :: proc() -> i32
{
    w := i32{}
    h := i32{}
    sdl.GetWindowSize(state.window, &w, &h)
    return h
}

window_width :: proc() -> i32
{
    w := i32{}
    h := i32{}
    sdl.GetWindowSize(state.window, &w, &h)
    return w
}

init :: proc (width: int, height: int)
{ 
    /* init SDL and renderer */
    sdl.Init(sdl.INIT_EVERYTHING)
    r_init(width, height)

    /* init microui */
    mu.init(&mu_ctx)
    mu_ctx.text_width = mu.default_atlas_text_width
    mu_ctx.text_height = mu.default_atlas_text_height
}

draw :: proc (draw_screen: proc(ctx: ^mu.Context))
{
    e := sdl.Event{}

    ctx := &mu_ctx
    for sdl.PollEvent(&e) {
        #partial switch e.type {
        case .QUIT:
            state.should_close = true
            ev.signal(&ue.quitEvent)
        case .MOUSEMOTION: 
            mu.input_mouse_move(ctx, e.motion.x, e.motion.y)
        case .MOUSEWHEEL: 
            mu.input_scroll(ctx, 0, e.wheel.y * -30)
        case .TEXTINPUT: 
            mu.input_text(ctx, string(cstring(&e.text.text[0])))

        case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
            fn := e.type == .MOUSEBUTTONDOWN ? mu.input_mouse_down : mu.input_mouse_up
            switch e.button.button {
            case sdl.BUTTON_LEFT:       fn(ctx, e.button.x, e.button.y, .LEFT)
            case sdl.BUTTON_MIDDLE:     fn(ctx, e.button.x, e.button.y, .MIDDLE)
            case sdl.BUTTON_RIGHT:      fn(ctx, e.button.x, e.button.y, .RIGHT)
            }

        case .KEYDOWN, .KEYUP: 
            if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
                sdl.PushEvent(&sdl.Event{type = .QUIT})
            }
            
            fn := mu.input_key_down if e.type == .KEYDOWN else mu.input_key_up
            
            #partial switch e.key.keysym.sym {
            case .LSHIFT:    fn(ctx, .SHIFT)
            case .RSHIFT:    fn(ctx, .SHIFT)
            case .LCTRL:     fn(ctx, .CTRL)
            case .RCTRL:     fn(ctx, .CTRL)
            case .LALT:      fn(ctx, .ALT)
            case .RALT:      fn(ctx, .ALT)
            case .RETURN:    fn(ctx, .RETURN)
            case .KP_ENTER:  fn(ctx, .RETURN)
            case .BACKSPACE: fn(ctx, .BACKSPACE)
            } 
        }
    }

    // Draw
    mu.begin(ctx)
    {
        draw_screen(ctx)
    }
    mu.end(ctx)

    /* render */
    render()

    time.sleep(10)
}

close_window :: proc ()
{
    sdl.DestroyRenderer(state.renderer)
    sdl.DestroyWindow(state.window)
    sdl.Quit()
}


window_should_close :: proc () -> bool
{
    return state.should_close
}

@private
render :: proc() 
{
    ctx := &mu_ctx
	render_texture :: proc(renderer: ^sdl.Renderer, dst: ^sdl.Rect, src: mu.Rect, color: mu.Color) {
		dst.w = src.w
		dst.h = src.h

		sdl.SetTextureAlphaMod(state.atlas_texture, color.a)
		sdl.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b)
		sdl.RenderCopy(renderer, state.atlas_texture, &sdl.Rect{src.x, src.y, src.w, src.h}, dst)
	}

	viewport_rect := &sdl.Rect{}
	sdl.GetRendererOutputSize(state.renderer, &viewport_rect.w, &viewport_rect.h)
	sdl.RenderSetViewport(state.renderer, viewport_rect)
	sdl.RenderSetClipRect(state.renderer, viewport_rect)
	sdl.SetRenderDrawColor(state.renderer, BACKGROUND.r, BACKGROUND.g, BACKGROUND.b, BACKGROUND.a)
	sdl.RenderClear(state.renderer)

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			dst := sdl.Rect{cmd.pos.x, cmd.pos.y, 0, 0}
			for ch in cmd.str do if ch&0xc0 != 0x80 {
				r := min(int(ch), 127)
				src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				render_texture(state.renderer, &dst, src, cmd.color)
				dst.x += dst.w
			}
		case ^mu.Command_Rect:
			sdl.SetRenderDrawColor(state.renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
			sdl.RenderFillRect(state.renderer, &sdl.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w)/2
			y := cmd.rect.y + (cmd.rect.h - src.h)/2
			render_texture(state.renderer, &sdl.Rect{x, y, 0, 0}, src, cmd.color)
		case ^mu.Command_Clip:
			sdl.RenderSetClipRect(state.renderer, &sdl.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h})
		case ^mu.Command_Jump: 
			unreachable()
		}
	}

	sdl.RenderPresent(state.renderer)
}


r_init :: proc(width: int, height: int) 
{
    /* init SDL window */
    state.window = sdl.CreateWindow(  "STERM", 
                                sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 
                                i32(width), i32(height), sdl.WINDOW_OPENGL)
    sdl.GL_CreateContext(state.window)

    configured_renderer := configuration.config.renderer
    configured_renderer = proc(renderer: cstring) -> cstring {
        for r in SUPPORTED_RENDERERS {
            if renderer == r {
                return r
            }
        }

        return DEFAULT_RENDERER
    }(configured_renderer)

    log.info("Using", configured_renderer, "rendering")
    backend_idx :i32 = -1
    backend_flags := sdl.RendererFlags{}
    if n := sdl.GetNumRenderDrivers(); n > 0 {
        for i in 0..<n {
            info: sdl.RendererInfo
            if sdl.GetRenderDriverInfo(i, &info) == 0 {
                log.debugf("Render driver found: %v", info)
                if info.name == configured_renderer {
                    backend_idx = i
                    backend_flags = info.flags
                }
            }
        }
    }
    else {
        log.error("No render driver found")
        return
    }


    state.renderer = sdl.CreateRenderer(state.window, backend_idx, backend_flags)
    if state.renderer == nil {
        log.error("Unable to create SDL renderer: ", sdl.GetError())
        return
    }

    state.atlas_texture = sdl.CreateTexture(state.renderer, sdl.PixelFormatEnum.RGBA32, .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT)
	assert(state.atlas_texture != nil)
	if err := sdl.SetTextureBlendMode(state.atlas_texture, .BLEND); err != 0 {
        log.error("Unable to set texture blend mode: ", sdl.GetError())
		return
	}

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a   = alpha
	}

	if err := sdl.UpdateTexture(state.atlas_texture, nil, raw_data(pixels), 4*mu.DEFAULT_ATLAS_WIDTH); err != 0 {
        log.error("Unable to update texture: ", sdl.GetError())
		return
	}
}


