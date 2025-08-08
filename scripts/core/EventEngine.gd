extends Node

signal event_generated(event_data: Dictionary)
signal match_minute_changed(minute: int)
signal live_ticker_message(message: String, minute: int)

enum EventType {
	NORMAL_ATTACK,
	FREISTOSS,
	ALLEINGANG,
	ELFMETER,
	EIGENTOR,
	VERLETZUNG,
	TACKLING,
	ABSEITSFALLE,
	GELBE_KARTE,
	ROTE_KARTE,
	ABWEHRFEHLER,
	ECKBALL,
	KOPFBALL,
	RUECKPASS_SITUATION,
	SPIELZUG
}

var current_minute: int = 0
var is_match_running: bool = false
var home_team_id: String = ""
var away_team_id: String = ""
var match_events: Array = []
var cached_lineups: Dictionary = {}
var cached_player_strengths: Dictionary = {} # team_id -> {player_id: strength_value}
var base_team_strengths: Dictionary = {}     # team_id -> base_strength_ohne_spieler
var red_carded_players: Dictionary = {}     # team_id -> [player_ids] mit roten Karten
var injured_players: Dictionary = {}        # team_id -> [player_ids] mit Verletzungen
var substituted_players: Dictionary = {}    # team_id -> {out_player_id: in_player_id}
var events_this_minute: Array = []          # Events die bereits in aktueller Minute stattgefunden haben

# NACHSPIELZEIT-System
var match_duration: int = 90  # Standard 90 Min
var is_injury_time: bool = false
var injury_time_duration: int = 0

var card_reasons: Dictionary = {}
var injury_types: Dictionary = {}

func _ready():
	load_event_data()

func load_event_data():
	load_card_reasons()
	load_injury_types()

