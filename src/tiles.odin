package main


Tile :: struct {
	active:              bool,
	health:              f32,
	max_health:          f32,
	grid_position:       Vector2Int,
	chunk_grid_position: Vector2Int,
	position:            Vector2,
	bitmask:             u8,
}


TILE_SIZE: f32 : 16
CHUNK_GRID_SIZE_X: u32 : 30
CHUNK_GRID_SIZE_Y: u32 : 20
CHUNK_ACTUAL_SIZE_X: f32 : f32(CHUNK_GRID_SIZE_X) * TILE_SIZE
CHUNK_ACTUAL_SIZE_Y: f32 : f32(CHUNK_GRID_SIZE_Y) * TILE_SIZE
Chunk :: struct {
	top_left_pos:        Vector2,
	chunk_grid_position: Vector2Int,
	tiles:               [CHUNK_GRID_SIZE_X * CHUNK_GRID_SIZE_Y]Tile,
	// index into a tile in the chuck by offset + (y * width + x) e.g tile:= game.tiles[offset + (y * width + x)]
}


div_floor :: proc(a, b: int) -> int {
	result := a / b
	if (a < 0 && a % b != 0) {
		result -= 1
	}
	return result
}


get_chunk_keys_in_rect :: proc(rect: AABB) -> [dynamic]Vector2Int {
	min_chunk_x := div_floor(int(rect.position.x), auto_cast CHUNK_ACTUAL_SIZE_X)
	min_chunk_y := div_floor(int(rect.position.y), auto_cast CHUNK_ACTUAL_SIZE_Y)
	max_chunk_x := div_floor(int(rect.position.x + rect.size.x - 1), auto_cast CHUNK_ACTUAL_SIZE_X)
	max_chunk_y := div_floor(int(rect.position.y + rect.size.y - 1), auto_cast CHUNK_ACTUAL_SIZE_Y)
	chunks: [dynamic]Vector2Int
	chunks.allocator = temp_allocator()
	for y := min_chunk_y; y <= max_chunk_y; y += 1 {
		for x := min_chunk_x; x <= max_chunk_x; x += 1 {
			pos: Vector2Int = {x, y}
			append(&chunks, pos)
		}
	}

	return chunks
}

get_chunk_key :: proc(position: Vector2) -> Vector2Int {
	return Vector2Int {
		auto_cast (position.x / CHUNK_ACTUAL_SIZE_X),
		auto_cast (position.y / CHUNK_ACTUAL_SIZE_Y),
	}
}


create_chunk :: proc(position: Vector2Int) {
	chunk: Chunk
	chunk_offset := Vector2 {
		f32(position.x) * CHUNK_ACTUAL_SIZE_Y,
		f32(position.y) * CHUNK_ACTUAL_SIZE_Y,
	}
	for x: u32 = 0; x < CHUNK_GRID_SIZE_X; x += 1 {
		for y: u32 = 0; y < CHUNK_GRID_SIZE_Y; y += 1 {
			tile: Tile
			tile.chunk_grid_position = Vector2Int{auto_cast x, auto_cast y}
			tile.grid_position =
				Vector2Int{auto_cast x, auto_cast y} +
				position * Vector2Int{auto_cast CHUNK_GRID_SIZE_X, auto_cast CHUNK_GRID_SIZE_Y}
			tile.active = true
			tile.position =
				Vector2{auto_cast tile.grid_position.x, auto_cast tile.grid_position.y} * TILE_SIZE
			chunk.tiles[y * CHUNK_GRID_SIZE_X + x] = tile
		}
	}
	chunk.chunk_grid_position = position
	game_data.chunks[position] = chunk

}


get_chunks_keys_and_allocate_new :: proc(view_box: AABB) -> []Vector2Int {
	chunk_keys := get_chunk_keys_in_rect(view_box)

	did_create_chunk := make(map[Vector2Int]bool, temp_allocator())

	for chunk_grid_pos in chunk_keys {
		if !(chunk_grid_pos in game_data.chunks) {
			create_chunk(chunk_grid_pos)
			did_create_chunk[chunk_grid_pos] = true
		}
	}

	for chunk_grid_pos in chunk_keys {
		if chunk_grid_pos in did_create_chunk {
			allocate_tile_bitmasks(chunk_grid_pos)
		}
	}


	return chunk_keys[:]

}

get_chunks_in_view :: proc() -> []Vector2Int {
	view_box: AABB = get_frame_view()

	return get_chunks_keys_and_allocate_new(view_box)
}

neighbour_directions: [8]Vector2Int = {
	{1, -1},
	{1, 0},
	{1, 1},
	{0, -1},
	{0, 1},
	{-1, -1},
	{-1, 0},
	{-1, 1},
}

