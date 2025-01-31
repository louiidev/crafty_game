package main

import "core:math"
import "core:math/linalg"

rect_circle_collision :: proc(rect: Vector4, circle_center: Vector2, radius: f32) -> bool {

    rect_min:= rect.xy;
    size: = rect.zw;
    dist_x:= math.abs(circle_center.x - (rect_min.x + size.x / 2));
    dist_y:= math.abs(circle_center.y - (rect_min.y + size.y / 2));

    if (dist_x > (size.x / 2 + radius)) { return false; }
    if (dist_y > (size.y / 2 + radius)) { return false; }

    if (dist_x <= (size.x / 2)) { return true; }
    if (dist_y <= (size.y / 2)) { return true; }

    dx:= dist_x - size.x / 2;
    dy:= dist_y - size.y / 2;
    return (dx * dx + dy * dy <= (radius * radius));
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


calculate_collision_point_circle_overlap :: proc ( a_pos_center: Vector2, b_pos_center: Vector2, a_radius: f32) -> Vector2 {
    dir := linalg.normalize(b_pos_center - a_pos_center)
    collision_point := a_pos_center + dir * a_radius

    return collision_point
}



aabb_collide_center :: proc(a_center_position: Vector2, a_size: Vector2, b_center_position: Vector2, b_size: Vector2) -> (bool, Vector2) {
    // Calculate distance between centers
    dx := a_center_position.x - b_center_position.x
    dy := a_center_position.y - b_center_position.y

    // Calculate the combined half-extents
    combined_half_width := (a_size.x + b_size.x) / 2
    combined_half_height := (a_size.y + b_size.y) / 2

    // Calculate overlap on each axis
    overlap_x := combined_half_width - abs(dx)
    overlap_y := combined_half_height - abs(dy)

    // If there is no overlap on any axis, there is no collision
    if overlap_x <= 0 || overlap_y <= 0 {
        return false, Vector2{}
    }

    // Find the penetration vector (smallest displacement needed to separate the rectangles)
    penetration := Vector2{}
    if overlap_x < overlap_y {
        penetration.x = overlap_x if dx > 0 else -overlap_x
    } else {
        penetration.y = overlap_y if dy > 0 else -overlap_y
    }

    return true, penetration
}


aabb_center_contains :: proc(center_position: Vector2, size: Vector2, p: Vector2) -> bool {
	return(
		p.x >= center_position.x - size.x * 0.5 &&
		p.x <= center_position.x + size.x * 0.5 &&
		p.y >= center_position.y - size.y * 0.5 &&
		p.y <= center_position.y + size.y * 0.5
	)
}


aabb_contains :: proc(position: Vector2, size: Vector2, p: Vector2) -> bool {
    using math
    min_x: = min(position.x, position.x + size.x);
    max_x: = max(position.x, position.x + size.x);
    min_y: = min(position.y, position.y + size.y);
    max_y: = max(position.y, position.y + size.y);

    return p.x >= min_x && p.x <= max_x && p.y >= min_y && p.y <= max_y;
}
