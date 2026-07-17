extends CharacterBody2D
# Personnage : avance tout seul (auto-run), le joueur tape l'écran pour sauter
# (double saut possible). Sprite tiré du pack Kenney "Pixel Platformer",
# avec un petit effet d'étirement au saut pour plus de "feel".

signal died
signal jumped

const GRAVITY := 1400.0
const JUMP_VELOCITY := -620.0
const MAX_JUMPS := 2

const CHAR_TEX := preload("res://assets/characters.png")
const CHAR_TILE := 24
const CHAR_SCALE := 1.4
const CHAR_ROW := 0
const COL_IDLE := 0
const COL_RUN := [1, 2]
const COL_JUMP := 3
const RUN_FRAME_TIME := 0.12

var run_speed: float = 260.0
var _jumps_left: int = MAX_JUMPS
var _alive: bool = true
var _sprite: Sprite2D
var _run_frame_timer: float = 0.0
var _run_frame_index: int = 0
var _was_on_floor: bool = true

func _ready() -> void:
	add_to_group("player")
	_sprite = Sprite2D.new()
	_sprite.texture = CHAR_TEX
	_sprite.region_enabled = true
	_sprite.scale = Vector2(CHAR_SCALE, CHAR_SCALE)
	add_child(_sprite)
	_set_frame(COL_IDLE)

func _set_frame(col: int) -> void:
	_sprite.region_rect = Rect2(col * CHAR_TILE, CHAR_ROW * CHAR_TILE, CHAR_TILE, CHAR_TILE)

func set_run_speed(speed: float) -> void:
	run_speed = speed

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	velocity.y += GRAVITY * delta
	velocity.x = run_speed

	var on_floor := is_on_floor()
	if on_floor:
		_jumps_left = MAX_JUMPS
		_run_frame_timer += delta
		if _run_frame_timer >= RUN_FRAME_TIME:
			_run_frame_timer = 0.0
			_run_frame_index = 1 - _run_frame_index
			_set_frame(COL_RUN[_run_frame_index])
		if not _was_on_floor:
			_play_land_squash()
	else:
		_set_frame(COL_JUMP)

	_was_on_floor = on_floor
	move_and_slide()

func try_jump() -> void:
	if not _alive:
		return
	if _jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		_jumps_left -= 1
		_set_frame(COL_JUMP)
		_play_jump_stretch()
		jumped.emit()

func _play_jump_stretch() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(CHAR_SCALE * 0.82, CHAR_SCALE * 1.22), 0.07)
	tw.tween_property(_sprite, "scale", Vector2(CHAR_SCALE, CHAR_SCALE), 0.12)

func _play_land_squash() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(CHAR_SCALE * 1.2, CHAR_SCALE * 0.8), 0.06)
	tw.tween_property(_sprite, "scale", Vector2(CHAR_SCALE, CHAR_SCALE), 0.1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		try_jump()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_jump()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		try_jump()

func kill() -> void:
	if not _alive:
		return
	_alive = false
	died.emit()

func revive_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_alive = true
	_jumps_left = MAX_JUMPS
	_set_frame(COL_IDLE)
