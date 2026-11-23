class_name Main
extends Node3D

# ------------------------------------------------------------------
# main.gd
#
# This is the whole level for the first playtest.
# It builds two rooms with a door in between, puts some props in them,
# spawns the player and two enemies and keeps the camera on the player.
#
# Everything is made in code on purpose, so you can just read this file
# top to bottom and see the whole level, instead of clicking through
# a bunch of scenes in the editor.
#
# What the level looks like from above (x goes right, z goes down):
#
#   z=-5  +------------------+------------------+
#         |                  |                  |
#         |      ROOM A      D      ROOM B      |
#         |   (start room)   |   (enemy room)   |
#         |                  |                  |
#   z=+5  +------------------+------------------+
#        x=-10              x=0               x=10
#
#   D = the door. It sits in a 2 metre gap in the middle wall.
# ------------------------------------------------------------------


# --- numbers you might want to tweak ---
const WALL_HEIGHT = 2.5
const FRONT_WALL_HEIGHT = 1.0   # the wall closest to the camera is low, otherwise it hides the player
const WALL_THICKNESS = 0.3
const DOOR_WIDTH = 2.0
const DOOR_RANGE = 2.5          # how close you have to stand to the door to open it
const CAMERA_OFFSET = Vector3(0, 14, 8)   # camera hangs 14m above and 8m behind the player

# --- colours, all in one place so they're easy to change ---
const FLOOR_A_COLOR = Color(0.45, 0.32, 0.2)
const FLOOR_B_COLOR = Color(0.38, 0.27, 0.17)
const WALL_COLOR = Color(0.3, 0.2, 0.12)
const DOOR_COLOR = Color(0.55, 0.35, 0.15)
const WOOD_COLOR = Color(0.5, 0.33, 0.18)
const LIGHT_WOOD_COLOR = Color(0.65, 0.48, 0.3)
const METAL_COLOR = Color(0.2, 0.2, 0.22)
const BACKGROUND_COLOR = Color(0.05, 0.07, 0.1)

var player: Player
var camera: Camera3D
var door_hinge: Node3D       # the door swings around this point
var door_open = false
var info_label: Label        # top left text (health etc.)
var hint_label: Label        # bottom middle text ("E - open door" etc.)
var room_covers = {}         # one dark box per room, "A" and "B" (see build_room_covers)
var current_room = ""        # the room the player is in right now


# Godot calls this once when the level starts. We just build everything in order.
func _ready():
	setup_controls()
	build_lights()
	build_rooms()
	build_door()
	build_props()
	build_room_covers()
	spawn_player()
	spawn_enemies()
	build_camera()
	build_ui()


# Godot calls this every frame.
func _process(_delta):
	# camera follows the player. it always keeps the same angle so we only move it, never rotate it
	camera.global_position = player.global_position + CAMERA_OFFSET

	# only show the room the player is standing in
	update_room_covers()

	# door: if you stand close enough and press E, it opens (or closes)
	# the door sits at the middle of the level, which is (0, 0, 0)
	var near_door = player.global_position.distance_to(Vector3.ZERO) < DOOR_RANGE
	if near_door and not player.dead and Input.is_action_just_pressed("interact"):
		toggle_door()

	# R restarts the whole level (Godot just loads this scene again from scratch)
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	update_ui(near_door)


# ==================================================================
#  CONTROLS
# ==================================================================

# We add the keys in code instead of in Project Settings > Input Map,
# so you can see all controls in one spot.
func setup_controls():
	add_key("move_up", [KEY_W, KEY_UP])
	add_key("move_down", [KEY_S, KEY_DOWN])
	add_key("move_left", [KEY_A, KEY_LEFT])
	add_key("move_right", [KEY_D, KEY_RIGHT])
	add_key("interact", [KEY_E])
	add_key("restart", [KEY_R])

	# attack is space OR left mouse click, the mouse needs a different kind of event
	if not InputMap.has_action("attack"):
		add_key("attack", [KEY_SPACE])
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)


func add_key(action, keys):
	# when you restart the level the keys are still there from last time, so skip them then
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


# ==================================================================
#  LIGHTS
# ==================================================================

func build_lights():
	# one big "sun" light that shines in from the side, with shadows
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# dark blue background + a bit of soft light everywhere so the shadows aren't pitch black
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	environment.ambient_light_energy = 0.5
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


# ==================================================================
#  ROOMS
# ==================================================================

