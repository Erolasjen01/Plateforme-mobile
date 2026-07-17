extends Node2D
# Chef d'orchestre du jeu : génère les niveaux, gère l'état de la partie,
# l'UI (avec un minimum de style), le système de vies, et déclenche les
# pubs / achats aux bons moments.

enum State { PLAYING, GAME_OVER, LEVEL_COMPLETE }

const GROUND_Y := 900.0
const SEGMENT_WIDTH := 140.0
const HOLE_WIDTH := 90.0
const PLAYER_START_X := 200.0

const PLAYER_SIZE := 34.0
const PLAYER_REST_OFFSET := PLAYER_SIZE / 2.0

const GROUND_TEX := preload("res://assets/tiles.png")
const GROUND_TILE_SIZE := 18
const GROUND_TILE_SCALE := 2.0
const GROUND_VISUAL_SIZE := GROUND_TILE_SIZE * GROUND_TILE_SCALE  # 36 px

# Un thème par "biome" : couleur de ciel/collines + case de sol dans assets/tiles.png.
# Les mondes alternent entre les deux, ça change un peu l'ambiance visuelle
# sans ajouter d'assets supplémentaires.
const BIOMES := [
	{"sky": Color(0.875, 0.965, 0.961), "hill": Color(0.180, 0.690, 0.510), "ground_col": 2, "ground_row": 0},
	{"sky": Color(0.875, 0.965, 0.961), "hill": Color(0.796, 0.506, 0.369), "ground_col": 4, "ground_row": 0},
]

const COLOR_PRIMARY := Color(0.30, 0.68, 0.38)   # actions de progression (rejouer, niveau suivant)
const COLOR_AD := Color(0.56, 0.36, 0.86)        # actions liées à une pub (mises en avant)
const COLOR_SECONDARY := Color(0.32, 0.42, 0.58) # actions neutres (menu)
const COLOR_GOLD := Color(0.80, 0.62, 0.18)      # achat intégré

var _state: State = State.PLAYING
var _player: CharacterBody2D
var _camera: Camera2D
var _hud: CanvasLayer
var _score_label: Label
var _info_label: Label
var _lives_label: Label
var _game_over_panel: Panel
var _level_complete_panel: Panel

var _current_world: int = 1
var _current_level: int = 1
var _level_config: Dictionary = {}
var _biome: Dictionary = {}
var _coins_this_run: int = 0
var _level_length_px: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_current_world = Session.selected_world
	_current_level = Session.selected_level
	_build_hud()
	_start_level(_current_world, _current_level)

func _start_level(world: int, level: int) -> void:
	_clear_level()
	_current_world = world
	_current_level = level
	_level_config = LevelData.get_level_config(world, level)
	_biome = BIOMES[(world - 1) % BIOMES.size()]
	_rng.seed = _level_config["seed"]
	_level_length_px = _level_config["length"] * SEGMENT_WIDTH
	_coins_this_run = 0
	_state = State.PLAYING

	_spawn_background()
	_spawn_ground_and_obstacles()
	_spawn_player()
	_spawn_camera()
	_update_info_label()

func _clear_level() -> void:
	for child in get_children():
		if child is CanvasLayer:
			continue
		child.queue_free()

func _spawn_background() -> void:
	var parallax := ParallaxBackground.new()
	add_child(parallax)
	move_child(parallax, 0)

	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.05, 0.05)
	parallax.add_child(sky_layer)
	var sky_rect := ColorRect.new()
	sky_rect.color = _biome["sky"]
	sky_rect.size = Vector2(6000, 1800)
	sky_rect.position = Vector2(-1000, -1400)
	sky_layer.add_child(sky_rect)

	var hill_layer := ParallaxLayer.new()
	hill_layer.motion_scale = Vector2(0.35, 0.35)
	parallax.add_child(hill_layer)
	var hill_rect := ColorRect.new()
	hill_rect.color = _biome["hill"]
	hill_rect.size = Vector2(6000, 260)
	hill_rect.position = Vector2(-1000, GROUND_Y - 220)
	hill_layer.add_child(hill_rect)

