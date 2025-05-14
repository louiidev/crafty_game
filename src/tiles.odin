package main

import "core:math"
import "core:math/rand"


TileOccupiedBy :: enum {
	nil,
	Dirt,
	Building,
	Resource,
}

Tile :: struct {
	queued_for_destruction: bool,
	occupied_by:            TileOccupiedBy,
	health:                 f32,
	max_health:             f32,
	grid_position:          Vector2Int,
	chunk_grid_position:    Vector2Int,
	position:               Vector2,
	bitmask:                u8,
}


ConveyorDirections :: enum {
	NORTH,
	EAST,
	SOUTH,
	WEST,
	NE,
	EN,
	SE,
	ES,
	NW,
	WN,
	SW,
	WS,
}

ConveyorType :: enum {
	SLOW,
	MID,
	FAST,
}
get_conveyor_speed :: proc(type: ConveyorType) -> f32 {
	switch (type) {
	case .SLOW:
		return 20
	case .MID:
		return 40
	case .FAST:
		return 60
	}

	assert(false)
	return {}
}


get_conveyor_direction :: proc(direction: ConveyorDirections) -> Vector2 {
	switch (direction) {
	case .EAST, .NE, .SE:
		return {1, 0}
	case .EN, .NORTH, .WN:
		return {0, 1}
	case .ES, .SOUTH, .WS:
		return {0, -1}
	case .WEST, .SW, .NW:
		return {-1, 0}
	}

	assert(false)
	return {}
}

ConveyorBelt :: struct {
	initial_direction:   ConveyorDirections,
	visual_direction:    ConveyorDirections,
	position:            Vector2,
	world_tile_position: Vector2Int,
	chunk_position:      Vector2Int,
	type:                ConveyorType,
}


get_animation_conveyor_frame :: proc(direction: ConveyorDirections) -> int {
	base_speed: f32 = 192 // A constant that keeps the animation consistent
	frame_count := 16
	speed: f32 = base_speed / f32(frame_count)
	#partial switch (direction) {
	case .NW, .NE, .EN, .SE, .ES, .SW, .WN, .WS:
		frame_count = 4

	}

	frame := int(game_data.world_time_elapsed * speed) % frame_count
	return frame
}

import "core:math/linalg"

render_conveyor_belt :: proc(
	facing_direction: ConveyorDirections,
	position: Vector2,
	color: Vector4,
	animate := true,
) {
	frame := animate ? get_animation_conveyor_frame(facing_direction) : 0

	sprite: ImageId = .conveyor_yellow
	xform := transform_2d(position)
	#partial switch (facing_direction) {
	case .NORTH:
		xform *= rotate_z(math.to_radians_f32(-90))
	case .EAST:
		xform *= rotate_z(math.to_radians_f32(180))
	case .EN:
		xform *= rotate_z(math.to_radians_f32(90))
		xform *= linalg.matrix4_scale(Vector3{1.0, -1.0, 1.0})
		xform *= rotate_z(math.to_radians_f32(-90))
		sprite = .conveyor_corner
	case .NE:
		xform *= rotate_z(math.to_radians_f32(-90))
		sprite = .conveyor_corner
	case .NW:
		sprite = .conveyor_corner
		xform *= linalg.matrix4_scale(Vector3{-1.0, 1.0, 1.0})
		xform *= rotate_z(math.to_radians_f32(-90))

	case .WN:
		sprite = .conveyor_corner

	case .ES:
		sprite = .conveyor_corner
		xform *= rotate_z(math.to_radians_f32(-180))
	case .SOUTH:
		xform *= rotate_z(math.to_radians_f32(90))
	case .SE:
		sprite = .conveyor_corner
		xform *= rotate_z(math.to_radians_f32(90))
		xform *= linalg.matrix4_scale(Vector3{1.0, -1.0, 1.0})

	case .SW:
		sprite = .conveyor_corner
		xform *= rotate_z(math.to_radians_f32(90))
	case .WS:
		sprite = .conveyor_corner
		xform *= linalg.matrix4_scale(Vector3{1.0, -1.0, 1.0})

	}


	draw_quad_center_xform(
		xform,
		{16, 16},
		sprite,
		get_frame_uvs(sprite, {frame, 0}, {16, 16}),
		color,
	)
}


