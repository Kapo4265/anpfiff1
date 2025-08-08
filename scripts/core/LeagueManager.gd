extends Node

# 3-Liga-System Manager für KERN 3: SPIELTAG-SIMULATION
# Verwaltet 1. Liga (18 Teams), 2. Liga (18 Teams), 3. Liga (12 Teams)

signal league_initialized()
signal teams_loaded(league_id: int, teams: Array)

var leagues: Dictionary = {}
var user_team_id: String = ""
var user_league: int = 1  # User startet immer in 1. Liga

# Liga-Konfiguration für Testphase
var league_config = {
	1: {"name": "1. Liga", "teams": 18, "test_teams": true, "range": [1, 18]},
	2: {"name": "2. Liga", "teams": 18, "test_teams": true, "range": [19, 36]}, 
	3: {"name": "3. Liga", "teams": 12, "test_teams": true, "range": [37, 48]}
}

func _ready():
	# Warten bis GameManager Teams geladen hat
	if not GameManager.teams.is_empty():
		initialize_leagues()
	else:
		# Kurz warten und dann prüfen
		await get_tree().process_frame
		call_deferred("check_game_manager_ready")

func check_game_manager_ready():
	if not GameManager.teams.is_empty():
		initialize_leagues()
	else:
		# GameManager manuell initialisieren
		print("LeagueManager: GameManager not initialized, starting...")
		GameManager.initialize_game()
		await get_tree().process_frame
		
		if not GameManager.teams.is_empty():
			initialize_leagues()
		else:
			print("LeagueManager: Failed to load teams from GameManager")

func initialize_leagues():
	print("LeagueManager: Initializing 3-Liga-System...")
	
	# Prüfen ob GameManager Teams hat
	if GameManager.teams.is_empty():
		print("LeagueManager: GameManager teams not loaded yet")
		return
	
	# Alle 3 Ligen laden
	for league_id in league_config.keys():
		load_league_teams(league_id)
	
	print("LeagueManager: All leagues initialized")
	league_initialized.emit()

func load_league_teams(league_id: int):
	var config = league_config[league_id]
	var required_teams = config.teams
	
	var available_teams = []
	
	if config.has("test_teams") and config.test_teams:
		# TESTPHASE: Verwende Ranges für alle Ligen
		var range_start = config.range[0]
		var range_end = config.range[1]
		print("Loading %s: %d test teams (t%02d-t%02d)" % [config.name, required_teams, range_start, range_end])
		
		for i in range(range_start, range_end + 1):
			var team_key = "t%02d" % i
			var team_data = GameManager.teams[team_key]
			
			available_teams.append({
				"id": team_key,
				"name": team_data["team_name"],
				"tier": team_data["tier"],
				"city": team_data["city"],
				"data": team_data
			})
	else:
		# Normale Liga-Zuordnung nach league_name
		var target_league_name = config.league_name
		print("Loading %s: %d teams from league_name '%s'" % [config.name, required_teams, target_league_name])
		
		for team_key in GameManager.teams.keys():
			var team_data = GameManager.teams[team_key]
			var team_league = team_data["league_name"]
			
			if team_league == target_league_name:
				available_teams.append({
					"id": team_key,
					"name": team_data["team_name"],
					"tier": team_data["tier"],
					"city": team_data["city"],
					"data": team_data
				})
		
		# Auf gewünschte Anzahl begrenzen
		if available_teams.size() > required_teams:
			available_teams = available_teams.slice(0, required_teams)
	
	# Liga initialisieren
	leagues[league_id] = {
		"name": config.name,
		"teams": available_teams,
		"table": [],
		"current_matchday": 1,
		"max_matchdays": _get_max_matchdays(league_id),
		"season_finished": false
	}
	
	# Tabelle initialisieren
	initialize_league_table(league_id)
	
	print("%s loaded: %d teams" % [config.name, available_teams.size()])
	
	# Debug: Team IDs anzeigen
	if available_teams.size() > 0:
		var team_ids = []
		for team in available_teams:
			team_ids.append(team.id)
		print("  Team IDs: %s" % str(team_ids))
	
	teams_loaded.emit(league_id, available_teams)

func _get_max_matchdays(league_id: int) -> int:
	match league_id:
		1, 2: return 34  # 18 Teams = 34 Spieltage
		3: return 22     # 12 Teams = 22 Spieltage  
		_: return 34

