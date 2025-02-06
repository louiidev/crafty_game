//------------------------------------------------------------------------------
//  texcube/main.odin
//  Texture creation, rendering with texture, packed vertex components.
//------------------------------------------------------------------------------
package main

import sapp "../vendor/sokol/app"
import sg "../vendor/sokol/gfx"
import sglue "../vendor/sokol/glue"
import slog "../vendor/sokol/log"
import "core:os"
// import stime "../sokol/time"

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import "core:strings"

import "time"


DEBUG :: true

RELEASE :: !DEBUG

// PLATFORM :: #config(PLATFORM, "undefined")

DEMO :: #config(DEMO, true)

WEB :: ODIN_ARCH == .wasm32


// :config
when DEBUG {
	DEV :: true
	TESTING :: false
	PROFILE :: false
} else {
	DEV :: false
	TESTING :: false
	PROFILE :: false
	// log :: logger.info

}

pixel_width: f32 : 320
pixel_height: f32 : 200


temp_allocator :: proc() -> mem.Allocator {
	return context.temp_allocator
}


DebugPathfinding :: struct {
	nodes: map[Vector2Int]bool,
	start: Vector2Int,
	end:   Vector2Int,
}


GameRunState :: struct {
	chunks:                   map[Vector2Int]Chunk,
	particles:                [dynamic]Particle,
	sprite_particles:         [dynamic]SpriteParticle,
	popup_text:               [dynamic]PopupText,
	miners:                   [dynamic]Entity,
	enemy_spawn_timer:        f32,
	money:                    int,
	ticks:                    u64,
	selected_miner_ids:       [dynamic]u32,
	start_drag:               Vector2,
	selecting:                bool,

	// timers
	in_transition_timer:      f32,
	out_transition_timer:     f32,
	knockback_radius_timer:   f32,
	knockback_hold_timer:     f32,
	timer_to_show_upgrade:    f32,
	slowdown_multiplier:      f32,
	shop_in_transition_time:  f32,
	shop_out_transition_time: f32,
	debug_pathfinding:        DebugPathfinding,


	// camera shake
	camera_zoom:              f32,
	shake_amount:             f32,
	ui_state:                 GameUIState,
	app_state:                AppState,
	world_time_elapsed:       f32,
	explosions:               [dynamic]Explosion,
	knockback_position:       Vector2,
	// STATS
	enemies_killed:           u32,
	money_earned:             u32,
	using ux_state:           struct {
		ux_alpha:      f32,
		ux_anim_state: enum {
			fade_in,
			hold,
			fade_out,
		},
		hold_end_time: f64,
	},
}


log :: fmt.println

last_id: u32 = 0
Entity :: struct {
	using _:                 BaseEntity,
	id:                      u32,
	velocity:                Vector2,
	dodge_roll_cooldown:     f32,
	speed:                   f32,
	roll_speed:              f32,
	health:                  f32,
	max_health:              f32,
	collision_radius:        f32,
	knockback_timer:         f32,
	knockback_direction:     Vector2,
	knockback_velocity:      Vector2,
	attack_timer:            f32,
	stun_timer:              f32,
	current_animation_timer: f32,
	current_animation_frame: int,
	scale_x:                 f32,
	node_path:               [dynamic]Vector2Int,
}


AppState :: enum {
	splash_logo,
	splash_fmod,
	main_menu,
	game,
}

GameUIState :: enum {
	nil,
	pause_menu,
	upgrade_menu,
	player_death,
}


Camera :: struct {
	position: Vector2,
}


Bomb :: struct {
	using _:                 BaseEntity,
	current_animation_timer: f32,
	current_animation_frame: int,
	last_frame_timer:        f32,
}


MAX_POPUP_TEXT_LIFE_TIME: f32 : 1.0
PopupText :: struct {
	using _:   BaseEntity,
	alpha:     f32,
	text:      string,
	color:     Vector4,
	life_time: f32,
	scale:     f32,
}

DEFAULT_POPUP_TXT: PopupText : {active = true, color = COLOR_WHITE, scale = 1.0}

