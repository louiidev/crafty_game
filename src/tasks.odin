package main

import "core:slice"

TargetBlock :: struct {
	chunk_key:                      Vector2Int,
	tile_chunk_grid_position:       Vector2Int,
	tile_world_grid_position:       Vector2Int,
	building_index:                 int,
	miner_placement_world_position: Vector2Int, // world pos
}


TaskQueueItem :: struct {
	active:               bool,
	block_targets:        [dynamic]TargetBlock,
	current_target_index: int,
}


remove_blocks_for_destruction :: proc(miner: ^Entity, deletion_tile_pos: ^[dynamic]TargetBlock) {
	task := &miner.tasks[.destroy_blocks]


	if len(task.block_targets) > 0 {


		previous_task_index := task.current_target_index
		previous_task_pos := task.block_targets[previous_task_index].tile_world_grid_position

		for remove_block in deletion_tile_pos {
			for backwards_i := (len(task.block_targets) - 1); backwards_i >= 0; backwards_i -= 1 {
				if task.block_targets[backwards_i].tile_world_grid_position ==
				   remove_block.tile_world_grid_position {
					ordered_remove(&task.block_targets, backwards_i)
					if task.current_target_index == backwards_i {
						task.current_target_index = -1
					}
				}

			}
		}


		if len(task.block_targets) == 0 {
			if .destroy_blocks == miner.current_task {
				clear(&miner.node_path)
			}

			task.active = false
			miner.current_task = .nil
			set_state(miner, .idle)
		} else if previous_task_index > -1 {
			for backwards_i := (len(task.block_targets) - 1); backwards_i >= 0; backwards_i -= 1 {
				target := task.block_targets[backwards_i]
				if target.tile_world_grid_position == previous_task_pos {
					task.current_target_index = backwards_i
					break
				}
			}
		}
	}
}


add_blocks_for_destruction :: proc(miner: ^Entity, deletion_tile_pos: ^[dynamic]TargetBlock) {
	has_task := miner.tasks[.destroy_blocks].active

	if !has_task {
		add_new_task(.destroy_blocks, miner)
	}

	append_elems(&miner.tasks[.destroy_blocks].block_targets, ..deletion_tile_pos[:])
}


update_miner_cancel_destroy_block_task :: proc(position: Vector2, size: Vector2) {
	view_box: AABB = get_frame_view()
	target_blocks: [dynamic]TargetBlock
	target_blocks.allocator = temp_allocator()
	chunk_keys := get_chunk_keys_in_rect(view_box)
	for chunk_key in chunk_keys {
		chunk := &game_data.chunks[chunk_key]
		for &tile in chunk.tiles {
			if tile.active && aabb_contains(position, size, tile.position) {
				append(
					&target_blocks,
					TargetBlock {
						tile_world_grid_position = tile.grid_position,
						tile_chunk_grid_position = tile.chunk_grid_position,
						chunk_key = chunk_key,
					},
				)
				tile.queued_for_destruction = false
			}
		}
	}


	for &miner in game_data.miners {
		remove_blocks_for_destruction(&miner, &target_blocks)
	}


}


// get_tile_positions_in_selection_zone 

update_miner_destroy_block_task :: proc(position: Vector2, size: Vector2) {

	view_box: AABB = get_frame_view()
	target_blocks: [dynamic]TargetBlock
	target_blocks.allocator = temp_allocator()
	chunk_keys := get_chunk_keys_in_rect(view_box)
	for chunk_key in chunk_keys {
		chunk := &game_data.chunks[chunk_key]
		for &tile in chunk.tiles {
			if tile.active && aabb_contains(position, size, tile.position) {
				append(
					&target_blocks,
					TargetBlock {
						tile_world_grid_position = tile.grid_position,
						tile_chunk_grid_position = tile.chunk_grid_position,
						chunk_key = chunk_key,
					},
				)
				tile.queued_for_destruction = true
			}
		}
	}


	for &miner in game_data.miners {
		if len(game_data.selected_miner_ids) > 0 {
			for selected_id in game_data.selected_miner_ids {
				if selected_id == miner.id {
					add_blocks_for_destruction(&miner, &target_blocks)
					break
				}
			}
		} else {
			add_blocks_for_destruction(&miner, &target_blocks)
		}


	}
}


add_miner_building_task :: proc(b: ^Building, miner: ^Entity) {
	add_new_task(.build_building, miner)
	if miner.current_task == .build_building {
		// generate path to move
	}
}

generate_path_for_building :: proc(miner: ^Entity) {
	task := miner.tasks[.build_building]
	assert(task.active)
	assert(len(task.block_targets) > 0)
	miner_grid_position := world_pos_to_tile_pos(miner.position)
	miner_tile_world_pos := world_pos_to_tile_pos(miner.position)
	miner.tasks[.build_building].current_target_index = 0
	index := miner.tasks[.build_building].current_target_index


	target_block := &miner.tasks[.build_building].block_targets[index]


	b: Building = game_data.chunks[target_block.chunk_key].buildings[target_block.building_index]
	ok, position := get_closest_free_block_next_to_target(
		b.world_position,
		b.chunk_tile_position,
		b.chunk_key,
		miner_tile_world_pos,
	)

	if ok {
		path := find_path(world_pos_to_tile_pos(miner.position), position)
		target_block.miner_placement_world_position = position
		if path != nil {
			miner.node_path = slice.clone_to_dynamic(path[:])
		} else {
			log("CANT FIND PATH")
			assert(false)
		}
		delete(path)
	}
}


building_finished :: proc(task_world_pos: Vector2Int, distance: f32) {
	for &miner in game_data.miners {
		if manhattan_dist(task_world_pos, world_pos_to_tile_pos(miner.position)) > distance {
			continue
		}

		if miner.tasks[.build_building].active {
			set_state(&miner, .idle)
			ordered_remove(
				&miner.tasks[.build_building].block_targets,
				miner.tasks[.build_building].current_target_index,
			)
			if miner.current_task == .build_building {
				log("REMOVED CURRENT TASK")
				remove_current_task(&miner)
			}
		}
	}
}


add_new_building_task :: proc(b: ^Building, miner: ^Entity, building_index: int) {
	add_new_task(.build_building, miner)

	target: TargetBlock
	target.chunk_key = b.chunk_key
	target.tile_chunk_grid_position = b.chunk_tile_position
	target.tile_world_grid_position = b.world_position
	target.building_index = building_index
	target_index := len(miner.tasks[.build_building].block_targets)


	append(&miner.tasks[.build_building].block_targets, target)

	if miner.tasks[.build_building].current_target_index == -1 {
		miner.tasks[.build_building].current_target_index = target_index
	}
}

add_new_task :: proc(type: MinerTask, miner: ^Entity) {
	miner.tasks[type].active = true
}


setup_tasks :: proc(miner: ^Entity) {
	for &task in miner.tasks {
		task.current_target_index = -1
	}
}

remove_current_task :: proc(miner: ^Entity) {
	miner.tasks[miner.current_task].active = false
	miner.current_task = .nil
	clear(&miner.node_path)
}


is_task_higher_priority :: proc(current: MinerTask, new_task: MinerTask) -> bool {
	if new_task == .nil {
		return false
	}

	if current == .nil {
		return true
	}

	return current < new_task
}
