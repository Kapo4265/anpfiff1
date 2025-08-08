extends Node

# StatisticsCollector für KERN 3: Spieler/Team-Statistiken + Torjägerliste
# Sammelt alle Statistiken für 3-Liga-System laut Gesamtplan

const PerformanceRating = preload("res://scripts/core/PerformanceRating.gd")

signal statistics_updated()
signal table_updated(league_id: int)
signal scorer_list_updated()

# Liga-Tabellen für alle 3 Ligen
var league_tables: Dictionary = {
	1: {},  # 1. Liga
	2: {},  # 2. Liga  
	3: {}   # 3. Liga
}

# Torjägerliste (nur 1. Liga laut Gesamtplan)
var scorer_list: Array = []

# 11 of the day - beste Formation des Spieltags
var eleven_of_the_day: Dictionary = {}

# Spieler-Statistiken pro Liga
var player_stats: Dictionary = {}

# Team-Statistiken pro Liga
var team_stats: Dictionary = {}

# Karten-Statistiken
var card_stats: Dictionary = {
	"user_team": {"yellow": 0, "red": 0},  # Eigenes Team Karten
	"league_matchday": {"yellow": 0, "red": 0},  # 1.Liga Spieltag Karten
	"season_total": {"red": 0}  # Gesamte Saison Rote Karten
}

func _ready():
	# Verbinde mit MatchdayEngine Signals
	if MatchdayEngine:
		MatchdayEngine.user_match_completed.connect(_on_match_completed)
		MatchdayEngine.conference_match_completed.connect(_on_conference_match_completed)
		MatchdayEngine.all_leagues_completed.connect(_on_all_leagues_completed)
	
	# Verbinde mit LeagueManager für Initialisierung NACH Teams geladen
	if LeagueManager:
		LeagueManager.league_initialized.connect(_on_leagues_initialized)
	
	print("StatisticsCollector: Ready - warte auf Liga-Initialisierung")

func _on_leagues_initialized():
	# NACH LeagueManager-Initialisierung Tabellen erstellen
	print("StatisticsCollector: Liga-Initialisierung empfangen - erstelle Tabellen")
	_initialize_league_tables()
	_reset_matchday_card_stats()

func _initialize_league_tables():
	# Liga-Tabellen für alle 3 Ligen initialisieren
	for league_id in [1, 2, 3]:
		league_tables[league_id] = {}
		var teams = LeagueManager.get_league_teams(league_id)
		
		print("StatisticsCollector: Initialisiere Liga %d mit %d Teams" % [league_id, teams.size()])
		
		for team in teams:
			var team_id = team.id
			league_tables[league_id][team_id] = {
				"team_name": team.name,
				"matches_played": 0,
				"wins": 0,
				"draws": 0,
				"losses": 0,
				"goals_for": 0,
				"goals_against": 0,
				"goal_difference": 0,
				"points": 0,
				"home_goals": 0,
				"away_goals": 0,
				"home_wins": 0,
				"away_wins": 0
			}
			print("StatisticsCollector: Team %s (%s) zu Liga %d hinzugefügt" % [team_id, team.name, league_id])
	
	print("StatisticsCollector: League tables initialized for 3 leagues")

func _on_match_completed(result: Dictionary):
	# WICHTIG: Nur Liga-Spiele zählen für Statistiken, NICHT Pokalspiele!
	if not _is_league_match():
		print("StatisticsCollector: POKALSPIEL ignoriert - keine Liga-Statistiken")
		return
	
	# User-Match Statistiken verarbeiten
	print("StatisticsCollector: USER MATCH - %s %d:%d %s (Liga %d)" % [
		result.get("home_team", "?"), 
		result.get("home_goals", 0), 
		result.get("away_goals", 0), 
		result.get("away_team", "?"),
		LeagueManager.user_league
	])
	_process_match_result(LeagueManager.user_league, result)