// UPGRADES INITIAL VALUES
// REVOLVER
PLAYER_INITIAL_BULLETS :: 6
PLAYER_INITIAL_BULLET_RANGE: f32 : 100
PLAYER_INITIAL_BULLET_SPREAD: f32 : 12.0
PLAYER_INITIAL_RELOAD_TIME :: 1.4
PLAYER_INITIAL_BULLET_DMG: f32 : 10
PLAYER_INITIAL_BULLET_VELOCITY :: 900.0
PLAYER_INITIAL_FIRE_RATE :: 0.13


PLAYER_MIN_POSSIBLE_RELOAD_TIME :: 0.1

PLAYER_INITIAL_PICKUP_RADIUS :: 30
PLAYER_INITIAL_CRIT_CHANCE: f32 : 7.5
PLAYER_MAX_CRIT_CHANCE: f32 : 75.5
PLAYER_WALK_SPEED :: 120
PLAYER_WALK_SHOOTING_SPEED :: 80 * 0.25
PLAYER_SPEED_REDUCATION_PER_FRAME: f32 : 70.0
PLAYER_SPEED_ADDITION_PER_FRAME: f32 : 120.0
PLAYER_ROLL_SPEED :: 100
PLAYER_ROLLDOWN_COOLDOWN :: 0.8
PLAYER_DODGE_ROLL_PWR :: 180
PLAYER_DODGE_ROLL_TIME :: 0.36
PLAYER_DEFAULT_ORB_DMG: f32 : 3

PLAYER_INITIAL_poison_DMG: f32 : 1.0
PLAYER_INITIAL_FREEZE_SLOWDOWN: f32 : 0.75
INITIAL_EXPLOSIVE_DMG: f32 : 15
INITIAL_FREEZE_SLOWDOWN: f32 : 0.75

PLAYER_GUN_MOVE_DIST: f32 : 8.0


MIN_ENEMIES_PER_SPAWN: int : 4
MAX_ENEMIES_PER_SPAWN: int : 10

MAX_EVER_ENEMIES_PER_SPAWN: int : 15

WAVE_ENEMY_PER_SPAWN_MODIFIER: int : 1
WAVE_ENEMY_HEALTH_MODIFIER: f32 : 2.5


SPRITE_PIXEL_SIZE :: 16

PLAYER_KNOCKBACK_VELOCITY :: 120


REROLL_COST_MODIFIER :: 2
INITIAL_REROLL_COST :: 1


IDLE_ANIMATION_TIME :: 0.6
IDLE_ANIMATION_FRAMES :: 2
WALK_ANIMATION_TIME :: 0.08
WALK_ANIMATION_FRAMES :: 6
ROLLING_ANIMATION_TIME :: 0.08
ROLLING_ANIMATION_FRAMES :: 4

PLAYER_I_FRAME_TIMEOUT_AMOUNT :: 0.5

UPGRADE_TIMER_SHOW_TIME :: 0.9
TIMER_TO_SHOW_DEATH_UI: f32 : 2.0
TIMER_TO_SHOW_DEATH_ANIMATION: f32 : 1.5
INITIAL_STUN_TIME :: 0.5
INITIAL_KILL_AMOUNT :: 30
WAVE_KILL_MODIFIER: f32 : 1.2
WAVE_TIME_MODIFIER: f32 : 0.5
CAMERA_SHAKE_DECAY: f32 : 0.8
SHAKE_POWER: f32 : 2.0
SPAWN_INDICATOR_TIME: f32 : 0.90
LEVEL_BOUNDS: Vector2 : {480, 480}
SPAWN_BOUNDS: Vector2 : {LEVEL_BOUNDS.x - 44, LEVEL_BOUNDS.y - 44}
HALF_BOUNDS: Vector2 : {LEVEL_BOUNDS.x * 0.5, LEVEL_BOUNDS.y * 0.5}

WALLS: [4]Vector4 : {
	{-HALF_BOUNDS.x - 10, -HALF_BOUNDS.y, 10, LEVEL_BOUNDS.y}, // left
	{-HALF_BOUNDS.x, -HALF_BOUNDS.y - 10, LEVEL_BOUNDS.x, 10}, // bottom
	{HALF_BOUNDS.x, -HALF_BOUNDS.y, 10, LEVEL_BOUNDS.y}, // right
	{-HALF_BOUNDS.x, HALF_BOUNDS.y, LEVEL_BOUNDS.x, 10}, // up
}
DEBUG_HITBOXES :: false
DEBUG_NO_ENEMIES :: false


