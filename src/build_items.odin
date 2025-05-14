package main

import "core:math"

MinerBuildingTask :: struct {
	building_index: int,
	chunk_key:      Vector2Int,
}

BuildType :: enum {
	nil,
	Tent,
	Drill,
	ConveyorBelt,
	CollectionBox,
	Furnace,
}

BuildItem :: struct {
	cost:           int,
	size:           Vector2,
	sprite_coords:  Vector2Int,
	unlocked:       bool,
	type:           BuildType,
	belt_direction: ConveyorDirections,
}


Building :: struct {
	built:                        bool,
	invisible:                    bool,
	size:                         Vector2,
	type:                         BuildType,
	build_progress:               f32,
	chunk_key:                    Vector2Int,
	chunk_tile_position:          Vector2Int,
	world_position:               Vector2Int,
	sprite_coords:                Vector2Int,
	position:                     Vector2,
	active:                       bool,
	working:                      bool,
	current_animation_time:       f32,
	current_animation_frame:      int,
	output_direction:             CardinalDirection,
	furnace_smelt_type:           ResourceType,
	furnace_smelt_count:          int,
	belt_direction:               ConveyorDirections,
	last_world_item_output_index: int,
}


find_closest_building_type_in_chunk :: proc(
	chunk_key: Vector2Int,
	world_position: Vector2Int,
	type: BuildType,
) -> (
	bool,
	^Building,
) {

	found_b: ^Building = nil
	distance_from_target: f32 = math.inf_f32(1)
	ok := false

	for &building in game_data.chunks[chunk_key].buildings {
		if building.type == type {
			check_distance_from_target := manhattan_dist(building.world_position, world_position)
			if found_b == nil || check_distance_from_target < distance_from_target {
				found_b = &building
				distance_from_target = check_distance_from_target
				ok = true
			}
		}
	}

	return ok, found_b
}


get_build_item_sprite :: proc(type: BuildType) -> ImageId {
	sprite: ImageId = .nil
	switch (type) {
	case .Drill:
		sprite = .drill
	case .Tent:
		sprite = .tent
	case .ConveyorBelt:
		sprite = .conveyor_yellow
	case .CollectionBox:
		sprite = .storage_box
	case .Furnace:
		sprite = .furnace
	case .nil:

	}

	return sprite
}
