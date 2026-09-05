class_name Player
extends CharacterBody2D
## Spielerfigur: Bewegung mit Beschleunigung, 4 Richtungen, Idle- und Laufanimation.

const IDLE_FPS := 1.6
const WALK_FPS := 9.0

var _frames: Dictionary
var _sprite: Sprite2D
var _shadow: Sprite2D
var _dir: int = ActorArt.Dir.DOWN
var _flip: bool = false
var _anim_time: float = 0.0
var _step_accum: float = 0.0
var _was_moving: bool = false

func _ready() -> void:
	_frames = ActorArt.build()

	var shape := RectangleShape2D.new()
	shape.size = Config.PLAYER_HITBOX * 2.0
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -Config.PLAYER_HITBOX.y)
	add_child(col)

	_shadow = Sprite2D.new()
	_shadow.texture = _frames["shadow"]
	_shadow.centered = true
	_shadow.position = Vector2(0, -2)
	_shadow.z_index = -1
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = Vector2(-ActorArt.W * 0.5, -ActorArt.H)
	add_child(_sprite)
	_update_sprite(0.0)

func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input.length() > 1.0:
		input = input.normalized()

	var running := Input.is_action_pressed("run")
	var top_speed := Config.PLAYER_RUN_SPEED if running else Config.PLAYER_SPEED
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, Config.PLAYER_FRICTION * delta)
	else:
		velocity = velocity.move_toward(input * top_speed, Config.PLAYER_ACCEL * delta)
		_face(input)
	move_and_slide()

	var moving := velocity.length() > 6.0
	_anim_time += delta * (WALK_FPS if moving else IDLE_FPS)
	if not moving and _was_moving:
		_anim_time = 0.0
	_was_moving = moving
	_update_sprite(velocity.length())
	_footsteps(delta, moving, top_speed)

func _face(input: Vector2) -> void:
	if absf(input.x) > absf(input.y) + 0.15:
		_dir = ActorArt.Dir.SIDE
		_flip = input.x > 0.0
	elif absf(input.y) > 0.0:
		_dir = ActorArt.Dir.UP if input.y < 0.0 else ActorArt.Dir.DOWN

func _update_sprite(speed: float) -> void:
	var moving := speed > 6.0
	var set_name := "walk" if moving else "idle"
	var frames: Array = _frames[set_name][_dir]
	var idx := int(_anim_time) % frames.size()
	_sprite.texture = frames[idx]
	_sprite.flip_h = _flip
	# Beim Spiegeln muss der Versatz mitgespiegelt werden
	_sprite.offset.x = -ActorArt.W * 0.5

func _footsteps(delta: float, moving: bool, top_speed: float) -> void:
	if not moving:
		_step_accum = 0.35
		return
	_step_accum += delta * (top_speed / Config.PLAYER_SPEED)
	if _step_accum >= 0.36:
		_step_accum = 0.0
		Audio.play_step()
