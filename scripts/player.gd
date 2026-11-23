class_name Player
extends CharacterBody3D

# ------------------------------------------------------------------
# player.gd
#
# The pirate you play as. Walks with WASD, hits with space / left click.
# No animations yet: the body is a blue capsule with a hat, and the
# sword only shows up for a split second when you swing it.
# ------------------------------------------------------------------

const SPEED = 6.0                # metres per second
const MAX_HEALTH = 100
const ATTACK_DAMAGE = 25         # enemies have 60 health, so 3 hits to kill one
const ATTACK_RANGE = 2.0         # how far the sword reaches (metres)
const ATTACK_COOLDOWN = 0.4      # seconds you have to wait between swings
const SWING_TIME = 0.15          # how long the sword is visible during a swing
const BODY_COLOR = Color(0.2, 0.4, 0.85)

var health = MAX_HEALTH
var dead = false

# timers: we set them to some number of seconds and count them down to 0 every frame
var attack_timer = 0.0    # > 0 means we can't attack yet
var swing_timer = 0.0     # > 0 means the sword is mid swing
var hurt_timer = 0.0      # > 0 means we flash red because we just got hit

var body_material: StandardMaterial3D   # kept so we can change the colour (red flash)
var sword_pivot: Node3D                 # the sword rotates around this point


func _ready():
	add_to_group("player")

	# Collision layers, used the same way in every script:
	#   layer 1 = world (walls, door, props)    -> value 1
	#   layer 2 = player                         -> value 2
	#   layer 3 = enemies                        -> value 4
	# "layer" = what we ARE, "mask" = what we BUMP INTO
	collision_layer = 2
	collision_mask = 1 + 4    # we bump into the world and enemies

	# It's a top down game, so we don't need gravity or floors.
	# Floating mode just means: move and slide along walls, don't care about up and down.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	# the invisible capsule that actually collides with stuff
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9    # lift it up so the bottom touches the floor
	add_child(collision)

	# --- what the player looks like ---
	# body: a capsule the same size as the collision
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var body = Main.add_part(self, capsule, BODY_COLOR, Vector3(0, 0.9, 0))
	body_material = body.material_override
	# black pirate hat on top
	Main.add_part(self, Main.box(Vector3(0.8, 0.15, 0.5)), Color.BLACK, Vector3(0, 1.85, 0))
	# small yellow block on the front, so you can see which way we're looking
	# (in Godot "forward" is -z, that's why the z is negative)
	Main.add_part(self, Main.box(Vector3(0.2, 0.2, 0.2)), Color.YELLOW, Vector3(0, 1.4, -0.4))

	# the sword hangs off a pivot in the middle of the player at hand height.
	# to swing it we just rotate the pivot, same idea as the door hinge in main.gd
	sword_pivot = Node3D.new()
	sword_pivot.position.y = 1.0
	add_child(sword_pivot)
	Main.add_part(sword_pivot, Main.box(Vector3(0.1, 0.1, 1.4)), Color(0.85, 0.85, 0.9), Vector3(0, 0, -1.0))
	sword_pivot.visible = false


# Godot calls this 60 times per second, this is where all physics/movement goes.
func _physics_process(delta):
	if dead:
		return   # dead pirates don't move

	# count all timers down, but never below 0
	attack_timer = max(attack_timer - delta, 0.0)
	swing_timer = max(swing_timer - delta, 0.0)
	hurt_timer = max(hurt_timer - delta, 0.0)

	# --- MOVEMENT ---
	# get_vector gives us the WASD input as an arrow, for example W+D = up and to the right.
	# the screen's "up" is -z in the world, so input.y goes straight into z
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input.x, 0, input.y)
	velocity = direction * SPEED
	move_and_slide()   # Godot moves us and makes us slide along walls instead of getting stuck

	# turn to face the way we walk. only when we actually move, otherwise we'd snap back to some default
	if direction.length() > 0.1:
		look_at(global_position + direction)   # look_at turns our front (-z) towards that spot

	# --- FIGHTING ---
	# holding the button keeps attacking, the cooldown makes sure it's not every frame
	if Input.is_action_pressed("attack") and attack_timer == 0.0:
		attack()

	# swing the sword from left to right while the swing timer runs out
	if swing_timer > 0:
		var progress = 1.0 - swing_timer / SWING_TIME   # goes from 0 (start) to 1 (end of swing)
		sword_pivot.rotation_degrees.y = lerp(60.0, -60.0, progress)
	sword_pivot.visible = swing_timer > 0

	# flash red for a moment after getting hit
	body_material.albedo_color = Color.RED if hurt_timer > 0 else BODY_COLOR


func attack():
	attack_timer = ATTACK_COOLDOWN
	swing_timer = SWING_TIME

	# which way are we looking? -z of our own rotation is our front
	var forward = -global_transform.basis.z

	# check every enemy: is it close enough AND in front of us?
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0
		# the dot product says how much two directions point the same way:
		# 1 = exactly in front, 0 = exactly to the side, -1 = behind us.
		# > 0.3 means roughly in front (a cone of about 145 degrees)
		var in_front = forward.dot(to_enemy.normalized()) > 0.3
		if to_enemy.length() < ATTACK_RANGE and in_front:
			enemy.take_damage(ATTACK_DAMAGE, to_enemy.normalized())


# enemies call this when they hit us
func take_damage(amount):
	if dead:
		return
	health -= amount
	hurt_timer = 0.2
	if health <= 0:
		health = 0
		die()


func die():
	dead = true
	sword_pivot.visible = false
	body_material.albedo_color = Color(0.3, 0.3, 0.3)   # turn grey
	# fall over: tip 90 degrees and lift a bit so we don't sink into the floor
	rotation_degrees.x = -90
	position.y = 0.4
