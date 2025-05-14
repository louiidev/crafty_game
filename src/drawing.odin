package main
import sapp "../vendor/sokol/app"
import sg "../vendor/sokol/gfx"
import sglue "../vendor/sokol/glue"
import stbi "../vendor/stb-web/image"
import stbrp "../vendor/stb-web/rect_pack"
import stbtt "../vendor/stb-web/truetype"
import "base:runtime"
import "core:math"
import "core:math/linalg"
import "core:strings"


state: struct {
	pass_action: sg.Pass_Action,
	pip:         sg.Pipeline,
	bind:        sg.Bindings,
	rx, ry:      f32,
}

Vertex :: struct {
	pos:          Vector2,
	color:        Vector4,
	uv:           Vector2,
	tex_index:    f32,
	flash_amount: f32,
}

Quad :: [4]Vertex
DEFAULT_UV :: v4{0, 0, 1, 1}

GfxFilterMode :: enum {
	NEAREST,
	LINEAR,
}

QuadType :: enum {
	REGULAR,
	TEXT,
	CIRCLE,
}

GfxShaderExtension :: struct {
	shader_id: u32,
}


ZLayer :: enum u8 {
	background,
	shadow,
	game_play,
	particles,
	ui,
	// :layer
}

set_z_layer :: proc(zlayer: ZLayer) {
	draw_frame.active_z_layer = zlayer
}

DrawQuad :: struct {
	size:   Vector2,
	color:  Vector4,
	uv:     [4]Vector2,
	img_id: ImageId,
}


DrawFrame :: struct {
	projection:       Matrix4,
	camera_xform:     Matrix4,
	quads:            [ZLayer][dynamic]Quad,
	active_z_layer:   ZLayer,
	shader_extension: sg.Pipeline,
	cleared_frame:    bool,
}
draw_frame: DrawFrame


default_pipeline: sg.Pipeline
default_image: sg.Image
default_sampler: sg.Sampler

vbo: sg.Buffer
ibo: sg.Buffer

MAX_QUADS :: 8192

actual_quad_data: [MAX_QUADS * size_of(Quad)]u8

/**
4,736 left to allocate
*/
ZLayerQuadCount := [ZLayer]int {
	.background = 512,
	.shadow     = 128,
	.game_play  = 512,
	.particles  = 2048,
	.ui         = 256,
}


validate_draw_frame :: proc() {
	if DEBUG {
		overall_count := 0
		for layer in ZLayer {
			overall_count += ZLayerQuadCount[layer]
		}

		if overall_count > MAX_QUADS {
			assert(false, "WE NEED TO UPDATE MAX QUADS")
		}
	}

}

start_draw_frame :: proc() {
	for layer in ZLayer {
		count := ZLayerQuadCount[layer]
		draw_frame.quads[layer] = make([dynamic]Quad, 0, count, allocator = context.temp_allocator)
	}
}


clear_draw_frame :: proc() {
	for layer in ZLayer {
		clear(&draw_frame.quads[layer])
	}

	// mem.zero(raw_data(&actual_quad_data), MAX_QUADS * size_of(Quad) * size_of(u8))
}


gfx_init :: proc() {

	default_sampler = sg.make_sampler({})

	// make the vertex buffer
	state.bind.vertex_buffers[0] = sg.make_buffer(
		{usage = .DYNAMIC, size = size_of(actual_quad_data)},
	)

	// make & fill the index buffer
	index_buffer_count :: MAX_QUADS * 6
	indices: [index_buffer_count]u16
	i := 0
	for i < index_buffer_count {
		// vertex offset pattern to draw a quad
		// { 0, 1, 2,  0, 2, 3 }
		indices[i + 0] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 1] = auto_cast ((i / 6) * 4 + 1)
		indices[i + 2] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 3] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 4] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 5] = auto_cast ((i / 6) * 4 + 3)
		i += 6
	}

	state.bind.index_buffer = sg.make_buffer(
		{type = .INDEXBUFFER, data = {ptr = &indices, size = size_of(indices)}},
	)

	state.bind.samplers[SMP_default_sampler] = sg.make_sampler(
		{
			min_filter = sg.Filter.NEAREST,
			mag_filter = sg.Filter.NEAREST,
			mipmap_filter = sg.Filter.NEAREST,
		},
	)

	// default pass action
	state.pass_action = {
		colors = {0 = {load_action = .CLEAR, clear_value = clear_color}},
	}


	pipeline_desc: sg.Pipeline_Desc = {
		shader = sg.make_shader(quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				ATTR_quad_position = {format = .FLOAT2},
				ATTR_quad_color0 = {format = .FLOAT4},
				ATTR_quad_uv0 = {format = .FLOAT2},
				ATTR_quad_tex_id = {format = .FLOAT},
				ATTR_quad_flash_amount = {format = .FLOAT},
			},
		},
	}


	blend_state: sg.Blend_State = {
		enabled          = true,
		src_factor_rgb   = .SRC_ALPHA,
		dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
		op_rgb           = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha         = .ADD,
	}


	pipeline_desc.colors[0] = {
		blend = blend_state,
	}


	state.pip = sg.make_pipeline(pipeline_desc)
	start_draw_frame()
	validate_draw_frame()
}


