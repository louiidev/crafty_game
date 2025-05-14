//------------------------------------------------------------------------------
//  texcube/main.odin
//  Texture creation, rendering with texture, packed vertex components.
//------------------------------------------------------------------------------
package main
import imgui "../vendor/odin-imgui"
import sapp "../vendor/sokol/app"
import sg "../vendor/sokol/gfx"
import sglue "../vendor/sokol/glue"
import slog "../vendor/sokol/log"
import "core:os"
import "core:strings"
// import stime "../sokol/time"

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:slice"

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


MINE_BLOCK_TIMER :: 0.3
BUILD_BUILDING_TIMER :: 0.3
STAMINA_TIMER :: 0.1
STAMINA_REST_TIMER :: 0.3


PlayerActionType :: enum {
	nil,
	Destroy,
	Cancel,
}

GameRunState :: struct {
	chunks:                      map[Vector2Int]Chunk,
	particles:                   [dynamic]Particle,
	sprite_particles:            [dynamic]SpriteParticle,
	popup_text:                  [dynamic]PopupText,
	miners:                      [dynamic]Entity,
	world_items:                 [dynamic]WorldItem,
	build_items:                 map[BuildType]BuildItem,
	enemy_spawn_timer:           f32,
	money:                       int,
	ticks:                       u64,
	selected_miner_ids:          [dynamic]u32,
	start_drag:                  Vector2,
	selecting:                   bool,
	start_selecting:             bool,
	selecting_mouse_btn:         sapp.Mousebutton,
	dropbox:                     TargetBlock,
	action_type:                 PlayerActionType,

	// timers
	in_transition_timer:         f32,
	out_transition_timer:        f32,
	knockback_radius_timer:      f32,
	knockback_hold_timer:        f32,
	timer_to_show_upgrade:       f32,
	slowdown_multiplier:         f32,
	shop_in_transition_time:     f32,
	shop_out_transition_time:    f32,
	// debug_pathfinding:        DebugPathfinding,
	current_selected_build_type: BuildType,


	// camera shake
	camera_zoom:                 f32,
	shake_amount:                f32,
	ui_state:                    GameUIState,
	app_state:                   AppState,
	world_time_elapsed:          f32,
	explosions:                  [dynamic]Explosion,
	knockback_position:          Vector2,
	// STATS
	enemies_killed:              u32,
	money_earned:                u32,
	using ux_state:              struct {
		ux_alpha:      f32,
		ux_x_offset:   f32,
		ux_anim_state: enum {
			fade_in,
			hold,
			fade_out,
		},
		hold_end_time: f64,
	},
}

game_data: GameRunState


miner_type :: enum {
	normal,
	bulk,
	square,
	wide,
}

ent_state :: enum {
	idle,
	walking,
	mining,
	collecting,
	sleeping,
}


log :: fmt.println

last_id: u32 = 0
Entity :: struct {
	current_task:               MinerTask,
	using _:                    BaseEntity,
	id:                         u32,
	velocity:                   Vector2,
	speed:                      f32,
	roll_speed:                 f32,
	health:                     f32,
	max_health:                 f32,
	collision_radius:           f32,
	knockback_timer:            f32,
	knockback_direction:        Vector2,
	knockback_velocity:         Vector2,
	attack_timer:               f32,
	stun_timer:                 f32,
	current_animation_timer:    f32,
	current_animation_frame:    int,
	scale_x:                    f32,
	node_path:                  [dynamic]Vector2Int,
	last_face_direction:        Vector2Int,
	type:                       miner_type,
	state:                      ent_state,
	tasks:                      [MinerTask]TaskQueueItem,
	task_timer:                 f32,
	mined_resource:             ResourceType,
	chunk_task_target_position: Vector2Int,
	stamina:                    f32,
	stamina_timer:              f32,
	resting_in_tent:            bool,
}


set_state :: proc(ent: ^Entity, state: ent_state) {
	if ent.state != state {
		ent.state = state
		ent.current_animation_frame = 0
		ent.current_animation_timer = 0
	}
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
	build_menu,
}