func _spawn_ground_and_obstacles() -> void:
	var x := 0.0

	while x < _level_length_px:
		var make_hole: bool = _rng.randf() < _level_config["gap_frequency"] and x > SEGMENT_WIDTH * 3
		if make_hole:
			x += HOLE_WIDTH
		else:
			_add_ground_piece(x, SEGMENT_WIDTH)
			if _rng.randf() < 0.35:
				_add_coin(x + SEGMENT_WIDTH * 0.5, GROUND_Y - 120)
			if _rng.randf() < 0.2 and x > SEGMENT_WIDTH * 4:
				_add_spike(x + SEGMENT_WIDTH * 0.5)
			x += SEGMENT_WIDTH

	_add_ground_piece(x, SEGMENT_WIDTH * 3)
	var flag := ColorRect.new()
	flag.size = Vector2(20, 100)
	flag.position = Vector2(x + SEGMENT_WIDTH, GROUND_Y - 100)
	flag.color = Color(0.95, 0.35, 0.35)
	add_child(flag)
	_level_length_px = x + SEGMENT_WIDTH

func _add_ground_piece(x: float, width: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, GROUND_Y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, GROUND_VISUAL_SIZE)
	shape.shape = rect
	shape.position = Vector2(width / 2.0, GROUND_VISUAL_SIZE / 2.0)
	body.add_child(shape)

	var tile_count := int(ceil(width / GROUND_VISUAL_SIZE))
	for i in range(tile_count):
		var tile_sprite := Sprite2D.new()
		tile_sprite.texture = GROUND_TEX
		tile_sprite.region_enabled = true
		tile_sprite.region_rect = Rect2(
			_biome["ground_col"] * GROUND_TILE_SIZE, _biome["ground_row"] * GROUND_TILE_SIZE,
			GROUND_TILE_SIZE, GROUND_TILE_SIZE
		)
		tile_sprite.scale = Vector2(GROUND_TILE_SCALE, GROUND_TILE_SCALE)
		tile_sprite.position = Vector2(i * GROUND_VISUAL_SIZE + GROUND_VISUAL_SIZE / 2.0, GROUND_VISUAL_SIZE / 2.0)
		body.add_child(tile_sprite)

	add_child(body)

func _add_spike(x: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y - 20)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	shape.shape = rect
	area.add_child(shape)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-15, 15), Vector2(15, 15), Vector2(0, -15)])
	visual.color = Color(0.85, 0.15, 0.15)
	area.add_child(visual)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(-15, 15), Vector2(15, 15), Vector2(0, -15), Vector2(-15, 15)])
	outline.width = 2.0
	outline.default_color = Color(0.4, 0.05, 0.05)
	area.add_child(outline)

	area.body_entered.connect(_on_spike_hit)
	add_child(area)

func _add_coin(x: float, y: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	area.add_child(shape)

	var visual := ColorRect.new()
	visual.size = Vector2(22, 22)
	visual.position = Vector2(-11, -11)
	visual.color = Color(1.0, 0.82, 0.15)
	visual.name = "Visual"
	area.add_child(visual)

	area.body_entered.connect(_on_coin_collected.bind(area))
	add_child(area)

func _spawn_player() -> void:
	_player = CharacterBody2D.new()
	_player.position = Vector2(PLAYER_START_X, GROUND_Y - PLAYER_REST_OFFSET)
	_player.set_script(load("res://scripts/player.gd"))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PLAYER_SIZE, PLAYER_SIZE)
	shape.shape = rect
	_player.add_child(shape)

	add_child(_player)
	_player.set_run_speed(_level_config["speed"])
	_player.died.connect(_on_player_died)
	_player.jumped.connect(func(): SfxManager.play_jump())

func _spawn_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.zoom = Vector2(1.15, 1.15)
	_player.add_child(_camera)
	_camera.enabled = true

func _process(_delta: float) -> void:
	if _state != State.PLAYING or _player == null:
		return

	if _player.global_position.y > GROUND_Y + 400:
		_player.kill()

	if _player.global_position.x >= _level_length_px:
		_on_level_complete()

	_update_info_label()

func _on_spike_hit(body: Node) -> void:
	if body == _player:
		_player.kill()

