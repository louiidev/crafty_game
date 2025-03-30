package main


ResourceType :: enum {
	nil,
	Copper,
	Iron,
	Gold,
	Diamond,
}

Deposit :: struct {
	chunk_grid_position: Vector2Int,
	position:            Vector2,
	variant:             int,
	active:              bool,
	resource_count:      i32,
	type:                ResourceType,
}


ItemType :: enum {
	MinedResource,
	SmeltedResource,
}

WorldItem :: struct {
	position:            Vector2,
	active:              bool,
	type:                ItemType,
	mined_resource_type: ResourceType,
}


import "core:math/rand"

resource_distribution := [4]struct {
	type:   ResourceType,
	weight: f32,
} {
	{.Copper, 0.50}, // 50% chance for copper
	{.Iron, 0.30}, // 30% chance for iron
	{.Gold, 0.15}, // 15% chance for gold
	{.Diamond, 0.05}, // 5% chance for diamond
}

generate_random_deposit_type :: proc() -> ResourceType {


	// Calculate total weight
	total_weight: f32 = 0
	for res in resource_distribution {
		total_weight += res.weight
	}

	roll := rand.float32_range(0, total_weight)

	// Select resource based on weighted probability
	current_weight: f32 = 0
	for res in resource_distribution {
		current_weight += res.weight
		if roll <= current_weight {
			return res.type
		}
	}


	return .Copper
}

create_deposit :: proc(
	world_grid_pos: Vector2Int,
	chunk_pos: Vector2Int,
	type: ResourceType,
) -> Deposit {

	// Set up deposit
	deposit: Deposit
	deposit.active = true
	deposit.position = tile_pos_to_world_pos(world_grid_pos)
	deposit.chunk_grid_position = chunk_pos
	deposit.variant = auto_cast rand.int31_max(2)
	deposit.resource_count = rand.int31_max(75) + 25
	deposit.type = type
	return deposit
}


check_deposit_active :: proc(chunk_key: Vector2Int, chunk_tile_pos: Vector2Int) -> bool {
	chunk := &game_data.chunks[chunk_key]
	deposit := chunk.deposits[chunk_tile_pos.y * auto_cast CHUNK_GRID_SIZE_X + chunk_tile_pos.x]
	is_active := false
	return deposit.active
}


mine_deposit :: proc(chunk_key: Vector2Int, chunk_tile_pos: Vector2Int) -> (bool, ResourceType) {
	chunk := &game_data.chunks[chunk_key]
	deposit := chunk.deposits[chunk_tile_pos.y * auto_cast CHUNK_GRID_SIZE_X + chunk_tile_pos.x]
	is_active := false
	resource_type := ResourceType.nil
	if deposit.active {
		deposit.resource_count -= 1
		if deposit.resource_count <= 0 {
			deposit.active = false
		} else {
			is_active = true
		}
		resource_type = deposit.type
	}

	return is_active, resource_type
}


smelt_deposit :: proc(building: ^Building) {
	building.furnace_smelt_count -= 1
	if building.furnace_smelt_count == 0 {
		building.furnace_smelt_type = .nil
	}
}