draw_quad_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	img_id: ImageId = .nil,
	uv: Vector4 = DEFAULT_UV,
	col: Vector4 = COLOR_WHITE,
	flash_amount: f32 = 0,
	texture_index: u8 = 0,
) {
	draw_quad_xform_in_frame(
		{size = size, uv = {uv.xy, uv.xw, uv.zw, uv.zy}, color = col, img_id = img_id},
		xform,
		&draw_frame,
		flash_amount,
		texture_index,
	)
}

draw_rect_xform :: proc(xform: Matrix4, size: Vector2, col: Vector4 = COLOR_WHITE) {
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

draw_rect_center_xform :: proc(xform: Matrix4, size: Vector2, col: Vector4 = COLOR_WHITE) {
	xform := xform * linalg.matrix4_translate(Vector3{-size.x * 0.5, -size.y * 0.5, 0.0})
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

draw_quad_center_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	img_id: ImageId = .nil,
	uv: Vector4 = DEFAULT_UV,
	col: Vector4 = COLOR_WHITE,
	flash_amount: f32 = 0,
) {
	xform := xform * linalg.matrix4_translate(Vector3{-size.x * 0.5, -size.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{size = size, uv = {uv.xy, uv.xw, uv.zw, uv.zy}, color = col, img_id = img_id},
		xform,
		&draw_frame,
		flash_amount,
	)
}


draw_quad_xform_in_frame :: proc(
	quad: DrawQuad,
	xform: Matrix4,
	frame: ^DrawFrame,
	flash_amount: f32 = 0,
	texture_id: u8 = 0,
) {

	uv0 := quad.uv
	default_uv: [4]Vector2 = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy}
	if quad.uv == default_uv {
		atlas_uvs := images[quad.img_id].atlas_uvs
		uv0 = {atlas_uvs.xy, atlas_uvs.xw, atlas_uvs.zw, atlas_uvs.zy}
	}


	world_to_clip := draw_frame.projection * draw_frame.camera_xform * xform

	quad_array := &draw_frame.quads[draw_frame.active_z_layer]
	verts: [4]Vertex
	quad_array.allocator = temp_allocator()
	defer append(quad_array, verts)

	verts[0].pos = (world_to_clip * v4{0, 0, 0.0, 1.0}).xy
	verts[1].pos = (world_to_clip * Vector4{0, quad.size.y, 0.0, 1.0}).xy
	verts[2].pos = (world_to_clip * Vector4{quad.size.x, quad.size.y, 0.0, 1.0}).xy
	verts[3].pos = (world_to_clip * Vector4{quad.size.x, 0, 0.0, 1.0}).xy
	verts[0].color = quad.color
	verts[1].color = quad.color
	verts[2].color = quad.color
	verts[3].color = quad.color

	verts[0].uv = uv0[0]
	verts[1].uv = uv0[1]
	verts[2].uv = uv0[2]
	verts[3].uv = uv0[3]


	verts[0].tex_index = auto_cast texture_id
	verts[1].tex_index = auto_cast texture_id
	verts[2].tex_index = auto_cast texture_id
	verts[3].tex_index = auto_cast texture_id
	verts[0].flash_amount = flash_amount
	verts[1].flash_amount = flash_amount
	verts[2].flash_amount = flash_amount
	verts[3].flash_amount = flash_amount


}

import "core:mem"


gfx_render_draw_frame :: proc(frame: ^DrawFrame) {
	state.bind.images[IMG_tex0] = atlas.sg_image
	state.bind.images[IMG_tex1] = font_image
	total_quad_count := 0
	offset := 0

	for quads_in_layer, layer in draw_frame.quads {
		total_quad_count += len(quads_in_layer)
	}

	if (total_quad_count == 0) {
		return
	}
	// log(total_quad_count)
	assert(total_quad_count <= MAX_QUADS)
	for quads_in_layer, layer in draw_frame.quads {
		size := size_of(Quad) * len(quads_in_layer)


		mem.copy(
			mem.ptr_offset(raw_data(actual_quad_data[:]), offset),
			raw_data(quads_in_layer),
			size,
		)
		offset += size
	}


	sg.update_buffer(
		state.bind.vertex_buffers[0],
		{ptr = raw_data(actual_quad_data[:]), size = len(actual_quad_data)},
	)

	action: sg.Pass_Action = {}

	if !frame.cleared_frame {
		action = state.pass_action
		// frame.cleared_frame = true
	}

	sg.begin_pass({action = action, swapchain = sglue.swapchain()})
	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)

	sg.draw(0, 6 * total_quad_count, 1)
	// imgui_draw()
	sg.end_pass()
}