func build_rooms():
	# floors. these don't need collision because nothing has gravity (see player.gd),
	# so nobody can fall through anyway. one floor per room, slightly different colour
	add_part(self, box(Vector3(10, 0.2, 10)), FLOOR_A_COLOR, Vector3(-5, -0.1, 0))
	add_part(self, box(Vector3(10, 0.2, 10)), FLOOR_B_COLOR, Vector3(5, -0.1, 0))

	var t = WALL_THICKNESS
	var h = WALL_HEIGHT

	# the 4 outside walls, going around both rooms
	wall(Vector3(0, 0, -5), Vector3(20 + t, h, t))                   # back wall (top of the screen)
	wall(Vector3(0, 0, 5), Vector3(20 + t, FRONT_WALL_HEIGHT, t))    # front wall (low, see above)
	wall(Vector3(-10, 0, 0), Vector3(t, h, 10))                      # left wall
	wall(Vector3(10, 0, 0), Vector3(t, h, 10))                       # right wall

	# the middle wall between the rooms. it's made of 2 pieces with a gap in the middle for the door.
	# each piece is 4m long: (10m room - 2m door) / 2. piece centres are at z = -3 and z = 3
	wall(Vector3(0, 0, -3), Vector3(t, h, 4))
	wall(Vector3(0, 0, 3), Vector3(t, h, 4))


# One wall = a solid block (so you can't walk through it) + a box you can see.
func wall(pos, size):
	var body = make_solid(self, pos, size)
	add_part(body, box(size), WALL_COLOR, Vector3(0, size.y / 2, 0))


# ==================================================================
#  ONLY SEE THE ROOM YOU'RE IN
# ==================================================================

# The trick: every room gets a big box over it with the exact same colour as the background.
# When the box is see-through you see the room, when it's solid the room just looks like
# empty space. So we fade the box of your room out and the other room's box in.
#
# The boxes go from the outside wall up to the middle wall, but NOT over the middle wall
# itself, so you can still see the wall and the door of the room you're in.
func build_room_covers():
	room_covers["A"] = make_cover(-5.225)   # covers x from -10.3 to -0.15
	room_covers["B"] = make_cover(5.225)    # covers x from 0.15 to 10.3


func make_cover(center_x):
	var material = StandardMaterial3D.new()
	material.albedo_color = BACKGROUND_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # ignore the lights, always exactly this colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA      # so we can fade it in and out

	var cover = MeshInstance3D.new()
	cover.mesh = box(Vector3(10.15, 2.65, 10.6))   # a bit bigger than the room, just taller than the walls
	cover.material_override = material
	cover.position = Vector3(center_x, 1.225, 0)   # bottom just under the floor, top just over the walls
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # it's not a real thing, so no shadow
	add_child(cover)
	return cover


func update_room_covers():
	# which room are we in? the middle wall is at x = 0, so left of it is A and right of it is B
	var room = "A" if player.global_position.x < 0 else "B"
	if room == current_room:
		return   # still in the same room, nothing to do
	current_room = room

	# fade our room's cover away (alpha 0 = see-through) and the other one in (alpha 1 = solid)
	for room_name in room_covers:
		var target_alpha = 0.0 if room_name == room else 1.0
		var tween = create_tween()
		tween.tween_property(room_covers[room_name], "material_override:albedo_color:a", target_alpha, 0.25)


# ==================================================================
#  DOOR
# ==================================================================

func build_door():
	# The trick for a swinging door: we make an empty "hinge" node at one edge of the doorway,
	# and hang the door off it. Then we only rotate the hinge and the door swings with it,
	# just like a real door on a hinge.
	door_hinge = Node3D.new()
	door_hinge.position = Vector3(0, 0, -DOOR_WIDTH / 2)   # top edge of the doorway
	add_child(door_hinge)

	var door_size = Vector3(0.2, 2.2, DOOR_WIDTH)
	# the door's centre is half a door away from the hinge, so it exactly fills the gap
	var door = make_solid(door_hinge, Vector3(0, 0, DOOR_WIDTH / 2), door_size)
	add_part(door, box(door_size), DOOR_COLOR, Vector3(0, door_size.y / 2, 0))
	# little handle so you can tell it's a door and not a wall
	add_part(door, box(Vector3(0.35, 0.1, 0.1)), METAL_COLOR, Vector3(0, 1.0, 0.7))


func toggle_door():
	door_open = not door_open
	# open = turn the hinge 90 degrees so the door swings into room B, closed = back to 0
	var target_angle = 90.0 if door_open else 0.0
	# a tween smoothly changes a value over time, here over 0.3 seconds, so the door doesn't just teleport
	var tween = create_tween()
	tween.tween_property(door_hinge, "rotation_degrees:y", target_angle, 0.3)


# ==================================================================
#  PROPS
# ==================================================================

func build_props():
	# room A (start room)
	table(Vector3(-6, 0, -1))
	barrel(Vector3(-9, 0, -4))
	barrel(Vector3(-8, 0, -4.2))
	barrel(Vector3(-9.1, 0, -3))
	cannon(Vector3(-4, 0, 3.6), 180)    # turned around so it points at the front wall

	# room B (enemy room)
	table(Vector3(6, 0, 2))
	barrel(Vector3(9, 0, 4))
	barrel(Vector3(8, 0, 4.2))
	cannon(Vector3(4, 0, -3.6), 0)      # points at the back wall
	cannon(Vector3(7.5, 0, -3.6), 0)


# Every prop gets ONE simple box for collision (the invisible bit you bump into),
# and then a few meshes on top for the looks. The box doesn't have to match the shape
# exactly, it just needs to be roughly the right size.