Explosion :: struct {
	using _:          BaseEntity,
	current_lifetime: f32,
	max_lifetime:     f32,
	size:             f32,
}


MONEY_ANIM_FRAMES :: 8
MONEY_ANIM_TIME_PER_FRAME: f32 : 0.1


game_data: GameRunState


camera: Camera


setup_run :: proc() {
	game_data.app_state = .game
	game_data.camera_zoom = 1.0
}


background_color: Vector4
clear_color: sg.Color

import "core:mem"
init :: proc "c" () {
	context = runtime.default_context()
	sg.setup(
		{
			environment = sglue.environment(),
			logger = {func = slog.func},
			d3d11_shader_debugging = ODIN_DEBUG,
		},
	)

	background_color = hex_to_rgb(0x25131a)
	clear_color = vec_to_color(background_color)
	// stime.setup()
	gfx_init()
	init_images()
	init_sound()
	setup_run()
	init_time = time.now()


	when (!DEBUG || !TESTING) && !DEV {
		game_data.app_state = .splash_logo
		sapp.toggle_fullscreen()
	} else {
		game_data.app_state = .game
		// ux_mode = .splash_logo
	}
	{
		ent: Entity
		ent.active = true
		ent.id = 1
		ent.speed = 20
		ent.position = Vector2{80, 80}
		append(&game_data.miners, ent)
	}
	{
		ent: Entity
		ent.active = true
		ent.id = 2
		ent.position = Vector2{30, 30}
		ent.speed = 20

		append(&game_data.miners, ent)
	}

	{
		ent: Entity
		ent.active = true
		ent.id = 3
		ent.speed = 20
		ent.position = Vector2{180, 180}
		append(&game_data.miners, ent)
	}
	{
		ent: Entity
		ent.active = true
		ent.id = 4
		ent.position = Vector2{50, 50}
		ent.speed = 20

		append(&game_data.miners, ent)
	}


	// data: [len(game_data.tiles)]byte


	// write save file
	data, ok := os.read_entire_file("test.data", context.temp_allocator)


	create_chunk({0, 0})
	new_chunk: ^Chunk = &game_data.chunks[{0, 0}]
	for x: u32 = 0; x < CHUNK_GRID_SIZE_X; x += 1 {
		for y: u32 = 0; y < CHUNK_GRID_SIZE_Y; y += 1 {

			active := true
			for ent in game_data.miners {
				pos := world_pos_to_tile_pos(ent.position)
				if manhattan_dist(pos, new_chunk.tiles[y * CHUNK_GRID_SIZE_X + x].grid_position) <=
				   6 {
					active = false
				}
			}
			new_chunk.tiles[y * CHUNK_GRID_SIZE_X + x].active = active
		}
	}

	allocate_tile_bitmasks({0, 0})

}


paused := false
last_time: u64 = 0
mouse_world_position: Vector2


calc_rotation_to_target :: proc(a, b: Vector2) -> f32 {
	delta_x := a.x - b.x
	delta_y := a.y - b.y
	angle := linalg.atan2(delta_y, delta_x)
	return angle
}


DamageType :: enum {
	physical,
	projectile,
}


update_entity_timers :: proc(ent: ^Entity, dt: f32) {
	ent.attack_timer = math.max(0.0, ent.attack_timer - dt)
	ent.knockback_timer = math.max(0.0, ent.knockback_timer - dt)
	ent.stun_timer = math.max(0.0, ent.stun_timer - dt)

	ent.current_animation_timer += dt
	ent.dodge_roll_cooldown = math.max(0.0, ent.dodge_roll_cooldown - dt)
}


