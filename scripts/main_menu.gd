extends Control
# Menu principal : sélection de monde/niveau, pièces, vies, achat "suppression pubs"

const COLOR_BG := Color(0.09, 0.11, 0.16)
const COLOR_CARD := Color(0.14, 0.16, 0.23, 0.97)
const COLOR_PRIMARY := Color(0.30, 0.68, 0.38)
const COLOR_AD := Color(0.56, 0.36, 0.86)
const COLOR_GOLD := Color(0.80, 0.62, 0.18)
const COLOR_UNLOCKED_NEXT := Color(0.25, 0.55, 0.85)
const COLOR_UNLOCKED_DONE := Color(0.30, 0.68, 0.38)
const COLOR_LOCKED := Color(0.28, 0.30, 0.36)

func _ready() -> void:
	_build_ui()

func _style_button(btn: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = color.darkened(0.3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	btn.add_theme_font_size_override("font_size", 16)

func _style_label(lbl: Label, size: int = 20, color: Color = Color.WHITE) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(720, 1280)
	add_child(bg)

	var hill := ColorRect.new()
	hill.color = Color(0.180, 0.690, 0.510, 0.25)
	hill.position = Vector2(0, 1000)
	hill.size = Vector2(720, 280)
	add_child(hill)

	var title := Label.new()
	title.text = "PLATEFORME MOBILE"
	title.position = Vector2(40, 50)
	_style_label(title, 34)
	add_child(title)

	var card := Panel.new()
	card.position = Vector2(30, 110)
	card.size = Vector2(660, 1130)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = COLOR_CARD
	card_sb.set_corner_radius_all(20)
	card.add_theme_stylebox_override("panel", card_sb)
	add_child(card)

	var coins_label := Label.new()
	coins_label.text = "🪙 %d" % SaveManager.coins
	coins_label.position = Vector2(60, 130)
	_style_label(coins_label, 22, Color(1.0, 0.85, 0.2))
	add_child(coins_label)

	var lives := SaveManager.get_lives()
	var lives_label := Label.new()
	if lives >= SaveManager.MAX_LIVES:
		lives_label.text = "❤ %d/%d" % [lives, SaveManager.MAX_LIVES]
	else:
		var wait_min: int = int(ceil(SaveManager.seconds_until_next_life() / 60.0))
		lives_label.text = "❤ %d/%d (+1 dans ~%d min)" % [lives, SaveManager.MAX_LIVES, wait_min]
	lives_label.position = Vector2(220, 130)
	_style_label(lives_label, 22, Color(1.0, 0.4, 0.45))
	add_child(lives_label)

	var remove_ads_btn := Button.new()
	remove_ads_btn.text = "Supprimer les pubs"
	remove_ads_btn.position = Vector2(460, 122)
	remove_ads_btn.custom_minimum_size = Vector2(200, 40)
	_style_button(remove_ads_btn, COLOR_GOLD)
	remove_ads_btn.pressed.connect(func():
		# TODO: brancher le vrai flux d'achat (Google Play Billing / Apple IAP)
		AdManager.remove_ads_purchase()
		_build_ui()
	)
	add_child(remove_ads_btn)

	var sound_btn := Button.new()
	sound_btn.text = "🔊 Son" if SaveManager.sound_enabled else "🔇 Son coupé"
	sound_btn.position = Vector2(460, 170)
	sound_btn.custom_minimum_size = Vector2(200, 36)
	_style_button(sound_btn, Color(0.32, 0.42, 0.58))
	sound_btn.pressed.connect(func():
		SaveManager.toggle_sound()
		_build_ui()
	)
	add_child(sound_btn)

	var bonus_status: Dictionary = SaveManager.get_daily_bonus_status()
	var content_start_y := 230
	if bonus_status["available"]:
		var bonus_panel := Panel.new()
		bonus_panel.position = Vector2(60, 215)
		bonus_panel.size = Vector2(600, 90)
		var bonus_sb := StyleBoxFlat.new()
		bonus_sb.bg_color = Color(0.80, 0.62, 0.18, 0.95)
		bonus_sb.set_corner_radius_all(16)
		bonus_panel.add_theme_stylebox_override("panel", bonus_sb)
		add_child(bonus_panel)

		var streak: int = bonus_status["streak"]
		var bonus_label := Label.new()
		bonus_label.text = "Bonus du jour ! (jour %d/7) : +%d pièces" % [streak, streak * 10]
		bonus_label.position = Vector2(80, 228)
		_style_label(bonus_label, 18)
		add_child(bonus_label)

		var claim_btn := Button.new()
		claim_btn.text = "Récupérer"
		claim_btn.position = Vector2(460, 258)
		claim_btn.custom_minimum_size = Vector2(160, 36)
		_style_button(claim_btn, COLOR_PRIMARY)
		claim_btn.pressed.connect(func():
			SaveManager.claim_daily_bonus()
			_build_ui()
		)
		add_child(claim_btn)
		content_start_y = 320

	if lives <= 0:
		var refill_btn := Button.new()
		refill_btn.text = "Regarder une pub pour +1 vie"
		refill_btn.position = Vector2(60, content_start_y)
		refill_btn.custom_minimum_size = Vector2(300, 40)
		_style_button(refill_btn, COLOR_AD)
		refill_btn.pressed.connect(func():
			refill_btn.disabled = true
			AdManager.show_rewarded_ad()
			await AdManager.rewarded_ad_completed
			SaveManager.refill_one_life()
			_build_ui()
		)
		add_child(refill_btn)
		content_start_y += 55

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50, content_start_y)
	scroll.custom_minimum_size = Vector2(620, 1120 - content_start_y)
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var can_play_new: bool = SaveManager.get_lives() > 0

	for world in range(1, LevelData.TOTAL_WORLDS + 1):
		for level in range(1, LevelData.LEVELS_PER_WORLD + 1):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(112, 80)
			var completed: bool = world < SaveManager.unlocked_world or (world == SaveManager.unlocked_world and level < SaveManager.unlocked_level)
			var is_next: bool = world == SaveManager.unlocked_world and level == SaveManager.unlocked_level
			var unlocked: bool = completed or is_next
			btn.text = "M%d-%d" % [world, level]

			var color := COLOR_LOCKED
			if completed:
				color = COLOR_UNLOCKED_DONE
			elif is_next:
				color = COLOR_UNLOCKED_NEXT
			_style_button(btn, color)

			btn.disabled = not unlocked or not can_play_new
			if unlocked and can_play_new:
				btn.pressed.connect(_on_level_button_pressed.bind(world, level))
			grid.add_child(btn)

func _on_level_button_pressed(world: int, level: int) -> void:
	SfxManager.play_click()
	Session.selected_world = world
	Session.selected_level = level
	get_tree().change_scene_to_file("res://Main.tscn")

func _notification(what: int) -> void:
	# Bouton "retour" Android : on est déjà au menu, donc on quitte proprement.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
