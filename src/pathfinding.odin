package main

import "core:math"

manhattan_dist :: proc(a: Vector2Int, b: Vector2Int) -> f32 {
	return math.abs(f32(a.x) - f32(b.x)) + math.abs(f32(a.y) - f32(b.y))
}


Node :: struct {
	position:         Vector2Int,
	g:                f32, // distance from start node
	h:                f32, // distance from target node
	walkable:         bool,
	connection_coord: Vector2Int,
}


f_cost :: proc(node: Node) -> f32 {
	return node.g + node.h
}


neighbours: [4]Vector2Int : {{1, 0}, {0, -1}, {0, 1}, {-1, 0}}


gather_nodes :: proc(start: Vector2Int, end: Vector2Int, nodes: ^map[Vector2Int]Node) {
	start := Vector2{auto_cast start.x, auto_cast start.y} * TILE_SIZE
	end := Vector2{auto_cast end.x, auto_cast end.y} * TILE_SIZE
	box: AABB = make_aabb_from_positions(start, end)
	scale: f32 = 100
	box.position -= scale
	box.size += scale * 2
	chunk_keys := get_chunk_keys_in_rect(box)

	for key in chunk_keys {
		chunk := game_data.chunks[key]
		for tile in chunk.tiles {
			node: Node
			node.walkable = !tile.active
			node.position = tile.grid_position
			node.g = 100000000
			nodes[tile.grid_position] = node

		}
	}

	log("nodes gathered")
}


find_path :: proc(start: Vector2Int, end: Vector2Int) -> [dynamic]Vector2Int {
	nodes: map[Vector2Int]Node = make(map[Vector2Int]Node, temp_allocator())
	gather_nodes(start, end, &nodes)

	defer delete(nodes)
	if end in nodes {
		if !nodes[end].walkable {
			return nil
		}
	} else {
		return nil
	}

	to_search: [dynamic]Vector2Int = make([dynamic]Vector2Int, 1, temp_allocator())
	append(&to_search, start)
	processed: [dynamic]Vector2Int
	processed.allocator = temp_allocator()

	// Initialize the start node's g cost
	start: ^Node = &nodes[start]
	start.g = 0

	for len(to_search) > 0 {
		current_pos := to_search[0]
		current_index := 0

		// Find node with lowest f_cost
		for i := 0; i < len(to_search); i += 1 {
			pos := to_search[i]
			log(nodes[pos], nodes[current_pos])
			if f_cost(nodes[pos]) < f_cost(nodes[current_pos]) ||
			   f_cost(nodes[pos]) == f_cost(nodes[current_pos]) &&
				   nodes[pos].h < nodes[current_pos].h {
				current_pos = pos
				current_index = i
			}
		}

		append(&processed, current_pos)
		ordered_remove(&to_search, current_index)

		if current_pos == end {
			current_path_tile_pos := current_pos
			path: [dynamic]Vector2Int
			path.allocator = temp_allocator()
			for current_path_tile_pos != start.position {
				current := nodes[current_path_tile_pos]
				append(&path, current.position)
				current_path_tile_pos = current.connection_coord
			}
			// Add start node to complete the path
			// 
			return path
		}

		for neighbour_pos in neighbours {
			neighbour_position := neighbour_pos + current_pos

			if !(neighbour_position in nodes) || !nodes[neighbour_position].walkable {
				continue
			}

			already_processed := false
			for p in processed {
				if p == neighbour_position {
					already_processed = true
					break
				}
			}

			if already_processed {
				continue
			}

			cost_to_neighbour :=
				nodes[current_pos].g + manhattan_dist(current_pos, neighbour_position)

			in_search := false
			for search in to_search {
				if search == neighbour_position {
					in_search = true
					break
				}
			}

			if !in_search || cost_to_neighbour < nodes[neighbour_position].g {
				neighbour: ^Node = &nodes[neighbour_position]

				neighbour.g = cost_to_neighbour
				neighbour.connection_coord = current_pos
				if !in_search {
					neighbour.h = manhattan_dist(neighbour_position, end)
					append(&to_search, neighbour_position)
				}
			}
		}
	}
	return nil
}
