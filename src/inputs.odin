
package main
import sapp "../vendor/sokol/app"
import "base:runtime"
import "core:fmt"
import "core:sys/windows"


GamePadBtns :: enum {
	Up,
	Down,
	Left,
	Right,
	Start,
	Back,
	LeftThumb,
	RightThumb,
	LeftShoulder,
	RightShoulder,
	A,
	B,
	X,
	Y,
	LeftTrigger,
	RightTrigger,
}


Inputs :: struct {
	gamepad_button_down:                                                      [GamePadBtns]bool,
	gamepad_just_pressed:                                                     [GamePadBtns]bool,
	button_down:                                                              [sapp.MAX_KEYCODES]bool,
	button_just_pressed:                                                      [sapp.MAX_KEYCODES]bool,
	mouse_down:                                                               [sapp.MAX_MOUSEBUTTONS]bool,
	mouse_just_pressed:                                                       [sapp.MAX_MOUSEBUTTONS]bool,
	mouse_pos, prev_mouse_pos, mouse_delta, mouse_down_pos, mouse_down_delta: Vector2,
	screen_mouse_pos, screen_mouse_down_pos, screen_mouse_down_delta:         Vector2,
	mouse_scroll_delta:                                                       Vector2,
	xinput_state:                                                             windows.XINPUT_STATE,
}


