package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "os"

import sg "../vendor/sokol/gfx"

import stbi "../vendor/stb-web/image"
import stbrp "../vendor/stb-web/rect_pack"

ImageId :: enum {
	nil,
	miners,
	shadows,
	selected,
	tiles,
	money,
	circle,
	cursor,
	sprite_particles,
	explosion,
	bullet_shell,
	arrow,
	card,
	buttons,
	ui,
	statues,
	logo,
	background,
	transition,
	upgrade_sign,
	fmod_logo,
	destruction_block,
	storage_box,
	mined_resources,
	tent,
	conveyor_yellow,
	conveyor_corner,
	deposit,
	drill,
	ore,
	furnace,
	dig,
}


Image_Column_Rows_Count := [ImageId][2]int {
	.nil               = {0, 0},
	.miners            = {18, 4},
	.shadows           = {1, 1},
	.selected          = {1, 1},
	.tiles             = {16, 3},
	.money             = {8, 3},
	.circle            = {3, 1},
	.cursor            = {1, 1},
	.sprite_particles  = {7, 4},
	.explosion         = {1, 1},
	.bullet_shell      = {1, 1},
	.arrow             = {1, 1},
	.card              = {2, 1},
	.buttons           = {5, 1},
	.ui                = {1, 3},
	.statues           = {1, 2},
	.logo              = {1, 1},
	.background        = {1, 1},
	.transition        = {1, 1},
	.upgrade_sign      = {1, 1},
	.fmod_logo         = {1, 1},
	.destruction_block = {1, 1},
	.storage_box       = {1, 1},
	.mined_resources   = {3, 1},
	.tent              = {1, 1},
	.conveyor_yellow   = {16, 1},
	.conveyor_corner   = {4, 1},
	.deposit           = {3, 2},
	.drill             = {20, 1},
	.ore               = {4, 1},
	.furnace           = {1, 1},
	.dig               = {1, 1},
}


get_image_size :: proc(id: ImageId) -> Vector2 {
	return {auto_cast images[id].width, auto_cast images[id].height}
}

Image :: struct {
	width, height:    i32,
	data:             [^]byte,
	atlas_x, atlas_y: int, // probs not useful
	atlas_uvs:        Vector4,
}
images: [ImageId]Image
blank: []byte = {255, 255, 255, 255}

init_images :: proc() {
	using fmt

	img_dir := "./assets/sprites/"

	highest_id := 0
	images[ImageId.nil] = Image {
		width  = 1,
		height = 1,
		data   = raw_data(blank),
	}

	for img_name, id in ImageId {
		if id == 0 {continue}

		if id > highest_id {
			highest_id = id
		}

		path := tprint(img_dir, img_name, ".png", sep = "")
		img, succ := load_image_from_disk(path)
		if !succ {
			log.error("failed to load image:", img_name)
			continue
		}

		images[auto_cast id] = img
	}


	init_fonts()

	pack_images_into_atlas()

}


load_image_from_disk :: proc(path: string) -> (Image, bool) {
	stbi.set_flip_vertically_on_load(1)

	png_data, succ := os.read_entire_file(path)
	if !succ {
		log.error("read file failed")
		return {}, false
	}

	width, height, channels: i32
	img_data := stbi.load_from_memory(
		raw_data(png_data),
		auto_cast len(png_data),
		&width,
		&height,
		&channels,
		4,
	)
	if img_data == nil {
		log.error("stbi load failed, invalid image?")
		return {}, false
	}

	ret: Image
	ret.width = width
	ret.height = height
	ret.data = img_data


	return ret, true
}