func _on_conference_match_completed(league_id: int, home_team: String, away_team: String, result: Dictionary):
	# WICHTIG: Nur Liga-Spiele zählen für Statistiken, NICHT Pokalspiele!
	if not _is_league_match():
		return  # Pokalspiele werden ignoriert
	
	# Konferenz-Match Statistiken verarbeiten
	if league_id == 1:  # Nur 1. Liga detailliert
		print("StatisticsCollector: KONFERENZ MATCH Liga %d - %s %d:%d %s" % [
			league_id, home_team, result.get("home_goals", 0), result.get("away_goals", 0), away_team
		])
	_process_match_result(league_id, result)

func _on_all_leagues_completed():
	# WICHTIG: Nur Liga-Spieltage zählen für Statistiken, NICHT Pokalspiele!
	if not _is_league_match():
		print("StatisticsCollector: Pokal-Spieltag - KEINE 11ofTheDay Berechnung")
		return  # Pokalspiele werden ignoriert
	
	# DIREKTER ZUGRIFF auf MatchdayEngine Ergebnisse für Performance
	var simulation_results = MatchdayEngine.get_current_simulation_results()
	
	# Andere Ligen verarbeiten (da keine Signals gesendet werden)
	for league_id in simulation_results.get("other_leagues_results", {}).keys():
		print("StatisticsCollector: Verarbeite Liga %d mit %d Matches" % [
			league_id, simulation_results.other_leagues_results[league_id].size()
		])
		for match_data in simulation_results.other_leagues_results[league_id]:
			print("StatisticsCollector: Liga %d - %s %d:%d %s" % [
				league_id, 
				match_data.home_team, 
				match_data.result.get("home_goals", 0), 
				match_data.result.get("away_goals", 0), 
				match_data.away_team
			])
			_process_match_result(league_id, match_data.result)
	
	# Nach allen Matches: Tabellen sortieren und Signals senden
	_sort_all_league_tables()
	_update_scorer_list()
	_update_eleven_of_the_day()
	_print_debug_summary()
	
	# Karten-Statistiken für nächsten Spieltag vorbereiten  
	_reset_matchday_card_stats()
	
	statistics_updated.emit()
	print("StatisticsCollector: All statistics updated")

func _process_match_result(league_id: int, result: Dictionary):
	var home_team = result.get("home_team", "")
	var away_team = result.get("away_team", "")
	var home_goals = result.get("home_goals", 0)
	var away_goals = result.get("away_goals", 0)
	
	if home_team == "" or away_team == "":
		return
	
	# Liga-Tabelle aktualisieren (alle Ligen)
	_update_league_table(league_id, home_team, away_team, home_goals, away_goals)
	
	# Torjägerliste und Events NUR für 1. Liga
	if league_id != 1:
		return  # Nur 1. Liga bekommt Torjäger/Events
	
	# Torjägerliste und Events für 1. Liga
	var events = result.get("events", [])
	if not events.is_empty():
		print("StatisticsCollector: Liga 1 - %d Events gefunden, verarbeite für Torjägerliste..." % events.size())
		_update_player_stats(home_team, away_team, events)
	else:
		print("StatisticsCollector: Liga 1 - KEINE Events vorhanden (Match-Type ohne Events)")
	# Liga 2/3: nur Tabellen-Updates

func _update_league_table(league_id: int, home_team: String, away_team: String, home_goals: int, away_goals: int):
	if not league_tables.has(league_id):
		return
	
	# EU-Teams ignorieren - gehören nicht in deutsche Liga-Tabellen
	if _is_eu_team(home_team) or _is_eu_team(away_team):
		print("StatisticsCollector: EU-Team Match ignoriert - %s vs %s" % [home_team, away_team])
		return
	
	var table = league_tables[league_id]
	
	# DEBUG: Team-Existenz prüfen
	if not table.has(home_team):
		print("StatisticsCollector: WARNING - Heimteam %s nicht in Liga %d Tabelle gefunden!" % [home_team, league_id])
		return
	if not table.has(away_team):
		print("StatisticsCollector: WARNING - Auswärtsteam %s nicht in Liga %d Tabelle gefunden!" % [away_team, league_id])
		return
	
	# Heimteam aktualisieren
	var home_stats = table[home_team]
	home_stats.matches_played += 1
	home_stats.goals_for += home_goals
	home_stats.goals_against += away_goals
	home_stats.home_goals += home_goals
	
	if home_goals > away_goals:
		home_stats.wins += 1
		home_stats.home_wins += 1
		home_stats.points += 3
	elif home_goals == away_goals:
		home_stats.draws += 1
		home_stats.points += 1
	else:
		home_stats.losses += 1
	
	home_stats.goal_difference = home_stats.goals_for - home_stats.goals_against
	
	# Auswärtsteam aktualisieren
	var away_stats = table[away_team]
	away_stats.matches_played += 1
	away_stats.goals_for += away_goals
	away_stats.goals_against += home_goals
	away_stats.away_goals += away_goals
	
	if away_goals > home_goals:
		away_stats.wins += 1
		away_stats.away_wins += 1
		away_stats.points += 3
	elif away_goals == home_goals:
		away_stats.draws += 1
		away_stats.points += 1
	else:
		away_stats.losses += 1
	
	away_stats.goal_difference = away_stats.goals_for - away_stats.goals_against
	

