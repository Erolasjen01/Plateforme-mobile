extends Node
# Autoload : AdManager
# Interface avec les pubs. En mode _mock_mode=true, simule les pubs (pratique pour
# tester le jeu dans l'éditeur sans avoir installé le vrai plugin AdMob).
#
# Pour brancher les vraies pubs (vérifié en juillet 2026) :
# 1. Dans l'éditeur Godot : AssetLib -> cherche "Admob" -> installe le plugin
#    "godot-admob" (godot-sdk-integrations, successeur du plugin Poing Studios,
#    actively maintenu) : https://github.com/godot-sdk-integrations/godot-admob
# 2. Project -> Project Settings -> Plugins -> active le plugin
# 3. Ajoute un noeud "Admob" à la scène principale (MainMenu.tscn), et renseigne
#    dans l'Inspecteur : App ID Android/iOS + IDs des unités publicitaires
#    (des IDs de test Google sont pré-remplis par défaut, pratique pour tester)
# 4. Passe `is_real = true` sur le noeud Admob uniquement en production
# 5. Passe _mock_mode à false ci-dessous et adapte les appels vers le noeud
#    Admob (ex: $"/root/MainMenu/Admob".show_rewarded_ad(), en connectant les
#    signaux rewarded_ad_reward / interstitial_ad_closed à rewarded_ad_completed
#    et interstitial_closed ci-dessous)

const LEVELS_BETWEEN_INTERSTITIALS := 3

var _levels_completed_since_ad: int = 0
var _mock_mode: bool = true

signal rewarded_ad_completed
signal rewarded_ad_failed
signal interstitial_closed

func _ready() -> void:
	if not _mock_mode:
		# Admob.init()
		# Admob.rewarded_ad_reward.connect(func(_currency, _amount): rewarded_ad_completed.emit())
		# Admob.interstitial_ad_closed.connect(func(): interstitial_closed.emit())
		pass

func show_rewarded_ad() -> void:
	if SaveManager.ads_removed:
		# Un joueur ayant payé pour retirer les pubs reçoit quand même la récompense
		rewarded_ad_completed.emit()
		return

	if _mock_mode:
		print("[AdManager] (simulation) Affichage d'une pub récompensée...")
		await get_tree().create_timer(1.0).timeout
		rewarded_ad_completed.emit()
	else:
		# Admob.show_rewarded_ad()
		pass

func show_interstitial(force: bool = false) -> void:
	if SaveManager.ads_removed:
		interstitial_closed.emit()
		return

	_levels_completed_since_ad += 1
	if not force and _levels_completed_since_ad < LEVELS_BETWEEN_INTERSTITIALS:
		interstitial_closed.emit()
		return

	_levels_completed_since_ad = 0
	if _mock_mode:
		print("[AdManager] (simulation) Affichage d'une pub interstitielle...")
		await get_tree().create_timer(0.5).timeout
		interstitial_closed.emit()
	else:
		# Admob.show_interstitial_ad()
		pass

func remove_ads_purchase() -> void:
	# À appeler depuis le vrai flux d'achat intégré (Google Play Billing / Apple IAP)
	SaveManager.ads_removed = true
	SaveManager.save_game()
