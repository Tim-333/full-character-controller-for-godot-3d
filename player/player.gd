extends CharacterBody3D

# nodes
@onready var head: Node3D = $head
@onready var eyes: Node3D = $head/eyes
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape_2: CollisionShape3D = $crouching_collision_shape2
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera_3d: Camera3D = $head/eyes/Camera3D
@onready var left_wall_ray: RayCast3D = $Left_wall_ray
@onready var right_wall_ray: RayCast3D = $Right_wall_ray

# movement speeds
@export var slope_slide_angle = 35.0 
@export var slope_slide_speed = 6.0
@export var current_speed = 5.0
@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 3.0
@export var JUMP_VELOCITY = 4.5
@export var mouse_sens = 0.25
@export var lerp_speed = 10.0

# camera bobbing
const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0
const head_bobbing_crouching_intensity = 0.05
const head_bobbing_walking_intensity = 0.2
const head_bobbing_sprinting_intensity = 0.4
var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0
var crouching_depth = 0.5
var direction = Vector3.ZERO

# camera tilt
@export var tilt_amount_wallrun = 15.0 
@export var tilt_amount_slide = 10.0 
@export var tilt_speed = 5.0 
var target_tilt = 0.0 

# states
var walking = false
var sprinting = false
var crouching = false
var sliding = false
var wallrunning = false
var wall_normal = Vector3.ZERO

# timers
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0

# wallrunning
@export var wallrun_gravity = -1.5
@export var wallrun_speed = 5.0
@export var walljump_force = Vector3(0, 8, 0)
@export var walljump_sideways_force = 5.0
var just_walljumped = 0.0

func is_on_steep_slope() -> bool:
	if not is_on_floor():
		return false
	var floor_normal = get_floor_normal()
	var angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
	return angle > slope_slide_angle

# look around with mouse
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# mouse movement
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

# physics
func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "forward", "backward")

	# crouching
	if Input.is_action_pressed("crouch"):
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, -0.8 + crouching_depth, delta * lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape_2.disabled = false

		# sliding
		if sprinting and input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir

		walking = false
		sprinting = false
		crouching = true

	elif not ray_cast_3d.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape_2.disabled = true
		head.position.y = lerp(head.position.y, 0.8, delta * lerp_speed)

# camera tilt
	if wallrunning:
		if left_wall_ray.is_colliding():
			target_tilt = -tilt_amount_wallrun
		elif right_wall_ray.is_colliding():
			target_tilt = tilt_amount_wallrun
	elif sliding:
		target_tilt = tilt_amount_slide
	else:
		target_tilt = 0.0


		# sprinting and walking
		if Input.is_action_pressed("sprint"):
			current_speed = sprinting_speed
			walking = false
			sprinting = true
			crouching = false
		else:
			current_speed = walking_speed
			walking = true
			sprinting = false
			crouching = false

	# slide timer
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
		if not Input.is_action_pressed("crouch") or Input.get_vector("left", "right", "forward", "backward") == Vector2.ZERO:
			sliding = false

	# wallrun detection
	var wall_detected = left_wall_ray.is_colliding() or right_wall_ray.is_colliding()
	
	if not is_on_floor() and wall_detected and Input.is_action_pressed("forward") and just_walljumped <= 0.0:
		if not wallrunning:
			wallrunning = true
			if left_wall_ray.is_colliding():
				wall_normal = left_wall_ray.get_collision_normal()
			else:
				wall_normal = right_wall_ray.get_collision_normal()

	if wallrunning:
		if not wall_detected or not Input.is_action_pressed("forward"):
			wallrunning = false

	# gravity
	if not is_on_floor():
		if wallrunning:
			velocity.y = wallrun_gravity
		else:
			velocity += get_gravity() * delta

	# jumping
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			sliding = false
		elif wallrunning:
			velocity = wall_normal * walljump_sideways_force
			velocity.y = walljump_force.y
			wallrunning = false
			just_walljumped = 0.2

	if just_walljumped > 0.0:
		just_walljumped -= delta

	# direction and movement
	if wallrunning:
		var wall_forward = wall_normal.cross(Vector3.UP).normalized()
		if wall_forward.dot(transform.basis.z) > 0:
			wall_forward = -wall_forward

		direction = lerp(direction, wall_forward, delta * lerp_speed)
	else:
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)

	# apply movement
	if direction:
		if sliding:
			velocity.x = direction.x * (slide_timer + 0.8) * slide_speed
			velocity.z = direction.z * (slide_timer + 0.8) * slide_speed
		elif is_on_steep_slope():
			var slope_direction = -get_floor_normal().slide(Vector3.DOWN).normalized()
			velocity.x = slope_direction.x * slope_slide_speed
			velocity.z = slope_direction.z * slope_slide_speed
		elif direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)


	move_and_slide()

# head bobbing
func _process(delta: float) -> void:
	handle_head_bobbing(delta)
	handle_camera_tilt(delta)

#  camera tilting
func handle_camera_tilt(delta: float) -> void:
	var current_tilt = rad_to_deg(head.rotation.z)
	current_tilt = lerp(current_tilt, target_tilt, delta * tilt_speed)
	head.rotation.z = deg_to_rad(current_tilt)

#  head bobbing
func handle_head_bobbing(delta: float) -> void:
	if is_on_floor() and not sliding and direction.length() > 0.1:
		if sprinting:
			head_bobbing_current_intensity = head_bobbing_sprinting_intensity
			head_bobbing_index += head_bobbing_sprinting_speed * delta
		elif walking:
			head_bobbing_current_intensity = head_bobbing_walking_intensity
			head_bobbing_index += head_bobbing_walking_speed * delta
		elif crouching:
			head_bobbing_current_intensity = head_bobbing_crouching_intensity
			head_bobbing_index += head_bobbing_crouching_speed * delta

	if is_on_floor() and not sliding and direction.length() > 0:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index / 2.0) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity), delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