func _update_player_stats(home_team: String, away_team: String, events: Array):
	# Spieler-Statistiken aus Events aktualisieren (nur 1. Liga)
	for event in events:
		var player_id = event.get("player_id", "")
		var event_type = event.get("type", -1)
		var team_id = event.get("team_id", "")
		var success = event.get("success", false)
		
		if player_id == "" or team_id == "":
			continue
		
		# Karten-Events verarbeiten (für Statistiken)
		if success and event_type in [EventEngine.EventType.GELBE_KARTE, EventEngine.EventType.ROTE_KARTE]:
			_process_card_event(event_type, team_id)
		
		# Erweiterte Tor-Event-Erkennung: ALLE Event-Typen die Tore erzeugen können
		var is_goal = false
		if success:
			match event_type:
				EventEngine.EventType.NORMAL_ATTACK, EventEngine.EventType.FREISTOSS, EventEngine.EventType.ALLEINGANG, EventEngine.EventType.ELFMETER, EventEngine.EventType.KOPFBALL, EventEngine.EventType.SPIELZUG:
					is_goal = true
		
		if not is_goal:
			continue
		
		
		if player_id == "p0001":
			print("StatisticsCollector: FEHLER - Platzhalter player_id 'p0001' gefunden! EventEngine muss echte IDs verwenden!")
			continue
		
		# Spieler-Eintrag erstellen falls nicht vorhanden
		if not player_stats.has(player_id):
			var player_data = GameManager.get_player(player_id)
			var player_name = "Unbekannt"
			if not player_data.is_empty():
				player_name = player_data.get("first_name", "") + " " + player_data.get("last_name", "")
			
			player_stats[player_id] = {
				"player_name": player_name,
				"team_id": team_id,
				"goals": 0,
				"home_goals": 0,
				"away_goals": 0,
				"assists": 0,
				"yellow_cards": 0,
				"red_cards": 0
			}
		
		var stats = player_stats[player_id]
		
		# Tor hinzufügen
		stats.goals += 1
		if team_id == home_team:
			stats.home_goals += 1
		else:
			stats.away_goals += 1
		
		print("StatisticsCollector: TOR - %s (%s) [%s] hat %d Tore" % [stats.player_name, team_id, player_id, stats.goals])

func _sort_all_league_tables():
	# Alle Liga-Tabellen nach Punkten sortieren
	for league_id in league_tables.keys():
		var teams_array = []
		
		for team_id in league_tables[league_id].keys():
			var team_data = league_tables[league_id][team_id].duplicate()
			team_data["team_id"] = team_id
			teams_array.append(team_data)
		
		# Sortierung: 1. Punkte, 2. Tordifferenz, 3. Tore geschossen
		teams_array.sort_custom(func(a, b):
			if a.points != b.points:
				return a.points > b.points
			if a.goal_difference != b.goal_difference:
				return a.goal_difference > b.goal_difference
			return a.goals_for > b.goals_for
		)
		
		# Position hinzufügen
		for i in range(teams_array.size()):
			teams_array[i]["position"] = i + 1
		
		# Zurück in Dictionary speichern
		var sorted_table = {}
		for team_data in teams_array:
			sorted_table[team_data.team_id] = team_data
		
		league_tables[league_id] = sorted_table
		table_updated.emit(league_id)

func _update_scorer_list():
	# Torjägerliste für 1. Liga erstellen und sortieren
	scorer_list.clear()
	
	for player_id in player_stats.keys():
		var stats = player_stats[player_id]
		if stats.goals > 0:
			scorer_list.append({
				"player_id": player_id,
				"player_name": stats.player_name,
				"team_id": stats.team_id,
				"goals": stats.goals,
				"home_goals": stats.home_goals,
				"away_goals": stats.away_goals
			})
	
	# Nach Toren sortieren
	scorer_list.sort_custom(func(a, b): return a.goals > b.goals)
	
	# Positionen hinzufügen
	for i in range(scorer_list.size()):
		scorer_list[i]["position"] = i + 1
	
	scorer_list_updated.emit()

func _update_eleven_of_the_day():
	# PERFORMANCE: Events werden bereits in _process_match_result() gesammelt
	# Nutze diese statt neue Event-Sammlung
	print("StatisticsCollector: Delegating 11 of the day calculation to PerformanceRating...")
	
	# Sammle alle bereits verarbeiteten 1.Liga Events
	var all_liga1_events = []
	
	# User Match Events
	var simulation_results = MatchdayEngine.get_current_simulation_results()
	var user_match = simulation_results.get("user_match", {})
	if not user_match.is_empty():
		all_liga1_events.append_array(user_match.get("events", []))
	
	# Conference Match Events (bereits in _process_match_result verarbeitet)
	var conference_results = simulation_results.get("conference_results", {}).get(1, [])
	for conf_match in conference_results:
		all_liga1_events.append_array(conf_match.get("result", {}).get("events", []))
	
	print("StatisticsCollector: Gefunden %d Events für 11 of the day" % all_liga1_events.size())
	
	# PerformanceRating macht die komplette Berechnung
	eleven_of_the_day = PerformanceRating.calculate_eleven_of_the_day(all_liga1_events)
	
	print("StatisticsCollector: 11 of the day delegation completed")


# _count_eleven_players() WURDE NACH PerformanceRating.gd AUSGELAGERT

func get_league_table(league_id: int) -> Dictionary:
	return league_tables.get(league_id, {})

func get_scorer_list() -> Array:
	return scorer_list

func get_eleven_of_the_day() -> Dictionary:
	return eleven_of_the_day

func get_team_stats(team_id: String, league_id: int) -> Dictionary:
	var table = league_tables.get(league_id, {})
	return table.get(team_id, {})

func get_player_stats(player_id: String) -> Dictionary:
	return player_stats.get(player_id, {})

func get_league_top_scorer(league_id: int) -> Dictionary:
	if league_id == 1 and not scorer_list.is_empty():
		return scorer_list[0]
	return {}

func _print_debug_summary():
	print("\n=== STATISTIK DEBUG ZUSAMMENFASSUNG ===")
	
	# 1. Liga detailliert
	print("1. LIGA TABELLE (Top 5):")
	var liga1_teams = _get_sorted_league_teams(1)
	for i in range(min(5, liga1_teams.size())):
		var team = liga1_teams[i]
		print("  %d. %s - %dP (%d/%d/%d) %d:%d" % [
			team.position, team.team_name, team.points, 
			team.wins, team.draws, team.losses,
			team.goals_for, team.goals_against
		])
	
	# Torjägerliste Top 3
	if not scorer_list.is_empty():
		print("TORJÄGERLISTE 1. LIGA (Top 3):")
		for i in range(min(3, scorer_list.size())):
			var scorer = scorer_list[i]
			print("  %d. %s (%s) - %d Tore" % [
				scorer.position, scorer.player_name, scorer.team_id, scorer.goals
			])
	else:
		print("TORJÄGERLISTE: Keine Tore gefunden")
	
	# 11 of the day
	if not eleven_of_the_day.is_empty():
		print("11 OF THE DAY:")
		for position in ["TW", "AB", "MF", "ST"]:
			if eleven_of_the_day.has(position):
				var position_players = eleven_of_the_day[position]
				for player in position_players:
					print("  %s: %s (%.1f) - %s" % [
						position, player.name, player.match_rating, 
						GameManager.get_team(player.team_id).get("team_name", "?")
					])
	else:
		print("11 OF THE DAY: Noch nicht berechnet")
	
	# 2./3. Liga Übersicht
	print("2. LIGA: Spitzenreiter - %s" % _get_league_leader(2))
	print("3. LIGA: Spitzenreiter - %s" % _get_league_leader(3))
	print("=== DEBUG ENDE ===\n")

func _get_sorted_league_teams(league_id: int) -> Array:
	var teams_array = []
	var table = league_tables.get(league_id, {})
	
	for team_id in table.keys():
		var team_data = table[team_id].duplicate()
		team_data["team_id"] = team_id
		teams_array.append(team_data)
	
	teams_array.sort_custom(func(a, b):
		if a.points != b.points:
			return a.points > b.points
		if a.goal_difference != b.goal_difference:
			return a.goal_difference > b.goal_difference
		return a.goals_for > b.goals_for
	)
	
	return teams_array

func _get_league_leader(league_id: int) -> String:
	var teams = _get_sorted_league_teams(league_id)
	if teams.is_empty():
		return "Keine Daten"
	
	var leader = teams[0]
	return "%s (%dP)" % [leader.team_name, leader.points]

func _process_card_event(event_type: int, team_id: String):
	# Karten-Statistiken aktualisieren
	var user_team_id = LeagueManager.user_team_id
	
	if event_type == EventEngine.EventType.GELBE_KARTE:
		# 1.Liga Spieltag Gelbe Karten (alle Teams)
		card_stats.league_matchday.yellow += 1
		
		# Eigenes Team Gelbe Karten
		if team_id == user_team_id:
			card_stats.user_team.yellow += 1
			
	elif event_type == EventEngine.EventType.ROTE_KARTE:
		# 1.Liga Spieltag Rote Karten (alle Teams)
		card_stats.league_matchday.red += 1
		
		# Eigenes Team Rote Karten
		if team_id == user_team_id:
			card_stats.user_team.red += 1
		
		# Saison-Gesamt Rote Karten (alle Teams)
		card_stats.season_total.red += 1

func _reset_matchday_card_stats():
	# Spieltag-Karten für neue Runde zurücksetzen
	card_stats.league_matchday.yellow = 0
	card_stats.league_matchday.red = 0

func get_card_statistics() -> Dictionary:
	# Liefert alle Karten-Statistiken für UI
	return {
		"user_team_yellow": card_stats.user_team.yellow,
		"user_team_red": card_stats.user_team.red,
		"matchday_yellow": card_stats.league_matchday.yellow,
		"matchday_red": card_stats.league_matchday.red,
		"season_total_red": card_stats.season_total.red
	}

func reset_season_stats():
	# Für neue Saison alle Statistiken zurücksetzen
	_initialize_league_tables()
	player_stats.clear()
	scorer_list.clear()
	
	# Karten-Statistiken zurücksetzen
	card_stats.user_team.yellow = 0
	card_stats.user_team.red = 0
	card_stats.season_total.red = 0
	_reset_matchday_card_stats()
	
	print("StatisticsCollector: Season stats reset")

func _is_league_match() -> bool:
	"""Prüft ob aktueller Spieltag Liga-Spiele enthält (nicht nur Pokalspiele)"""
	# Hole aktuelle Woche Info vom ScheduleGenerator
	var week_info = ScheduleGenerator.get_current_week_info()
	
	# Liga-Spieltage haben type "league" oder enthalten Liga-Spiele
	var week_type = week_info.get("type", "unknown")
	
	# Liga-Spieltage: "league", gemischte Spieltage: "mixed"
	# Reine Pokalspiele: "cup", "cup_dfb", etc.
	return week_type == "league" or week_type == "mixed"

func _is_eu_team(team_id: String) -> bool:
	"""Prüft ob es ein EU-Team ist (gehört nicht in deutsche Liga-Tabellen)"""
	return team_id.begins_with("t-eur-")