mouse_to_matrix :: proc() -> Vector2 {
	// MOUSE TO WORLD
	mouse_x := inputs.screen_mouse_pos.x
	mouse_y := inputs.screen_mouse_pos.y
	proj := draw_frame.projection
	view := draw_frame.camera_xform

	// Normalize the mouse coordinates
	ndc_x := (mouse_x / (auto_cast sapp.width() * 0.5)) - 1.0
	ndc_y := (mouse_y / (auto_cast sapp.height() * 0.5)) - 1.0

	// Transform to world coordinates
	world_pos: Vector4 = {ndc_x, ndc_y, 0, 1}
	world_pos = linalg.inverse(proj * view) * world_pos
	// world_pos = view * world_pos
	return world_pos.xy
}


is_within_bounds :: proc(position: Vector2) -> bool {
	if HALF_BOUNDS.x <= position.x ||
	   HALF_BOUNDS.y <= position.y ||
	   -HALF_BOUNDS.x > position.x ||
	   -HALF_BOUNDS.y > position.y {
		return false
	}

	return true
}


inside_circle :: proc(center: Vector2Int, tile: Vector2Int, diameter: int) -> bool {
	dx := center.x - tile.x
	dy := center.y - tile.y
	distance_squared := dx * dx + dy * dy
	return 4 * distance_squared <= diameter * diameter
}

round_to_half :: proc(value: f32) -> f32 {
	return math.round(value * 2) / 2
}


check_wall_collision :: proc(player_pos: Vector2, player_radius: f32, wall: Vector4) -> bool {
	// Create player AABB centered on player position
	player_half_size := player_radius / 2
	player_box := Vector4 {
		player_pos.x - player_half_size, // min x
		player_pos.y - player_half_size, // min y
		player_pos.x + player_half_size, // max x
		player_pos.y + player_half_size, // max y
	}
	// Wall is already in min/max format
	return rect_circle_collision(wall, player_pos, player_radius)
}

