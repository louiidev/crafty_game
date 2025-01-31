package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

Particle :: struct {
	using _:          BaseEntity,
	velocity:         Vector2,
	rotation:         f32,
	lifetime:         f32,
	current_lifetime: f32,
	size:             f32,
	color:            Vector4,
	imageId:          ImageId,
	uv:               Vector4,
	delay:            f32,
	delay_start:      f32,
}


SpriteParticle :: struct {
	using _:                Particle,
	time_per_frame:         f32,
	sprite_cell_start:      Vector2Int,
	animation_count:        int,
	current_frame:          int,
	current_animation_time: f32,
	scale:                  f32,
}


PARTICLE_LIFETIME: f32 : 0.5
PARTICLE_EXPLOSION_LIFETIME: f32 : 1.5

PARTICLE_VELOCITY: f32 : 50

spawn_particles :: proc(position: Vector2, color: Vector4 = COLOR_WHITE) {
	num_particles := rand.int_max(5) + 4
	last_dir: f32 = 0
	for i := 0; i < num_particles; i += 1 {

		rand_direction: f32 = math.to_radians(rand.float32_range(0, 360)) + last_dir
		last_dir = rand_direction
		particle: Particle
		particle.position = position
		particle.active = true
		particle.color = color
		particle.lifetime = PARTICLE_LIFETIME
		particle.size = 5.0 + rand.float32_range(-1.5, 1.5)
		particle.uv = DEFAULT_UV

		particle.velocity =
			{math.cos(rand_direction), math.sin(rand_direction)} * PARTICLE_VELOCITY
		append(&game_data.particles, particle)
	}
}


spawn_explosion_particles :: proc(position: Vector2, size: f32, color: Vector4) {
	points, angles := generate_points_rotation_around_circle(size / 2, 8, 360)


	for i := 0; i < len(points); i += 1 {

		angle_radians := angles[i]
		opposite_direction: Vector2 = {
			math.cos(angle_radians), // Negative cosine for opposite direction
			math.sin(angle_radians), // Negative sine for opposite direction
		}

		p_size := 30.0 + rand.float32_range(-5, 10.5)
		point_position := points[i]
		color := color
		color.a = 0.5
		particle: Particle
		particle.delay_start = 0.5
		particle.delay = 0.1
		particle.position = position + point_position - opposite_direction * p_size * 0.2
		particle.active = true
		particle.color = color
		particle.lifetime = PARTICLE_EXPLOSION_LIFETIME
		particle.size = 20.0 + rand.float32_range(-5, 10.5)
		particle.imageId = .circle
		particle.uv = get_frame_uvs(.circle, {0, 0}, {64, 64})


		particle.velocity = {}
		append(&game_data.particles, particle)
	}

	delete(points)
	delete(angles)
}


spawn_walking_particles :: proc(position: Vector2, color: Vector4, direction: Vector2) {
	num_particles := rand.int_max(1) + 1
	last_dir: f32 = 0

	for i := 0; i < num_particles; i += 1 {

		rand_direction: f32 = rand.float32_range(-1.5, 1.5)

		particle: Particle
		particle.position = position + rand_direction
		particle.active = true
		particle.color = color
		particle.lifetime = PARTICLE_LIFETIME
		particle.size = 3.0 + rand.float32_range(0, 1.5)
		particle.imageId = .circle
		particle.uv = get_frame_uvs(.circle, {0, 0}, {64, 64})


		particle.velocity = {}
		append(&game_data.particles, particle)
	}

}

spawn_orb_particles :: proc(position: Vector2, color: Vector4, direction: Vector2) {

	particle: Particle
	particle.position = position
	particle.active = true
	particle.color = color
	particle.lifetime = PARTICLE_LIFETIME * 2
	particle.size = 8.0
	particle.imageId = .circle
	particle.uv = get_frame_uvs(.circle, {0, 0}, {64, 64})


	particle.velocity = {}
	append(&game_data.particles, particle)
}


update_render_particles :: proc(dt: f32) {

	for &particle in &game_data.particles {

		if !particle.active {

			continue
		}
		if particle.delay > 0 {
			particle.delay -= dt
			continue
		}


		if particle.delay_start > 0 {
			particle.delay_start -= dt
		}
		current_size := particle.size
		if particle.delay <= 0 {
			particle.current_lifetime += dt


			normalized_life := particle.current_lifetime / particle.lifetime
			scale := (1.0 - normalized_life) * (1.0 - normalized_life)

			current_size = particle.size * scale
			if current_size <= 0 || particle.current_lifetime >= particle.lifetime {
				particle.active = false

			}

			current_velocity := particle.velocity * scale
			particle.position += current_velocity * dt
		}

		draw_quad_center_xform(
			transform_2d(particle.position),
			{current_size, current_size},
			particle.imageId,
			particle.uv,
			particle.color,
		)
	}


	for &particle in &game_data.sprite_particles {


		if particle.current_frame >= particle.animation_count - 1 {
			particle.active = false
		}
		if !particle.active {
			continue
		}

		particle.current_animation_time += dt

		if particle.current_frame < particle.animation_count - 1 &&
		   particle.current_animation_time > particle.time_per_frame {
			particle.current_frame += 1
			particle.current_animation_time = 0
		}


		xform := transform_2d(particle.position, particle.rotation, particle.scale)

		uvs := get_frame_uvs(
			.sprite_particles,
			{particle.sprite_cell_start.x + particle.current_frame, particle.sprite_cell_start.y},
			{16, 16},
		)
		draw_quad_center_xform(xform, {16, 16}, .sprite_particles, uvs)
	}

}