func barrel(pos):
	var body = make_solid(self, pos, Vector3(0.8, 1.0, 0.8))
	add_part(body, cylinder(0.4, 1.0), WOOD_COLOR, Vector3(0, 0.5, 0))
	# 2 dark metal rings around the barrel (slightly wider than the barrel so they poke out)
	add_part(body, cylinder(0.42, 0.08), METAL_COLOR, Vector3(0, 0.25, 0))
	add_part(body, cylinder(0.42, 0.08), METAL_COLOR, Vector3(0, 0.75, 0))


func table(pos):
	var body = make_solid(self, pos, Vector3(2.0, 0.8, 1.2))
	# table top
	add_part(body, box(Vector3(2.0, 0.1, 1.2)), LIGHT_WOOD_COLOR, Vector3(0, 0.75, 0))
	# 4 legs, one in each corner
	for x in [-0.9, 0.9]:
		for z in [-0.5, 0.5]:
			add_part(body, box(Vector3(0.1, 0.7, 0.1)), WOOD_COLOR, Vector3(x, 0.35, z))


# turn_degrees = which way the cannon points. 0 = up the screen, 180 = down the screen
func cannon(pos, turn_degrees):
	var body = make_solid(self, pos, Vector3(1.0, 0.9, 1.8))
	body.rotation_degrees.y = turn_degrees
	# the wooden cart the cannon sits on
	add_part(body, box(Vector3(0.8, 0.3, 1.2)), WOOD_COLOR, Vector3(0, 0.3, 0))
	# 4 wheels. cylinders stand upright by default, so we tip them on their side
	for x in [-0.45, 0.45]:
		for z in [-0.4, 0.4]:
			var wheel = add_part(body, cylinder(0.2, 0.1), METAL_COLOR, Vector3(x, 0.2, z))
			wheel.rotation_degrees.z = 90
	# the barrel of the cannon, also a cylinder but laid down so it points forward
	var tube = add_part(body, cylinder(0.22, 1.6), METAL_COLOR, Vector3(0, 0.65, -0.2))
	tube.rotation_degrees.x = 90


# ==================================================================
#  PLAYER, ENEMIES, CAMERA
# ==================================================================

func spawn_player():
	player = Player.new()                 # Player = the class from player.gd
	player.position = Vector3(-7, 0, 1)   # left side of room A
	add_child(player)


func spawn_enemies():
	# both enemies start in room B, so you have to go through the door to fight them
	for pos in [Vector3(6, 0, -1), Vector3(7.5, 0, 2.5)]:
		var enemy = Enemy.new()           # Enemy = the class from enemy.gd
		enemy.position = pos
		enemy.player = player             # tell the enemy who to chase
		add_child(enemy)


func build_camera():
	camera = Camera3D.new()
	add_child(camera)
	camera.global_position = player.global_position + CAMERA_OFFSET
	# point it at the player once. after this we only move it (see _process), the angle stays the same
	camera.look_at(player.global_position)


# ==================================================================
#  UI (just text for now)
# ==================================================================

func build_ui():
	# a CanvasLayer draws on top of the 3D world, that's where 2D stuff like text goes
	var ui = CanvasLayer.new()
	add_child(ui)

	info_label = Label.new()
	info_label.position = Vector2(20, 20)
	info_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(info_label)

	# this one stretches across the bottom of the screen with the text centred
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -90
	hint_label.offset_bottom = -40
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 30)
	ui.add_child(hint_label)


func update_ui(near_door):
	var enemies_left = get_tree().get_nodes_in_group("enemies").size()
	info_label.text = "Health: %d\nEnemies left: %d\n\nWASD - move\nSpace / click - attack\nE - door\nR - restart" % [player.health, enemies_left]

	# the hint at the bottom, most important message first
	if player.dead:
		hint_label.text = "You died... press R to try again"
	elif enemies_left == 0:
		hint_label.text = "All enemies down! Press R to play again"
	elif near_door and door_open:
		hint_label.text = "E - close door"
	elif near_door:
		hint_label.text = "E - open door"
	else:
		hint_label.text = ""


# ==================================================================
#  HELPERS
#  small building blocks used everywhere above (and in player.gd / enemy.gd).
#  "static" means you can call them from other scripts as Main.box(...) etc.
# ==================================================================

# Makes an invisible solid block that stuff bumps into. pos is the spot on the FLOOR
# where the block stands (so the bottom of the block), which makes placing things easy.
# It goes on collision layer 1, which is the "world" layer (walls, door, props).
func make_solid(parent, pos, size):
	var body = StaticBody3D.new()
	body.position = pos
	var shape = BoxShape3D.new()
	shape.size = size
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y / 2   # lift it up by half its height so it stands ON the floor
	body.add_child(collision)
	parent.add_child(body)
	return body


# Makes something you can SEE (no collision) with a plain colour, and sticks it on parent.
static func add_part(parent, mesh, color, pos):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	var part = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	parent.add_child(part)
	return part


static func box(size):
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(radius, height):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh
