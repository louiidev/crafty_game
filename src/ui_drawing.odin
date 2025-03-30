package main
import sapp "../vendor/sokol/app"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"

draw_rect_bordered_center_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	border_size: f32,
	col: Vector4 = COLOR_WHITE,
	border_color: Vector4 = COLOR_WHITE,
) {
	border_size_v := size + border_size
	center_xform :=
		xform *
		linalg.matrix4_translate(Vector3{-border_size_v.x * 0.5, -border_size_v.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size + border_size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = border_color,
			img_id = .nil,
		},
		center_xform,
		&draw_frame,
	)

	center_xform = xform * linalg.matrix4_translate(Vector3{-size.x * 0.5, -size.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = col,
			img_id = .nil,
		},
		center_xform,
		&draw_frame,
	)
}

draw_rect_bordered_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	border_size: f32,
	col: Vector4 = COLOR_WHITE,
	border_color: Vector4 = COLOR_WHITE,
) {
	border_size_v := size + border_size
	border_xform :=
		xform * linalg.matrix4_translate(Vector3{-border_size * 0.5, -border_size * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size + border_size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = border_color,
			img_id = .nil,
		},
		border_xform,
		&draw_frame,
	)

	draw_quad_xform_in_frame(
		{
			size = size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = col,
			img_id = .nil,
		},
		xform,
		&draw_frame,
	)
}


BUTTON_BORDER_SIZE :: 8
BUTTON_COLOR: Vector4 : {0.5, 0.5, 0.5, 1}
BUTTON_HOVER_COLOR: Vector4 : {0.3, 0.3, 0.3, 1}
BUTTON_BORDER_COLOR: Vector4 : {1, 1, 1, 1}
BUTTON_DISABLED_COLOR: Vector4 : {0.1, 0.1, 0.1, 1.0}
BUTTON_SELECTED_COLOR: Vector4 : {0.1, 0.6, 1.0, 1}
bordered_button :: proc(
	position: Vector2,
	size: Vector2,
	text: string,
	font_size: f32,
	id: UiID,
	disabled: bool = false,
	selected: bool = false,
) -> bool {
	xform := transform_2d(position)
	color := BUTTON_COLOR
	if !disabled && aabb_center_contains(position, size, mouse_world_position) {
		ui_state.hover_id = id
		color = BUTTON_HOVER_COLOR
	}
	if !disabled && inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] && ui_state.hover_id == id {
		ui_state.down_clicked_id = id
		ui_state.click_captured = true
	}


	if disabled {
		color = BUTTON_DISABLED_COLOR
	}

	if selected {
		color = BUTTON_SELECTED_COLOR
	}

	pressed := false

	if !disabled &&
	   ui_state.hover_id == id &&
	   !ui_state.click_captured &&
	   inputs.mouse_just_released[sapp.Mousebutton.LEFT] &&
	   ui_state.down_clicked_id == id {
		pressed = true
		ui_state.click_captured = true
	}


	draw_rect_bordered_center_xform(xform, size, BUTTON_BORDER_SIZE, color, BUTTON_BORDER_COLOR)


	draw_text_center_center(transform_2d(position), text, font_size)


	return pressed
}

TEXT_BUTTON_COLOR: Vector4 : {0.7, 0.7, 0.7, 1}
TEXT_HOVER_COLOR: Vector4 : COLOR_WHITE

text_button :: proc(
	position: Vector2,
	text: string,
	font_size: f32,
	id: UiID,
	disabled: bool = false,
) -> bool {
	xform := transform_2d(position)

	size := measure_text(text, font_size) * 1.5
	center_pos := position + size * 0.5 - {20, 10}
	color := BUTTON_COLOR
	if !disabled && aabb_contains(center_pos, size, mouse_world_position) {
		ui_state.hover_id = id
		color = BUTTON_HOVER_COLOR
	}
	if !disabled && inputs.mouse_down[sapp.Mousebutton.LEFT] && ui_state.hover_id == id {
		ui_state.down_clicked_id = id
	}


	if ui_state.hover_id == id {
		t := ui_state.hover_time / HOVER_TIME
		eased_t: f32 = ease.elastic_out(ui_state.hover_id == id ? t : 0)
		start_value: f32 = 0.0
		end_value: f32 = 20.0
		current_value := start_value + eased_t * (end_value - start_value)
		draw_quad_xform(
			transform_2d(position + {current_value + size.x * 0.75, -2.5}),
			{32, 32},
			.arrow,
			DEFAULT_UV,
		)
	}

	// if disabled {
	// 	color = BUTTON_DISABLED_COLOR
	// }

	pressed := false

	if !disabled &&
	   ui_state.hover_id == id &&
	   !ui_state.click_captured &&
	   inputs.mouse_just_released[sapp.Mousebutton.LEFT] &&
	   ui_state.down_clicked_id == id {
		pressed = true
		ui_state.click_captured = true
	}

	{
		t := ui_state.hover_time / HOVER_TIME
		eased_t: f32 = ease.elastic_out(ui_state.hover_id == id ? t * 1 : 0)
		start_value: f32 = 0.0
		end_value: f32 = 20.0
		current_value := start_value + eased_t * (end_value - start_value)
		draw_text_outlined(
			transform_2d(position + {current_value, 0}),
			text,
			font_size,
			3,
			4.0,
			ui_state.hover_id == id ? TEXT_HOVER_COLOR : TEXT_BUTTON_COLOR,
			COLOR_BLACK,
		)
	}


	return pressed
}


image_button :: proc(
	position: Vector2,
	text: string,
	font_size: f32,
	id: UiID,
	size: Vector2 = {60, 24},
	disabled: bool = false,
	color_override := COLOR_WHITE,
	border_override := COLOR_BLACK,
) -> bool {
	xform := transform_2d(position)
	x_frame := 0
	hover_position: Vector2 = {0, 0}
	color := BUTTON_COLOR
	if !disabled && aabb_contains(position, size, mouse_world_position) {
		ui_state.hover_id = id
		x_frame = 1
		hover_position.y += 5
	}
	if !disabled && inputs.mouse_down[sapp.Mousebutton.LEFT] && ui_state.hover_id == id {
		ui_state.down_clicked_id = id
		hover_position.y -= 5
	}


	if disabled {
		x_frame = 3
	}

	pressed := false

	if !disabled &&
	   ui_state.hover_id == id &&
	   !ui_state.click_captured &&
	   inputs.mouse_just_released[sapp.Mousebutton.LEFT] &&
	   ui_state.down_clicked_id == id {
		pressed = true
		ui_state.click_captured = true
	}


	uv := get_frame_uvs(.buttons, {x_frame, 0}, {60, 24})
	shadow_uv := get_frame_uvs(.buttons, {4, 0}, {60, 24})
	draw_quad_center_xform(
		xform * transform_2d({-5, -5}),
		size,
		.buttons,
		shadow_uv,
		color_override,
	)
	draw_quad_center_xform(
		xform * transform_2d(hover_position),
		size,
		.buttons,
		uv,
		color_override,
	)


	draw_text_outlined_center(
		transform_2d(position - {0, 8} + hover_position),
		text,
		font_size,
		0.0,
		4.0,
		color_override,
		border_override,
	)


	return pressed
}
