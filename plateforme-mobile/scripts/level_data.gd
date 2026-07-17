extends Node
# Autoload : LevelData
# Génère la config de difficulté pour chaque (monde, niveau), et un thème
# de couleurs différent par monde (pour varier visuellement sans avoir
# besoin d'assets externes).

const LEVELS_PER_WORLD := 5
const TOTAL_WORLDS := 6

const WORLD_THEMES := [
	{"sky": Color(0.55, 0.75, 0.95), "hills": Color(0.35, 0.55, 0.35), "ground_top": Color(0.4, 0.75, 0.35), "ground_body": Color(0.45, 0.32, 0.2)},
	{"sky": Color(0.95, 0.78, 0.55), "hills": Color(0.75, 0.5, 0.3), "ground_top": Color(0.85, 0.65, 0.3), "ground_body": Color(0.5, 0.35, 0.15)},
	{"sky": Color(0.62, 0.85, 0.9), "hills": Color(0.5, 0.7, 0.75), "ground_top": Color(0.85, 0.92, 0.95), "ground_body": Color(0.55, 0.6, 0.65)},
	{"sky": Color(0.32, 0.2, 0.45), "hills": Color(0.25, 0.15, 0.35), "ground_top": Color(0.45, 0.28, 0.55), "ground_body": Color(0.2, 0.12, 0.28)},
	{"sky": Color(0.85, 0.55, 0.6), "hills": Color(0.6, 0.35, 0.4), "ground_top": Color(0.75, 0.4, 0.45), "ground_body": Color(0.4, 0.22, 0.25)},
	{"sky": Color(0.12, 0.15, 0.22), "hills": Color(0.18, 0.2, 0.28), "ground_top": Color(0.35, 0.35, 0.45), "ground_body": Color(0.15, 0.15, 0.2)},
]

func get_level_config(world: int, level: int) -> Dictionary:
	var difficulty: float = 1.0 + (world - 1) * 0.15 + (level - 1) * 0.03
	return {
		"world": world,
		"level": level,
		"speed": 260.0 * difficulty,
		"gap_frequency": clamp(0.35 + difficulty * 0.05, 0.3, 0.75),
		"length": 40 + level * 4,
		"seed": world * 1000 + level,
		"coin_reward": 10 + world * 5,
	}

func get_world_theme(world: int) -> Dictionary:
	var idx: int = clamp(world - 1, 0, WORLD_THEMES.size() - 1)
	return WORLD_THEMES[idx]

func is_last_level_of_world(level: int) -> bool:
	return level >= LEVELS_PER_WORLD
