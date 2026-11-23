class_name Enemy
extends CharacterBody3D

# ------------------------------------------------------------------
# enemy.gd
#
# A really simple enemy: a red block, no skin, no animations.
# It stands still until it sees you, then walks towards you and
# hits you when it's close enough.
#
# "Sees you" = you're close enough AND there's no wall or door in between.
# So if you keep the door closed, they can't see you (or reach you).
# ------------------------------------------------------------------

const SPEED = 3.5              # slower than the player (6), so you can always run away
const MAX_HEALTH = 60
const SIGHT_RANGE = 9.0        # how far it can see you (metres)
const ATTACK_RANGE = 1.4       # how close it has to be to hit you
const ATTACK_DAMAGE = 10       # player has 100 health, so 10 hits and you're dead
const ATTACK_COOLDOWN = 1.0    # seconds between hits
const KNOCKBACK_SPEED = 6.0    # how hard it gets pushed back when you hit it
const BODY_COLOR = Color(0.8, 0.15, 0.15)

var player: Player             # main.gd fills this in when it spawns us
var health = MAX_HEALTH
var attack_timer = 0.0         # > 0 means we can't hit yet
var hurt_timer = 0.0           # > 0 means we flash white because we just got hit
var knockback = Vector3.ZERO   # extra push from getting hit, fades out quickly
var body_material: StandardMaterial3D


func _ready():
	add_to_group("enemies")   # this is how the player and main.gd find all enemies

	# same layer system as the player (see player.gd):
	# we are on layer 3 (value 4) and we bump into world (1), player (2) and other enemies (4)
	collision_layer = 4
	collision_mask = 1 + 2 + 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # top down, no gravity, same as player

	# invisible box we collide with
	var size = Vector3(0.8, 1.6, 0.8)
	var shape = BoxShape3D.new()
	shape.size = size
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y / 2
	add_child(collision)

	# what it looks like: a red block the same size, plus a dark "face" so you can see where it looks
	var body = Main.add_part(self, Main.box(size), BODY_COLOR, Vector3(0, size.y / 2, 0))
	body_material = body.material_override
	Main.add_part(self, Main.box(Vector3(0.5, 0.2, 0.1)), Color(0.15, 0.05, 0.05), Vector3(0, 1.3, -0.42))


func _physics_process(delta):
	attack_timer = max(attack_timer - delta, 0.0)
	hurt_timer = max(hurt_timer - delta, 0.0)
	body_material.albedo_color = Color.WHITE if hurt_timer > 0 else BODY_COLOR

	# where is the player compared to us? (ignore height, we only care about the floor)
	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	# the "brain", checked top to bottom, the first one that's true wins:
	if player.dead:
		# 1. player is dead -> stand still
		velocity = Vector3.ZERO
	elif distance < ATTACK_RANGE:
		# 2. close enough to hit -> stop and hit (if the cooldown is over)
		velocity = Vector3.ZERO
		if attack_timer == 0.0:
			player.take_damage(ATTACK_DAMAGE)
			attack_timer = ATTACK_COOLDOWN
	elif distance < SIGHT_RANGE and can_see_player():
		# 3. we can see the player -> walk straight at them
		velocity = to_player.normalized() * SPEED
	else:
		# 4. can't see anyone -> just stand there
		velocity = Vector3.ZERO

	# add the knockback push on top, then let it fade to 0 quickly
	velocity += knockback
	knockback = knockback.move_toward(Vector3.ZERO, 30 * delta)
	move_and_slide()

	# turn to look at the player (keep our own height, otherwise we'd tilt)
	if distance > 0.1 and not player.dead:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))


# Shoots an invisible line (a "raycast") from our eyes to the player's eyes.
# It only checks layer 1 (walls, door, props), so if the line hits nothing,
# nothing is in the way and we can see the player.
# Eyes are at 1.5m, higher than the barrels/tables/cannons, so we can look over those.
func can_see_player():
	var eyes = Vector3(0, 1.5, 0)
	var ray = PhysicsRayQueryParameters3D.create(global_position + eyes, player.global_position + eyes, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty()


# the player calls this when the sword hits us.
# push_direction = the direction from the player to us, so we get pushed away from them
func take_damage(amount, push_direction):
	health -= amount
	hurt_timer = 0.15
	knockback = push_direction * KNOCKBACK_SPEED
	if health <= 0:
		queue_free()   # removes the enemy from the game