game_play :: proc() {


	dt: f32 = get_delta_time()
	app_dt: f32 = get_delta_time()
	ticks_per_second = u64(1.0 / dt)
	ticks_per_second = clamp(ticks_per_second, 60, 240)
	defer game_data.ticks += 1

	defer game_data.world_time_elapsed += app_dt

	particle_dt: f32 = get_delta_time()

	if inputs.button_just_pressed[sapp.Keycode.ESCAPE] {
		if game_data.ui_state == .pause_menu {
			game_data.ui_state = nil
		} else if game_data.ui_state == nil {
			game_data.ui_state = .pause_menu
		}
	}


	game_play_paused :=
		game_data.ui_state != nil ||
		game_data.in_transition_timer > 0 ||
		game_data.out_transition_timer > 0

	if game_play_paused {
		dt = 0.0
	}


	if !game_play_paused {


		max_distance: f32 = 25

		if game_data.ui_state == nil {
			game_data.shake_amount = math.max(game_data.shake_amount - CAMERA_SHAKE_DECAY * dt, 0)
			amount := math.pow(game_data.shake_amount, SHAKE_POWER)
			// rotation = max_roll * amount * rand_range(-1, 1)

			camera.position.x += amount * rand.float32_range(-1, 1)
			camera.position.y += amount * rand.float32_range(-1, 1)
		} else {
			game_data.shake_amount = 0
		}

	}


	using sapp.Keycode
	x := f32(int(inputs.button_down[D]) - int(inputs.button_down[A]))
	y := f32(int(inputs.button_down[W]) - int(inputs.button_down[S]))

	camera.position += {x, y} * dt * 130

	draw_frame.camera_xform = translate_mat4(Vector3{-camera.position.x, -camera.position.y, 0})
	set_ortho_projection(game_data.camera_zoom)

	mouse_world_position = mouse_to_matrix()


	// @gameplay inputs 
	if !game_play_paused {


		if inputs.mouse_scroll_delta != {} {
			game_data.camera_zoom = math.clamp(
				game_data.camera_zoom + inputs.mouse_scroll_delta.y * dt * 16,
				0.5,
				2.5,
			)
		}


		if inputs.mouse_just_pressed[sapp.Mousebutton.RIGHT] {
			clear(&game_data.selected_miner_ids)
		}

		if inputs.mouse_down[sapp.Mousebutton.LEFT] && !game_data.selecting {
			game_data.start_drag = mouse_world_position
			game_data.selecting = true
		} else if inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] {
			size: Vector2 = {
				mouse_world_position.x - game_data.start_drag.x,
				mouse_world_position.y - game_data.start_drag.y,
			}


			if len(game_data.selected_miner_ids) > 0 && linalg.length(size) <= 10 {

				set_z_layer(.ui)

				for &miner in game_data.miners {
					for selected_id in game_data.selected_miner_ids {
						if selected_id == miner.id {

							path := find_path(
								world_pos_to_tile_pos(miner.position),
								world_pos_to_tile_pos(mouse_world_position),
							)
							if path != nil {
								miner.node_path = slice.clone_to_dynamic(path[:])
							}
							delete(path)

							break
						}
					}
				}
				clear(&game_data.selected_miner_ids)
			}


			if game_data.selecting {
				clear(&game_data.selected_miner_ids)
				for miner in game_data.miners {
					if aabb_contains(game_data.start_drag, size, miner.position) {

						append(&game_data.selected_miner_ids, miner.id)
					}
				}
				game_data.selecting = false
			}

		}

		if game_data.selecting {

			color := Vector4{0, 0, 0.8, 0.4}
			// border_color:= {0, 0, 0.8, 0.8}
			size: Vector2 = {
				mouse_world_position.x - game_data.start_drag.x,
				mouse_world_position.y - game_data.start_drag.y,
			}
			set_z_layer(.ui)
			draw_rect_xform(transform_2d(game_data.start_drag), size, color)
		}

	}


	half_tile_size: f32 = TILE_SIZE * 0.5
	tiles_x: f32 = math.ceil(pixel_width / TILE_SIZE)
	tiles_y: f32 = math.ceil(pixel_height / TILE_SIZE)


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

	view := get_frame_view()
	view.position -= TILE_SIZE * 2
	view.size += TILE_SIZE * 4


	// @TILES 
	for key in get_chunks_in_view() {
		chunk := game_data.chunks[key]
		for tile in chunk.tiles {

			xform := transform_2d(tile.position)


			if !tile.active {
				color := hex_to_rgb(0x6b4337)
				if (tile.grid_position.x + tile.grid_position.y) % 2 == 0 {
					color = hex_to_rgb(0x684236)
				}
				set_z_layer(.background)
				xform := transform_2d(tile.position)
				draw_quad_center_xform(xform, {TILE_SIZE, TILE_SIZE}, .nil, DEFAULT_UV, color)
				continue
			}

			if !aabb_contains(view.position, view.size, tile.position) || tile.bitmask == 255 {
				continue
			}


			tile_index := get_tile_coords(bitmask_map_value_to_index(tile.bitmask))

			set_z_layer(.background)


			set_z_layer(.game_play)

			draw_quad_center_xform(
				xform,
				{TILE_SIZE, TILE_SIZE},
				.tiles,
				get_frame_uvs(.tiles, tile_index, {16, 16}),
				COLOR_WHITE,
			)


			if tile.grid_position == world_pos_to_tile_pos(mouse_world_position) {
				set_z_layer(.ui)
				draw_quad_center_xform(
					xform,
					{TILE_SIZE, TILE_SIZE},
					.nil,
					DEFAULT_UV,
					{1, 0, 0, 0.3},
				)

				if inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] {
					chunk := &game_data.chunks[chunk.chunk_grid_position]
					chunk.tiles[tile.chunk_grid_position.y * auto_cast CHUNK_GRID_SIZE_X + tile.chunk_grid_position.x].active =
						false

					// performance, we should just update neighbours	
					allocate_tile_bitmasks(chunk.chunk_grid_position)
					log(
						chunk.tiles[tile.chunk_grid_position.y * auto_cast CHUNK_GRID_SIZE_X + tile.chunk_grid_position.x].active,
					)
				}
			}


		}
	}


	{
		// @miners
		for &miner in game_data.miners {
			if len(miner.node_path) > 0 {
				last := len(miner.node_path) - 1

				target := miner.node_path[last]
				target_pos := tile_pos_to_world_pos(target)
				if target_pos - miner.position != 0 &&
				   !almost_equals_v2(target_pos, miner.position, 0.5) {
					dir: Vector2 = linalg.vector_normalize(target_pos - miner.position)
					miner.position += dir * dt * miner.speed
				} else {
					pop(&miner.node_path)
				}
			}


			shadow_xform := transform_2d(miner.position + {0, -3})
			{
				set_z_layer(.shadow)

				draw_quad_center_xform(shadow_xform, {16, 16}, .shadows, DEFAULT_UV, COLOR_WHITE)
			}
			set_z_layer(.game_play)
			xform := transform_2d(miner.position)

			selected := false
			for id in game_data.selected_miner_ids {
				if id == miner.id {
					selected = true
					break
				}
			}

			if selected {
				draw_quad_center_xform(shadow_xform, {16, 16}, .selected)
			}
			draw_quad_center_xform(
				xform,
				{16, 16},
				.miners,
				get_frame_uvs(.miners, {0, 0}, {16, 16}),
				COLOR_WHITE,
			)
		}
	}

	{
		for &popup_txt in game_data.popup_text {
			popup_txt.life_time += dt


			t := popup_txt.life_time / MAX_POPUP_TEXT_LIFE_TIME
			eased_t := ease.cubic_in(t)

			start_value: f32 = 0.0
			end_value: f32 = 10.0
			current_value := start_value + eased_t * (end_value - start_value)
			start_alpha_value: f32 = 1.0
			end_alpha_value: f32 = 0.0
			current_alpha_value :=
				start_alpha_value + eased_t * (end_alpha_value - start_alpha_value)
			color := popup_txt.color
			border_color := COLOR_BLACK
			color.a = current_alpha_value
			border_color.a = current_alpha_value

			if popup_txt.life_time >= MAX_POPUP_TEXT_LIFE_TIME {
				popup_txt.active = false
			}
			draw_text_outlined_center(
				transform_2d(popup_txt.position + {0, current_value}),
				popup_txt.text,
				8 * popup_txt.scale,
				0.5 * popup_txt.scale,
				0.5 * popup_txt.scale,
				color,
				border_color,
			)
		}
	}
	calculate_fps :: proc(dt: f32) -> f32 {
		if dt > 0 {
			return 1.0 / dt
		}
		return 0.0 // Prevent division by zero
	}


	draw_frame.camera_xform = identity()

	mouse_ui_pos := mouse_to_matrix()
	set_z_layer(.ui)
	{
		// Base UI
		set_ui_projection_alignment(.bottom_left)
		ticks_before_updating_fps -= 1
		if ticks_before_updating_fps <= 0 {
			fps = calculate_fps(dt)
			ticks_before_updating_fps = 144
		}
		draw_text_center_center(
			transform_2d({100, 50}),
			fmt.tprintf("FPS %.0f", fps),
			20,
			{1, 1, 1, 1},
		)
		_, height := get_ui_dimensions()
		using game_data
		base_pos_y := 0.9 * height
		padding: f32 = 8
		draw_quad_xform(
			transform_2d({10, base_pos_y}),
			{64, 64},
			.ui,
			get_frame_uvs(.ui, {0, 0}, {16, 16}),
		)
		draw_text_outlined(transform_2d({50, base_pos_y}), fmt.tprintf("$%d", game_data.money), 32)


	}


	if ui_state.hover_id != 0 {
		ui_state.hover_time += app_dt
	}


	{
		scale: f32 = 16
		sapp.show_mouse(false)
		set_ortho_projection(scale)
		mouse_world_position = mouse_to_matrix()
		draw_quad_center_xform(
			transform_2d(mouse_world_position, auto_cast game_data.world_time_elapsed * 0.1),
			{14 / scale, 14 / scale},
			.cursor,
		)
	}

	transition(app_dt)


	{
		// CLEANUP frame
		cleanup_base_entity(&game_data.particles)
		cleanup_base_entity(&game_data.sprite_particles)
		cleanup_base_entity(&game_data.explosions)
		cleanup_base_entity(&game_data.popup_text)
	}


}
fps: f32 = 0
ticks_before_updating_fps := 5