func _on_coin_collected(body: Node, area: Area2D) -> void:
	if body == _player and is_instance_valid(area):
		_coins_this_run += 10
		SfxManager.play_coin()
		area.set_deferred("monitoring", false)
		var tw := create_tween()
		tw.tween_property(area, "scale", Vector2(1.7, 1.7), 0.08)
		tw.parallel().tween_property(area.get_node("Visual"), "modulate:a", 0.0, 0.08)
		tw.tween_callback(area.queue_free)

func _on_player_died() -> void:
	_state = State.GAME_OVER
	SfxManager.play_death()
	SaveManager.lose_life()
	_show_game_over_panel()

func _on_level_complete() -> void:
	_state = State.LEVEL_COMPLETE
	SfxManager.play_level_complete()
	var reward: int = _level_config["coin_reward"] + _coins_this_run
	SaveManager.add_coins(reward)
	SaveManager.unlock_next_level(_current_world, _current_level)
	_show_level_complete_panel(reward)

# --- Style (couleurs/coins arrondis, appliqué à tous les panneaux/boutons) ---

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.97)
	sb.set_corner_radius_all(18)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.content_margin_left = 20
	sb.content_margin_top = 20
	return sb

func _button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _style_button(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _button_style(color))
	btn.add_theme_stylebox_override("hover", _button_style(color.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.15)))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)

func _style_label(lbl: Label, size: int = 20) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 5)

# --- HUD ---

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	_info_label = Label.new()
	_info_label.position = Vector2(20, 16)
	_style_label(_info_label, 22)
	_hud.add_child(_info_label)

	_score_label = Label.new()
	_score_label.position = Vector2(20, 50)
	_style_label(_score_label, 18)
	_hud.add_child(_score_label)

	_lives_label = Label.new()
	_lives_label.position = Vector2(20, 80)
	_style_label(_lives_label, 18)
	_hud.add_child(_lives_label)

	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.position = Vector2(600, 20)
	_style_button(menu_btn, COLOR_SECONDARY)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_hud.add_child(menu_btn)

	_game_over_panel = Panel.new()
	_game_over_panel.visible = false
	_game_over_panel.position = Vector2(160, 380)
	_game_over_panel.size = Vector2(400, 320)
	_game_over_panel.add_theme_stylebox_override("panel", _panel_style())
	_hud.add_child(_game_over_panel)

	_level_complete_panel = Panel.new()
	_level_complete_panel.visible = false
	_level_complete_panel.position = Vector2(160, 400)
	_level_complete_panel.size = Vector2(400, 320)
	_level_complete_panel.add_theme_stylebox_override("panel", _panel_style())
	_hud.add_child(_level_complete_panel)

func _update_info_label() -> void:
	_info_label.text = "Monde %d - Niveau %d" % [_current_world, _current_level]
	_score_label.text = "Pièces : %d (total : %d)" % [_coins_this_run, SaveManager.coins]
	_lives_label.text = "Vies : %d/%d" % [SaveManager.get_lives(), SaveManager.MAX_LIVES]