func initialize_league_table(league_id: int):
	var teams = leagues[league_id].teams
	var table = []
	
	for team in teams:
		table.append({
			"team_id": team.id,
			"team_name": team.name,
			"position": 0,  # Wird nach erstem Spieltag berechnet
			"matches_played": 0,
			"wins": 0,
			"draws": 0,
			"losses": 0,
			"goals_for": 0,
			"goals_against": 0,
			"goal_difference": 0,
			"points": 0,
			"form": [], # Letzte 5 Spiele: ["W", "D", "L", ...]
			"home_record": {"w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0},
			"away_record": {"w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0}
		})
	
	leagues[league_id].table = table

func get_league_teams(league_id: int) -> Array:
	if not leagues.has(league_id):
		return []
	return leagues[league_id].teams

func get_league_table(league_id: int) -> Array:
	if not leagues.has(league_id):
		return []
	return leagues[league_id].table

func get_user_available_teams() -> Array:
	# User kann nur aus 1. Liga Teams wählen
	return get_league_teams(1)

func set_user_team(team_id: String) -> bool:
	# Prüfen ob Team in 1. Liga verfügbar
	var first_league_teams = get_league_teams(1)
	
	for team in first_league_teams:
		if team.id == team_id:
			user_team_id = team_id
			user_league = 1
			print("LeagueManager: User team set to %s (%s)" % [team.name, team_id])
			return true
	
	print("LeagueManager: Error - Team %s not found in 1. Liga" % team_id)
	return false

func get_user_team_data() -> Dictionary:
	if user_team_id == "":
		return {}
	
	for team in get_league_teams(user_league):
		if team.id == user_team_id:
			return team
	
	return {}

func get_team_league(team_id: String) -> int:
	for league_id in leagues.keys():
		for team in leagues[league_id].teams:
			if team.id == team_id:
				return league_id
	return -1

func update_table_after_match(league_id: int, home_team_id: String, away_team_id: String, home_goals: int, away_goals: int):
	var table = leagues[league_id].table
	var home_entry = null
	var away_entry = null
	
	# Teams in Tabelle finden
	for entry in table:
		if entry.team_id == home_team_id:
			home_entry = entry
		elif entry.team_id == away_team_id:
			away_entry = entry
	
	if not home_entry or not away_entry:
		print("LeagueManager: Error - Teams not found in league table")
		return
	
	# Statistiken updaten
	home_entry.matches_played += 1
	away_entry.matches_played += 1
	
	home_entry.goals_for += home_goals
	home_entry.goals_against += away_goals
	away_entry.goals_for += away_goals
	away_entry.goals_against += home_goals
	
	# Heim-/Auswärts-Rekorde
	if home_goals > away_goals:  # Heimsieg
		home_entry.wins += 1
		away_entry.losses += 1
		home_entry.points += 3
		home_entry.home_record.w += 1
		away_entry.away_record.l += 1
		_update_form(home_entry, "W")
		_update_form(away_entry, "L")
	elif away_goals > home_goals:  # Auswärtssieg
		away_entry.wins += 1
		home_entry.losses += 1
		away_entry.points += 3
		away_entry.away_record.w += 1
		home_entry.home_record.l += 1
		_update_form(away_entry, "W")
		_update_form(home_entry, "L")
	else:  # Unentschieden
		home_entry.draws += 1
		away_entry.draws += 1
		home_entry.points += 1
		away_entry.points += 1
		home_entry.home_record.d += 1
		away_entry.away_record.d += 1
		_update_form(home_entry, "D")
		_update_form(away_entry, "D")
	
	# Tordifferenz berechnen
	home_entry.goal_difference = home_entry.goals_for - home_entry.goals_against
	away_entry.goal_difference = away_entry.goals_for - away_entry.goals_against
	
	# Heim-/Auswärts-Tore
	home_entry.home_record.gf += home_goals
	home_entry.home_record.ga += away_goals
	away_entry.away_record.gf += away_goals
	away_entry.away_record.ga += home_goals
	
	# Tabelle neu sortieren
	_sort_league_table(league_id)

func _update_form(entry: Dictionary, result: String):
	entry.form.append(result)
	if entry.form.size() > 5:
		entry.form.pop_front()

func _sort_league_table(league_id: int):
	var table = leagues[league_id].table
	
	# Nach Punkten, Tordifferenz, Tore sortieren
	table.sort_custom(func(a, b):
		if a.points != b.points:
			return a.points > b.points
		elif a.goal_difference != b.goal_difference:
			return a.goal_difference > b.goal_difference
		else:
			return a.goals_for > b.goals_for
	)
	
	# Positionen aktualisieren
	for i in range(table.size()):
		table[i].position = i + 1

func get_current_matchday(league_id: int) -> int:
	if not leagues.has(league_id):
		return 1
	return leagues[league_id].current_matchday

func advance_matchday(league_id: int):
	if leagues.has(league_id):
		leagues[league_id].current_matchday += 1
		
		var max_matchdays = leagues[league_id].max_matchdays
		if leagues[league_id].current_matchday > max_matchdays:
			leagues[league_id].season_finished = true
			print("LeagueManager: %s season finished!" % leagues[league_id].name)

func is_season_finished(league_id: int) -> bool:
	if not leagues.has(league_id):
		return false
	return leagues[league_id].get("season_finished", false)

func get_league_info() -> Dictionary:
	return {
		"leagues_count": leagues.size(),
		"user_team": user_team_id,
		"user_league": user_league,
		"current_matchdays": {
			1: get_current_matchday(1),
			2: get_current_matchday(2),
			3: get_current_matchday(3)
		}
	}