Camera :: struct {
	position: Vector2,
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


SPRITE_PIXEL_SIZE :: 16


IDLE_ANIMATION_TIME :: .6
WALK_ANIMATION_TIME :: .3
IDLE_ANIMATION_FRAMES :: 2
WALK_ANIMATION_FRAMES :: 6
ROLLING_ANIMATION_TIME :: 0.08
ROLLING_ANIMATION_FRAMES :: 4

PLAYER_I_FRAME_TIMEOUT_AMOUNT :: 0.5

UPGRADE_TIMER_SHOW_TIME :: 0.9
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


camera: Camera


setup_run :: proc() {
	game_data.app_state = .game
	game_data.camera_zoom = 1.0
}


background_color: Vector4
clear_color: sg.Color

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
	// imgui_init()

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
		ent.speed = rand.float32_range(16, 26)
		ent.position = Vector2{80, 80}
		ent.type = auto_cast rand.int31_max(len(miner_type))
		ent.stamina = 100
		setup_tasks(&ent)
		append(&game_data.miners, ent)
	}
	{
		ent: Entity
		ent.active = true
		ent.id = 2
		ent.position = Vector2{30, 30}
		ent.speed = rand.float32_range(16, 26)
		ent.type = auto_cast rand.int31_max(len(miner_type))
		ent.stamina = 100
		setup_tasks(&ent)

		append(&game_data.miners, ent)
	}

	{
		ent: Entity
		ent.active = true
		ent.id = 3
		ent.speed = rand.float32_range(16, 26)
		ent.position = Vector2{180, 180}
		ent.type = auto_cast rand.int31_max(len(miner_type))
		ent.stamina = 100
		setup_tasks(&ent)

		append(&game_data.miners, ent)
	}
	{
		ent: Entity
		ent.active = true
		ent.id = 4
		ent.position = Vector2{50, 50}
		ent.speed = rand.float32_range(16, 26)
		ent.stamina = 100
		ent.type = auto_cast rand.int31_max(len(miner_type))
		setup_tasks(&ent)

		append(&game_data.miners, ent)
	}


	{
		build: BuildItem

		build.cost = 40
		build.size = {15, 15}
		build.sprite_coords = {0, 0}
		build.unlocked = true
		build.type = .Tent
		game_data.build_items[BuildType.Tent] = build
	}

	{
		build: BuildItem

		build.cost = 40
		build.size = {15, 15}
		build.sprite_coords = {0, 0}
		build.unlocked = true
		build.type = .Drill
		game_data.build_items[BuildType.Drill] = build
	}

	{
		build: BuildItem

		build.cost = 10
		build.size = {15, 15}
		build.sprite_coords = {0, 0}
		build.unlocked = true
		build.type = .ConveyorBelt
		build.belt_direction = .EAST
		game_data.build_items[BuildType.ConveyorBelt] = build
	}

	{
		build: BuildItem
		build.cost = 10
		build.size = {16, 16}
		build.sprite_coords = {0, 0}
		build.unlocked = true
		build.type = .Furnace
		game_data.build_items[BuildType.Furnace] = build

	}


	game_data.money = 100000
	// data: [len(game_data.tiles)]byte


	// write save file
	data, ok := os.read_entire_file("test.data", context.temp_allocator)


	create_chunk({0, 0})
	new_chunk: ^Chunk = &game_data.chunks[{0, 0}]

	{
		collection_box: Building
		collection_box.working = true
		collection_box.active = true
		collection_box.build_progress = 100
		collection_box.chunk_key = {0, 0}
		collection_box.chunk_tile_position = {10, 10}
		collection_box.position = {10, 10} * {16, 16}
		collection_box.size = {16, 16}
		collection_box.type = .CollectionBox
		new_chunk.tiles[10 * CHUNK_GRID_SIZE_X + 10].occupied_by = .Building
		collection_box.sprite_coords = {0, 0}
		append(&new_chunk.buildings, collection_box)
	}


	game_data.dropbox = TargetBlock {
		chunk_key                = {0, 0},
		tile_chunk_grid_position = {10, 10},
		tile_world_grid_position = {10, 10},
	}
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

			if x == auto_cast game_data.dropbox.tile_world_grid_position.x &&
			   y == auto_cast game_data.dropbox.tile_world_grid_position.y {
				active = false
			}

			new_chunk.tiles[y * CHUNK_GRID_SIZE_X + x].occupied_by = active ? .Dirt : .nil

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

	stamina_modifier: f32 = ent.state == .idle ? 0.15 : 1.0


	ent.attack_timer = math.max(0.0, ent.attack_timer - dt)
	ent.knockback_timer = math.max(0.0, ent.knockback_timer - dt)
	ent.stun_timer = math.max(0.0, ent.stun_timer - dt)
	ent.task_timer = math.max(0.0, ent.task_timer - dt)
	ent.stamina_timer = math.max(0.0, ent.stamina_timer - dt * stamina_modifier)
	ent.current_animation_timer += dt
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

	if inputs.button_just_released[sapp.Keycode.ESCAPE] && game_data.ui_state != .build_menu {
		consume_key_just_released(.ESCAPE)
		if game_data.ui_state == .pause_menu || game_data.ui_state == .upgrade_menu {
			game_data.ui_state = nil
		} else if game_data.ui_state == nil {
			game_data.ui_state = .pause_menu
		}
	}


	game_play_paused :=
		game_data.ui_state != nil && game_data.ui_state != .build_menu ||
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


	upgrade_menu_width :: 800
	upgrade_menu_height :: 500
	row_margin :: 50
	upgrade_row_height :: 100
	upgrade_row_height_margin :: 25


	build_menu_padding :: 30
	build_menu_button_size :: 32 * 3
	build_menu_width :: (build_menu_button_size * 2) + (build_menu_padding * 3)
	build_menu_height :: 500
	ui_border_width :: 10

	upgrade_menu_row :: proc(description: string, position: Vector2, price: int) -> bool {
		xform := transform_2d(position)
		draw_rect_bordered_center_xform(
			xform,
			{upgrade_menu_width - row_margin * 2, upgrade_row_height},
			10,
			COLOR_WHITE,
			COLOR_BLACK,
		)

		draw_text_center_center(xform, description, 32, COLOR_BLACK)


		clicked := bordered_button(
			position + {300, 0},
			{200, 70},
			fmt.tprint(price),
			32,
			3,
			price > game_data.money,
		)


		return clicked
	}


	// @OVERWORLD UI
	// we do it here so we can capture clicks
	{
		set_z_layer(.ui)
		set_ui_projection_alignment(.bottom_left)
		w, h := get_ui_dimensions()

		if bordered_button(
			{130, 50},
			{150, 50},
			"Destroy",
			28,
			2,
			game_data.ui_state == .upgrade_menu || game_data.ui_state == .pause_menu,
			game_data.action_type == .Destroy,
		) {
			game_data.action_type = game_data.action_type == .Destroy ? .nil : .Destroy
		}

		if bordered_button(
			{300, 50},
			{150, 50},
			"Cancel",
			28,
			3,
			game_data.ui_state == .upgrade_menu || game_data.ui_state == .pause_menu,
			game_data.action_type == .Cancel,
		) {
			game_data.action_type = game_data.action_type == .Cancel ? .nil : .Cancel

		}


		if bordered_button(
			{w - 130, 50},
			{150, 50},
			"UPGRADES",
			28,
			4,
			game_data.ui_state == .upgrade_menu || game_data.ui_state == .pause_menu,
		) {
			game_data.ui_state = .upgrade_menu
			game_data.action_type = .nil

		}

		if bordered_button(
			{w - 130 - 170, 50},
			{150, 50},
			"BUILD",
			28,
			5,
			game_data.ui_state == .pause_menu,
			game_data.ui_state == .build_menu,
		) {
			game_data.ui_state = game_data.ui_state == .build_menu ? .nil : .build_menu
			game_data.ux_state.ux_x_offset = -450
			game_data.action_type = .nil
		}


		#partial switch (game_data.ui_state) {
		case .upgrade_menu:
			{

				set_ui_projection_alignment(.center_center)

				draw_rect_bordered_center_xform(
					transform_2d({0, 0}),
					{upgrade_menu_width, upgrade_menu_height},
					ui_border_width,
					COLOR_WHITE,
					COLOR_BLACK,
				)


				if upgrade_menu_row(
					"Stamina",
					{0, upgrade_row_height + upgrade_row_height_margin},
					100,
				) {

				}

				if upgrade_menu_row("Mining power", {0, 0}, 100) {

				}

				if upgrade_menu_row(
					"Mining luck",
					{0, -(upgrade_row_height + upgrade_row_height_margin)},
					100,
				) {

				}


				if bordered_button({0, -300}, {200, 70}, "X", 32, 3, false) {
					game_data.ui_state = .nil
				}

			}


		case .build_menu:
			{
				reached_end := false
				set_ui_projection_alignment(.bottom_left)
				using game_data
				switch ux_anim_state {

				case .fade_in:
					reached := animate_to_target_f32(
						&ux_x_offset,
						build_menu_width * 0.5 + ui_border_width,
						app_dt,
						rate = 5.0,
						good_enough = 0.5,
					)
					if reached {
						game_data.ux_anim_state = .hold
					}

				case .hold:

				case .fade_out:
					reached_end = animate_to_target_f32(
						&ux_x_offset,
						-build_menu_width * 0.5 - 100,
						app_dt,
						rate = 10.0,
						good_enough = 1,
					)

				}

				position := Vector2{ux_x_offset, get_ui_height() * 0.5}
				xform := transform_2d(position)
				draw_rect_bordered_center_xform(
					xform,
					{build_menu_width, build_menu_height},
					ui_border_width,
					{1, 1, 1, 0.3},
					COLOR_BLACK,
				)

				x := 0
				y := 0

				position = {ux_x_offset, position.y}
				// @BUILD-ITEMS
				for type in game_data.build_items {
					item := game_data.build_items[type]
					if !item.unlocked {
						continue
					}
					defer x += 1
					if x % 2 == 0 {
						defer y -= 1
						defer x = 0
					}


					placement_pos :=
						(position - build_menu_width * 0.5) +
						build_menu_button_size * 0.5 +
						build_menu_padding +
						({
									build_menu_button_size + build_menu_padding,
									build_menu_button_size + build_menu_padding,
								} *
								{auto_cast x, auto_cast y})
					xform = transform_2d(placement_pos)
					if bordered_button(
						placement_pos,
						{build_menu_button_size, build_menu_button_size},
						"",
						32,
						auto_cast item.type + 10,
						item.cost > game_data.money,
					) {
						game_data.current_selected_build_type = item.type
					}
					sprite := get_build_item_sprite(type)
					draw_quad_center_xform(
						xform,
						{32 * 2, 32 * 2},
						sprite,
						get_frame_uvs(sprite, item.sprite_coords, {16, 16}),
					)
				}
				if inputs.button_just_released[sapp.Keycode.ESCAPE] {
					consume_key_just_released(.ESCAPE)
					if game_data.current_selected_build_type != .nil {
						game_data.current_selected_build_type = .nil
					} else {
						game_data.ux_anim_state = .fade_out
					}
				}

				if bordered_button(position - {0, 300}, {200, 70}, "X", 32, 3, false) {
					game_data.current_selected_build_type = .nil
					game_data.ux_anim_state = .fade_out
				}

				if reached_end {
					game_data.ui_state = .nil
					game_data.ux_anim_state = .fade_in
					game_data.ux_state = {}
				}
			}


		}


		set_z_layer(.background)
	}


	using sapp.Keycode
	x := f32(int(inputs.button_down[D]) - int(inputs.button_down[A]))
	y := f32(int(inputs.button_down[W]) - int(inputs.button_down[S]))

	camera.position += {x, y} * dt * (130 / game_data.camera_zoom)

	draw_frame.camera_xform = translate_mat4(Vector3{-camera.position.x, -camera.position.y, 0})
	set_ortho_projection(game_data.camera_zoom)

	mouse_world_position = mouse_to_matrix()

	{
		//@placing building

		if game_data.current_selected_build_type != .nil {
			item := &game_data.build_items[game_data.current_selected_build_type]
			tile_position := world_pos_to_tile_pos(mouse_world_position)
			position := tile_pos_to_world_pos(tile_position)
			chunk_key := get_chunk_key(position)
			cant_place := is_tile_occupied(chunk_key, tile_position.x, tile_position.y)
			log(cant_place, chunk_key, tile_position.x, tile_position.y)
			chunk := &game_data.chunks[chunk_key]


			if inputs.button_just_released[sapp.Keycode.R] {
				belt_direction_len := len(ConveyorDirections)
				if int(item.belt_direction) >= 3 {
					item.belt_direction = auto_cast 0
				} else {
					item.belt_direction = auto_cast (int(item.belt_direction) + 1)
				}
			}

			set_z_layer(.ui)
			if game_data.current_selected_build_type == .ConveyorBelt {
				render_conveyor_belt(
					item.belt_direction,
					position,
					cant_place ? {1, 0.3, 0.3, 0.5} : {1, 1, 1, 0.3},
				)
			} else {
				sprite := get_build_item_sprite(game_data.current_selected_build_type)

				if item.type == .Furnace || item.type == .Drill {
					draw_quad_center_xform(
						transform_2d(
							position + get_conveyor_direction(item.belt_direction) * 16,
							math.to_radians(f32(item.belt_direction) * -90),
						),
						{16, 16},
						.arrow,
						DEFAULT_UV,
						cant_place ? {1, 0.3, 0.3, 0.5} : {1, 1, 1, 0.3},
					)
				}

				draw_quad_center_xform(
					transform_2d(position),
					{16, 16},
					sprite,
					get_frame_uvs(sprite, item.sprite_coords, {16, 16}),
					cant_place ? {1, 0.3, 0.3, 0.5} : {1, 1, 1, 0.3},
				)
			}

			if !cant_place && inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] {
				consume_mouse_just_pressed(.LEFT)


				b: Building
				b.active = true
				b.working = true
				b.last_world_item_output_index = -1
				b.build_progress = 0
				b.chunk_key = chunk_key
				b.position = position
				b.size = item.size
				b.type = item.type
				b.belt_direction = item.belt_direction
				b.world_position = tile_position
				b.sprite_coords = item.sprite_coords
				b.chunk_tile_position = get_chunk_local_tile_position(b.position)
				b.output_direction = auto_cast item.belt_direction
				building_index := len(chunk.buildings)
				chunk.tiles[b.chunk_tile_position.y * auto_cast CHUNK_GRID_SIZE_X + b.chunk_tile_position.x].occupied_by =
				.Building
				append(&chunk.buildings, b)

				game_data.money -= item.cost
				game_data.current_selected_build_type = .nil
				if len(game_data.selected_miner_ids) > 0 {

					for &miner in game_data.miners {
						for selected_id in game_data.selected_miner_ids {
							if selected_id == miner.id {
								add_new_building_task(&b, &miner, building_index)
								break
							}

						}
					}
				} else {
					for &miner in game_data.miners {

						miner_grid_position := world_pos_to_tile_pos(miner.position)

						if manhattan_dist(miner_grid_position, b.world_position) > 30 {
							continue
						}

						add_new_building_task(&b, &miner, building_index)
					}

				}
			}
		}
	}


	// @gameplay inputs 
	if !game_play_paused {

		if inputs.mouse_scroll_delta != {} {
			game_data.camera_zoom = math.clamp(
				game_data.camera_zoom + inputs.mouse_scroll_delta.y * dt * 16,
				0.5,
				2.5,
			)
		}


		using sapp

		just_released_btn := false
		size: Vector2

		if inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] && !game_data.selecting {
			consume_mouse_just_pressed(.LEFT)
			game_data.start_selecting = true

		} else if inputs.mouse_down[sapp.Mousebutton.LEFT] &&
		   !game_data.selecting &&
		   game_data.start_selecting {
			consume_mouse_just_pressed(.LEFT)
			game_data.selecting = true
			game_data.start_drag = mouse_world_position
			game_data.start_selecting = false

		} else if inputs.mouse_just_released[sapp.Mousebutton.LEFT] {
			consume_mouse_just_released(.LEFT)
			size = {
				mouse_world_position.x - game_data.start_drag.x,
				mouse_world_position.y - game_data.start_drag.y,
			}

			just_released_btn = true

		}


		if just_released_btn &&
		   len(game_data.selected_miner_ids) > 0 &&
		   linalg.length(size) <= 10 &&
		   game_data.start_selecting {

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

		if just_released_btn {
			if game_data.action_type == .nil && game_data.selecting {
				clear(&game_data.selected_miner_ids)
				for miner in game_data.miners {
					if aabb_contains(game_data.start_drag, size, miner.position) {
						append(&game_data.selected_miner_ids, miner.id)
					}
				}
			}

			if game_data.action_type == .Destroy && game_data.selecting {
				update_miner_destroy_block_task(game_data.start_drag, size)
			}

			if game_data.action_type == .Cancel && game_data.selecting {
				update_miner_cancel_destroy_block_task(game_data.start_drag, size)
			}

			if just_released_btn && game_data.selecting {
				game_data.selecting = false
			}
		}


		if game_data.selecting {
			color :=
				game_data.selecting_mouse_btn == .LEFT ? Vector4{0, 0, 0.8, 0.4} : Vector4{0.8, 0, 0.0, 0.4}
			// border_color:= {0, 0, 0.8, 0.8}
			size: Vector2 = {
				mouse_world_position.x - game_data.start_drag.x,
				mouse_world_position.y - game_data.start_drag.y,
			}
			set_z_layer(.ui)
			draw_rect_xform(transform_2d(game_data.start_drag), size, color)
		}


		if inputs.mouse_just_released[sapp.Mousebutton.LEFT] {
			consume_mouse_just_released(.LEFT)
			game_data.start_selecting = false
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

	four_neighbour_directions: [4]Vector2Int = {{1, 0}, {0, -1}, {0, 1}, {-1, 0}}

	view := get_frame_view()
	view.position -= TILE_SIZE * 2
	view.size += TILE_SIZE * 4


	// @TILES 
	for key in get_chunks_in_view() {
		chunk := game_data.chunks[key]
		for tile in chunk.tiles {

			xform := transform_2d(tile.position)
			if tile.queued_for_destruction {
				set_z_layer(.ui)
				draw_quad_center_xform(
					xform,
					{TILE_SIZE, TILE_SIZE},
					.destruction_block,
					DEFAULT_UV,
					{1, 1, 1, 0.4},
				)
			}

			if tile.occupied_by != .Dirt {
				color := hex_to_rgb(0x6b4337)
				if (tile.grid_position.x + tile.grid_position.y) % 2 == 0 {
					color = hex_to_rgb(0x684236)
				}
				set_z_layer(.background)
				xform := transform_2d(tile.position)
				draw_quad_center_xform(xform, {TILE_SIZE, TILE_SIZE}, .nil, DEFAULT_UV, color)

				deposit :=
					chunk.deposits[tile.chunk_grid_position.y * auto_cast CHUNK_GRID_SIZE_X + tile.chunk_grid_position.x]
				if deposit.active {
					sprite_x: int = auto_cast deposit.type
					sprite_y := deposit.variant

					xform := transform_2d(deposit.position)
					draw_quad_center_xform(
						xform,
						{16, 16},
						.deposit,
						get_frame_uvs(.deposit, {sprite_x, sprite_y}, {16, 16}),
					)
				}

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

		}

		set_z_layer(.background)

		// @transport belt
		for conveyor_belt in chunk.conveyor_belts {
			render_conveyor_belt(
				conveyor_belt.visual_direction,
				conveyor_belt.position,
				COLOR_WHITE,
			)
		}

		// @buildings
		for &building in chunk.buildings {

			built := building.build_progress >= 100
			if built {
				#partial switch (building.type) {
				case .Drill:
					DRILL_ANIMATION_TIME :: 0.2
					building.current_animation_time += dt
					if building.current_animation_frame == 0 {
						if !check_deposit_active(
							chunk.chunk_grid_position,
							building.chunk_tile_position,
						) {

							building.working = false
						}
					}

					if building.last_world_item_output_index != -1 {
						item := game_data.world_items[building.last_world_item_output_index]
						if item.active &&
						   manhattan_dist(
							   world_pos_to_tile_pos(item.position),
							   building.world_position,
						   ) <=
							   1 {
							building.working = false
						} else {
							building.working = true
							building.last_world_item_output_index = -1
						}
					}


					if building.working &&
					   building.current_animation_time >= DRILL_ANIMATION_TIME {
						building.current_animation_time = 0
						building.current_animation_frame += 1
						if building.current_animation_frame > 19 {
							building.current_animation_frame = 0
							is_active_deposit, resource_type := mine_deposit(
								chunk.chunk_grid_position,
								building.chunk_tile_position,
							)

							if !is_active_deposit {
								building.working = false
							}
							mined_resource: WorldItem
							mined_resource.active = true
							mined_resource.type = .MinedResource
							mined_resource.mined_resource_type = resource_type
							mined_resource.position =
								building.position +
								cardinal_direction_to_vector(building.output_direction) * 10
							append(&game_data.world_items, mined_resource)
							building.last_world_item_output_index = len(game_data.world_items) - 1
						}
					}
				case .Furnace:
					FURNACE_ANIMATION_TIME :: 0.2
					building.current_animation_time += dt
					if building.current_animation_frame == 0 {
						if building.furnace_smelt_count <= 0 {
							building.working = false
						}
					}
					if building.working &&
					   building.current_animation_time >= FURNACE_ANIMATION_TIME {
						building.current_animation_time = 0
						building.current_animation_frame += 1
						if building.current_animation_frame > 7 {
							building.current_animation_frame = 0

							smelt_deposit(&building)

							mined_resource: WorldItem
							mined_resource.active = true
							mined_resource.type = .SmeltedResource
							mined_resource.mined_resource_type = building.furnace_smelt_type
							mined_resource.position =
								building.position +
								cardinal_direction_to_vector(building.output_direction) * 16
							append(&game_data.world_items, mined_resource)

							if building.furnace_smelt_count <= 0 {
								building.working = false
							}

						}
					}
				}


			}

			if !building.invisible {
				if building.type == .ConveyorBelt {
					render_conveyor_belt(
						building.belt_direction,
						building.position,
						building.build_progress < 100 ? {0.3, 0.3, 1.0, 0.5} : COLOR_WHITE,
						false,
					)
				} else {
					sprite := get_build_item_sprite(building.type)
					draw_quad_center_xform(
						transform_2d(building.position),
						{16, 16},
						sprite,
						get_frame_uvs(sprite, {building.current_animation_frame, 0}, {16, 16}),
						building.build_progress < 100 ? {0.3, 0.3, 1.0, 0.5} : COLOR_WHITE,
					)
					if !building.working {
						draw_quad_center_xform(
							transform_2d(building.position + {7, 7}),
							{8, 8},
							.circle,
							get_frame_uvs(.circle, {0, 0}, {64, 64}),
							COLOR_WHITE,
						)
						draw_quad_center_xform(
							transform_2d(building.position + {7, 7}),
							{6, 6},
							.circle,
							get_frame_uvs(.circle, {0, 0}, {64, 64}),
							COLOR_RED,
						)
					}

				}


			}


			if building.build_progress < 100 {
				draw_rect_bordered_xform(
					transform_2d(building.position + {-16, 16}),
					{32, 2},
					1.0,
					COLOR_WHITE,
					COLOR_BLACK,
				)

				draw_rect_xform(
					transform_2d(building.position + {-16, 16}),
					{32 * building.build_progress * 0.01, 2},
					COLOR_GREEN,
				)
			}
		}

	}


	{
		//@world items

		viewbox := get_frame_view()
		for &world_item in game_data.world_items {
			tile_pos := world_pos_to_tile_pos(world_item.position)
			draw_rect_center_xform(
				transform_2d(tile_pos_to_world_pos(tile_pos)),
				{16, 16},
				{1, 0, 0, 0.3},
			)
			if is_point_in_viewbox(viewbox, world_item.position) {

				switch (world_item.type) {
				case .MinedResource:
					draw_quad_center_xform(
						transform_2d(world_item.position),
						{16, 16},
						.ore,
						get_frame_uvs(
							.ore,
							{auto_cast world_item.mined_resource_type, 0},
							{16, 16},
						),
					)
				case .SmeltedResource:
					draw_quad_center_xform(
						transform_2d(world_item.position),
						{16, 16},
						.ore,
						get_frame_uvs(
							.ore,
							{auto_cast world_item.mined_resource_type, 0},
							{16, 16},
						),
					)
				}
			}

			chunk_key := get_chunk_key(world_item.position)


			for belt in game_data.chunks[chunk_key].conveyor_belts {
				if belt.world_tile_position == tile_pos {
					conveyor_direction := get_conveyor_direction(belt.initial_direction)
					direction: Vector2 = conveyor_direction * get_conveyor_speed(belt.type)

					tile_pos := world_pos_to_tile_pos(world_item.position)
					blocked := false
					for other_world_item in game_data.world_items {
						other_tile_pos := world_pos_to_tile_pos(other_world_item.position)
						if manhattan_dist(tile_pos, other_tile_pos) == 1 {
							if tile_pos + {int(conveyor_direction.x), int(conveyor_direction.y)} ==
							   other_tile_pos {
								blocked = true
								break
							}
						}
					}
					if !blocked {
						world_item.position += direction * dt
					}


					break
				}
			}


		}
	}

	{
		// @miners
		for &miner in game_data.miners {

			update_entity_timers(&miner, dt)

			if miner.current_task == .nil {
				// find next best task if one
				for task in MinerTask {
					if task == .build_building {

						if len(miner.tasks[task].block_targets) > 0 &&
						   miner.tasks[task].current_target_index > -1 {
							miner.current_task = task
							miner.tasks[task].active = true
							if len(miner.node_path) == 0 {
								generate_path_for_building(&miner)
							}
							break

						}
					} else if miner.tasks[task].active &&
					   len(miner.tasks[task].block_targets) > 0 {
						miner.current_task = task
						break
					}
				}
			}

			// if task != .heading_to_rest &&
			//    task != .return_item &&
			//    miner.stamina_timer <= 0 &&
			//    miner.state != .sleeping {
			// 	// miner.stamina -= 1
			// 	miner.stamina_timer = STAMINA_TIMER
			// 	if miner.stamina <= 0 {
			// 		miner.stamina = 0

			// 		chunk_key := get_chunk_key(miner.position)
			// 		ok, building := find_closest_building_type_in_chunk(
			// 			chunk_key,
			// 			world_pos_to_tile_pos(miner.position),
			// 			.Tent,
			// 		)

			// 		if ok {
			// 			index := len(miner.task_queue)
			// 			add_new_task(.heading_to_rest, &miner)
			// 			miner.current_task_target_position = building.world_position
			// 		} else {
			// 			miner.state = .sleeping
			// 		}
			// 	}
			// }


			{
				// @DEBUG @REMOVE @TESTING
				if miner.mined_resource != .nil && miner.current_task != .return_item {
					log(miner.mined_resource, miner.current_task == .return_item)

					assert(
						false,
						fmt.tprintfln(
							"ERROR, allocated task while holding resource ",
							miner.mined_resource,
						),
					)
				}

			}


			switch miner.current_task {
			case .nil:
				set_state(&miner, .idle)
				if len(miner.node_path) > 0 {
					clear(&miner.node_path)
					log("MISSING NODE PATH CLEANUP")
				}
			case .heading_to_rest:
				miner_block_pos := world_pos_to_tile_pos(miner.position)
				if manhattan_dist(
					   miner.tasks[.heading_to_rest].block_targets[0].tile_world_grid_position,
					   miner_block_pos,
				   ) ==
				   0 {
					miner.resting_in_tent = true
					remove_current_task(&miner)
				}
			case .build_building:
				{
					miner_block_pos := world_pos_to_tile_pos(miner.position)
					task_index := miner.tasks[.build_building].current_target_index

					if task_index > -1 &&
					   miner.tasks[.build_building].active &&
					   len(miner.tasks[.build_building].block_targets) > 0 {

						if manhattan_dist(
							   miner.tasks[.build_building].block_targets[task_index].miner_placement_world_position,
							   miner_block_pos,
						   ) ==
						   0 {
							set_state(&miner, .mining)
							if miner.task_timer <= 0 {
								target := miner.tasks[.build_building].block_targets[task_index]
								miner.task_timer = BUILD_BUILDING_TIMER
								chunk_key := target.chunk_key
								chunk := &game_data.chunks[chunk_key]
								building: ^Building = &chunk.buildings[target.building_index]
								building.build_progress += 10

								if building.build_progress >= 100 && !building.built {
									building.built = true
									building_finished(building.world_position, 40)
									if building.type == .ConveyorBelt {
										belt: ConveyorBelt
										belt.position = building.position
										belt.type = .SLOW
										belt.initial_direction = building.belt_direction
										belt.chunk_position = building.chunk_tile_position
										belt.world_tile_position = building.world_position
										direction := get_conveyor_direction(belt.initial_direction)


										has_neighbour := false
										neighbour_conveyor_direction: ConveyorDirections
										belt_pointer: ^ConveyorBelt
										for neighbour_direction in four_neighbour_directions {

											position :=
												neighbour_direction + building.world_position
											for &belt in chunk.conveyor_belts {
												belt_pos := world_pos_to_tile_pos(belt.position)
												if belt_pos == position {
													// check conflict e.g west cant be transfer into east
													if -direction !=
													   get_conveyor_direction(
														   belt.initial_direction,
													   ) {
														has_neighbour = true
														neighbour_conveyor_direction =
															belt.initial_direction
														belt_pointer = &belt
														break
													}

												}
											}
										}

										belt.visual_direction = building.belt_direction
										if has_neighbour &&
										   neighbour_conveyor_direction != belt.initial_direction {
											// create corner join

											// belt.visual_direction = building.belt_direction


											if belt.initial_direction == .EAST &&
											   belt_pointer.initial_direction == .SOUTH {
												if belt.position.x == belt_pointer.position.x {
													belt.visual_direction = .SE
												} else if belt.position.x >
													   belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {

													belt_pointer.visual_direction = .SE
												}
											}

											if belt.initial_direction == .EAST &&
											   belt_pointer.initial_direction == .NORTH {
												if belt.position.x == belt_pointer.position.x {
													belt.visual_direction = .NE
												} else if belt.position.x >
													   belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .NE
												}
											}

											if belt.initial_direction == .WEST &&
											   belt_pointer.initial_direction == .SOUTH {
												if belt.position.x == belt_pointer.position.x {
													belt.visual_direction = .SW
												} else if belt.position.x <
													   belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .SW
												}
											}

											if belt.initial_direction == .WEST &&
											   belt_pointer.initial_direction == .NORTH {
												if belt.position.x == belt_pointer.position.x {
													belt.visual_direction = .NW
												} else if belt.position.x <
													   belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .NW
												}
											}


											if belt.initial_direction == .NORTH &&
											   belt_pointer.initial_direction == .EAST {
												if belt.position.x == belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .EN
												} else if belt.position.x >
												   belt_pointer.position.x {
													belt.visual_direction = .EN
												}
											}

											if belt.initial_direction == .NORTH &&
											   belt_pointer.initial_direction == .WEST {
												if belt.position.x == belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .WN
												} else if belt.position.x <
												   belt_pointer.position.x {
													belt.visual_direction = .WN
												}
											}

											if belt.initial_direction == .SOUTH &&
											   belt_pointer.initial_direction == .EAST {
												if belt.position.x == belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .ES
												} else if belt.position.x >
												   belt_pointer.position.x {
													belt.visual_direction = .ES
												}
											}

											if belt.initial_direction == .SOUTH &&
											   belt_pointer.initial_direction == .WEST {
												if belt.position.x == belt_pointer.position.x &&
												   belt.initial_direction ==
													   belt.visual_direction {
													belt_pointer.visual_direction = .WS
												} else if belt.position.x <
												   belt_pointer.position.x {
													belt.visual_direction = .WS
												}
											}
										}

										append(&chunk.conveyor_belts, belt)
										building.invisible = true
									}
								}
							}
						}

					}
				}
			case .return_item:
				{
					miner_block_pos := world_pos_to_tile_pos(miner.position)
					if len(miner.tasks[.build_building].block_targets) > 0 &&
					   manhattan_dist(
						   miner.tasks[.build_building].block_targets[0].tile_world_grid_position,
						   miner_block_pos,
					   ) ==
						   0 {
						remove_current_task(&miner)


						switch (miner.mined_resource) {
						case .nil:
						case .Copper:
						case .Iron:
							game_data.money += 3
						case .Gold:
							game_data.money += 5
						case .Diamond:
							game_data.money += 10
						}

						miner.mined_resource = .nil


					}
				}
			case .destroy_building:
				{
					task := &miner.tasks[.destroy_blocks]
					block_targets := &task.block_targets

					if task.current_target_index == -1 && len(block_targets) > 0 {
						// find a block to destroy
						closest_dist: f32 = math.inf_f32(1)
						closest_block: Vector2Int = {}
						miner_block_pos := world_pos_to_tile_pos(miner.position)

						for i := 0; i < len(block_targets); i += 1 {
							block := block_targets[i]
							dist := manhattan_dist(block.tile_world_grid_position, miner_block_pos)
							if dist < closest_dist {
								ok, pos := get_closest_free_block_next_to_target(
									block.tile_world_grid_position,
									block.tile_chunk_grid_position,
									block.chunk_key,
									miner_block_pos,
								)
								if ok {
									task.block_targets[i].miner_placement_world_position = pos
									task.current_target_index = i
									closest_dist = dist
									closest_block = block.tile_world_grid_position
								}
							}
						}
						if task.current_target_index == -1 {
							remove_current_task(&miner)
						}
						// assert(task.current_target_index > -1)
						clear(&miner.node_path)
					}


					if len(block_targets) > 0 &&
					   len(miner.node_path) == 0 &&
					   manhattan_dist(
						   task.block_targets[task.current_target_index].miner_placement_world_position,
						   world_pos_to_tile_pos(miner.position),
					   ) >
						   0 {
						path := find_path(
							world_pos_to_tile_pos(miner.position),
							task.block_targets[task.current_target_index].miner_placement_world_position,
						)
						if path != nil {
							miner.node_path = slice.clone_to_dynamic(path[:])
						} else {
							log("no path")
						}
						delete(path)
					}


					if len(block_targets) > 0 &&
					   manhattan_dist(
						   task.block_targets[task.current_target_index].miner_placement_world_position,
						   world_pos_to_tile_pos(miner.position),
					   ) ==
						   0 {
						if miner.state != .mining {
							miner.task_timer = MINE_BLOCK_TIMER
						}

						set_state(&miner, .mining)

						block_target := task.block_targets[task.current_target_index]
						target_pos := tile_pos_to_world_pos(block_target.tile_world_grid_position)

						dir: Vector2Int =
							block_target.tile_world_grid_position -
							world_pos_to_tile_pos(miner.position)
						miner.last_face_direction = dir
					}

					if task.current_target_index == -1 && len(task.block_targets) == 0 {
						remove_current_task(&miner)
						set_state(&miner, .idle)
					}
				}
			case .destroy_blocks:
				{
					task := &miner.tasks[.destroy_blocks]
					block_targets := &task.block_targets

					if task.current_target_index == -1 && len(block_targets) > 0 {
						// find a block to destroy
						closest_dist: f32 = math.inf_f32(1)
						closest_block: Vector2Int = {}
						miner_block_pos := world_pos_to_tile_pos(miner.position)

						for i := 0; i < len(block_targets); i += 1 {
							block := block_targets[i]
							dist := manhattan_dist(block.tile_world_grid_position, miner_block_pos)
							if dist < closest_dist {
								ok, pos := get_closest_free_block_next_to_target(
									block.tile_world_grid_position,
									block.tile_chunk_grid_position,
									block.chunk_key,
									miner_block_pos,
								)
								if ok {
									task.block_targets[i].miner_placement_world_position = pos
									task.current_target_index = i
									closest_dist = dist
									closest_block = block.tile_world_grid_position
								}
							}
						}
						if task.current_target_index == -1 {
							remove_current_task(&miner)
						}
						// assert(task.current_target_index > -1)
						clear(&miner.node_path)
					}


					if len(block_targets) > 0 &&
					   len(miner.node_path) == 0 &&
					   manhattan_dist(
						   task.block_targets[task.current_target_index].miner_placement_world_position,
						   world_pos_to_tile_pos(miner.position),
					   ) >
						   0 {
						path := find_path(
							world_pos_to_tile_pos(miner.position),
							task.block_targets[task.current_target_index].miner_placement_world_position,
						)
						if path != nil {
							miner.node_path = slice.clone_to_dynamic(path[:])
						} else {
							log("no path")
						}
						delete(path)
					}


					if len(block_targets) > 0 &&
					   manhattan_dist(
						   task.block_targets[task.current_target_index].miner_placement_world_position,
						   world_pos_to_tile_pos(miner.position),
					   ) ==
						   0 {
						if miner.state != .mining {
							miner.task_timer = MINE_BLOCK_TIMER
						}

						set_state(&miner, .mining)

						block_target := task.block_targets[task.current_target_index]
						target_pos := tile_pos_to_world_pos(block_target.tile_world_grid_position)

						dir: Vector2Int =
							block_target.tile_world_grid_position -
							world_pos_to_tile_pos(miner.position)
						miner.last_face_direction = dir
					}

					if task.current_target_index == -1 && len(task.block_targets) == 0 {
						remove_current_task(&miner)
						set_state(&miner, .idle)
					}


				}
			}


			if len(miner.node_path) > 0 {
				last := len(miner.node_path) - 1
				target := miner.node_path[last]
				target_pos := tile_pos_to_world_pos(target)
				if target_pos - miner.position != 0 &&
				   !almost_equals_v2(target_pos, miner.position, 0.5) {
					dir: Vector2 = linalg.vector_normalize(target_pos - miner.position)
					miner.last_face_direction.x = auto_cast math.round(dir.x)
					miner.position += dir * dt * miner.speed
					previous_state := miner.state

					set_walking_frame := false
					if miner.state != .walking {
						set_walking_frame = true
					}
					if miner.mined_resource != .nil {
						set_state(&miner, .collecting)
					} else {
						set_state(&miner, .walking)
					}

					if previous_state != .walking && miner.state == .walking {
						miner.current_animation_frame = 2
					}

					if previous_state != .collecting && miner.state == .collecting {
						miner.current_animation_frame = 15
					}
				} else {
					pop(&miner.node_path)
				}
			}

			// else if miner.current_block_target == nil {
			// 	set_state(&miner, .idle)
			// }

			ent_animation_frame_x := 0
			rotation: f32 = 0
			animation_frame_offset := 0
			switch miner.state {
			case .idle:
				if miner.current_animation_timer >= IDLE_ANIMATION_TIME {
					miner.current_animation_timer = 0
					miner.current_animation_frame += 1
					if miner.current_animation_frame > 1 {
						miner.current_animation_frame = 0
					}

				}
			case .walking:
				using miner
				position.y += sine_breathe_alpha(game_data.world_time_elapsed) * speed * dt
				position.y -= cos_breathe_alpha(game_data.world_time_elapsed) * speed * dt

				rotation =
					cos_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1 -
					sine_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1

				in_walk_cycle_anim := miner.current_animation_frame == 2
				anim_time: f32 =
					in_walk_cycle_anim ? WALK_ANIMATION_TIME : WALK_ANIMATION_TIME * 0.6

				if miner.current_animation_timer >= anim_time {
					miner.current_animation_timer = 0
					miner.current_animation_frame = miner.current_animation_frame == 0 ? 2 : 0
				}

			case .collecting:
				using miner
				position.y += sine_breathe_alpha(game_data.world_time_elapsed) * speed * dt
				position.y -= cos_breathe_alpha(game_data.world_time_elapsed) * speed * dt

				rotation =
					cos_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1 -
					sine_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1

				in_walk_cycle_anim := miner.current_animation_frame == 15
				anim_time: f32 =
					in_walk_cycle_anim ? WALK_ANIMATION_TIME : WALK_ANIMATION_TIME * 0.6

				if miner.current_animation_timer >= anim_time {
					miner.current_animation_timer = 0
					miner.current_animation_frame = miner.current_animation_frame == 16 ? 15 : 16
				}

			case .sleeping:
				using miner
				if stamina_timer <= 0 {
					log("STAMina UPDATEd")
					stamina_timer = STAMINA_REST_TIMER
					if resting_in_tent {
						stamina += 2
					} else {
						stamina += 1
					}


					if stamina == 100 {
						log("MINER IS RESTED")
						miner.state = .idle
						miner.resting_in_tent = false
					}

					animation_frame_offset = 17
				}


			case .mining:
				using miner
				in_mining_cycle_anim :=
					miner.current_animation_frame == 3 || miner.current_animation_frame == 5
				anim_time: f32 =
					in_mining_cycle_anim ? WALK_ANIMATION_TIME : WALK_ANIMATION_TIME * 0.3

				if last_face_direction.y > 0 {
					animation_frame_offset = 4
				} else if last_face_direction.y < 0 {
					animation_frame_offset = 8
				}
				if miner.current_animation_frame == 0 {
					miner.current_animation_frame = 3
				}
				if miner.current_animation_timer >= anim_time {
					miner.current_animation_timer = 0
					miner.current_animation_frame += 1
					if miner.current_animation_frame > 6 {
						miner.current_animation_frame = 3
					}
				}


				task := miner.tasks[miner.current_task]
				if task_timer <= 0.0 && task.current_target_index != -1 {
					task_timer = MINE_BLOCK_TIMER
					block_target_to_remove := task.block_targets[task.current_target_index]
					if miner.current_task == .destroy_blocks &&
						   damage_block_and_check_destroyed(&miner, block_target_to_remove, 1.0) ||
					   miner.current_task == .destroy_building &&
						   damage_building_and_check_destroyed(
							   &miner,
							   block_target_to_remove,
							   1.0,
						   ) {

						// @TODO @PERFORMANCE
						// maybe check nearby miners instead?
						for &m in game_data.miners {
							m_task := &m.tasks[current_task]
							index := -1
							blocks: for i := 0; i < len(m_task.block_targets); i += 1 {
								if block_target_to_remove.tile_world_grid_position ==
								   m_task.block_targets[i].tile_world_grid_position {
									index = i
									break
								}
							}

							if index > -1 {
								unordered_remove(&m_task.block_targets, index)
								if index == m_task.current_target_index {
									set_state(&m, .idle)
								}
								m_task.current_target_index = -1
							}
						}

						if miner.current_task == .destroy_blocks {
							allocate_tile_neighbour_bitmasks(
								block_target_to_remove.chunk_key,
								block_target_to_remove.tile_chunk_grid_position,
							)
						}


					}

				}

			}


			should_render := !miner.resting_in_tent

			if should_render {
				shadow_xform := transform_2d(miner.position + {0, -3})
				{
					set_z_layer(.shadow)

					draw_quad_center_xform(
						shadow_xform,
						{16, 16},
						.shadows,
						DEFAULT_UV,
						COLOR_WHITE,
					)
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

				set_z_layer(.ui)
				draw_rect_bordered_xform(
					xform * transform_2d({-10, 10}),
					{20, 2},
					1.0,
					COLOR_WHITE,
					COLOR_BLACK,
				)


				draw_rect_xform(
					xform * transform_2d({-10, 10}),
					{20 * (miner.stamina / 100), 2},
					COLOR_GREEN,
				)

				set_z_layer(.game_play)

				if miner.last_face_direction.x < 0 {
					xform = xform * transform_2d({}, 0, {-1, 1})
				}


				if miner.state == .walking || miner.state == .collecting {
					xform *= transform_2d({-5, -5}, rotation)
					xform *= transform_2d({5, 5})
				}


				draw_quad_center_xform(
					xform,
					{16, 16},
					.miners,
					get_frame_uvs(
						.miners,
						{
							miner.current_animation_frame + animation_frame_offset,
							auto_cast miner.type,
						},
						{16, 16},
					),
					COLOR_WHITE,
				)


				xform *= transform_2d({0, 10})
				if miner.mined_resource != .nil {
					draw_quad_center_xform(
						xform,
						{16, 16},
						.mined_resources,
						get_frame_uvs(
							.mined_resources,
							{auto_cast miner.mined_resource - 1, 0},
							{16, 16},
						),
						COLOR_WHITE,
					)
				}
			}


		}
	}
	{
		using imgui
		using strings
		// imgui.SetNextItemWidth(200.0)
		// imgui.SetNextWindowSize({600, 800}, imgui.Cond.FirstUseEver)

		// Begin("Debug Menu")

		// for &ent in game_data.miners {

		// 	ent_id := strings.clone_to_cstring(
		// 		fmt.tprintfln("Ent ID: {}", ent.id),
		// 		temp_allocator(),
		// 	)
		// 	imgui.Text(ent_id)
		// 	imgui.SliderFloat("Speed", &ent.speed, 0, 200)
		// 	{
		// 		current_task: i32 = auto_cast ent.current_task
		// 		b: Builder
		// 		countie: i32
		// 		for kind in MinerTask {
		// 			write_string(&b, fmt.tprint(kind))
		// 			write_byte(&b, 0)
		// 			countie += 1
		// 		}
		// 		write_byte(&b, 0)
		// 		imgui.Combo("Current entity task", &current_task, to_cstring(&b), countie)
		// 		current_task_active := strings.clone_to_cstring(
		// 			fmt.tprintfln("current_task_active: {}", ent.tasks[ent.current_task].active),
		// 			temp_allocator(),
		// 		)
		// 		imgui.Text(current_task_active)
		// 	}

		// 	task_length := strings.clone_to_cstring(
		// 		fmt.tprintfln(
		// 			"Task Block Target Count: {}",
		// 			len(ent.tasks[ent.current_task].block_targets),
		// 		),
		// 		temp_allocator(),
		// 	)
		// 	imgui.Text(task_length)


		// 	current_target_id := strings.clone_to_cstring(
		// 		fmt.tprintfln(
		// 			"current_target_index: {}",
		// 			ent.tasks[ent.current_task].current_target_index,
		// 		),
		// 		temp_allocator(),
		// 	)
		// 	imgui.Text(current_target_id)
		// 	{
		// 		current_state: i32 = auto_cast ent.state
		// 		b: Builder
		// 		countie: i32
		// 		for kind in ent_state {
		// 			write_string(&b, fmt.tprint(kind))
		// 			write_byte(&b, 0)
		// 			countie += 1
		// 		}
		// 		write_byte(&b, 0)
		// 		imgui.Combo("Current entity state", &current_state, to_cstring(&b), countie)
		// 	}

		// 	node_path_count := strings.clone_to_cstring(
		// 		fmt.tprintfln("Node path count: {}", len(ent.node_path)),
		// 		temp_allocator(),
		// 	)
		// 	imgui.Text(node_path_count)

		// }

		// // TODO, insert the widgets here


		// End()
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
			transform_2d({50, 150}),
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
		rotation :=
			cos_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1 -
			sine_breathe_alpha(game_data.world_time_elapsed * 0.75) * 0.1
		scale: f32 = 32
		// sapp.show_mouse(false)
		set_ortho_projection(scale)
		mouse_world_position = mouse_to_matrix()
		draw_quad_center_xform(
			transform_2d(mouse_world_position + {0, -(5 / scale)}, rotation),
			{22 / scale, 22 / scale},
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
	down_clicked_id: u32,
}

reset_ui_state :: proc() {
	if ui_state.hover_id == 0 {
		ui_state.hover_time = 0
	}
	ui_state.hover_id = 0

	if inputs.mouse_just_released[sapp.Mousebutton.LEFT] {
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
	if inputs.button_just_released[sapp.Keycode.F11] {
		sapp.toggle_fullscreen()
	}


	update_sound()
	// imgui_new_frame()
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
