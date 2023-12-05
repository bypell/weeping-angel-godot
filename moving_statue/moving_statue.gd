extends CharacterBody3D


const SPEED = 3.5
const VIS_RAY_TARGET_Y_OFFSET = 0.5

@export var target_player : CharacterBody3D

var _occlusion_check_rays : Array[RayCast3D]
var is_looked_at = true
var follow_player = false

@onready var occlusion_check_rays_parent = $OcclusionCheckRaysParent
@onready var visible_on_screen_notifier = $VisibleOnScreenNotifier3D
@onready var nav_agent = $NavigationAgent3D


func _ready():
	# validate that player target export var is set
	if not target_player:
		printerr(self.name + " has no player target")
		set_physics_process(false)
		return
	
	# add all RayCast3Ds to the _occlusion_check_rays array
	for r in occlusion_check_rays_parent.get_children():
		if r is RayCast3D:
			# add the ennemy as an exception so that the ray does not collide with it
			r.add_exception(self)
			r.add_exception(target_player) # not really necessary since the rays are not scanning on the player's layer 
			_occlusion_check_rays.append(r)
	
	_queue_begin_following.call_deferred()


func _queue_begin_following():
	# start following player on the next physics frame (NavigationServer has to sync blablabla)
	await get_tree().physics_frame
	follow_player = true


func _physics_process(_delta):
	if not follow_player:
		return
	
	is_looked_at = _is_viewed()
	
	if is_looked_at:
		return
	
	# movement direction
	var direction = Vector3.ZERO
	nav_agent.target_position = target_player.global_position
	direction = nav_agent.get_next_path_position() - global_position
	direction.y = 0
	direction = direction.normalized()
	
	# look direction
	if nav_agent.get_current_navigation_path():
		var where_to_look = nav_agent.get_next_path_position()
		where_to_look.y = self.global_position.y
		if not where_to_look == self.global_position:
			look_at(where_to_look, Vector3.UP)
	
	# applying velocity using move direction
	velocity = direction * SPEED
	move_and_slide()


func _is_viewed() -> bool:
	var viewed = visible_on_screen_notifier.is_on_screen()
	var colliding_rays = 0
	
	# make rays point to player and count how many are getting occluded
	for r in _occlusion_check_rays:
		r.target_position = (target_player.global_position - r.global_position) * self.basis
		r.target_position.y += VIS_RAY_TARGET_Y_OFFSET
		if viewed and r.is_colliding():
			colliding_rays += 1
	
	# if all rays are colliding, the statue is "hidden"
	if colliding_rays >= _occlusion_check_rays.size():
		viewed = false
	
	return viewed
