extends Node

signal match_result(home_team: String, away_team: String, home_goals: int, away_goals: int)
signal match_started(home_team: String, away_team: String)
signal match_ended()

var use_event_system: bool = true
var current_home_goals: int = 0
var current_away_goals: int = 0

func _ready():
	EventEngine.event_generated.connect(_on_event_generated)

func simulate_match(home_team_id: String, away_team_id: String, with_events: bool = true) -> Dictionary:
	current_home_goals = 0
	current_away_goals = 0
	
	match_started.emit(home_team_id, away_team_id)
	
	if with_events:
		return await simulate_match_with_events(home_team_id, away_team_id)
	else:
		return simulate_match_instant(home_team_id, away_team_id)

func simulate_match_with_events(home_team_id: String, away_team_id: String) -> Dictionary:
	EventEngine.start_match(home_team_id, away_team_id)
	
	for minute in range(1, 91):
		EventEngine.simulate_minute()
		await get_tree().process_frame
	
	return create_final_result(home_team_id, away_team_id)

# OPTION D: HYBRID-SYSTEM - Verschiedene Geschwindigkeiten je nach Match-Typ
func simulate_match_instant(home_team_id: String, away_team_id: String) -> Dictionary:
	# VOLLSTÄNDIGE Events für User-Match (wie bisher)
	return _simulate_with_full_events(home_team_id, away_team_id)


func simulate_match_lightning(home_team_id: String, away_team_id: String) -> Dictionary:
	# BLITZ-Modus für andere Ligen: Nur Ergebnis, 100x schneller
	return _simulate_result_only(home_team_id, away_team_id)

func _simulate_with_full_events(home_team_id: String, away_team_id: String) -> Dictionary:
	# Originale vollständige Simulation (wie bisher)
	current_home_goals = 0
	current_away_goals = 0
	
	# NACHSPIELZEIT-System zurücksetzen vor neuem Match
	EventEngine.reset_injury_time()
	EventEngine.start_match(home_team_id, away_team_id)
	
	# Original: 90 Minuten mit teamstärken-basierter Event-Chance
	for minute in range(1, 91):
		EventEngine.simulate_minute()
	
	# NACHSPIELZEIT: Berechne Nachspielzeit basierend auf Events
	var injury_time = 0
	if _should_have_injury_time(home_team_id, away_team_id):
		injury_time = EventEngine.calculate_injury_time(EventEngine.match_events)
		EventEngine.extend_match_for_injury_time(injury_time)
		
		# EINFACH: Bestehende simulate_minute() für Nachspielzeit nutzen
		for minute in range(91, 91 + injury_time):
			EventEngine.simulate_minute()
	
	# WICHTIG: Events sofort kopieren bevor sie durch nächstes Match gelöscht werden!
	var match_events_copy = EventEngine.match_events.duplicate()
	
	# Finale Tor-Zählung aus kopierten Events
	current_home_goals = _count_goals_from_events(home_team_id, match_events_copy)
	current_away_goals = _count_goals_from_events(away_team_id, match_events_copy)
	
	return create_final_result(home_team_id, away_team_id, match_events_copy)


