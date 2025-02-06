package main

import "core:math"
import "core:math/linalg"

rect_circle_collision :: proc(rect: Vector4, circle_center: Vector2, radius: f32) -> bool {

	rect_min := rect.xy
	size := rect.zw
	dist_x := math.abs(circle_center.x - (rect_min.x + size.x / 2))
	dist_y := math.abs(circle_center.y - (rect_min.y + size.y / 2))

	if (dist_x > (size.x / 2 + radius)) {return false}
	if (dist_y > (size.y / 2 + radius)) {return false}

	if (dist_x <= (size.x / 2)) {return true}
	if (dist_y <= (size.y / 2)) {return true}

	dx := dist_x - size.x / 2
	dy := dist_y - size.y / 2
	return dx * dx + dy * dy <= (radius * radius)
}


circles_overlap :: proc(
	a_pos_center: Vector2,
	a_radius: f32,
	b_pos_center: Vector2,
	b_radius: f32,
) -> bool {
	distance := linalg.distance(a_pos_center, b_pos_center)
	// Check if the distance is less than or equal to the sum of the radii
	if (distance <= (a_radius + b_radius)) {
		return true
	}

	return false
}


calculate_collision_point_circle_overlap :: proc(
	a_pos_center: Vector2,
	b_pos_center: Vector2,
	a_radius: f32,
) -> Vector2 {
	dir := linalg.normalize(b_pos_center - a_pos_center)
	collision_point := a_pos_center + dir * a_radius

	return collision_point
}


AABB :: struct {
	position: Vector2, // Top-left corner
	size:     Vector2, // Width and Height
}

make_aabb_from_positions :: proc(start, end: Vector2) -> AABB {
	min_x := math.min(start.x, end.x)
	min_y := math.min(start.y, end.y)
	width := math.abs(end.x - start.x)
	height := math.abs(end.y - start.y)

	return AABB{position = Vector2{min_x, min_y}, size = Vector2{width, height}}
}

// Function to check AABB overlap
is_aabb_overlapping :: proc(a, b: AABB) -> bool {
	a_min := Vector2{a.position.x, a.position.y - a.size.y} // Bottom-left
	a_max := Vector2{a.position.x + a.size.x, a.position.y} // Top-right

	b_min := Vector2{b.position.x, b.position.y - b.size.y} // Bottom-left
	b_max := Vector2{b.position.x + b.size.x, b.position.y} // Top-right

	return (a_min.x <= b_max.x && a_max.x >= b_min.x) && (a_min.y <= b_max.y && a_max.y >= b_min.y)
}


aabb_center_contains :: proc(center_position: Vector2, size: Vector2, p: Vector2) -> bool {
	return(
		p.x >= center_position.x - size.x * 0.5 &&
		p.x <= center_position.x + size.x * 0.5 &&
		p.y >= center_position.y - size.y * 0.5 &&
		p.y <= center_position.y + size.y * 0.5 \
	)

}


aabb_contains :: proc(position: Vector2, size: Vector2, p: Vector2) -> bool {
	using math
	min_x := min(position.x, position.x + size.x)
	max_x := max(position.x, position.x + size.x)
	min_y := min(position.y, position.y + size.y)
	max_y := max(position.y, position.y + size.y)

	return p.x >= min_x && p.x <= max_x && p.y >= min_y && p.y <= max_y
}