allocate_tile_bitmasks :: proc(chunk_position: Vector2Int) {
	for x: int = 0; x < auto_cast CHUNK_GRID_SIZE_X; x += 1 {
		for y: int = 0; y < auto_cast CHUNK_GRID_SIZE_Y; y += 1 {
			neighbour_active: [8]bool

			for i := 0; i < len(neighbour_active); i += 1 {
				neighbour_active[i] = is_tile_active(
					chunk_position,
					&game_data.chunks,
					x + neighbour_directions[i].x,
					y + neighbour_directions[i].y,
				)


			}

			chunk := &game_data.chunks[chunk_position]
			bitmask := wang_blob_map_number(
				neighbour_active[0],
				neighbour_active[1],
				neighbour_active[2],
				neighbour_active[3],
				neighbour_active[4],
				neighbour_active[5],
				neighbour_active[6],
				neighbour_active[7],
			)

			tile := &chunk.tiles[y * auto_cast CHUNK_GRID_SIZE_X + x]
			// log(bitmask)
			tile.bitmask = bitmask
		}
	}

}


NORTH_WEST :: 1 << 0 // 1
NORTH :: 1 << 1 // 1
NORTH_EAST :: 1 << 2 // 4

WEST :: 1 << 3 // 8

EAST :: 1 << 4 // 16

SOUTH_WEST :: 1 << 5 // 32
SOUTH :: 1 << 6 // 64
SOUTH_EAST :: 1 << 7 // 128


wang_blob_map_number :: proc(tl, t, tr, l, r, bl, b, br: bool) -> u8 {
	tl, tr, bl, br := tl, tr, bl, br
	if !t && !l {tl = false}
	if !t && !r {tr = false}
	if !b && !l {bl = false}
	if !b && !r {br = false}

	bitmask: u8 = 0

	if t do bitmask |= NORTH
	if r do bitmask |= EAST
	if b do bitmask |= SOUTH
	if l do bitmask |= WEST

	if tl do bitmask |= NORTH_WEST
	if tr do bitmask |= NORTH_EAST
	if bl do bitmask |= SOUTH_WEST
	if br do bitmask |= SOUTH_EAST


	return bitmask
}


bitmask_map_value_to_index :: proc(index: u8) -> int {
	switch index {

	case 43, 47, 15:
		return 12


	case 150, 151, 23:
		return 5

	// left-face in
	case 191, 63, 159, 31:
		return 13

	case 158:
		return 19

	case 233:
		return 10


	// top-face in
	case 239, 107, 111, 235:
		return 14
	case 244, 212, 240, 208:
		return 3

	// bottom-face in
	case 247, 215, 214, 246, 90:
		return 7
	// right face in??
	case 253, 248, 252, 249, 216:
		return 11
	case 251:
		return 44
	case 232, 105, 104:
		return 10

	case 26:
		return 15
	case 250:
		return 16

	case 224:
		return 2

	case 148, 20, 144:
		return 1

	case 40, 41, 8:
		return 8

	case 6, 7:
		return 4

	case 185, 188, 56, 57, 24, 60, 157:
		return 9
	case 80:
		return 17

	case 121, 120:
		return 27

	case 227:
		return 6
	case 79:
		return 18

	case 87:
		return 20
	case 3:
		return 4

	case 73:
		return 22

	case 187:
		return 26

	case 220:
		return 21


	//default ones
	case 2:
		return 1
	case 10:
		return 3
	case 11:
		return 4
	case 16:
		return 5
	case 18:
		return 6
	case 22:
		return 7

	case 27:
		return 10
	case 30:
		return 11

	case 66:
		return 14
	case 72:
		return 15
	case 74:
		return 16
	case 75:
		return 17
	case 82:
		return 19
	case 86:
		return 20
	case 88:
		return 21
	case 91:
		return 23
	case 94:
		return 24
	case 95:
		return 25

	case 106:
		return 27
	case 122:
		return 30
	case 123:
		return 31
	case 126:
		return 32
	case 127:
		return 45

	case 210:
		return 35

	case 218:
		return 38
	case 219:
		return 39
	case 222:
		return 40
	case 223:
		return 41

	case 254:
		return 33
	case 255:
		return 46
	case 0:
		return 47

	}
	// log(index)
	return 0
}

is_tile_active :: proc(
	current_chunk: Vector2Int,
	chunks: ^map[Vector2Int]Chunk,
	x, y: int,
) -> bool {
	x, y := x, y
	chunk_pos := current_chunk
	if x < 0 {
		chunk_pos.x -= 1
		x = auto_cast CHUNK_GRID_SIZE_X - 1
	}
	if y < 0 {
		chunk_pos.y -= 1
		y = auto_cast CHUNK_GRID_SIZE_Y - 1
	}
	if x >= auto_cast CHUNK_GRID_SIZE_X {
		chunk_pos.x += 1
		x = 0
	}

	if y >= auto_cast CHUNK_GRID_SIZE_Y {
		chunk_pos.y += 1
		y = 0
	}
	return chunks[chunk_pos].tiles[y * auto_cast CHUNK_GRID_SIZE_X + x].active
}


get_tile_coords :: proc(index: int) -> Vector2Int {
	x := index % 16
	y := index / 16
	return {x, y}
}

import "core:math"


world_pos_to_tile_pos :: proc(world_pos: Vector2) -> Vector2Int {
	tile_pos := Vector2Int {
		auto_cast math.round(world_pos.x / 16.0),
		auto_cast math.round(world_pos.y / 16.0),
	}

	return tile_pos
}


tile_pos_to_world_pos :: proc(tile_pos: Vector2Int) -> Vector2 {
	return {f32(tile_pos.x) * 16.0, f32(tile_pos.y) * 16.0}
}
