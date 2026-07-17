extends Node
# Autoload : SaveManager
# Gère la persistance : pièces, niveaux débloqués, vies (énergie), achat "suppression des pubs"

const SAVE_PATH := "user://save_data.cfg"
const MAX_LIVES := 5
const LIFE_REGEN_SECONDS := 20 * 60  # 1 vie gratuite toutes les 20 minutes

var coins: int = 0
var ads_removed: bool = false
var unlocked_world: int = 1
var unlocked_level: int = 1
var best_score: int = 0
var lives: int = MAX_LIVES
var last_life_lost_unix: int = 0
var sound_enabled: bool = true
var last_login_day: int = -1
var login_streak: int = 0

func _ready() -> void:
	load_game()
	_apply_life_regen()

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "ads_removed", ads_removed)
	cfg.set_value("progress", "unlocked_world", unlocked_world)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "lives", lives)
	cfg.set_value("progress", "last_life_lost_unix", last_life_lost_unix)
	cfg.set_value("progress", "sound_enabled", sound_enabled)
	cfg.set_value("progress", "last_login_day", last_login_day)
	cfg.set_value("progress", "login_streak", login_streak)
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	coins = cfg.get_value("progress", "coins", 0)
	ads_removed = cfg.get_value("progress", "ads_removed", false)
	unlocked_world = cfg.get_value("progress", "unlocked_world", 1)
	unlocked_level = cfg.get_value("progress", "unlocked_level", 1)
	best_score = cfg.get_value("progress", "best_score", 0)
	lives = cfg.get_value("progress", "lives", MAX_LIVES)
	last_life_lost_unix = cfg.get_value("progress", "last_life_lost_unix", 0)
	sound_enabled = cfg.get_value("progress", "sound_enabled", true)
	last_login_day = cfg.get_value("progress", "last_login_day", -1)
	login_streak = cfg.get_value("progress", "login_streak", 0)

func add_coins(amount: int) -> void:
	coins += amount
	save_game()

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		save_game()
		return true
	return false

func unlock_next_level(world: int, level: int) -> void:
	if world > unlocked_world or (world == unlocked_world and level >= unlocked_level):
		unlocked_world = world
		unlocked_level = level + 1
		save_game()

func _apply_life_regen() -> void:
	if lives >= MAX_LIVES or last_life_lost_unix == 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed: int = now - last_life_lost_unix
	var regenerated := int(elapsed / LIFE_REGEN_SECONDS)
	if regenerated > 0:
		lives = min(MAX_LIVES, lives + regenerated)
		if lives >= MAX_LIVES:
			last_life_lost_unix = 0
		else:
			last_life_lost_unix += regenerated * LIFE_REGEN_SECONDS
		save_game()

func get_lives() -> int:
	_apply_life_regen()
	return lives

func seconds_until_next_life() -> int:
	_apply_life_regen()
	if lives >= MAX_LIVES or last_life_lost_unix == 0:
		return 0
	var now := int(Time.get_unix_time_from_system())
	var elapsed: int = now - last_life_lost_unix
	return max(0, LIFE_REGEN_SECONDS - elapsed)

func lose_life() -> void:
	_apply_life_regen()
	if lives > 0:
		lives -= 1
		if last_life_lost_unix == 0:
			last_life_lost_unix = int(Time.get_unix_time_from_system())
		save_game()

func refill_one_life() -> void:
	_apply_life_regen()
	lives = min(MAX_LIVES, lives + 1)
	if lives >= MAX_LIVES:
		last_life_lost_unix = 0
	save_game()

func refill_all_lives() -> void:
	lives = MAX_LIVES
	last_life_lost_unix = 0
	save_game()

func toggle_sound() -> bool:
	sound_enabled = not sound_enabled
	save_game()
	return sound_enabled

func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400)

func get_daily_bonus_status() -> Dictionary:
	var today := _today()
	if last_login_day == today:
		return {"available": false, "streak": login_streak}
	var new_streak := 1
	if last_login_day == today - 1:
		new_streak = login_streak + 1
	if new_streak > 7:
		new_streak = 1
	return {"available": true, "streak": new_streak}

func claim_daily_bonus() -> int:
	var status := get_daily_bonus_status()
	if not status["available"]:
		return 0
	login_streak = status["streak"]
	last_login_day = _today()
	var reward: int = 10 * login_streak
	coins += reward
	save_game()
	return reward
