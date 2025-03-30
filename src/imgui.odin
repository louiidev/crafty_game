#+build windows
package main

import imgui "../vendor/odin-imgui"
import imgui_dx "../vendor/odin-imgui/imgui_impl_dx11"

import sapp "../vendor/sokol/app"
import sg "../vendor/sokol/gfx"

import "base:runtime"

Imgui_State :: struct {
	is_hovered:  bool,
	using frame: struct {},
}
imgui_state: Imgui_State

imgui_init :: proc() {
	ctx: ^imgui.Context = imgui.CreateContext()

	io := imgui.GetIO()
	io.ConfigFlags += {.DockingEnable, .NavEnableKeyboard}
	io.DisplaySize = v2{f32(1280), f32(720)}

	imgui_dx.Init(auto_cast sg.d3d11_device(), auto_cast sg.d3d11_device_context())
}

imgui_new_frame :: proc() {
	imgui_dx.NewFrame()
	imgui.NewFrame()

	// app_state.frame.hover_consumed = imgui_state.is_hovered
	// if imgui_state.is_hovered {
	// 	if key_just_pressed(.LEFT_MOUSE) {
	// 		consume_key_just_pressed(.LEFT_MOUSE)
	// 	}
	// }
}

imgui_draw :: proc() {
	imgui.Render()
	imgui_dx.RenderDrawData(imgui.GetDrawData())
	imgui_state.frame = {}
}

sokol_update_modifier :: proc(io: ^imgui.IO, mod: u32) {
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Ctrl, (mod & sapp.MODIFIER_CTRL) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Shift, (mod & sapp.MODIFIER_SHIFT) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Alt, (mod & sapp.MODIFIER_ALT) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Super, (mod & sapp.MODIFIER_SUPER) != 0)
}

sokol_add_mouse_pos_event :: proc(io: ^imgui.IO, x: f32, y: f32) {
	imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
	imgui.IO_AddMousePosEvent(io, x, y)
}

sokol_to_imgui :: proc "c" (ev: ^sapp.Event) -> bool {
	context = runtime.default_context()
	io := imgui.GetIO()
	dpi_scale := imgui.GetWindowDpiScale()

	#partial switch ev.type {
	case .FOCUSED:
		imgui.IO_AddFocusEvent(io, true)
	case .UNFOCUSED:
		imgui.IO_AddFocusEvent(io, false)
	case .MOUSE_DOWN:
		x := ev.mouse_x / dpi_scale
		y := ev.mouse_y / dpi_scale
		imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
		imgui.IO_AddMouseButtonEvent(io, cast(i32)ev.mouse_button, true)
		imgui.IO_AddMousePosEvent(io, x, y)

		sokol_update_modifier(io, ev.modifiers)

	case .MOUSE_UP:
		x := ev.mouse_x / dpi_scale
		y := ev.mouse_y / dpi_scale
		imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)

		imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
		imgui.IO_AddMouseButtonEvent(io, cast(i32)ev.mouse_button, false)
		sokol_update_modifier(io, ev.modifiers)

	case .MOUSE_MOVE:
		x := ev.mouse_x / dpi_scale
		y := ev.mouse_y / dpi_scale
		imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
		imgui.IO_AddMousePosEvent(io, x, y)
		imgui_state.is_hovered = io.WantCaptureMouse
	case .MOUSE_SCROLL:
		x := ev.scroll_x
		y := ev.scroll_y
		imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
		imgui.IO_AddMouseWheelEvent(io, x, y)
		break
	case .RESIZED:
		//global.window_h = ev.window_height
		//global.window_w = ev.window_width
		io.DisplaySize = v2{f32(ev.window_width), f32(ev.window_height)}
	/**
        case SAPP_EVENTTYPE_KEY_DOWN:
            _simgui_update_modifiers(io, ev->modifiers);
            // intercept Ctrl-V, this is handled via EVENTTYPE_CLIPBOARD_PASTED
            if (!_simgui.desc.disable_paste_override) {
                if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_V)) {
                    break;
                }
            }
            // on web platform, don't forward Ctrl-X, Ctrl-V to the browser
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_X)) {
                sapp_consume_event();
            }
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_C)) {
                sapp_consume_event();
            }
            // it's ok to add ImGuiKey_None key events
            _simgui_add_sapp_key_event(io, ev->key_code, true);
            break;
        case SAPP_EVENTTYPE_KEY_UP:
            _simgui_update_modifiers(io, ev->modifiers);
            // intercept Ctrl-V, this is handled via EVENTTYPE_CLIPBOARD_PASTED
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_V)) {
                break;
            }
            // on web platform, don't forward Ctrl-X, Ctrl-V to the browser
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_X)) {
                sapp_consume_event();
            }
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_C)) {
                sapp_consume_event();
            }
            // it's ok to add ImGuiKey_None key events
            _simgui_add_sapp_key_event(io, ev->key_code, false);
            break;
        case SAPP_EVENTTYPE_CHAR:
            /* on some platforms, special keys may be reported as
               characters, which may confuse some ImGui widgets,
               drop those, also don't forward characters if some
               modifiers have been pressed
            */
            _simgui_update_modifiers(io, ev->modifiers);
            if ((ev->char_code >= 32) &&
                (ev->char_code != 127) &&
                (0 == (ev->modifiers & (SAPP_MODIFIER_ALT|SAPP_MODIFIER_CTRL|SAPP_MODIFIER_SUPER))))
            {
                simgui_add_input_character(ev->char_code);
            }
            break;
        case SAPP_EVENTTYPE_CLIPBOARD_PASTED:
            // simulate a Ctrl-V key down/up
            if (!_simgui.desc.disable_paste_override) {
                _simgui_add_imgui_key_event(io, _simgui_copypaste_modifier(), true);
                _simgui_add_imgui_key_event(io, ImGuiKey_V, true);
                _simgui_add_imgui_key_event(io, ImGuiKey_V, false);
                _simgui_add_imgui_key_event(io, _simgui_copypaste_modifier(), false);
            }
            break;

		**/

	}

	return io.WantCaptureMouse

}