func _simulate_result_only(home_team_id: String, away_team_id: String) -> Dictionary:
	# AUTHENTISCHES ANSTOSS 1 SYSTEM: Pure Teamstärke + Glücksfaktor Berechnung
	var home_strength: float
	var away_strength: float
	
	# Prüfe ob Teams im Cache sind (Liga-Teams)
	if MatchdayEngine.cached_team_strengths.has(home_team_id):
		var home_strength_cache = MatchdayEngine.cached_team_strengths[home_team_id]
		home_strength = home_strength_cache["home"]
	else:
		# Berechnung für nicht-gecachte Teams
		var home_team_data = GameManager.get_team(home_team_id)
		var home_team = TeamData.new(home_team_data)
		home_strength = home_team.calculate_team_strength(true, "Normal", "Normal")
	
	if MatchdayEngine.cached_team_strengths.has(away_team_id):
		var away_strength_cache = MatchdayEngine.cached_team_strengths[away_team_id]
		away_strength = away_strength_cache["away"]
	else:
		# Berechnung für nicht-gecachte Teams
		var away_team_data = GameManager.get_team(away_team_id)
		var away_team = TeamData.new(away_team_data)
		away_strength = away_team.calculate_team_strength(false, "Normal", "Normal")
	
	# Glücksfaktor: ±20% der schwächeren Team-Stärke für mehr Variation
	var weaker_strength = min(home_strength, away_strength)
	var luck_factor = (randf() - 0.5) * 0.4 * weaker_strength  # -20% bis +20%
	
	# Angepasste Stärken mit Glück
	var final_home_strength = home_strength + luck_factor
	var final_away_strength = away_strength - luck_factor
	
	# Exponential scaling für stärkere Teams (mehr Variation in Ergebnissen)
	var strength_ratio = max(home_strength, away_strength) / min(home_strength, away_strength)
	var bonus_factor = 1.0 + (strength_ratio - 1.0) * 0.3  # Stärkere Teams bekommen mehr Tor-Potenzial
	
	# Tor-Berechnung: Stärke direkt in Tor-Potenzial umwandeln
	# Basis-Formel: (stärke / 25) = durchschnittliche Tore
	var home_goal_potential = (final_home_strength / 25.0) * (bonus_factor if home_strength > away_strength else 1.0)
	var away_goal_potential = (final_away_strength / 25.0) * (bonus_factor if away_strength > home_strength else 1.0)
	
	# Integer-Umwandlung mit Nachkomma als Wahrscheinlichkeit
	current_home_goals = int(home_goal_potential)
	current_away_goals = int(away_goal_potential)
	
	# Nachkomma-Anteil als Zusatztor-Chance
	var home_decimal = home_goal_potential - current_home_goals
	var away_decimal = away_goal_potential - current_away_goals
	
	if randf() < home_decimal:
		current_home_goals += 1
	if randf() < away_decimal:
		current_away_goals += 1
	
	return create_final_result(home_team_id, away_team_id, [])  # Keine Events


# Poisson-Funktion entfernt - Anstoss 1 ist rein stärkebasiert, KEIN Zufall!


func create_final_result(home_team_id: String, away_team_id: String, events_array: Array = []) -> Dictionary:
	# Verwende gecachte Stärken aus EventEngine statt neu zu berechnen
	var home_strength = _calculate_cached_team_strength(home_team_id, true)
	var away_strength = _calculate_cached_team_strength(away_team_id, false)
	
	var final_events = events_array if not events_array.is_empty() else EventEngine.match_events.duplicate()
	
	# NACHSPIELZEIT aus EventEngine übernehmen (bereits berechnet)
	var injury_time = EventEngine.injury_time_duration
	var final_minute = EventEngine.match_duration
	
	var result = {
		"home_team": home_team_id,
		"away_team": away_team_id,
		"home_goals": current_home_goals,
		"away_goals": current_away_goals,
		"home_strength": home_strength,
		"away_strength": away_strength,
		"winner": "",
		"draw": false,
		"events": final_events,
		"injury_time": injury_time,
		"final_minute": final_minute
	}
	
	if current_home_goals > current_away_goals:
		result.winner = home_team_id
	elif current_away_goals > current_home_goals:
		result.winner = away_team_id
	else:
		result.draw = true
	
	match_result.emit(home_team_id, away_team_id, current_home_goals, current_away_goals)
	match_ended.emit()
	
	return result

