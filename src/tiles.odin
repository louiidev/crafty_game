package main

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


is_tile_active :: proc(x, y: int) -> bool {
	if x < 0 || y < 0 || x >= TILES_W || y >= TILES_H {
		return false
	}
	return game_data.tiles[y * TILES_W + x].active
}


get_tile_coords :: proc(index: int) -> Vector2Int {
	x := index % 16
	y := index / 16
	return {x, y}
}

import "core:math"

tiles_x: int : 22
tiles_y: int : 15
grid_offset := Vector2{auto_cast tiles_x, auto_cast tiles_y} * 0.5
world_pos_to_tile_pos :: proc(world_pos: Vector2) -> Vector2Int {
	tile_pos := Vector2Int {
		auto_cast math.floor(world_pos.x / 16.0),
		auto_cast math.round(world_pos.y / 16.0),
	}

	return tile_pos + {auto_cast math.round(grid_offset.x), auto_cast math.floor(grid_offset.y)}
}