gfx_update :: proc() {
	if (!sapp.isvalid()) {
		return
	}

	// Clear window & render global draw frame to window
	gfx_render_draw_frame(&draw_frame)
	sg.commit()

	draw_frame_reset(&draw_frame)

}


draw_frame_reset :: proc(frame: ^DrawFrame) {
	using runtime, linalg
	draw_frame = {}

	clear_draw_frame()
	frame.cleared_frame = false
	draw_frame.shader_extension = default_pipeline
	// start_draw_frame()

	set_ortho_projection(game_data.camera_zoom)
	frame.camera_xform = Matrix4(1)
}


set_ortho_projection :: proc(zoom: f32) {
	scale := f32(pixel_height) / f32(sapp.height())

	w := f32(sapp.width()) * scale
	h := f32(sapp.height()) * scale


	using runtime, linalg
	draw_frame.projection = matrix_ortho3d_f32(
		w * -0.5 / zoom,
		w * 0.5 / zoom,
		h * -0.5 / zoom,
		h * 0.5 / zoom,
		-1,
		1,
	)
}

Alignment :: enum {
	bottom_left,
	bottom_center,
	center_center,
}


get_ui_width :: proc() -> f32 {
	scale := f32(base_height) / f32(sapp.height())
	w := f32(sapp.width()) * scale

	return w
}

get_ui_height :: proc() -> f32 {
	scale := f32(base_height) / f32(sapp.height())
	h := f32(sapp.height()) * scale

	return h
}

get_ui_dimensions :: proc() -> (f32, f32) {
	scale := f32(base_height) / f32(sapp.height())

	w := f32(sapp.width()) * scale
	h := f32(sapp.height()) * scale

	return w, h
}


set_ui_projection_alignment :: proc(alignment: Alignment) {

	w, h := get_ui_dimensions()

	using linalg
	switch alignment {
	case .bottom_left:
		draw_frame.projection = matrix_ortho3d_f32(0, w, 0, h, -1, 1)
	case .bottom_center:
		draw_frame.projection = matrix_ortho3d_f32(-w * 0.5, w * 0.5, 0, h, -1, 1)
	case .center_center:
		draw_frame.projection = matrix_ortho3d_f32(-w * 0.5, w * 0.5, -h * 0.5, h * 0.5, -1, 1)
	}
	mouse_world_position = mouse_to_matrix()
}


measure_text :: proc(text: string, font_size: f32 = DEFAULT_FONT_SIZE) -> Vector2 {
	x: f32
	size_y: f32 = 0.0
	scale: f32 = font_size / DEFAULT_FONT_SIZE

	using stbtt

	for char in text {
		advance_x: f32
		advance_y: f32
		q: aligned_quad
		GetBakedQuad(
			&font.char_data[0],
			font_bitmap_w,
			font_bitmap_h,
			cast(i32)char - 32,
			&advance_x,
			&advance_y,
			&q,
			false,
		)


		size_y = math.max(abs(q.y0 - q.y1), size_y)

		x += advance_x
	}

	return {x, size_y} * scale
}