MAIN_MENU_CLEAR_COLOR: sg.Color : {1, 1, 1, 1}


UiID :: u32

HOVER_TIME: f32 = 0.3

UiState :: struct {
	hover_id:        UiID,
	hover_time:      f32,
	click_captured:  bool,
	down_clicked_id: u32,
}

reset_ui_state :: proc() {
	ui_state.click_captured = false
	if ui_state.hover_id == 0 {
		ui_state.hover_time = 0
	}
	ui_state.hover_id = 0

	if inputs.button_just_pressed[sapp.Mousebutton.LEFT] {
		ui_state.down_clicked_id = 0
	}
}

ui_state: UiState

import fstudio "../vendor/fmod/studio"
has_played_song := false
main_menu_song_instance: ^fstudio.EVENTINSTANCE
main_menu :: proc() {
	using game_data
	dt: f32 = get_delta_time()
	switch game_data.ux_anim_state {

	case .fade_in:
		reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
		if reached {
			ux_anim_state = .hold
			hold_end_time = app_now() + 1.5
		}

	case .hold:
		if app_now() >= hold_end_time {
			ux_anim_state = .fade_out
		}

	case .fade_out:

	}
	col := COLOR_WHITE
	border_col := COLOR_BLACK
	col.a = ux_alpha
	border_col.a = ux_alpha

	w, h := get_ui_dimensions()
	if !has_played_song {
		has_played_song = true
		main_menu_song_instance = play_sound("event:/main_menu")
	}

	// clear_color = MAIN_MENU_CLEAR_COLOR
	set_ui_projection_alignment(.center_center)
	mouse_world_position = mouse_to_matrix()
	start_btn_pos: Vector2 = {0, -40}
	button_size: Vector2 = {60, 24} * 4.5
	padding: f32 = 5

	draw_quad_center_xform(
		transform_2d({0, 0}),
		{w, h},
		.background,
		DEFAULT_UV,
		col - {0, 0, 0, 0.7},
	)

	draw_quad_center_xform(transform_2d({0, 180}), {320, 180} * 1.8, .logo, DEFAULT_UV, col)


	if image_button(start_btn_pos, "Start Game", 38, 1, button_size, false, col, border_col) {
		game_data.in_transition_timer = IN_TRANSITION_TIME
	}
	start_btn_pos.y -= button_size.y + padding
	if image_button(start_btn_pos, "Options", 38, 2, button_size, false, col, border_col) {
	}
	start_btn_pos.y -= button_size.y + padding
	if image_button(start_btn_pos, "Exit", 38, 3, button_size, false, col, border_col) {
		log("Exit pressed")
		sapp.quit()
	}


	transition(dt)
}