func _show_game_over_panel() -> void:
	for child in _game_over_panel.get_children():
		child.queue_free()

	var lives_left: int = SaveManager.get_lives()

	var label := Label.new()
	label.text = "Perdu !\nVies restantes : %d/%d" % [lives_left, SaveManager.MAX_LIVES]
	label.position = Vector2(20, 20)
	_style_label(label, 20)
	_game_over_panel.add_child(label)

	var continue_btn := Button.new()
	continue_btn.text = "Continuer ici (pub)"
	continue_btn.position = Vector2(20, 90)
	continue_btn.custom_minimum_size = Vector2(360, 44)
	_style_button(continue_btn, COLOR_AD)
	continue_btn.pressed.connect(_on_continue_with_ad_pressed)
	_game_over_panel.add_child(continue_btn)

	if lives_left > 0:
		var retry_btn := Button.new()
		retry_btn.text = "Rejouer le niveau"
		retry_btn.position = Vector2(20, 150)
		retry_btn.custom_minimum_size = Vector2(360, 44)
		_style_button(retry_btn, COLOR_PRIMARY)
		retry_btn.pressed.connect(func(): _start_level(_current_world, _current_level))
		_game_over_panel.add_child(retry_btn)
	else:
		var refill_btn := Button.new()
		refill_btn.text = "Regarder une pub pour +1 vie"
		refill_btn.position = Vector2(20, 150)
		refill_btn.custom_minimum_size = Vector2(360, 44)
		_style_button(refill_btn, COLOR_AD)
		refill_btn.pressed.connect(func():
			refill_btn.disabled = true
			AdManager.show_rewarded_ad()
			await AdManager.rewarded_ad_completed
			SaveManager.refill_one_life()
			_show_game_over_panel()
		)
		_game_over_panel.add_child(refill_btn)

		var wait_min: int = int(ceil(SaveManager.seconds_until_next_life() / 60.0))
		var wait_label := Label.new()
		wait_label.text = "(ou attendre ~%d min pour une vie gratuite)" % wait_min
		wait_label.position = Vector2(20, 200)
		_style_label(wait_label, 14)
		_game_over_panel.add_child(wait_label)

		var menu_btn2 := Button.new()
		menu_btn2.text = "Retour au menu"
		menu_btn2.position = Vector2(20, 240)
		menu_btn2.custom_minimum_size = Vector2(360, 44)
		_style_button(menu_btn2, COLOR_SECONDARY)
		menu_btn2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
		_game_over_panel.add_child(menu_btn2)

	_game_over_panel.visible = true

func _show_level_complete_panel(reward: int) -> void:
	for child in _level_complete_panel.get_children():
		child.queue_free()

	var label := Label.new()
	label.text = "Niveau terminé !\n+%d pièces" % reward
	label.position = Vector2(20, 20)
	_style_label(label, 20)
	_level_complete_panel.add_child(label)

	var double_btn := Button.new()
	double_btn.text = "Doubler les pièces (pub)"
	double_btn.position = Vector2(20, 100)
	double_btn.custom_minimum_size = Vector2(360, 44)
	_style_button(double_btn, COLOR_AD)
	double_btn.pressed.connect(func():
		double_btn.disabled = true
		AdManager.show_rewarded_ad()
		await AdManager.rewarded_ad_completed
		SaveManager.add_coins(reward)
		label.text = "Niveau terminé !\n+%d pièces (doublé)" % (reward * 2)
	)
	_level_complete_panel.add_child(double_btn)

	var next_btn := Button.new()
	next_btn.text = "Niveau suivant"
	next_btn.position = Vector2(20, 160)
	next_btn.custom_minimum_size = Vector2(360, 44)
	_style_button(next_btn, COLOR_PRIMARY)
	next_btn.pressed.connect(_on_next_level_pressed)
	_level_complete_panel.add_child(next_btn)

	var menu_btn3 := Button.new()
	menu_btn3.text = "Retour au menu"
	menu_btn3.position = Vector2(20, 220)
	menu_btn3.custom_minimum_size = Vector2(360, 44)
	_style_button(menu_btn3, COLOR_SECONDARY)
	menu_btn3.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_level_complete_panel.add_child(menu_btn3)

	_level_complete_panel.visible = true

func _on_continue_with_ad_pressed() -> void:
	_game_over_panel.visible = false
	AdManager.show_rewarded_ad()
	await AdManager.rewarded_ad_completed
	_state = State.PLAYING
	_player.revive_at(Vector2(max(PLAYER_START_X, _player.global_position.x - 300), GROUND_Y - PLAYER_REST_OFFSET))

func _on_next_level_pressed() -> void:
	_level_complete_panel.visible = false
	AdManager.show_interstitial()
	await AdManager.interstitial_closed
	var next_level := _current_level + 1
	var next_world := _current_world
	if LevelData.is_last_level_of_world(_current_level):
		next_level = 1
		next_world += 1
	Session.selected_world = next_world
	Session.selected_level = next_level
	_start_level(next_world, next_level)

func _notification(what: int) -> void:
	# Bouton "retour" Android : ramène au menu plutôt que de fermer l'app d'un coup.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