TILE_SIZE: f32 : 16
CHUNK_GRID_SIZE_X: u32 : 30
CHUNK_GRID_SIZE_Y: u32 : 20
CHUNK_ACTUAL_SIZE_X: f32 : f32(CHUNK_GRID_SIZE_X) * TILE_SIZE
CHUNK_ACTUAL_SIZE_Y: f32 : f32(CHUNK_GRID_SIZE_Y) * TILE_SIZE
Chunk :: struct {
	chunk_grid_position: Vector2Int,
	tiles:               [CHUNK_GRID_SIZE_X * CHUNK_GRID_SIZE_Y]Tile,
	initialized:         bool,
	buildings:           [dynamic]Building,
	conveyor_belts:      [dynamic]ConveyorBelt,
	deposits:            [CHUNK_GRID_SIZE_X * CHUNK_GRID_SIZE_Y]Deposit,
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

get_chunk_local_tile_position :: proc(global_position: Vector2) -> Vector2Int {
	chunk_key := get_chunk_key(global_position) // Get the chunk key (x, y)

	// Compute the chunk's world-space origin
	chunk_origin_x := f32(chunk_key.x) * CHUNK_ACTUAL_SIZE_X
	chunk_origin_y := f32(chunk_key.y) * CHUNK_ACTUAL_SIZE_Y

	// Find position within the chunk
	local_x := auto_cast ((global_position.x - chunk_origin_x) / TILE_SIZE)
	local_y := auto_cast ((global_position.y - chunk_origin_y) / TILE_SIZE)

	// Ensure values are within [0, CHUNK_GRID_SIZE_X - 1] and [0, CHUNK_GRID_SIZE_Y - 1]
	if local_x < 0 {
		local_x += auto_cast CHUNK_GRID_SIZE_X
	}
	if local_y < 0 {
		local_y += auto_cast CHUNK_GRID_SIZE_Y
	}

	return Vector2Int{auto_cast local_x, auto_cast local_y}
}


create_chunk :: proc(chunk_key: Vector2Int) {
	chunk: Chunk
	for x: u32 = 0; x < CHUNK_GRID_SIZE_X; x += 1 {
		for y: u32 = 0; y < CHUNK_GRID_SIZE_Y; y += 1 {
			tile: Tile
			tile.health = 5
			tile.max_health = 5
			tile.chunk_grid_position = Vector2Int{auto_cast x, auto_cast y}
			tile.grid_position =
				Vector2Int{auto_cast x, auto_cast y} +
				chunk_key * Vector2Int{auto_cast CHUNK_GRID_SIZE_X, auto_cast CHUNK_GRID_SIZE_Y}
			tile.occupied_by = .Dirt
			tile.position =
				Vector2{auto_cast tile.grid_position.x, auto_cast tile.grid_position.y} * TILE_SIZE
			chunk.tiles[y * CHUNK_GRID_SIZE_X + x] = tile

		}
	}
	chunk.chunk_grid_position = chunk_key
	chunk.initialized = true


	deposits_per_chunk := rand.int31_max(3) + 1
	deposit_positions: [dynamic]Vector2Int
	deposit_radius: [dynamic]i32
	deposit_radius.allocator = temp_allocator()
	deposit_positions.allocator = temp_allocator()
	loop: for i: i32 = 0; i < deposits_per_chunk; i += 1 {
		radius := rand.int31_max(6) + 2
		deposit_position: Vector2Int = {
			auto_cast rand.int31_max(auto_cast CHUNK_GRID_SIZE_X),
			auto_cast rand.int31_max(auto_cast CHUNK_GRID_SIZE_Y),
		}


		for i := 0; i < len(deposit_positions); i += 1 {
			pos := deposit_positions[i]
			size := deposit_radius[i]
			if manhattan_dist(pos, deposit_position) < auto_cast radius ||
			   manhattan_dist(pos, deposit_position) < auto_cast size {
				log("overlap", chunk_key)
				log(pos, deposit_position, manhattan_dist(pos, deposit_position))
				continue loop
			}
		}

		append(&deposit_positions, deposit_position)
		append(&deposit_radius, radius)
		log("Deposit added:", deposit_position, "Radius:", radius)
	}


	for i := 0; i < len(deposit_positions); i += 1 {
		radius := deposit_radius[i]
		position := deposit_positions[i]
		type := generate_random_deposit_type()
		for y := -radius; y <= radius; y += 1 {
			for x := -radius; x <= radius; x += 1 {
				chunk_grid_position: Vector2Int = {
					auto_cast position.x + auto_cast x,
					auto_cast position.y + auto_cast y,
				}

				world_grid_position :=
					Vector2Int{auto_cast chunk_grid_position.x, auto_cast chunk_grid_position.y} +
					chunk_key *
						Vector2Int{auto_cast CHUNK_GRID_SIZE_X, auto_cast CHUNK_GRID_SIZE_Y}

				// Check if within the grid bounds
				if (chunk_grid_position.x >= 0 &&
					   chunk_grid_position.x < auto_cast CHUNK_GRID_SIZE_X &&
					   chunk_grid_position.y >= 0 &&
					   chunk_grid_position.y < auto_cast CHUNK_GRID_SIZE_Y) {
					// Check if within the circular radius
					if (x * x + y * y <= radius * radius) {
						deposit := create_deposit(world_grid_position, chunk_grid_position, type)
						chunk.deposits[chunk_grid_position.y * auto_cast CHUNK_GRID_SIZE_X + chunk_grid_position.x] =
							deposit

					}
				}
			}
		}


	}

	game_data.chunks[chunk_key] = chunk
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


allocate_tile_neighbour_bitmasks :: proc(
	chunk_position: Vector2Int,
	relative_chunk_tile_pos: Vector2Int,
) {


	for dir in neighbour_directions {
		position := relative_chunk_tile_pos + dir
		tile := get_tile_in_position(chunk_position, &game_data.chunks, position.x, position.y)

		neighbour_active: [8]bool
		for i := 0; i < len(neighbour_active); i += 1 {
			neighbour_active[i] = is_tile_active(
				chunk_position,
				position.x + neighbour_directions[i].x,
				position.y + neighbour_directions[i].y,
			)
		}


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

		tile.bitmask = bitmask
	}

}

allocate_tile_bitmasks :: proc(chunk_position: Vector2Int) {
	for x: int = 0; x < auto_cast CHUNK_GRID_SIZE_X; x += 1 {
		for y: int = 0; y < auto_cast CHUNK_GRID_SIZE_Y; y += 1 {
			neighbour_active: [8]bool

			for i := 0; i < len(neighbour_active); i += 1 {
				neighbour_active[i] = is_tile_active(
					chunk_position,
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


get_tile_in_position :: proc(
	current_chunk: Vector2Int,
	chunks: ^map[Vector2Int]Chunk,
	x, y: int,
) -> ^Tile {


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


	chunk := &chunks[chunk_pos]
	if !chunk.initialized {
		assert(false)
	}

	return &chunk.tiles[y * auto_cast CHUNK_GRID_SIZE_X + x]
}

is_tile_active :: proc(current_chunk: Vector2Int, x, y: int) -> bool {
	x, y := x, y
	chunk_pos := current_chunk
	chunks: ^map[Vector2Int]Chunk = &game_data.chunks
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
	return chunks[chunk_pos].tiles[y * auto_cast CHUNK_GRID_SIZE_X + x].occupied_by == .Dirt
}

is_tile_occupied :: proc(current_chunk: Vector2Int, x, y: int) -> bool {
	x, y := x, y
	chunk_pos := current_chunk
	chunks: ^map[Vector2Int]Chunk = &game_data.chunks
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
	return chunks[chunk_pos].tiles[y * auto_cast CHUNK_GRID_SIZE_X + x].occupied_by != .nil
}


get_tile_coords :: proc(index: int) -> Vector2Int {
	x := index % 16
	y := index / 16
	return {x, y}
}


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


get_closest_free_block_next_to_target :: proc(
	world_target_pos: Vector2Int,
	chunk_target_pos: Vector2Int,
	chunk_key: Vector2Int,
	miner_world_pos: Vector2Int,
) -> (
	bool,
	Vector2Int,
) {

	direction: Vector2Int = {
		auto_cast math.sign_f32(f32(miner_world_pos.x - world_target_pos.x)),
		auto_cast math.sign_f32(f32(miner_world_pos.y - world_target_pos.y)),
	}


	position_offsets: [2]Vector2Int = {{direction.x, 0}, {0, direction.y}}

	rand.shuffle(position_offsets[:])


	for offset in position_offsets {
		new_pos := offset + chunk_target_pos // Move to the new position
		if !is_tile_active(chunk_key, new_pos.x, new_pos.y) {
			// log(offset, "offset")
			// log(chunk_target_pos, "chunk_target_pos")
			// log(new_pos, "new_pos")
			return true, world_target_pos + offset
		}
	}

	// log(direction)
	// log(positions)

	return false, {}

}


damage_block_and_check_destroyed :: proc(
	miner: ^Entity,
	block_target: TargetBlock,
	dmg: f32,
) -> bool {
	x := block_target.tile_chunk_grid_position.x
	y := block_target.tile_chunk_grid_position.y
	chunk := &game_data.chunks[block_target.chunk_key]
	tile := &chunk.tiles[y * auto_cast CHUNK_GRID_SIZE_X + x]

	if tile.occupied_by == .Dirt {
		tile.health = math.max(0, tile.health - dmg)
	} else {
		return true
	}

	destroyed := false
	if tile.health <= 0 {
		tile.occupied_by = .nil
		destroyed = true
		tile.queued_for_destruction = false
	}


	return destroyed
}

damage_building_and_check_destroyed :: proc(
	miner: ^Entity,
	block_target: TargetBlock,
	dmg: f32,
) -> bool {
	x := block_target.tile_chunk_grid_position.x
	y := block_target.tile_chunk_grid_position.y
	chunk := &game_data.chunks[block_target.chunk_key]
	tile := &chunk.tiles[y * auto_cast CHUNK_GRID_SIZE_X + x]
	b_pointer: ^Building
	found_building := false
	for &building in chunk.buildings {
		if building.world_position == block_target.tile_world_grid_position {
			found_building = true
			b_pointer = &building
		}
	}

	if found_building {
		b_pointer.built = false
		b_pointer.build_progress -= math.max(0, b_pointer.build_progress - dmg)

		if b_pointer.build_progress <= 0 {
			tile.occupied_by = .nil
			b_pointer.active = false
			tile.queued_for_destruction = false
			return true
		}
	} else {
		log("CANT FIND BUILDING")
	}


	return false
}