Atlas :: struct {
	w, h:     int,
	sg_image: sg.Image,
}
atlas: Atlas
atlas_width :: 2048
// We're hardcoded to use just 1 atlas now since I don't think we'll need more
// It would be easy enough to extend though. Just add in more texture slots in the shader
pack_images_into_atlas :: proc() {

	// 8192 x 8192 is the WGPU recommended max I think
	atlas.w = atlas_width
	atlas.h = atlas_width

	cont: stbrp.Context
	nodes: [atlas_width]stbrp.Node // #volatile with atlas.w
	stbrp.init_target(&cont, auto_cast atlas.w, auto_cast atlas.h, &nodes[0], auto_cast atlas.w)

	rects: [dynamic]stbrp.Rect
	defer delete(rects)
	for img, id in images {
		if img.width == 0 {
			continue
		}
		append(
			&rects,
			stbrp.Rect{id = auto_cast id, w = auto_cast img.width, h = auto_cast img.height},
		)
	}

	succ := stbrp.pack_rects(&cont, &rects[0], auto_cast len(rects))
	if succ == 0 {
		assert(false, "failed to pack all the rects, ran out of space?")
	}

	// allocate big atlas
	raw_data, err := mem.alloc(atlas.w * atlas.h * 4)
	defer mem.free(raw_data)
	mem.set(raw_data, 0, atlas.w * atlas.h * 4)

	// copy rect row-by-row into destination atlas
	for rect in rects {
		img := &images[auto_cast rect.id]

		// copy row by row into atlas
		for row in 0 ..< rect.h {
			src_row := mem.ptr_offset(&img.data[0], row * rect.w * 4)
			dest_row := mem.ptr_offset(
				cast(^u8)raw_data,
				((rect.y + row) * auto_cast atlas.w + rect.x) * 4,
			)
			mem.copy(dest_row, src_row, auto_cast rect.w * 4)
		}

		// yeet old data
		if (rect.id != auto_cast ImageId.nil) {stbi.image_free(img.data)}
		img.data = nil

		img.atlas_x = auto_cast rect.x
		img.atlas_y = auto_cast rect.y

		img.atlas_uvs.x = cast(f32)img.atlas_x / cast(f32)atlas.w
		img.atlas_uvs.y = cast(f32)img.atlas_y / cast(f32)atlas.h
		img.atlas_uvs.z = img.atlas_uvs.x + cast(f32)img.width / cast(f32)atlas.w
		img.atlas_uvs.w = img.atlas_uvs.y + cast(f32)img.height / cast(f32)atlas.h
	}
	when ODIN_OS == .Windows {
		stbi.write_png(
			"atlas.png",
			auto_cast atlas.w,
			auto_cast atlas.h,
			4,
			raw_data,
			4 * auto_cast atlas.w,
		)
	}


	// setup image for GPU
	desc: sg.Image_Desc
	desc.width = auto_cast atlas.w
	desc.height = auto_cast atlas.h
	desc.pixel_format = .RGBA8
	desc.data.subimage[0][0] = {
		ptr  = raw_data,
		size = auto_cast (atlas.w * atlas.h * 4),
	}
	atlas.sg_image = sg.make_image(desc)
	if atlas.sg_image.id == sg.INVALID_ID {
		log.info("failed to make image")
	}
}


get_frame_uvs :: proc(
	sprite_id: ImageId,
	sprite_index: Vector2Int,
	frame_size: Vector2,
) -> Vector4 {

	row_column_data := Image_Column_Rows_Count[sprite_id]

	// We want to reverse the y sprite index since we need to flip the image on load
	sprite_index_y: int = 0 + (row_column_data.y - 1) - sprite_index.y


	sprite := images[sprite_id]
	// Convert sprite's UV coordinates to pixel coordinates
	x := int(sprite.atlas_uvs.x * f32(atlas.w))
	y := int(sprite.atlas_uvs.y * f32(atlas.h))

	// Calculate the pixel coordinates for the top-left corner of the frame
	frame_x := x + sprite_index.x * auto_cast frame_size.x
	frame_y := y + sprite_index_y * auto_cast frame_size.y

	// Convert back to UV coordinates
	left := f32(frame_x) / f32(atlas.w)
	top := f32(frame_y) / f32(atlas.h)
	right := f32(frame_x + auto_cast frame_size.x) / f32(atlas.w)
	bottom := f32(frame_y + auto_cast frame_size.y) / f32(atlas.h)

	return {left, top, right, bottom}
}
