class_name Player
extends CharacterBody2D
## Spielerfigur: Bewegung mit Beschleunigung, 4 Richtungen, Idle- und Laufanimation.

const IDLE_FPS := 1.6

## Bilder je Sekunde beim GEHEN. Beim Rennen und beim Schwimmen laeuft der
## Zyklus schneller bzw. langsamer — im Verhaeltnis zur tatsaechlichen
## Geschwindigkeit, siehe `_walk_fps`.
const WALK_FPS := 9.0

## Wird beim Eintauchen gemeldet, damit die Wasserwirkung einen Ring zeichnen
## kann. Die Figur weiss nichts vom Wasser-Effekt, nur dass sie eintaucht.
signal splashed(pos: Vector2)

## Wird beim Aufkommen nach einem Sprung gemeldet — für die Staubwolke.
signal landed(pos: Vector2)

## Wird beim Durchwaten gemeldet: hier zieht jemand durchs Wasser.
signal waded(pos: Vector2, dir: Vector2)

## Halbe Kantenlänge des Fussabdrucks. Schmaler als eine Kachel, damit die
## Figur durch eine ein Feld breite Lücke passt.

var _frames: Dictionary
var _sprite: Sprite2D
var _shadow: Sprite2D
var _dir: int = ActorArt.Dir.DOWN
var _flip: bool = false
var _anim_time: float = 0.0
var _was_moving: bool = false
var _jump_time: float = -1.0   ## < 0 = am Boden, sonst Fortschritt in Sekunden
var _swimming: bool = false
var _wake_timer: float = 0.0

## Wie lange die Landung noch nachfedert. Ohne das endet der Sprung damit, dass
## die Figur schlagartig wieder steht — und dann war der ganze Sprung wieder
## nur eine Verschiebung.
var _land_time: float = 0.0
const LAND_TIME := 0.14

## Ab welcher Geschwindigkeit die Figur als „in Bewegung" gilt — fuer das
## Laufbild und die Wasserspur. Stand vorher zweimal als nackte 6.0 da.
const MOVING_FROM := 6.0

var map: MapData               ## um zu wissen, worauf die Figur steht

## Schwimmt die Figur gerade?
func is_swimming() -> bool:
	return _swimming

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
	# Die Zeichnungen sind doppelt so fein wie die Welt (siehe ActorArt.ART).
	# Halbe Darstellung heisst: gleiche Groesse in der Welt, viermal so viele
	# Bildpunkte. Bei Zoom 2 faellt ein Kunstpixel genau auf einen
	# Bildschirmpunkt.
	_shadow.scale = Vector2.ONE * ActorArt.DRAW_SCALE
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = Vector2(-ActorArt.W * 0.5, -ActorArt.H)
	_sprite.scale = Vector2.ONE * ActorArt.DRAW_SCALE
	add_child(_sprite)

	_update_sprite(false)

func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input.length() > 1.0:
		input = input.normalized()

	_update_swimming()
	var running := Input.is_action_pressed("run") and not _swimming
	var top_speed := Config.PLAYER_SPEED
	if _swimming:
		top_speed = Config.SWIM_SPEED
	elif running:
		top_speed = Config.PLAYER_RUN_SPEED
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, Config.PLAYER_FRICTION * delta)
	else:
		velocity = velocity.move_toward(input * top_speed, Config.PLAYER_ACCEL * delta)
		_face(input)
	move_and_slide()
	_jump(delta)

	var moving := velocity.length() > MOVING_FROM
	_trail(delta, moving)
	_anim_time += delta * (_walk_fps(velocity.length()) if moving else IDLE_FPS)
	if not moving and _was_moving:
		_anim_time = 0.0
	_was_moving = moving
	# Die Landung federt nach. Sie hier herunterzuzaehlen und nicht im
	# Zeichnen: `_update_sprite` laeuft auch aus `_ready()` und koennte je Bild
	# mehrfach gerufen werden — dann waere die Federung halb so lang.
	if _land_time > 0.0:
		_land_time = maxf(_land_time - delta, 0.0)
	_update_sprite(moving)

## Wie schnell der Laufzyklus laeuft — im Verhaeltnis zur Geschwindigkeit.
##
## Vorher lief er immer mit denselben 9 Bildern je Sekunde. Beim Rennen (216
## statt 124 px/s) legte die Figur damit fast die doppelte Strecke je Schritt
## zurueck und RUTSCHTE sichtbar ueber den Boden; beim Schwimmen (68 px/s)
## ruderte sie umgekehrt schneller, als sie vorankam.
##
## Der Zyklus haengt jetzt an der Strecke statt an der Uhr: bei Gehtempo sind
## es weiterhin genau 9 Bilder je Sekunde, darueber und darunter entsprechend.
## Begrenzt, damit es bei einem Stoss von aussen nicht flimmert.
func _walk_fps(speed: float) -> float:
	return clampf(WALK_FPS * speed / Config.PLAYER_SPEED, 4.0, 16.0)

## Welche Sprungstellung gerade gilt.
##
## Der Absprung dauert nur ein paar Hundertstel: lange genug, dass man die
## Hocke sieht, kurz genug, dass der Sprung nicht träge wirkt.
func _jump_phase() -> int:
	if _jump_time < 0.0:
		return ActorArt.JUMP_CROUCH            # Landung federt nach
	var t := _jump_time / Config.JUMP_TIME
	if t < 0.16:
		return ActorArt.JUMP_CROUCH
	return ActorArt.JUMP_RISE if t < 0.55 else ActorArt.JUMP_FALL

