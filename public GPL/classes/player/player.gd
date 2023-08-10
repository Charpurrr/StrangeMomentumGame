class_name Player
extends CharacterBody2D
# A playable character controlled by the user

# references
@onready var hitbox : CollisionShape2D = $Hitbox
@onready var crouchbox : CollisionShape2D = $Crouchbox

@onready var autocrouch_area : Area2D = $AutocrouchBox
@onready var autocrouch_cast_true : RayCast2D = $CrawlCastTrue
@onready var autocrouch_cast_false : RayCast2D = $CrawlCastFalse

@onready var doll : AnimatedSprite2D = $Doll

# x
const MAX_SPEED_X : float = 1.75

const GROUND_ACCEL_TIME : int = 7 # frames it takes to accel on ground
const GROUND_ACCEL_STEP : float = MAX_SPEED_X / GROUND_ACCEL_TIME

const GROUND_DECEL_TIME : int = 5 # frames it takes to decel on ground
const GROUND_DECEL_STEP : float = MAX_SPEED_X / GROUND_DECEL_TIME

const QUICK_TURN_IGNORE_TIME : int = 4 # amt of frames quick turning is ignored after landing
var quick_turn_ignore_timer : int

var vel : Vector2

# y
const GRAVITY : float = 0.08
const TERM_VEL : float = 6.00
const JUMP_POWER : float = 2.73

const AIR_ACCEL_TIME : int = 9 # frames it takes to accel in air
const AIR_ACCEL_STEP : float = MAX_SPEED_X / AIR_ACCEL_TIME

var air_decel_time : int = 40 # variable because wall jumps change this
var air_decel_step : float = MAX_SPEED_X / air_decel_time

const COYOTE_TIME : int = 8 # coyote jumping/falling
var coyote_timer : int

const BUFFER_TIME : int = 4 # buffer jump
var buffer_timer : int 

# air pounding
const AIR_POUND_POWER = 4
var can_air_pound : bool = false
var air_pounding : bool

const AIR_POUND_TIME : int = 10
var air_pound_timer : int

# dashing
const DASHES : int = 3
var dash_count : int

const DASH_TIME : int = 10
var dash_timer : int

const DASH_POWER : float = 3.6
var dashing : bool
var dash_direction : float

# wall jumping
const WALL_JUMP_POWER : float = 2.5

const WALL_CLIMBS : int = 3 # amt of times the player can jump off the same wall
var wall_climb_count : int
var last_climbed_wall : int # in vector

const VEL_SUSTAIN_TIME : int = 8
var vel_sustain_timer : int

var vel_sustain : float # vel.x before a wall was hit

# double jumping
const DOUBLE_JUMP_IGNORE : int = 4 # how many frames above the ground a double jump input is ignored
var jumps : int = 1

# misc
var facing_direction : float = 1 # default to facing right
var is_grounded : bool
var crouching : bool


func _ready():
	set_up_direction(Vector2.UP)

	hitbox.disabled = false
	crouchbox.disabled = true


func _process(_delta):
	print(can_air_pound)

	crouch()

	autocrouch_cast_true.target_position.x = abs(autocrouch_cast_true.target_position.x) * facing_direction
	autocrouch_cast_false.target_position.x = abs(autocrouch_cast_false.target_position.x) * facing_direction

	doll.flip_h = (facing_direction == -1) # flip sprite depending on the way player's facing

	# animation
	if crouching: doll.animation = "crouch"
	else: doll.animation = "idle"


func _physics_process(delta):
	var input_vec : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
	var accel

	is_grounded = is_on_floor()
	dash(input_vec)
	air_pound()

	# x movement
	if input_vec.x != 0: # update facing_direction whenever you move
		facing_direction = input_vec.x

	if not dashing:
		if is_grounded:
			air_decel_time = 40

			dash_count = DASHES
			wall_climb_count = WALL_CLIMBS

			accel = GROUND_ACCEL_STEP
		else:
			accel = AIR_ACCEL_STEP

		if input_vec.x != 0: # accelerate
			if vel.x * input_vec.x + accel < MAX_SPEED_X:
				if vel.x != 0 and input_vec.x != sign(vel.x) and quick_turn_ignore_timer == 0 and is_on_floor(): # quick turn
					vel.x = abs(vel.x) * input_vec.x * 0.5
				else:
					vel.x += input_vec.x * accel
			elif vel.x * input_vec.x < MAX_SPEED_X:
				vel.x = input_vec.x * MAX_SPEED_X

		if abs(vel.x) > MAX_SPEED_X and is_grounded: # decelerate from overdrive
			vel.x = move_toward(vel.x, (MAX_SPEED_X * facing_direction), GROUND_DECEL_STEP * 0.25)

		if input_vec.x == 0: # decelerate
			if is_grounded: vel.x = move_toward(vel.x, 0, GROUND_DECEL_STEP)
			else: vel.x = move_toward(vel.x, 0, air_decel_step)

	# y movement
	if is_grounded:
		coyote_timer = COYOTE_TIME
		vel_sustain_timer = 0
		jumps = 1
		quick_turn_ignore_timer = max(quick_turn_ignore_timer - 1,0)
	else:
		quick_turn_ignore_timer = QUICK_TURN_IGNORE_TIME
		coyote_timer -= 1

	if coyote_timer > 0: # add coyote timing to falling
		vel.y = 0

	if not dashing:
		if Input.is_action_pressed("down") and vel.y > 0: # fast falling
			vel.y += GRAVITY * 1.75
			vel.y = min(vel.y, TERM_VEL * 2)
		elif not (is_wallsliding_left() or is_wallsliding_right()): # normal falling
			vel.y += GRAVITY
			vel.y = min(vel.y, TERM_VEL)
		else: # wall slide falling
			vel.y += GRAVITY * 0.5
			vel.y = min(vel.y, TERM_VEL * 0.25)

	buffer_timer = max(buffer_timer - 1,0)

	sustain_velocity() # sustain velocity for wall jumps

	# y input stuff
	if Input.is_action_just_pressed("jump"):
		buffer_timer = BUFFER_TIME
		can_air_pound = true

	if Input.is_action_pressed("jump") and buffer_timer > 0:
		dashing = false
		dash_timer = 0

		if coyote_timer > 0: # normal/coyote;double jump
			jump()
		elif can_walljump_left(): # wall jump left
			wall_jump_left()
		elif can_walljump_right(): # wall jump right
			wall_jump_right()
		elif jumps == 1 and not should_ignore_double_jump(): # double jump
			jumps = max(jumps - 1, 0)
			jump()


	if Input.is_action_just_released("jump") and vel.y < 0: 
		vel.y *= 0.5

	# dash movement
	if Input.is_action_just_pressed("dash") and dash_count != 0:
		dash_direction = facing_direction
		dashing = true

		can_air_pound = true
		
		if not is_grounded:
			dash_count = max(dash_count - 1,0)

	# physics
	set_velocity(vel / delta)
	move_and_slide()
	vel = velocity * delta