init_time: time.Time
seconds_since_init :: proc() -> f64 {
	using time
	if init_time._nsec == 0 {
		log("invalid time")
		return 0
	}
	return duration_seconds(since(init_time))
}

app_now :: seconds_since_init


last_frame_time: f64
actual_dt: f64

get_delta_time :: proc() -> f32 {
	return f32(actual_dt)
}

frame :: proc "c" () {
	context = runtime.default_context()
	start_frame_time := seconds_since_init()
	actual_dt = start_frame_time - last_frame_time
	defer last_frame_time = start_frame_time
	if inputs.button_just_pressed[sapp.Keycode.F11] {
		sapp.toggle_fullscreen()
	}


	update_sound()
	switch game_data.app_state {
	case .splash_logo:
		set_ui_projection_alignment(.center_center)
		using game_data
		dt: f32 = get_delta_time()
		switch game_data.ux_anim_state {

		case .fade_in:
			reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
			if reached {
				ux_anim_state = .hold
				hold_end_time = app_now() + 1.5
			}

		case .hold:
			if app_now() >= hold_end_time {
				ux_anim_state = .fade_out
			}

		case .fade_out:
			reached := animate_to_target_f32(&ux_alpha, 0.0, dt, rate = 15.0, good_enough = 0.05)
			if reached {
				ux_state = {}
				app_state = .splash_fmod
			}
		}
		col := COLOR_WHITE
		col.a = ux_alpha

		draw_text_center_center(Matrix4(1), "A game by louidev..", 40, col)
		draw_text_center_center(transform_2d({0, -60}), "Early demo v0.1", 30, col)

	case .splash_fmod:
		set_ui_projection_alignment(.center_center)
		using game_data
		dt: f32 = get_delta_time()
		switch ux_anim_state {
		case .fade_in:
			reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
			if reached {
				ux_anim_state = .hold
				hold_end_time = app_now() + 1.5
			}

		case .hold:
			if app_now() >= hold_end_time {
				ux_anim_state = .fade_out
			}

		case .fade_out:
			reached := animate_to_target_f32(&ux_alpha, 0.0, dt, rate = 15.0, good_enough = 0.05)
			if reached {
				ux_state = {}
				app_state = .main_menu
			}
		}
		col := COLOR_WHITE
		col.a = ux_alpha
		draw_quad_center_xform(Matrix4(1), get_image_size(.fmod_logo), .fmod_logo, DEFAULT_UV, col)
	case .main_menu:
		main_menu()
	case .game:
		game_play()
	}

	reset_ui_state()

	gfx_update()
	inputs_end_frame()
	free_all(context.temp_allocator)

}