draw_text_center_center :: proc(
	center_xform: Matrix4,
	text: string,
	font_size: f32 = DEFAULT_FONT_SIZE,
	col := COLOR_WHITE,
) {
	text_size := measure_text(text, font_size)


	draw_text_xform(
		transform_2d({-text_size.x * 0.5, -text_size.y * 0.5}) * center_xform,
		text,
		font_size,
		col,
	)
}


draw_text_center :: proc(
	center_xform: Matrix4,
	text: string,
	font_size: f32 = DEFAULT_FONT_SIZE,
	col := COLOR_WHITE,
) {
	text_size := measure_text(text, font_size)

	draw_text_xform(transform_2d({-text_size.x * 0.5, 0.0}) * center_xform, text, font_size, col)
}


draw_text_outlined :: proc(
	xform: Matrix4,
	text: string,
	font_size: f32 = DEFAULT_FONT_SIZE,
	drop_shadow: f32 = 0.0,
	width: f32 = 4.0,
	color := COLOR_WHITE,
	outline_color := COLOR_BLACK,
) {
	draw_text_xform(xform * transform_2d({width, width}), text, font_size, outline_color)
	draw_text_xform(xform * transform_2d({width, -width}), text, font_size, outline_color)
	draw_text_xform(xform * transform_2d({-width, width}), text, font_size, outline_color)
	draw_text_xform(xform * transform_2d({-width, -width}), text, font_size, outline_color)

	if width >= 3 {
		draw_text_xform(xform * transform_2d({width, 0}), text, font_size, outline_color)
		draw_text_xform(xform * transform_2d({0, width}), text, font_size, outline_color)
		draw_text_xform(xform * transform_2d({-width, 0}), text, font_size, outline_color)
		draw_text_xform(xform * transform_2d({0, -width}), text, font_size, outline_color)
	}

	if drop_shadow > 0.0 {
		draw_text_xform(
			xform * transform_2d({0, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
		draw_text_xform(
			xform * transform_2d({-width, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
		draw_text_xform(
			xform * transform_2d({width, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
	}

	draw_text_xform(xform, text, font_size, color)

}

draw_text_outlined_center :: proc(
	xform: Matrix4,
	text: string,
	font_size: f32 = DEFAULT_FONT_SIZE,
	drop_shadow: f32 = 0.0,
	width: f32 = 4.0,
	color := COLOR_WHITE,
	outline_color := COLOR_BLACK,
) {
	draw_text_center(xform * transform_2d({width, width}), text, font_size, outline_color)
	draw_text_center(xform * transform_2d({width, -width}), text, font_size, outline_color)
	draw_text_center(xform * transform_2d({-width, width}), text, font_size, outline_color)
	draw_text_center(xform * transform_2d({-width, -width}), text, font_size, outline_color)

	if width >= 3 {
		draw_text_center(xform * transform_2d({width, 0}), text, font_size, outline_color)
		draw_text_center(xform * transform_2d({0, width}), text, font_size, outline_color)
		draw_text_center(xform * transform_2d({-width, 0}), text, font_size, outline_color)
		draw_text_center(xform * transform_2d({0, -width}), text, font_size, outline_color)
	}

	if drop_shadow > 0.0 {
		draw_text_center(
			xform * transform_2d({0, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
		draw_text_center(
			xform * transform_2d({-width, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
		draw_text_center(
			xform * transform_2d({width, -(drop_shadow + width)}),
			text,
			font_size,
			outline_color,
		)
	}
	draw_text_center(xform, text, font_size, color)
}


draw_text_xform :: proc(
	xform: Matrix4,
	text: string,
	font_size: f32 = DEFAULT_FONT_SIZE,
	color := COLOR_WHITE,
) {
	using stbtt

	x: f32
	y: f32

	scale: f32 = font_size / f32(DEFAULT_FONT_SIZE)


	for char in text {

		advance_x: f32
		advance_y: f32
		q: aligned_quad


		GetBakedQuad(
			&font.char_data[0],
			font_bitmap_w,
			font_bitmap_h,
			cast(i32)char - 32,
			&advance_x,
			&advance_y,
			&q,
			false,
		)
		// this is the the data for the aligned_quad we're given, with y+ going down
		// x0, y0,     s0, t0, // top-left
		// x1, y1,     s1, t1, // bottom-right

		size := v2{abs(q.x0 - q.x1), abs(q.y0 - q.y1)}

		offset_to_render_at: v2

		bottom_left := v2{q.x0, -q.y1}
		top_right := v2{q.x1, -q.y0}
		assert(bottom_left + size == top_right)

		offset_to_render_at = v2{x, y} + bottom_left


		uv := v4{q.s0, q.t1, q.s1, q.t0}
		xform :=
			xform *
			linalg.matrix4_scale_f32({scale, scale, scale}) *
			transform_2d(offset_to_render_at)
		draw_quad_xform(xform, size, .nil, uv, color, 0, 1)

		x += advance_x
		y += -advance_y
	}
}


draw_text_constrainted_center :: proc(
	xform: Matrix4,
	text: string,
	box_width: f32,
	font_size: f32 = DEFAULT_FONT_SIZE,
	col := COLOR_WHITE,
) -> f32 {

	overall_height: f32 = 0.0
	current_width: f32 = 0.0
	additional_y: f32 = 0
	spacing_y := font_size * 0.25
	str_arr := strings.split(text, " ", context.temp_allocator)

	temp_str_buffer: [dynamic]string
	temp_str_buffer.allocator = temp_allocator()
	for str in str_arr {
		width := measure_text(str, font_size).x
		if current_width + width > box_width {
			assert(len(temp_str_buffer) > 0)
			str := strings.join(temp_str_buffer[:], " ", context.temp_allocator)
			draw_text_center(xform * transform_2d({0, additional_y}), str, font_size, col)
			remove_range(&temp_str_buffer, 0, len(temp_str_buffer))
			height := measure_text(str, font_size).y
			additional_y -= height + spacing_y
			overall_height += height
			current_width = 0
		}

		current_width += width
		append(&temp_str_buffer, str)
	}

	if len(temp_str_buffer) > 0 {
		str := strings.join(temp_str_buffer[:], " ", context.temp_allocator)
		height := measure_text(str, font_size).y
		overall_height += height
		draw_text_center(xform * transform_2d({0, additional_y}), str, font_size, col)
	}

	return overall_height
}


draw_text_constrainted_center_outlined :: proc(
	xform: Matrix4,
	text: string,
	box_width: f32,
	font_size: f32 = DEFAULT_FONT_SIZE,
	drop_shadow: f32 = 0.0,
	width: f32 = 4.0,
	color := COLOR_WHITE,
	outline_color := COLOR_BLACK,
) -> f32 {

	overall_height: f32 = 0.0
	current_width: f32 = 0.0
	additional_y: f32 = 0
	spacing_y := font_size * 0.25
	str_arr := strings.split(text, " ", context.temp_allocator)

	temp_str_buffer: [dynamic]string
	temp_str_buffer.allocator = temp_allocator()
	for str in str_arr {
		text_width := measure_text(str, font_size).x
		if current_width + text_width > box_width {
			assert(len(temp_str_buffer) > 0)
			str := strings.join(temp_str_buffer[:], " ", context.temp_allocator)
			draw_text_outlined_center(
				xform * transform_2d({0, additional_y}),
				str,
				font_size,
				drop_shadow,
				width,
				color,
				outline_color,
			)
			remove_range(&temp_str_buffer, 0, len(temp_str_buffer))
			height := measure_text(str, font_size).y
			additional_y -= height + spacing_y
			overall_height += height
			current_width = 0
		}

		current_width += text_width
		append(&temp_str_buffer, str)
	}

	if len(temp_str_buffer) > 0 {
		str := strings.join(temp_str_buffer[:], " ", context.temp_allocator)
		height := measure_text(str, font_size).y
		overall_height += height
		draw_text_outlined_center(
			xform * transform_2d({0, additional_y}),
			str,
			font_size,
			drop_shadow,
			width,
			color,
			outline_color,
		)
	}

	return overall_height
}
