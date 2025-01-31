package main

import "core:math"

manhattan_dist :: proc(a: Vector2Int, b: Vector2Int) -> f32 {
	return math.abs(f32(a.x) - f32(b.x)) + math.abs(f32(a.y) - f32(b.y))
}


Node :: struct {
	g: f32,
	h: f32,
}


f_cost :: proc(node: ^Node) -> f32 {
	return node.g + node.h
}


neighbours: [4]Vector2Int : {{1, 0}, {0, -1}, {0, 1}, {-1, 0}}

find_path :: proc(start: Vector2Int, end: Vector2Int) {
	to_search: [dynamic]Node = make([dynamic]Node, 1, temp_allocator())
	append(&to_search, Node{})
	processed: [dynamic]Node
	processed.allocator = temp_allocator()


	for len(to_search) > 0 {
		current_index := 0
		current := &to_search[current_index]
		for i := 0; i < len(to_search); i += 1 {
			t := &to_search[i]
			if f_cost(t) < f_cost(current) || f_cost(t) == f_cost(current) && t.h < current.h {
				current_index = i
				current = t
			}
		}


		// maybe i shouldn't be using pointers? feels like Im going to do something stupid like assign a ref instead of a copy
		append(&processed, current^)
		ordered_remove(&to_search, current_index)


		for neighbour in neighbours {
            // we need to check the bounds
            // 
		}
	}
}