func _calculate_cached_team_strength(team_id: String, is_home: bool) -> float:
	# PERFORMANCE: Nutze MatchdayEngine cached strengths wenn vorhanden
	if MatchdayEngine.cached_team_strengths.has(team_id):
		var cache = MatchdayEngine.cached_team_strengths[team_id]
		return cache["home" if is_home else "away"]
	
	# Direkte Berechnung ohne TeamData.new()
	var team_data = GameManager.get_team(team_id)
	var lineup = team_data.get("starting_eleven", [])
	if lineup.is_empty():
		print("MatchEngine: Team %s hat keine starting_eleven - generiere aus besten Spielern" % team_id)
		# Lineup aus besten Spielern je Position generieren
		var team_obj = TeamData.new(team_data)
		lineup = team_obj.generate_lineup()  # Beste Spieler je Position in 4-4-2 Formation
		# Lineup im GameManager speichern für zukünftige Verwendung
		GameManager.teams[team_id]["starting_eleven"] = lineup
		print("MatchEngine: Beste Aufstellung für %s generiert (%d Spieler)" % [team_id, lineup.size()])
	
	var total_strength = 0.0
	var count = 0
	for player_id in lineup.slice(0, 11):
		if player_id == "" or player_id == null:
			print("MatchEngine: WARNUNG - Leere Player-ID in Team %s Lineup!" % team_id)
			continue
			
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			var base = player_data.get("strength_overall_base", 50)
			var form = player_data.get("current_form", 10)
			total_strength += base * (1.0 + (form - 10) * 0.02)
			count += 1
		else:
			print("MatchEngine: WARNUNG - Spieler %s nicht gefunden für Team %s!" % [player_id, team_id])
	
	var avg_strength = total_strength / max(count, 1)
	return avg_strength * (1.05 if is_home else 1.0)  # Heimvorteil

func _on_event_generated(event_data: Dictionary):
	if event_data.success:
		# Normale Tore (für das eigene Team)
		if event_data.type in [EventEngine.EventType.NORMAL_ATTACK, EventEngine.EventType.FREISTOSS, EventEngine.EventType.ALLEINGANG, EventEngine.EventType.ELFMETER, EventEngine.EventType.KOPFBALL, EventEngine.EventType.SPIELZUG]:
			if event_data.team_id == EventEngine.home_team_id:
				current_home_goals += 1
			else:
				current_away_goals += 1
		# Eigentore (für die gegnerische Mannschaft)
		elif event_data.type == EventEngine.EventType.EIGENTOR:
			if event_data.team_id == EventEngine.home_team_id:
				current_away_goals += 1  # Heimteam schießt Eigentor → Auswärtsteam bekommt Tor
			else:
				current_home_goals += 1  # Auswärtsteam schießt Eigentor → Heimteam bekommt Tor

func _count_goals_from_events(team_id: String, events: Array) -> int:
	var goal_count = 0
	
	for event in events:
		if event.success:
			# Normale Tore für das eigene Team
			if event.team_id == team_id and event.type in [EventEngine.EventType.NORMAL_ATTACK, EventEngine.EventType.FREISTOSS, EventEngine.EventType.ALLEINGANG, EventEngine.EventType.ELFMETER, EventEngine.EventType.KOPFBALL, EventEngine.EventType.SPIELZUG]:
				goal_count += 1
			# Eigentore des Gegners zählen für unser Team
			elif event.team_id != team_id and event.type == EventEngine.EventType.EIGENTOR:
				goal_count += 1
	
	return goal_count

func get_match_result_text(result: Dictionary) -> String:
	var home_name = GameManager.get_team(result.home_team)["team_name"]
	var away_name = GameManager.get_team(result.away_team)["team_name"]
	
	return "%s %d:%d %s" % [home_name, result.home_goals, result.away_goals, away_name]

# ====== NACHSPIELZEIT-FUNKTIONEN ======

func _should_have_injury_time(home_team: String, away_team: String) -> bool:
	"""Prüft ob Match Nachspielzeit haben soll"""
	var user_team = LeagueManager.user_team_id
	
	# Liga 1 Matches (User + Konferenz) - ALLE Liga 1 Matches
	if _is_league_1_team(home_team) and _is_league_1_team(away_team):
		return true
	
	# User-Pokale (nur wenn User beteiligt)
	if home_team == user_team or away_team == user_team:
		return _is_cup_match(home_team, away_team)
	
	return false

func _is_league_1_team(team_id: String) -> bool:
	"""Prüft ob Team in Liga 1 spielt"""
	return LeagueManager.get_team_league(team_id) == 1

func _is_cup_match(home_team: String, away_team: String) -> bool:
	"""Prüft ob Match ein Pokalspiel ist"""
	# Vereinfacht: Wenn einer der Teams nicht in den deutschen Ligen ist
	var home_league = LeagueManager.get_team_league(home_team)
	var away_league = LeagueManager.get_team_league(away_team) 
	
	# EU-Teams (t-eur-*) oder Amateur-Teams haben league = 0
	return home_league == 0 or away_league == 0
