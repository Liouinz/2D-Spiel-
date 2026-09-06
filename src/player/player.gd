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
var _jump_time: float = -1.0   ## < 0 = am Boden, sonst Fortschritt in Sekunden

## Ist die Figur gerade in der Luft? Der Selbsttest fragt das ab.
func is_jumping() -> bool:
	return _jump_time >= 0.0

## Aktuelle Sprunghöhe in Bildpunkten (0 = am Boden).
func jump_height() -> float:
	if _jump_time < 0.0:
		return 0.0
	# Wurfparabel: 4*h*t*(1-t) erreicht bei t = 0.5 genau h.
	var t := _jump_time / Config.JUMP_TIME
	return 4.0 * Config.JUMP_HEIGHT * t * (1.0 - t)

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
	_jump(delta)

	var moving := velocity.length() > 6.0
	_anim_time += delta * (WALK_FPS if moving else IDLE_FPS)
	if not moving and _was_moving:
		_anim_time = 0.0
	_was_moving = moving
	_update_sprite(velocity.length())
	_footsteps(delta, moving, top_speed)

## Der Sprung verschiebt nur die Grafik. Position und Kollision bleiben am
## Boden, damit sich niemand über Wände oder Wasser hinwegsetzen kann.
func _jump(delta: float) -> void:
	if _jump_time < 0.0:
		if Input.is_action_just_pressed("jump"):
			_jump_time = 0.0
			Audio.play_ui("jump")
		return
	_jump_time += delta
	if _jump_time >= Config.JUMP_TIME:
		_jump_time = -1.0
		Audio.play_ui("land")

func _face(input: Vector2) -> void:
	if absf(input.x) > absf(input.y) + 0.15:
		_dir = ActorArt.Dir.SIDE
		# Die Seitenansicht in ActorArt ist nach RECHTS gezeichnet (Auge und Nase
		# liegen rechts, das Hinterkopfhaar links). Gespiegelt wird deshalb beim
		# Laufen nach links, nicht nach rechts.
		_flip = input.x < 0.0
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

	# Sprung: Figur hoch, Schatten bleibt liegen und wird kleiner und blasser.
	var lift := jump_height()
	_sprite.offset.y = -ActorArt.H - lift
	if lift > 0.0:
		var f := lift / Config.JUMP_HEIGHT
		_shadow.scale = Vector2.ONE * (1.0 - 0.32 * f)
		_shadow.modulate.a = 1.0 - 0.45 * f
	else:
		_shadow.scale = Vector2.ONE
		_shadow.modulate.a = 1.0

func _footsteps(delta: float, moving: bool, top_speed: float) -> void:
	if not moving:
		_step_accum = 0.35
		return
	_step_accum += delta * (top_speed / Config.PLAYER_SPEED)
	if _step_accum >= 0.36:
		_step_accum = 0.0
		Audio.play_step()