## Kielwellen hinter der Figur, solange sie sich im Wasser bewegt.
##
## In festem Abstand statt jedes Bild: bei 60 Bildern je Sekunde entstünden
## sonst sechzig Wellen je Sekunde, und die Spur wäre ein heller Balken statt
## einzelner Wellen. Alle 0,16 Sekunden ergibt eine Kette, in der man die
## einzelne Welle noch sieht.
func _trail(delta: float, moving: bool) -> void:
	if not (_swimming and moving):
		_wake_timer = 0.0
		return
	_wake_timer -= delta
	if _wake_timer > 0.0:
		return
	_wake_timer = WaterFx.WAKE_EVERY
	waded.emit(global_position, velocity)

## Im flachen Wasser wird geschwommen: langsamer, ohne Rennen und Springen.
## Wasser hält niemanden auf — es wird durchschwommen.
##
## Während eines Sprungs wird NICHT geschwommen: sonst klappte die Figur mitten
## in der Luft ins Schwimmbild um. Der Sprung wird zu Ende geflogen, das
## Eintauchen kommt beim Aufkommen.
func _update_swimming() -> void:
	if map == null:
		return
	var b := GridOverlay.block_at(global_position)
	var wet := map.is_swimmable(b.x, b.y) and not is_jumping()
	if wet == _swimming:
		return
	_swimming = wet
	if wet:
		splashed.emit(global_position)

## Wie hoch die Figur gerade über dem Boden schwebt. Das ist AUSSCHLIESSLICH
## der Sprung.
##
## Hier lag der Fehler mit dem „Hochklatschen“: beim Verlassen einer Stufe
## wurde dem Versatz schlagartig die volle Wandhöhe aufgeschlagen und dann
## weggeblendet — die Figur schoss also erst 16 Pixel nach OBEN und sank dann.
## Das war doppelt falsch: sie soll herunter, nicht hinauf, und die Höhe steckt
## ohnehin schon in der Kachelgrafik (Wand und Schlagschatten). Ein Versatz
## verschöbe die Figur gegen ihre eigene Kollisionsfläche.
func lift() -> float:
	return jump_height()

## Der Sprung verschiebt nur die Grafik. Position und Kollision bleiben am
## Boden, damit sich niemand über Wände oder Wasser hinwegsetzen kann.
func _jump(delta: float) -> void:
	if _swimming:
		return
	if _jump_time < 0.0:
		if Input.is_action_just_pressed("jump"):
			_jump_time = 0.0
		return
	_jump_time += delta
	if _jump_time >= Config.JUMP_TIME:
		_jump_time = -1.0
		_land_time = LAND_TIME
		landed.emit(global_position)

func _face(input: Vector2) -> void:
	if absf(input.x) > absf(input.y) + 0.15:
		_dir = ActorArt.Dir.SIDE
		# Die Seitenansicht in ActorArt ist nach RECHTS gezeichnet (Auge und Nase
		# liegen rechts, das Hinterkopfhaar links). Gespiegelt wird deshalb beim
		# Laufen nach links, nicht nach rechts.
		_flip = input.x < 0.0
	elif absf(input.y) > 0.0:
		_dir = ActorArt.Dir.UP if input.y < 0.0 else ActorArt.Dir.DOWN

func _update_sprite(moving: bool) -> void:
	var set_name := "swim" if _swimming else ("walk" if moving else "idle")
	var frames: Array = _frames[set_name][_dir]
	var idx := int(_anim_time) % frames.size()
	# Sprung und Landung haben eigene Stellungen. Ohne sie wäre der Sprung
	# dasselbe Standbild, nur weiter oben — und genau so sah er auch aus.
	if _jump_time >= 0.0 or _land_time > 0.0:
		frames = _frames["jump"][_dir]
		idx = _jump_phase()
	_sprite.texture = frames[idx]
	_sprite.flip_h = _flip

	# Schwimmen: das Bild taucht an der Wasserlinie ein (siehe
	# `ActorArt._submerge`), also muss es um denselben Betrag nach unten, damit
	# der Kopf an seiner Stelle bleibt. Der Bodenschatten fällt weg — im Wasser
	# gibt es keinen.
	if _swimming:
		_sprite.offset.y = -ActorArt.H + ActorArt.SWIM_SINK
		_sprite.position.y = 0.0
		_shadow.visible = false
		return
	# Schatten sind abschaltbar (Grafikeinstellungen). Im Wasser gibt es
	# ohnehin keinen.
	_shadow.visible = Graphics.shadows_on()

	# Sprung und Fallen: Figur hoch, Schatten bleibt liegen und wird kleiner
	# und blasser.
	var lift := lift()
	# Der Versatz steht in KUNSTpixeln (er wird mitskaliert), die Sprunghoehe
	# in WELTpixeln. Beides in `offset` zu addieren hiesse, die Sprunghoehe zu
	# halbieren — die Figur haette nur noch halb so hoch gesprungen, ohne dass
	# jemand eine Zahl geaendert haette.
	_sprite.offset.y = -ActorArt.H
	_sprite.position.y = -lift
	if lift > 0.0:
		var f := minf(lift / Config.JUMP_HEIGHT, 1.0)
		_shadow.scale = Vector2.ONE * ActorArt.DRAW_SCALE * (1.0 - 0.32 * f)
		_shadow.modulate.a = 1.0 - 0.45 * f
	else:
		_shadow.scale = Vector2.ONE * ActorArt.DRAW_SCALE
		_shadow.modulate.a = 1.0