func load_card_reasons():
	var file = FileAccess.open("res://data/card_reasons.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			card_reasons = json.get_data()
			print("Card reasons loaded")
		else:
			print("Error parsing card_reasons.json")

func load_injury_types():
	var file = FileAccess.open("res://data/injury_types.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			injury_types = json.get_data()
			print("Injury types loaded")
		else:
			print("Error parsing injury_types.json")

func start_match(home_id: String, away_id: String):
	home_team_id = home_id
	away_team_id = away_id
	current_minute = 0
	is_match_running = true
	match_events.clear()
	cached_lineups.clear()
	cached_player_strengths.clear()
	base_team_strengths.clear()
	red_carded_players.clear()  # Reset rote Karten für neues Match
	injured_players.clear()     # Reset Verletzungen für neues Match
	substituted_players.clear() # Reset Einwechslungen für neues Match
	
	# Lineups und Spielerstärken zu Beginn des Matches cachen
	_cache_team_strength_data(home_id, true)
	_cache_team_strength_data(away_id, false)
	
	# Live-Status Listen initialisieren
	red_carded_players[home_id] = []
	red_carded_players[away_id] = []
	injured_players[home_id] = []
	injured_players[away_id] = []
	substituted_players[home_id] = {}
	substituted_players[away_id] = {}
	

func _cache_team_strength_data(team_id: String, is_home: bool):
	"""Cached Lineup + individuelle Spielerstärken + Basis-Teamstärke für Live-Berechnung"""
	var team_data = GameManager.get_team(team_id)
	
	var lineup = team_data.get("starting_eleven", [])
	if lineup.is_empty():
		print("EventEngine: Team %s hat keine starting_eleven - generiere aus besten Spielern" % team_id)
		var team_obj = TeamData.new(team_data)
		lineup = team_obj.generate_lineup()
		GameManager.teams[team_id]["starting_eleven"] = lineup
		print("EventEngine: Beste Aufstellung für %s generiert (%d Spieler)" % [team_id, lineup.size()])
	
	cached_lineups[team_id] = lineup
	cached_player_strengths[team_id] = {}
	
	# Individuelle Spielerstärken cachen (für automatischen Abzug/Addierung)
	var players_total_strength: float = 0.0
	for player_id in lineup.slice(0, 11):  # Nur starting 11
		if player_id != "" and player_id != null:
			var player_data = GameManager.get_player(player_id)
			if not player_data.is_empty():
				var player = PlayerData.new(player_data)
				var player_strength = player.get_effective_strength()
				cached_player_strengths[team_id][player_id] = player_strength
				players_total_strength += player_strength
	
	# Basis-Teamstärke (ohne Spieler): Moral + Heimvorteil + Modifikatoren
	var base_strength: float = 0.0
	base_strength += float(team_data.get("morale", 5))  # Team-Moral
	if is_home:
		base_strength += 4.0  # Heimvorteil
	
	base_team_strengths[team_id] = base_strength + players_total_strength
	print("📊 Team %s gecacht: %d Spieler, %.1f Gesamtstärke" % [team_id, cached_player_strengths[team_id].size(), base_team_strengths[team_id]])

func simulate_minute():
	if not is_match_running:
		return
	
	current_minute += 1
	events_this_minute.clear()  # Reset für neue Minute
	match_minute_changed.emit(current_minute)
	
	check_for_events()
	
	if current_minute >= 90:
		end_match()

func check_for_events():
	check_team_event(home_team_id, true)
	check_team_event(away_team_id, false)

func check_team_event(team_id: String, is_home: bool):
	# Prüfe ob bereits ein reguläres Event in dieser Minute stattgefunden hat
	if _has_regular_event_this_minute():
		return  # Keine weiteren Events in dieser Minute
	
	# Team-Stärke holen (aus Cache oder berechnen)
	var team_strength: float
	
	# DYNAMISCHE TEAMSTÄRKE: Rote Karten berücksichtigen
	team_strength = _calculate_live_team_strength(team_id, is_home)
	
	var event_chance = calculate_event_chance(team_strength)
	
	if randf() < event_chance:
		generate_event(team_id, is_home, team_strength)

func calculate_event_chance(team_strength: float) -> float:
	# ANSTOSS 1 AUTHENTISCH: Teamstärke direkt als Event-Wahrscheinlichkeit
	# Keine Base-Chance - alles hängt von der Teamstärke ab!
	# Stärke 40 → 8%, Stärke 60 → 12%, Stärke 80 → 16%
	return team_strength / 500.0

func _has_regular_event_this_minute() -> bool:
	"""Prüft ob bereits ein reguläres Event (kein Folgeevent) in dieser Minute stattgefunden hat"""
	for event in events_this_minute:
		# Folgeevents zählen nicht als "reguläre" Events
		if not _is_generated_followup_event(event):
			return true
	return false

func _is_generated_followup_event(event: Dictionary) -> bool:
	"""Prüft ob Event ein generiertes Folgeevent ist (nicht ein regulär gewürfeltes)"""
	# Folgeevents werden nur durch diese 3 Hauptevents ausgelöst
	var event_type = event.get("type")
	
	# Kopfball ist Folgeevent wenn ein Eckball in derselben Minute existiert
	if event_type == EventType.KOPFBALL:
		for other_event in events_this_minute:
			if other_event.get("type") == EventType.ECKBALL:
				return true
	
	# Normal Attack ist Folgeevent wenn Abwehrfehler/Rückpass in derselben Minute
	elif event_type == EventType.NORMAL_ATTACK:
		for other_event in events_this_minute:
			if other_event.get("type") in [EventType.ABWEHRFEHLER, EventType.RUECKPASS_SITUATION]:
				return true
	
	return false

func _calculate_live_team_strength(team_id: String, is_home: bool) -> float:
	"""Berechnet Live-Teamstärke durch automatischen Abzug/Addierung individueller Spielerstärken"""
	
	# Start mit gecachter Basis-Teamstärke
	var current_strength = base_team_strengths.get(team_id, 0.0)
	var player_strengths = cached_player_strengths.get(team_id, {})
	
	# Rote Karten: Spielerstärke abziehen
	for player_id in red_carded_players.get(team_id, []):
		var player_strength = player_strengths.get(player_id, 0.0)
		if player_strength > 0:
			current_strength -= player_strength
			# Debug-Output nur einmal pro Event, nicht bei jeder Berechnung
			# print("🔴 LIVE: -%s Stärke (Rote Karte %s)" % [player_strength, player_id])
	
	# Verletzungen: Originalspieler abziehen, Ersatzspieler addieren  
	for injured_player_id in injured_players.get(team_id, []):
		var original_strength = player_strengths.get(injured_player_id, 0.0)
		current_strength -= original_strength
		
		# Ersatzspieler addieren
		var substitute_id = substituted_players.get(team_id, {}).get(injured_player_id, "")
		if substitute_id != "":
			var substitute_strength = _get_player_strength(substitute_id)
			current_strength += substitute_strength
			# Debug-Output nur einmal pro Event
			# print("🚑 LIVE: -%s +%s Stärke (Verletzung %s → %s)" % [original_strength, substitute_strength, injured_player_id, substitute_id])
		else:
			pass # print("🚑 LIVE: -%s Stärke (Verletzung %s, kein Ersatz)" % [original_strength, injured_player_id])
	
	return current_strength

func _get_player_strength(player_id: String) -> float:
	"""Hilfsfunktion: Liefert Spielerstärke für Live-Berechnung"""
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return 0.0
	var player = PlayerData.new(player_data)
	return player.get_effective_strength()

func _track_red_card(player_id: String, team_id: String):
	"""Trackt rote Karte für Live-Teamstärke Berechnung"""
	if not red_carded_players.has(team_id):
		red_carded_players[team_id] = []
	
	if player_id not in red_carded_players[team_id]:
		red_carded_players[team_id].append(player_id)
		var player_strength = cached_player_strengths.get(team_id, {}).get(player_id, 0.0)
		print("🔴 ROTE KARTE TRACKER: Spieler %s von Team %s (-%s Stärke) - Live-Teamstärke reduziert!" % [player_id, team_id, player_strength])

func _track_injury(player_id: String, team_id: String):
	"""Trackt Verletzung für Live-Teamstärke Berechnung und simuliert Einwechslung"""
	if not injured_players.has(team_id):
		injured_players[team_id] = []
	
	if player_id not in injured_players[team_id]:
		injured_players[team_id].append(player_id)
		
		# Automatische Einwechslung simulieren
		var substitute_id = _get_substitute_player(team_id, player_id)
		if substitute_id != "":
			substituted_players[team_id][player_id] = substitute_id
			var original_strength = cached_player_strengths.get(team_id, {}).get(player_id, 0.0)
			var substitute_strength = _get_player_strength(substitute_id)
			print("🚑 VERLETZUNG TRACKER: %s (-%s) → %s (+%s) eingewechselt" % [player_id, original_strength, substitute_id, substitute_strength])
		else:
			print("🚑 VERLETZUNG TRACKER: %s verletzt, kein Ersatzspieler verfügbar!" % player_id)

func _get_substitute_player(team_id: String, injured_player_id: String) -> String:
	"""Findet besten verfügbaren Ersatzspieler aus der Bank"""
	var team_data = GameManager.get_team(team_id)
	var lineup = cached_lineups.get(team_id, [])
	
	# Bank-Spieler sind positions 11-21 im player_roster
	var bench_players = lineup.slice(11, 22)  # Bank-Spieler
	
	var best_substitute = ""
	var best_strength = 0.0
	
	for substitute_id in bench_players:
		if substitute_id == "" or substitute_id == null:
			continue
			
		# Bereits eingewechselte Spieler überspringen
		var already_used = false
		for used_sub in substituted_players.get(team_id, {}).values():
			if used_sub == substitute_id:
				already_used = true
				break
		
		if not already_used:
			var substitute_strength = _get_player_strength(substitute_id)
			if substitute_strength > best_strength:
				best_strength = substitute_strength
				best_substitute = substitute_id
	
	return best_substitute

func generate_event(team_id: String, is_home: bool, team_strength: float):
	var event_type = select_event_type(team_id)
	var event_data = create_event_data(event_type, team_id, is_home)
	
	# ERST Erfolg berechnen, DANN Signal senden
	var success = calculate_event_success(event_data)
	event_data.success = success
	
	
	var description = generate_event_description(event_data)
	event_data.description = description
	
	# Live-Events für Teamstärke-Tracking
	if success:
		if event_type == EventType.ROTE_KARTE:
			_track_red_card(event_data.player_id, event_data.team_id)
		elif event_type == EventType.VERLETZUNG:
			_track_injury(event_data.player_id, event_data.team_id)
	
	# Event zu aktueller Minute tracken (für Ein-Event-pro-Minute Regel)
	events_this_minute.append(event_data)
	
	# ERST ursprüngliches Event zur Liste hinzufügen und senden
	match_events.append(event_data)
	event_generated.emit(event_data)
	live_ticker_message.emit(description, event_data.minute)
	
	# DANN Folge-Events generieren (für korrekte Reihenfolge)
	if success and event_type in [EventType.ABWEHRFEHLER, EventType.RUECKPASS_SITUATION, EventType.ECKBALL]:
		match event_type:
			EventType.ABWEHRFEHLER:
				_generate_follow_up_event(event_data, EventType.NORMAL_ATTACK, true)
			EventType.RUECKPASS_SITUATION:
				_generate_follow_up_event(event_data, EventType.NORMAL_ATTACK, true)
			EventType.ECKBALL:
				_generate_follow_up_event(event_data, EventType.KOPFBALL, false)

func select_event_type(team_id: String) -> EventType:
	var weights = get_event_weights(team_id)
	var total_weight = 0.0
	
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for event_type in weights:
		current_weight += weights[event_type]
		if random_value <= current_weight:
			return event_type
	
	return EventType.NORMAL_ATTACK

func get_event_weights(team_id: String) -> Dictionary:
	var base_weights = {
		EventType.NORMAL_ATTACK: 50.0,  # Reduziert für mehr Event-Vielfalt
		EventType.FREISTOSS: 18.0,      # Erhöht für mehr Freistoß-Tore
		EventType.ALLEINGANG: 15.0,     # Leicht erhöht
		EventType.ELFMETER: 3.0,        # Leicht erhöht
		EventType.EIGENTOR: 1.0,
		EventType.VERLETZUNG: 4.0,
		EventType.TACKLING: 5.0,
		EventType.GELBE_KARTE: 3.0,
		EventType.ROTE_KARTE: 1.0,
		EventType.ABWEHRFEHLER: 8.0,
		EventType.ECKBALL: 20.0,        # Erhöht für mehr Eckbälle
		EventType.KOPFBALL: 12.0,       # Leicht erhöht für mehr Kopfball-Tore
		EventType.RUECKPASS_SITUATION: 3.0,
		EventType.SPIELZUG: 12.0        # Erhöht für mehr Spielzug-Tore
	}
	
	# Taktik-Modifikatoren anwenden
	var team_data = GameManager.get_team(team_id)
	if team_data.has("starting_eleven"):
		var team_obj = TeamData.new(team_data)
		var risk_modifiers = team_obj.get_event_risk_modifiers()
		
		# Spielweise beeinflusst Event-Häufigkeiten
		var event_mods = risk_modifiers.event_modifiers
		for event_type in event_mods:
			var godot_event_type = _get_eventtype_from_string(event_type)
			if base_weights.has(godot_event_type):
				base_weights[godot_event_type] *= event_mods[event_type]
		
		# Einsatz beeinflusst Karten- und Verletzungsrisiko
		base_weights[EventType.GELBE_KARTE] *= risk_modifiers.card_risk
		base_weights[EventType.ROTE_KARTE] *= risk_modifiers.card_risk
		base_weights[EventType.VERLETZUNG] *= risk_modifiers.injury_risk
		base_weights[EventType.TACKLING] *= risk_modifiers.card_risk
	
	return base_weights

func _get_eventtype_from_string(event_string: String) -> EventType:
	"""Konvertiert Event-String zu EventType Enum"""
	match event_string:
		"NORMAL_ATTACK": return EventType.NORMAL_ATTACK
		"FREISTOSS": return EventType.FREISTOSS
		"ALLEINGANG": return EventType.ALLEINGANG
		"ELFMETER": return EventType.ELFMETER
		"SPIELZUG": return EventType.SPIELZUG
		"TACKLING": return EventType.TACKLING
		"ABWEHRFEHLER": return EventType.ABWEHRFEHLER
		"ECKBALL": return EventType.ECKBALL
		"KOPFBALL": return EventType.KOPFBALL
		"RUECKPASS_SITUATION": return EventType.RUECKPASS_SITUATION
		_: return EventType.NORMAL_ATTACK

func create_event_data(event_type: EventType, team_id: String, is_home: bool) -> Dictionary:
	return {
		"type": event_type,
		"team_id": team_id,
		"minute": current_minute,
		"is_home": is_home,
		"player_id": select_event_player(team_id, event_type),
		"success": false,
		"description": ""
	}

func select_event_player(team_id: String, event_type: EventType) -> String:
	# Verwende gecachtes Lineup - keine erneute Generierung
	var lineup = cached_lineups.get(team_id, [])
	
	if lineup.is_empty():
		return ""
	
	var filtered_players = filter_players_by_event_type(lineup, event_type)
	
	if filtered_players.is_empty():
		return lineup[randi() % lineup.size()]
	
	return filtered_players[randi() % filtered_players.size()]

func filter_players_by_event_type(lineup: Array, event_type: EventType) -> Array:
	var suitable_players = []
	
	match event_type:
		EventType.ELFMETER, EventType.FREISTOSS:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["MF", "ST"]:
						suitable_players.append(player_id)
		EventType.ALLEINGANG, EventType.SPIELZUG:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["ST"]:
						suitable_players.append(player_id)
		EventType.ABWEHRFEHLER:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["AB"]:
						suitable_players.append(player_id)
		EventType.ECKBALL:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["MF", "ST"]:
						suitable_players.append(player_id)
		EventType.KOPFBALL:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["AB", "ST"]:
						suitable_players.append(player_id)
		EventType.RUECKPASS_SITUATION:
			for player_id in lineup:
				var player_data = GameManager.get_player(player_id)
				if not player_data.is_empty():
					# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
					var position = player_data.get("primary_position", "MF")
					if position in ["AB"]:
						suitable_players.append(player_id)
		_:
			suitable_players = lineup.duplicate()
	
	return suitable_players


func calculate_event_success(event_data: Dictionary) -> bool:
	var player_data = GameManager.get_player(event_data.player_id)
	if player_data.is_empty():
		return false
	
	# PERFORMANCE: Direkte Berechnung statt PlayerData.new()
	var base_strength = player_data.get("strength_overall_base", 50)
	var current_form = player_data.get("current_form", 10)
	var form_modifier = 1.0 + ((current_form - 10) * 0.02)
	var player_strength = base_strength * form_modifier
	
	# Taktik-Einflüsse auf Erfolgswahrscheinlichkeit
	var success_modifier = _get_tactical_success_modifier(event_data.team_id, event_data.type)
	
	# Event-Erfolgswahrscheinlichkeiten + authentische Karten-Logik + Taktik-Einfluss
	var base_chance = 0.0
	
	match event_data.type:
		EventType.NORMAL_ATTACK:
			base_chance = 0.08 + (player_strength * 0.01)  # 8-15% Tor-Chance
		EventType.FREISTOSS:
			# Zusätzlich: 15% Chance auf Gelbe Karte für Gegnerteam
			if randf() < 0.15:
				var card_reason = _get_random_card_reason(EventType.GELBE_KARTE)
				_generate_card_for_opponent(event_data, EventType.GELBE_KARTE, card_reason)
			base_chance = 0.12 + (player_strength * 0.012)  # 12-24% Tor-Chance (erhöht)
		EventType.ALLEINGANG:
			base_chance = 0.15 + (player_strength * 0.02)   # 15-30%
		EventType.ELFMETER:
			# Zusätzlich: 40% Chance auf Gelbe/Rote Karte für Gegnerteam  
			if randf() < 0.4:
				var card_type = EventType.GELBE_KARTE if randf() < 0.8 else EventType.ROTE_KARTE
				var card_reason = _get_random_card_reason(card_type)
				_generate_card_for_opponent(event_data, card_type, card_reason)
			base_chance = 0.75 + (player_strength * 0.01)  # 75-85%
		EventType.EIGENTOR:
			base_chance = 0.05  # 5% Eigentor-Wahrscheinlichkeit
		EventType.VERLETZUNG:
			# Verletzungsart aus JSON-Daten zuweisen
			base_chance = 0.8  # 80% Verletzung tritt ein
			if randf() < base_chance:
				var injury_info = _select_injury_from_json()
				event_data["injury_info"] = injury_info
				return true
			return false
		EventType.TACKLING:
			# Tackling kann Karten als Folge auslösen
			if randf() < 0.4:  # 40% Chance auf Karte beim Tackling
				var card_type = EventType.GELBE_KARTE if randf() < 0.85 else EventType.ROTE_KARTE
				var card_reason = _get_random_card_reason(card_type)
				_generate_card_for_opponent(event_data, card_type, card_reason)
			base_chance = 0.3   # 30% erfolgreiches Tackling
		EventType.GELBE_KARTE:
			# Realistischen Grund aus card_reasons.json wählen
			var reason = _get_random_card_reason(EventType.GELBE_KARTE)
			event_data["reason"] = reason
			base_chance = 0.9   # 90% Karte wird gezeigt
		EventType.ROTE_KARTE:
			# Realistischen Grund aus card_reasons.json wählen  
			var reason = _get_random_card_reason(EventType.ROTE_KARTE)
			event_data["reason"] = reason
			base_chance = 0.95  # 95% Karte wird gezeigt
		EventType.ABWEHRFEHLER:
			base_chance = 0.02 + (player_strength * 0.0006)  # 2-5% Abwehrfehler passiert
		EventType.ECKBALL:
			base_chance = 0.20 + (player_strength * 0.01)   # 20-25% Eckball kommt vors Tor  
		EventType.KOPFBALL:
			base_chance = 0.12 + (player_strength * 0.01)   # 12-18% Kopfballtor
		EventType.RUECKPASS_SITUATION:
			base_chance = 0.05 + (player_strength * 0.0004)  # 5-7% Rückpass-Fehler passiert
		EventType.SPIELZUG:
			# Spielzug-Training berücksichtigen - direktes Tor-Event
			var training_bonus = _get_spielzug_training_bonus(event_data.team_id)
			base_chance = (0.15 + (player_strength * 0.015)) * training_bonus  # 15-30% * Training
		_:
			base_chance = 0.1  # Default
	
	# Taktik-Modifikator anwenden und Erfolg bestimmen
	var final_chance = base_chance * success_modifier
	var success = randf() < final_chance
	
	return success

func _get_tactical_success_modifier(team_id: String, event_type: EventType) -> float:
	"""Berechnet Taktik-Einfluss auf Event-Erfolgswahrscheinlichkeit"""
	var team_data = GameManager.get_team(team_id)
	if not team_data.has("starting_eleven"):
		return 1.0
	
	var team_obj = TeamData.new(team_data)
	var risk_modifiers = team_obj.get_event_risk_modifiers()
	var event_mods = risk_modifiers.event_modifiers
	
	# Event-spezifische Modifikatoren
	match event_type:
		EventType.NORMAL_ATTACK:
			return event_mods.get("NORMAL_ATTACK", 1.0)
		EventType.FREISTOSS:
			return event_mods.get("FREISTOSS", 1.0)
		EventType.ALLEINGANG:
			return event_mods.get("ALLEINGANG", 1.0)
		EventType.TACKLING:
			return event_mods.get("TACKLING", 1.0)
		EventType.SPIELZUG:
			return event_mods.get("SPIELZUG", 1.0)
		EventType.ABWEHRFEHLER:
			return event_mods.get("ABWEHRFEHLER", 1.0)
		EventType.ECKBALL:
			return event_mods.get("ECKBALL", 1.0)
		EventType.KOPFBALL:
			return event_mods.get("KOPFBALL", 1.0)
		EventType.RUECKPASS_SITUATION:
			return event_mods.get("RUECKPASS_SITUATION", 1.0)
		_:
			return 1.0

func _generate_card_for_opponent(original_event: Dictionary, card_type: int, reason: String):
	# Karte für gegnerisches Team generieren
	var opponent_team = away_team_id if original_event.team_id == home_team_id else home_team_id
	var opponent_lineup = cached_lineups.get(opponent_team, [])
	
	if opponent_lineup.is_empty():
		return
	
	# Zufälligen Verteidiger/Mittelfeldspieler für Karten auswählen (realistischer)
	var defender_players = []
	for player_id in opponent_lineup:
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
			var position = player_data.get("primary_position", "MF")
			if position in ["AB", "MF"]:
				defender_players.append(player_id)
	
	var card_player = defender_players[randi() % defender_players.size()] if not defender_players.is_empty() else opponent_lineup[randi() % opponent_lineup.size()]
	
	# Karten-Event erstellen und zur Liste hinzufügen
	var card_event = {
		"type": card_type,
		"team_id": opponent_team,
		"minute": original_event.minute,
		"is_home": opponent_team == home_team_id,
		"player_id": card_player,
		"success": true,
		"description": "",
		"reason": reason
	}
	
	card_event.description = generate_event_description(card_event)
	events_this_minute.append(card_event)  # Karten-Events auch tracken
	match_events.append(card_event)
	event_generated.emit(card_event)

func _get_random_card_reason(card_type: EventType) -> String:
	"""Gibt zufälligen Karten-Grund aus card_reasons.json zurück"""
	if card_reasons.is_empty():
		print("FEHLER: Karten-Gründe nicht geladen!")
		assert(false, "CRITICAL: card_reasons.json muss verfügbar sein")
	
	match card_type:
		EventType.GELBE_KARTE:
			var yellow_reasons = card_reasons.get("yellow", ["Unsportliches Verhalten"])
			return yellow_reasons[randi() % yellow_reasons.size()]
		EventType.ROTE_KARTE:
			# Prüfe ob Gelb-Rot (zweite gelbe Karte) oder direkte rote Karte
			if randf() < 0.2:  # 20% Gelb-Rot
				var yellow_red_reasons = card_reasons.get("yellow_red", ["Zweite gelbe Karte"])
				return yellow_red_reasons[randi() % yellow_red_reasons.size()]
			else:
				var red_reasons = card_reasons.get("red", ["Grobes Foulspiel"])
				return red_reasons[randi() % red_reasons.size()]
		_:
			return "Regelverstoß"

func _select_injury_from_json() -> Dictionary:
	# Verletzungsart basierend auf Wahrscheinlichkeiten aus JSON auswählen
	var random_severity = randf()
	var severity_key = ""
	
	if random_severity < 0.4:
		severity_key = "leicht"
	elif random_severity < 0.8:
		severity_key = "mittel"  
	else:
		severity_key = "schwer"
	
	var severity_data = injury_types.get(severity_key, {})
	var injury_list = severity_data.get("types", [])
	
	if injury_list.is_empty():
		return {"name": "Verletzung", "duration": 2, "description": "Unbestimmte Verletzung"}
	
	var selected_injury = injury_list[randi() % injury_list.size()]
	var duration_range = selected_injury.get("duration_range", [1, 3])
	var actual_duration = randi_range(duration_range[0], duration_range[1])
	
	return {
		"name": selected_injury.get("name", "Verletzung"),
		"duration": actual_duration,
		"description": selected_injury.get("description", ""),
		"severity": severity_key
	}

func generate_event_description(event_data: Dictionary) -> String:
	var player_id = event_data.get("player_id", "")
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		print("EventEngine: FEHLER - Spieler %s nicht gefunden!" % player_id)
		return ""
	
	# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
	var first_name = player_data.get("first_name", "")
	var last_name = player_data.get("last_name", "")
	var player_name = first_name + " " + last_name
	
	# EU-Teams Fix: Leere Namen abfangen
	if player_name.strip_edges().is_empty():
		print("EventEngine: Player %s hat leeren Namen - Event wird übersprungen" % event_data.player_id)
		return ""  # Event ohne Namen nicht anzeigen
	
	match event_data.type:
		EventType.NORMAL_ATTACK:
			if event_data.success:
				return "%d' - TOOOR! %s trifft für %s!" % [event_data.minute, player_name, GameManager.get_team(event_data.team_id)["team_name"]]
			else:
				return "%d' - %s schießt knapp vorbei." % [event_data.minute, player_name]
		EventType.FREISTOSS:
			if event_data.success:
				return "%d' - Freistoßtor! %s trifft direkt!" % [event_data.minute, player_name]
			else:
				return "%d' - Freistoß von %s geht über das Tor." % [event_data.minute, player_name]
		EventType.ALLEINGANG:
			if event_data.success:
				return "%d' - Alleingang! %s überwindet den Keeper!" % [event_data.minute, player_name]
			else:
				return "%d' - %s scheitert im Alleingang." % [event_data.minute, player_name]
		EventType.ELFMETER:
			if event_data.success:
				return "%d' - Elfmeter verwandelt! %s bleibt cool." % [event_data.minute, player_name]
			else:
				return "%d' - Elfmeter verschossen! %s verzweifelt." % [event_data.minute, player_name]
		EventType.EIGENTOR:
			if event_data.success:
				return "%d' - EIGENTOR! Unglücklich von %s." % [event_data.minute, player_name]
			else:
				return "%d' - %s klärt gefährlich, aber erfolgreich." % [event_data.minute, player_name]
		EventType.GELBE_KARTE:
			if event_data.success:
				var reason = event_data.get("reason", "Unsportliches Verhalten")
				return "%d' - GELBE KARTE! %s sieht Gelb (%s)." % [event_data.minute, player_name, reason]
			else:
				return "%d' - Schiedsrichter lässt %s laufen." % [event_data.minute, player_name]
		EventType.ROTE_KARTE:
			if event_data.success:
				var reason = event_data.get("reason", "Tätlichkeit")
				return "%d' - ROTE KARTE! %s fliegt vom Platz (%s)!" % [event_data.minute, player_name, reason]
			else:
				return "%d' - Schiedsrichter zeigt %s nur Gelb." % [event_data.minute, player_name]
		EventType.TACKLING:
			if event_data.success:
				return "%d' - Harte Grätsche! %s bekommt eine Verwarnung." % [event_data.minute, player_name]
			else:
				return "%d' - %s geht fair in den Zweikampf." % [event_data.minute, player_name]
		EventType.VERLETZUNG:
			if event_data.success:
				var injury_info = event_data.get("injury_info", {"name": "Verletzung", "duration": 2})
				return "%d' - VERLETZUNG! %s bleibt liegen (%s, ~%d Spiele)." % [event_data.minute, player_name, injury_info.name, injury_info.duration]
			else:
				return "%d' - %s kann weiterspielen." % [event_data.minute, player_name]
		EventType.ABWEHRFEHLER:
			if event_data.success:
				return "%d' - ABWEHRFEHLER! %s leistet sich einen Patzer!" % [event_data.minute, player_name]
			else:
				return "%d' - %s kann den Ball noch abfangen." % [event_data.minute, player_name]
		EventType.ECKBALL:
			if event_data.success:
				return "%d' - ECKBALL! %s bringt den Ball vors Tor!" % [event_data.minute, player_name]
			else:
				return "%d' - Eckball von %s segelt über das Tor." % [event_data.minute, player_name]
		EventType.KOPFBALL:
			if event_data.success:
				return "%d' - KOPFBALL-TOR! %s steigt am höchsten!" % [event_data.minute, player_name]
			else:
				return "%d' - Kopfball von %s geht knapp vorbei." % [event_data.minute, player_name]
		EventType.RUECKPASS_SITUATION:
			if event_data.success:
				return "%d' - RÜCKPASS-SITUATION! %s spielt unglücklich zurück!" % [event_data.minute, player_name]
			else:
				return "%d' - Rückpass von %s kommt sicher beim Torwart an." % [event_data.minute, player_name]
		EventType.SPIELZUG:
			if event_data.success:
				return "%d' - SPIELZUG! %s vollendet einen tollen Angriff!" % [event_data.minute, player_name]
			else:
				return "%d' - Spielzug von %s wird abgeblockt." % [event_data.minute, player_name]
		_:
			return "%d' - Ereignis mit %s" % [event_data.minute, player_name]

func end_match():
	is_match_running = false

# ====== NACHSPIELZEIT-SYSTEM ======

func calculate_injury_time(events: Array) -> int:
	"""Berechnet Nachspielzeit basierend auf Events (0-8 Min)
	Events: Verletzung, Tore, Karten, Elfmeter"""
	var significant_events = 0
	
	for event in events:
		if _is_injury_time_relevant_event(event):
			significant_events += 1
	
	# Verbesserte Formel: Events / 4 = Minuten (aufgerundet), max 8 Min
	var injury_time = min(8, max(0, ceil(significant_events / 4.0)))
	
	print("EventEngine: Nachspielzeit berechnet - %d relevante Events → %d Minuten" % [significant_events, injury_time])
	return injury_time

func _is_injury_time_relevant_event(event: Dictionary) -> bool:
	"""Prüft ob Event Nachspielzeit verursacht - ALLE Events zählen für realistischere Berechnung"""
	var event_type = event.get("type")
	var relevant_types = [
		EventType.VERLETZUNG,
		EventType.GELBE_KARTE, 
		EventType.ROTE_KARTE, 
		EventType.ELFMETER,
		EventType.NORMAL_ATTACK,  # Tore
		EventType.FREISTOSS,      # Tore aus Freistößen
		EventType.ALLEINGANG,     # Tore aus Alleingängen  
		EventType.EIGENTOR,       # Eigentore
		# NEUE Events für realistische Nachspielzeit
		EventType.ABWEHRFEHLER,
		EventType.ECKBALL,
		EventType.KOPFBALL,
		EventType.RUECKPASS_SITUATION,
		EventType.SPIELZUG,
		EventType.TACKLING,
		EventType.ABSEITSFALLE
	]
	
	# Nur erfolgreiche Tore zählen für Nachspielzeit
	if event_type in [EventType.NORMAL_ATTACK, EventType.FREISTOSS, EventType.ALLEINGANG, EventType.EIGENTOR,
					  EventType.KOPFBALL, EventType.SPIELZUG]:
		return event.get("success", false)
	
	# Karten, Elfmeter, Verletzungen zählen immer
	return event_type in relevant_types

func extend_match_for_injury_time(injury_minutes: int):
	"""Erweitert Match um Nachspielzeit"""
	if injury_minutes > 0:
		match_duration = 90 + injury_minutes
		is_injury_time = true
		injury_time_duration = injury_minutes
		print("EventEngine: Match auf %d Minuten erweitert (Nachspielzeit: %d Min)" % [match_duration, injury_minutes])

func reset_injury_time():
	"""Setzt Nachspielzeit-System für neues Match zurück"""
	match_duration = 90
	is_injury_time = false
	injury_time_duration = 0

func _get_spielzug_training_bonus(team_id: String) -> float:
	"""Berechnet Training-Bonus für Spielzüge (1.0-1.5x)"""
	var team_data = GameManager.get_team(team_id)
	if not team_data.has("training"):
		return 1.2  # Default-Bonus für Teams ohne Training-Daten
	
	var training = team_data.get("training", {})
	var spielzug_points = training.get("Spielzüge", 3)  # Default 3 Punkte statt 0
	
	# 0 Punkte = 1.0x, 10 Punkte = 1.5x
	return 1.0 + (spielzug_points * 0.05)

func _generate_follow_up_event(original_event: Dictionary, follow_up_type: EventType, switch_team: bool):
	"""Generiert Folge-Event für Event-Ketten"""
	var follow_up_team_id = original_event.team_id
	var follow_up_is_home = original_event.is_home
	
	# Team wechseln für Abwehrfehler/Rückpass (Gegnerteam nutzt Fehler)
	if switch_team:
		follow_up_team_id = away_team_id if original_event.team_id == home_team_id else home_team_id
		follow_up_is_home = not original_event.is_home
	
	# Folge-Event erstellen
	var follow_up_event = create_event_data(follow_up_type, follow_up_team_id, follow_up_is_home)
	
	# Erfolg des Folge-Events berechnen
	var follow_up_success = calculate_event_success(follow_up_event)
	follow_up_event.success = follow_up_success
	
	# Beschreibung generieren
	var follow_up_description = generate_event_description(follow_up_event)
	follow_up_event.description = follow_up_description
	
	# Folge-Event zu aktueller Minute tracken
	events_this_minute.append(follow_up_event)
	
	# Folge-Event zur Liste hinzufügen und Signal senden
	match_events.append(follow_up_event)
	event_generated.emit(follow_up_event)
	
	# Live ticker für Live-Modus
	live_ticker_message.emit(follow_up_description, follow_up_event.minute)