func should_autocrouch() -> bool:
	# returns work in series
	if autocrouch_area.has_overlapping_bodies(): return true # if already in a crawling space
	if not is_grounded: return false # if you're not grounded
	# if colliding with a crawling space
	return (autocrouch_cast_true.is_colliding() and not autocrouch_cast_false.is_colliding())


func crouch():
	hitbox.disabled = crouching
	crouchbox.disabled = not crouching

	crouching = Input.is_action_pressed("down") or should_autocrouch()


func should_ignore_double_jump() -> bool: # whether or not the double jump input is ignored
	return test_move(transform, Vector2(0, DOUBLE_JUMP_IGNORE))


func jump(): # perform jump
	vel.y = -JUMP_POWER
	coyote_timer = 0
	buffer_timer = 0

	if crouching: # crouch hop
		vel.y = -JUMP_POWER * 0.7


func air_pound(): # perform air pound
	if air_pounding:
		vel.y += AIR_POUND_POWER
		air_pounding = false


func dash(input_vec): # perform dash
	if dashing:
		vel.x = DASH_POWER * sign(dash_direction)
		vel.y = 0

		if dash_timer < DASH_TIME:
			dash_timer += 1

		if dash_timer >= DASH_TIME:
			dash_timer = 0

			if input_vec.x == dash_direction:
				vel.x = MAX_SPEED_X * dash_direction
			else:
				vel.x = 0

			dashing = false


func is_wallsliding_left() -> bool: # check if user is trying to wallslide on a left wall
	return (is_on_wall() and vel.y > 0 
	and Input.is_action_pressed("left") and wall_casting(-1))


func is_wallsliding_right() -> bool: # check if user is trying to wallslide on a right wall
	return (is_on_wall() and vel.y > 0 
	and Input.is_action_pressed("right") and wall_casting(1))


func wall_casting(check_direction) -> bool: # check if the user is near a wall
	var forgiveness_x = 5.0 + clamp(abs(vel.x), 0.0, DASH_POWER) 
	# min as 0 (but actually 5)
	# max as DASH_POWER cuz u don't wanna be able to wall jump from across the map
	return test_move(transform, Vector2(forgiveness_x * check_direction, 0))


func sustain_velocity() -> void: # retain velocity gained from x movement to put into wall jumps
	vel_sustain_timer = max(vel_sustain_timer - 1,-1)

	if abs(vel.x) > WALL_JUMP_POWER: # set retained velocity for wall jumps
		vel_sustain = abs(vel.x)

	if (wall_casting(1) or wall_casting(-1)): # start sustain timer when hitting a wall
		if vel_sustain_timer == -1:
			vel_sustain_timer = VEL_SUSTAIN_TIME
	else:
		if vel_sustain_timer > 0:
			vel_sustain = 0

		vel_sustain_timer = -1

	if vel_sustain_timer == 0: # kill sustained speed after timer finishes
		vel_sustain = 0


func can_walljump_left() -> bool: # can wall jump from a left wall
	if not wall_casting(-1): return false

	return (wall_climb_count != 0 or last_climbed_wall == 1)


func can_walljump_right() -> bool: # can wall jump from a right wall
	if not wall_casting(1): return false

	return (wall_climb_count != 0 or last_climbed_wall == -1)


func wall_jump_left(): # perform wall jump from a left wall
	var power_multiplier : float

	facing_direction = 1
	buffer_timer = 0

	if crouching: power_multiplier = 0.7
	else: power_multiplier = 1

	vel = Vector2(max(vel_sustain, WALL_JUMP_POWER), -JUMP_POWER * power_multiplier)
	air_decel_time = 300

	if last_climbed_wall == 1: # right
		wall_climb_count = WALL_CLIMBS
		wall_climb_count = max(wall_climb_count - 1,0)
	else:
		wall_climb_count = max(wall_climb_count - 1,0)

	last_climbed_wall = -1


func wall_jump_right(): # perform wall jump from a right wall
	var power_multiplier : float

	facing_direction = -1
	buffer_timer = 0

	if crouching: power_multiplier = 0.7
	else: power_multiplier = 1

	vel = Vector2(-max(vel_sustain, WALL_JUMP_POWER), -JUMP_POWER * power_multiplier)
	air_decel_time = 300

	if last_climbed_wall == -1: # left
		wall_climb_count = WALL_CLIMBS
		wall_climb_count = max(wall_climb_count - 1,0)
	else:
		wall_climb_count = max(wall_climb_count - 1,0)

	last_climbed_wall = 1