inputs: Inputs
event_cb :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()
	inputs.screen_mouse_pos.x = event.mouse_x
	inputs.screen_mouse_pos.y = auto_cast (sapp.height() - auto_cast event.mouse_y)
	result := windows.XInputGetState(.One, &inputs.xinput_state)


	using sapp.Event_Type
	#partial switch event.type {

	case .MOUSE_DOWN, .MOUSE_UP, .MOUSE_MOVE, .MOUSE_SCROLL:
		if (event.type == .MOUSE_DOWN) {
			inputs.mouse_down_pos = inputs.mouse_pos
			inputs.screen_mouse_down_pos = inputs.screen_mouse_pos
			inputs.mouse_down[event.mouse_button] = true
		} else if (event.type == .MOUSE_UP) {
			inputs.mouse_down[event.mouse_button] = false
			inputs.mouse_just_pressed[event.mouse_button] = true
		} else if (event.type == .MOUSE_SCROLL) {
			inputs.mouse_scroll_delta = {event.scroll_x, event.scroll_y}
		}


	case .KEY_DOWN:
		inputs.button_down[event.key_code] = true

	case .KEY_UP:
		inputs.button_down[event.key_code] = false
		inputs.button_just_pressed[event.key_code] = true
	}
	using inputs
	using windows.XINPUT_GAMEPAD_BUTTON_BIT
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.A in xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.A] {
			inputs.gamepad_just_pressed[.A] = true
		}
		inputs.gamepad_button_down[.A] = true
	} else {
		inputs.gamepad_button_down[.A] = false
	}


	if windows.XINPUT_GAMEPAD_BUTTON_BIT.B in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.A] {
			inputs.gamepad_just_pressed[.A] = true
		}
		inputs.gamepad_button_down[.B] = true
	} else {
		inputs.gamepad_button_down[.B] = false
	}

	// Check if the X button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.X in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.X] {
			inputs.gamepad_just_pressed[.X] = true
		}
		inputs.gamepad_button_down[.X] = true
	} else {
		inputs.gamepad_button_down[.X] = false
	}

	// Check if the Y button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.Y in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Y] {
			inputs.gamepad_just_pressed[.Y] = true
		}
		inputs.gamepad_button_down[.Y] = true
	} else {
		inputs.gamepad_button_down[.Y] = false
	}

	// Check if the D-Pad Up button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_UP in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Up] {
			inputs.gamepad_just_pressed[.Up] = true
		}
		inputs.gamepad_button_down[.Up] = true
	} else {
		inputs.gamepad_button_down[.Up] = false
	}

	// Check if the D-Pad Down button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_DOWN in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Down] {
			inputs.gamepad_just_pressed[.Down] = true
		}
		inputs.gamepad_button_down[.Down] = true
	} else {
		inputs.gamepad_button_down[.Down] = false
	}

	// Check if the D-Pad Left button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_LEFT in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Left] {
			inputs.gamepad_just_pressed[.Left] = true
		}
		inputs.gamepad_button_down[.Left] = true
	} else {
		inputs.gamepad_button_down[.Left] = false
	}

	// Check if the D-Pad Right button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_RIGHT in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Right] {
			inputs.gamepad_just_pressed[.Right] = true
		}
		inputs.gamepad_button_down[.Right] = true
	} else {
		inputs.gamepad_button_down[.Right] = false
	}

	// Check if the Start button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.START in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Start] {
			inputs.gamepad_just_pressed[.Start] = true
		}
		inputs.gamepad_button_down[.Start] = true
	} else {
		inputs.gamepad_button_down[.Start] = false
	}

	// Check if the Back button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.BACK in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.Back] {
			inputs.gamepad_just_pressed[.Back] = true
		}
		inputs.gamepad_button_down[.Back] = true
	} else {
		inputs.gamepad_button_down[.Back] = false
	}

	// Check if the Left Thumb button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.LEFT_THUMB in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.LeftThumb] {
			inputs.gamepad_just_pressed[.LeftThumb] = true
		}
		inputs.gamepad_button_down[.LeftThumb] = true
	} else {
		inputs.gamepad_button_down[.LeftThumb] = false
	}

	// Check if the Right Thumb button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.RIGHT_THUMB in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.RightThumb] {
			inputs.gamepad_just_pressed[.RightThumb] = true
		}
		inputs.gamepad_button_down[.RightThumb] = true
	} else {
		inputs.gamepad_button_down[.RightThumb] = false
	}

	// Check if the Left Shoulder button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.LEFT_SHOULDER in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.LeftShoulder] {
			inputs.gamepad_just_pressed[.LeftShoulder] = true
		}
		inputs.gamepad_button_down[.LeftShoulder] = true
	} else {
		inputs.gamepad_button_down[.LeftShoulder] = false
	}

	// Check if the Right Shoulder button is pressed
	if windows.XINPUT_GAMEPAD_BUTTON_BIT.RIGHT_SHOULDER in inputs.xinput_state.Gamepad.wButtons {
		if !inputs.gamepad_button_down[.RightShoulder] {
			inputs.gamepad_just_pressed[.RightShoulder] = true
		}
		inputs.gamepad_button_down[.RightShoulder] = true
	} else {
		inputs.gamepad_button_down[.RightShoulder] = false
	}

	// Left and Right Triggers (handled as analog values, not bitmask)
	if inputs.xinput_state.Gamepad.bLeftTrigger > 30 {
		if !inputs.gamepad_button_down[.LeftTrigger] {
			inputs.gamepad_just_pressed[.LeftTrigger] = true
		}
		inputs.gamepad_button_down[.LeftTrigger] = true
	} else {
		inputs.gamepad_button_down[.LeftTrigger] = false
	}

	if inputs.xinput_state.Gamepad.bRightTrigger > 30 {
		if !inputs.gamepad_button_down[.RightTrigger] {
			inputs.gamepad_just_pressed[.RightTrigger] = true
		}
		inputs.gamepad_button_down[.RightTrigger] = true
	} else {
		inputs.gamepad_button_down[.RightTrigger] = false
	}


}


inputs_end_frame :: proc() {
	inputs.mouse_scroll_delta = {}
	for i := 0; i < len(inputs.button_just_pressed); i += 1 {
		inputs.button_just_pressed[i] = false
	}

	for &btn in inputs.gamepad_just_pressed {
		btn = false
	}

	for i := 0; i < len(inputs.mouse_just_pressed); i += 1 {
		inputs.mouse_just_pressed[i] = false
	}
}