cleanup :: proc "c" () {
	context = runtime.default_context()

	// data: [len(game_data.tiles)]byte


	// // write save file
	// os.write_entire_file("test.data", data[:])


	sg.shutdown()
}

base_width: f32 : 1280
base_height: f32 : 720

main :: proc() {

	_main()
}

@(export)
_main :: proc "c" () {
	context = runtime.default_context()
	when ODIN_ARCH == .wasm32 {
		context.allocator = emscripten_allocator()
		context.logger = create_emscripten_logger()
		context.assertion_failure_proc = web_assertion_failure_proc
	} else {
		context.logger = logger()
	}

	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			cleanup_cb = cleanup,
			event_cb = event_cb,
			width = auto_cast base_width,
			height = auto_cast base_height,
			window_title = "My Game",
			icon = {sokol_default = true},
			logger = {func = slog.func},
			html5_use_emsc_set_main_loop = true,
			html5_emsc_set_main_loop_simulate_infinite_loop = true,
			html5_ask_leave_site = RELEASE,
		},
	)

}


IN_TRANSITION_TIME: f32 = 2.0
OUT_TRANSITION_TIME: f32 = 2.0

transition :: proc(dt: f32) {
	set_ui_projection_alignment(.center_center)
	width, height := get_ui_dimensions()

	if game_data.in_transition_timer <= 0 {
		if game_data.out_transition_timer > 0 {
			current_value_out := ease_over_time(
				game_data.out_transition_timer,
				OUT_TRANSITION_TIME,
				.Cubic_Out,
				width + width,
				width,
			)
			game_data.out_transition_timer -= dt
			draw_transition(false, current_value_out)
		}
		return
	}


	game_data.in_transition_timer -= dt

	if game_data.in_transition_timer <= 0 && game_data.app_state == .main_menu {
		game_data.out_transition_timer = OUT_TRANSITION_TIME
		game_data.app_state = .game
		play_sound("event:/game_music")
		stop_sound(main_menu_song_instance)
	}

	current_value_in := ease_over_time(
		game_data.in_transition_timer,
		IN_TRANSITION_TIME,
		.Cubic_In,
		width,
		0,
	)


	draw_transition(true, current_value_in)

}

transition_size: Vector2 : {64, 128}
draw_transition :: proc(inwards: bool, current_value: f32) {

	width, height := get_ui_dimensions()

	amount_to_draw: f32 = height / transition_size.y
	draw_rect_xform(
		transform_2d({-width + current_value - 1, -height * 0.5} - {width * 0.5, 0}),
		{width + 2, height},
		hex_to_rgb(0x25131a),
	)
	for i := 0; i <= auto_cast amount_to_draw; i += 1 {
		if inwards {
			draw_quad_xform(
				transform_2d(
					{
						-width * 0.5 + current_value,
						0.5 * -height + transition_size.y * auto_cast i,
					},
				),
				transition_size,
				.transition,
			)
		} else {
			draw_quad_xform(
				transform_2d(
					{
						-width * 0.5 + current_value - width,
						0.5 * -height + transition_size.y + transition_size.y * auto_cast i,
					},
					math.to_radians_f32(180),
				),
				transition_size,
				.transition,
			)


		}
	}
}
