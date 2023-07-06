class_name Player
extends CharacterBody2D
# A playable character controlled by the user

# references
@onready var hitbox : CollisionShape2D = $Hitbox

# x
const MAX_SPEED_X : float = 1.75

const GROUND_ACCEL_TIME : int = 7 # in frames
const GROUND_ACCEL_STEP : float = MAX_SPEED_X / GROUND_ACCEL_TIME

const GROUND_DECEL_TIME : int = 5 # in frames
const GROUND_DECEL_STEP : float = MAX_SPEED_X / GROUND_DECEL_TIME

var vel : Vector2

# y
const GRAVITY : float = 0.08
const TERM_VEL : float = 6.00
const JUMP_POWER : float = 2.73

const AIR_ACCEL_TIME : int = 9
const AIR_ACCEL_STEP : float = MAX_SPEED_X / AIR_ACCEL_TIME

var air_decel_time : int = 40 # variable because wall jumps change this
var air_decel_step : float = MAX_SPEED_X / air_decel_time

const COYOTE_TIME : int = 8 # coyote jumping/falling
var coyote_timer : int

const BUFFER_TIME : int = 4 # buffer jump
var buffer_timer : int 

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

const WALL_JUMPS : int = 3
var wall_jump_count : int

const VEL_SUSTAIN_TIME : int = 8
var vel_sustain_timer : int

var vel_sustain : float # vel.x before a wall was hit

# double jumping
var jumps : int = 1

# misc
var facing_direction : float = 1 # default to facing right
var is_grounded : bool


func _ready():
	set_up_direction(Vector2.UP)


func _physics_process(delta):
#	print(jumps)

	var input_vec : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))

	is_grounded = is_on_floor()
	dash(input_vec)

	# x movement
	var accel

	if input_vec.x != 0: # change facing_direction whenever you move
		facing_direction = input_vec.x

	if not dashing:
		if is_grounded:
			air_decel_time = 40
			accel = GROUND_ACCEL_STEP

			dash_count = DASHES
			wall_jump_count = WALL_JUMPS
		else:
			accel = AIR_ACCEL_STEP

		if input_vec.x != 0:
			if vel.x * input_vec.x + accel < MAX_SPEED_X: # accelerating
				if vel.x != 0 and input_vec.x != sign(vel.x) and is_on_floor(): # quick turn
					vel.x = abs(vel.x) * input_vec.x * 0.5
				else:
					vel.x += input_vec.x * accel
			elif vel.x * input_vec.x < MAX_SPEED_X:
				vel.x = input_vec.x * MAX_SPEED_X

		if is_grounded and (input_vec.x == 0 or abs(vel.x) > MAX_SPEED_X): # decelerating (on ground)
			vel.x -= GROUND_DECEL_STEP * sign(vel.x)

			if abs(vel.x) < GROUND_DECEL_STEP:
				vel.x = 0
		elif input_vec.x == 0: # decelerating (in air)
			vel.x -= air_decel_step * sign(vel.x)

			if abs(vel.x) < air_decel_step:
				vel.x = 0

	# y movement
	if is_grounded:
		coyote_timer = COYOTE_TIME
		vel_sustain_timer = 0
		jumps = 1
	else:
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

	# sustain velocity for walljumps
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

	# y input stuff
	if Input.is_action_just_pressed("jump"):
		buffer_timer = BUFFER_TIME

	if Input.is_action_pressed("jump") and buffer_timer > 0:
		dashing = false
		dash_timer = 0

		if coyote_timer > 0: # normal/coyote;double jump
			jump()
		elif wall_casting(-1) and wall_jump_count != 0: # wall jump left
			wall_jump_left()
		elif wall_casting(1) and wall_jump_count != 0: # wall jump right
			wall_jump_right()
		elif jumps == 1: # double jump
			jumps = max(jumps - 1, 0)
			jump()


	if Input.is_action_just_released("jump") and vel.y < 0: 
		vel.y *= 0.5

	# dash movement
	if Input.is_action_just_pressed("dash") and dash_count != 0:
		dash_direction = facing_direction
		dashing = true
		
		if not is_grounded:
			dash_count = max(dash_count - 1,0)

	# physics
	# warning-ignore:return_value_discarded
	set_velocity(vel / delta)
	move_and_slide()
	vel = velocity * delta


func jump(): # perform jump
	vel.y = -JUMP_POWER
	coyote_timer = 0
	buffer_timer = 0

	if Input.is_action_pressed("down"): # fuck i mean duck jump
		vel.y = -JUMP_POWER * 0.7


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
	return test_move(transform, Vector2(3 * check_direction, 0))


func wall_jump_left(): # perform wall jump from a left wall
		facing_direction = 1
		buffer_timer = 0

		vel = Vector2(max(vel_sustain, WALL_JUMP_POWER), -JUMP_POWER)
		air_decel_time = 300
		wall_jump_count = max(wall_jump_count - 1,0)


func wall_jump_right(): # perform wall jump from a right wall
	facing_direction = -1
	buffer_timer = 0

	vel = Vector2(-max(vel_sustain, WALL_JUMP_POWER), -JUMP_POWER)
	air_decel_time = 300
	wall_jump_count = max(wall_jump_count - 1,0)
