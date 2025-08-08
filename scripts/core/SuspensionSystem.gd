extends Node

# SuspensionSystem für KERN 2: Karten & Sperren Verwaltung
# Verwaltet Gelbe/Rote Karten und berechnet Sperren authentisch wie im echten Fußball

signal player_suspended(player_id: String, team_id: String, reason: String, duration: int)
signal player_injured(player_id: String, team_id: String, injury_info: Dictionary)

# Karten-Tracking pro Spieler
var player_cards: Dictionary = {}  # player_id -> {"yellow": int, "red": int, "suspension_games": int}
var player_injuries: Dictionary = {}  # player_id -> {"injury_info": Dictionary, "games_remaining": int}

func _ready():
	# Mit EventEngine verbinden für Karten/Verletzungs-Events
	if EventEngine:
		EventEngine.event_generated.connect(_on_event_generated)

func _on_event_generated(event_data: Dictionary):
	if not event_data.success:
		return
		
	var player_id = event_data.get("player_id", "")
	var team_id = event_data.get("team_id", "")
	
	if player_id == "" or team_id == "":
		return
	
	match event_data.type:
		EventEngine.EventType.GELBE_KARTE:
			_add_yellow_card(player_id, team_id)
		EventEngine.EventType.ROTE_KARTE:
			_add_red_card(player_id, team_id)
		EventEngine.EventType.VERLETZUNG:
			var injury_info = event_data.get("injury_info", {})
			_add_injury(player_id, team_id, injury_info)

func _add_yellow_card(player_id: String, team_id: String):
	if not player_cards.has(player_id):
		player_cards[player_id] = {"yellow": 0, "red": 0, "suspension_games": 0}
	
	player_cards[player_id].yellow += 1
	var yellow_count = player_cards[player_id].yellow
	
	print("SuspensionSystem: %s (%s) erhält Gelbe Karte (%d/5)" % [_get_player_name(player_id), team_id, yellow_count])
	
	# 5 Gelbe Karten = 1 Spiel Sperre (authentisch)
	if yellow_count >= 5:
		player_cards[player_id].suspension_games = 1
		player_cards[player_id].yellow = 0  # Reset nach Sperre
		_suspend_player(player_id, team_id, "5. Gelbe Karte", 1)

func _add_red_card(player_id: String, team_id: String):
	if not player_cards.has(player_id):
		player_cards[player_id] = {"yellow": 0, "red": 0, "suspension_games": 0}
	
	player_cards[player_id].red += 1
	
	# Rote Karte: Abhängig von Team-Einsatz (authentisch)
	var team_data = GameManager.get_team(team_id)
	var einsatz_level = team_data.get("default_einsatz", "Normal")
	
	var suspension_games = _calculate_red_card_suspension(einsatz_level)
	player_cards[player_id].suspension_games = suspension_games
	
	print("SuspensionSystem: %s (%s) erhält Rote Karte - %d Spiele gesperrt (Einsatz: %s)" % [
		_get_player_name(player_id), team_id, suspension_games, einsatz_level
	])
	
	_suspend_player(player_id, team_id, "Rote Karte", suspension_games)

func _calculate_red_card_suspension(einsatz_level: String) -> int:
	# Authentische Sperrendauer abhängig von Einsatz-Level
	match einsatz_level:
		"Lieb & Nett", "Fair":
			return 1  # Leichte Vergehen
		"Normal":
			return randi_range(1, 2)  # 1-2 Spiele
		"Hart":
			return randi_range(2, 3)  # 2-3 Spiele
		"Brutal":
			return 3  # Schwere Vergehen, immer 3 Spiele
		_:
			return 2  # Default

func _add_injury(player_id: String, team_id: String, injury_info: Dictionary):
	var duration = injury_info.get("duration", 2)
	
	player_injuries[player_id] = {
		"injury_info": injury_info,
		"games_remaining": duration
	}
	
	print("SuspensionSystem: %s (%s) verletzt - %s (%d Spiele)" % [
		_get_player_name(player_id), team_id, injury_info.get("name", "Verletzung"), duration
	])
	
	# Spieler als verletzt markieren
	var player_data = GameManager.get_player(player_id)
	if not player_data.is_empty():
		# WICHTIG: Direkte Änderungen am GameManager-Index
		GameManager.player_index[player_id]["verletzungsart"] = injury_info.get("name", "Verletzung")
		GameManager.player_index[player_id]["ist_gesperrt"] = true  # Verletzt = nicht spielberechtigt
	
	player_injured.emit(player_id, team_id, injury_info)

func _suspend_player(player_id: String, team_id: String, reason: String, duration: int):
	# Spieler als gesperrt markieren
	var player_data = GameManager.get_player(player_id)
	if not player_data.is_empty():
		GameManager.player_index[player_id]["ist_gesperrt"] = true
	
	player_suspended.emit(player_id, team_id, reason, duration)

func advance_matchday():
	# Nach jedem Spieltag: Sperren und Verletzungen reduzieren
	print("SuspensionSystem: Spieltag vorbei - reduziere Sperren und Verletzungen...")
	
	# Kartensperren reduzieren
	for player_id in player_cards.keys():
		var card_data = player_cards[player_id]
		if card_data.suspension_games > 0:
			card_data.suspension_games -= 1
			
			if card_data.suspension_games <= 0:
				# Sperre beendet
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					GameManager.player_index[player_id]["ist_gesperrt"] = false
				print("SuspensionSystem: %s - Kartensperre beendet" % _get_player_name(player_id))
	
	# Verletzungen reduzieren
	for player_id in player_injuries.keys():
		var injury_data = player_injuries[player_id]
		injury_data.games_remaining -= 1
		
		if injury_data.games_remaining <= 0:
			# Verletzung geheilt
			var player_data = GameManager.get_player(player_id)
			if not player_data.is_empty():
				GameManager.player_index[player_id]["verletzungsart"] = ""
				# Nur entsperren wenn keine Kartensperren bestehen
				var card_data = player_cards.get(player_id, {"suspension_games": 0})
				if card_data.suspension_games <= 0:
					GameManager.player_index[player_id]["ist_gesperrt"] = false
			
			print("SuspensionSystem: %s - Verletzung geheilt (%s)" % [
				_get_player_name(player_id), injury_data.injury_info.get("name", "")
			])
			player_injuries.erase(player_id)

func is_player_available(player_id: String) -> bool:
	# Prüft ob Spieler spielberechtigt ist (nicht gesperrt/verletzt)
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return false
	
	return not player_data.get("ist_gesperrt", false)

func get_player_suspension_info(player_id: String) -> Dictionary:
	# Liefert detaillierte Sperr-/Verletzungsinfos für UI
	var result = {
		"available": is_player_available(player_id),
		"yellow_cards": 0,
		"red_cards": 0,
		"suspension_games": 0,
		"injury_games": 0,
		"injury_name": ""
	}
	
	if player_cards.has(player_id):
		var card_data = player_cards[player_id]
		result.yellow_cards = card_data.yellow
		result.red_cards = card_data.red
		result.suspension_games = card_data.suspension_games
	
	if player_injuries.has(player_id):
		var injury_data = player_injuries[player_id]
		result.injury_games = injury_data.games_remaining
		result.injury_name = injury_data.injury_info.get("name", "")
	
	return result

func _get_player_name(player_id: String) -> String:
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return "Unbekannt"
	
	return player_data.get("first_name", "") + " " + player_data.get("last_name", "")

func reset_season_stats():
	# Für neue Saison: Karten zurücksetzen, Verletzungen behalten
	player_cards.clear()
	print("SuspensionSystem: Season stats reset - Karten gelöscht")