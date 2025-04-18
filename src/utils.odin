package main

import sapp "../vendor/sokol/app"
import "base:intrinsics"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:math/linalg"


almost_equals :: proc(a, b, epsilon: f32) -> bool {
	return math.abs(a - b) <= epsilon
}

almost_equals_v2 :: proc(a, b: Vector2, epsilon: f32) -> bool {
	return almost_equals(a.x, b.x, epsilon) && almost_equals(a.y, b.y, epsilon)
}

animate_to_target_f32 :: proc(
	value: ^f32,
	target: f32,
	delta_t: f32,
	rate: f32 = 15.0,
	good_enough: f32 = 0.001,
) -> bool {
	value^ += (target - value^) * (1.0 - math.pow_f32(2.0, -rate * delta_t))
	if almost_equals(value^, target, good_enough) {
		value^ = target
		return true // reached
	}
	return false
}


animate_v2_to_target :: proc(value: ^Vector2, target: Vector2, delta_t: f32, rate: f32) {
	animate_to_target_f32(&value.x, target.x, delta_t, rate)
	animate_to_target_f32(&value.y, target.y, delta_t, rate)
}


camera_shake :: proc(amount: f32) {
	if amount > game_data.shake_amount {
		game_data.shake_amount = amount
	}
}


sine_breathe_alpha :: proc(p: $T) -> T where intrinsics.type_is_float(T) {
	return (math.sin((p - .25) * 2.0 * math.PI) / 2.0) + 0.5
}

cos_breathe_alpha :: proc(p: $T) -> T where intrinsics.type_is_float(T) {
	return (math.cos((p - .25) * 2.0 * math.PI) / 2.0) + 0.5
}

ticks_per_second: u64
run_every_seconds :: proc(s: f32) -> bool {

	test := f32(game_data.ticks) / f32(ticks_per_second)

	interval: f32 = s * f32(ticks_per_second)

	if interval < 1.0 {
		log.error("run_every_seconds is ticking each frame, can't go faster than this")
	}

	run := (game_data.ticks % u64(interval)) == 0
	return run
}


generate_points_rotation_around_circle :: proc(
	radius: f32,
	num_points: int,
	circle_degrees: f32,
) -> (
	[]Vector2,
	[]f32,
) {
	points: []Vector2 = make([]Vector2, num_points)
	rotations: []f32 = make([]f32, num_points)

	angle_step: f32 = circle_degrees / auto_cast num_points

	for i := 0; i < num_points; i += 1 {
		angle: f32 = math.to_radians(angle_step * auto_cast i)
		points[i] = Vector2{radius * math.cos(angle), radius * math.sin(angle)}
		rotations[i] = angle
	}

	return points, rotations
}

ease_over_time :: proc(
	current_t: f32,
	max_t: f32,
	type: ease.Ease,
	start_value: f32,
	end_value: f32,
) -> f32 {
	t := current_t / max_t
	eased_t := ease.ease(type, t)

	// if current_t >= max_t {
	// 	return end_value
	// }

	return start_value + eased_t * (end_value - start_value)
}


import sg "../vendor/sokol/gfx"
vec_to_color :: proc(color: Vector4) -> sg.Color {
	return sg.Color{color.r, color.g, color.b, color.a}
}


get_frame_view :: proc() -> AABB {
	w := get_scaled_width()
	camera_offset_x := camera.position.x - w * 0.5
	camera_offset_y := camera.position.y - (pixel_height / game_data.camera_zoom) * 0.5

	return AABB {
		position = {camera_offset_x, camera_offset_y},
		size = {w, pixel_height / game_data.camera_zoom},
	}

}


get_scaled_width :: proc() -> f32 {
	scale := f32(pixel_height) / f32(sapp.height())
	w := f32(sapp.width()) * scale

	return w / game_data.camera_zoom
}


CardinalDirection :: enum {
	North,
	East,
	South,
	West,
}


cardinal_direction_to_vector :: proc(direction: CardinalDirection) -> Vector2 {
	switch (direction) {
	case .North:
		return {0, 1}
	case .East:
		return {1, 0}
	case .South:
		return {0, -1}
	case .West:
		return {-1, 0}
	}

	assert(false)
	return {}
}


is_point_in_viewbox :: proc(viewbox: AABB, point: Vector2) -> bool {
	return aabb_contains(viewbox.position, viewbox.size, point)
}
