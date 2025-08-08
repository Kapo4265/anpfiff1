extends Node

signal season_changed(new_season: int)
signal matchday_changed(new_matchday: int)
signal match_finished(home_team: String, away_team: String, home_goals: int, away_goals: int)

var current_season: int = 1
var current_matchday: int = 1
var current_week: int = 1  # NEU: Woche im Saisonkalender (1-52)
var current_matchday_of_week: int = 1  # NEU: Spieltag innerhalb der Woche (1 oder 2)
var current_team_id: String = ""
var teams: Dictionary = {}
var players: Dictionary = {}
var player_index: Dictionary = {}  # PERFORMANCE: player_id -> player_data für O(1) Lookups
var is_initialized: bool = false

func _ready():
	print("GameManager initialized")

func load_teams():
	# NUR laden wenn noch keine Teams existieren (verhindert Moral-Reset)  
	if not teams.is_empty():
		print("Teams already loaded, keeping existing data with morale")
		return
		
	var file = FileAccess.open("res://data/master_teams.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			teams = json.get_data()
			print("Teams loaded: ", teams.size())
		else:
			print("Error parsing teams JSON")
	else:
		print("Could not open master_teams.json")

func load_players():
	# NUR laden wenn noch keine Spieler existieren (verhindert Form-Reset)
	if not players.is_empty():
		print("Players already loaded, keeping existing data with forms")
		# KRITISCH: player_index muss auch bei bereits geladenen Playern existieren
		if player_index.is_empty():
			print("Rebuilding player_index from existing players...")
			for tier_key in players.keys():
				var tier_players = players[tier_key]
				for player in tier_players:
					var player_id = player.get("player_id", "")
					if player_id != "":
						player_index[player_id] = player
			print("Player index rebuilt: ", player_index.size(), " entries")
		return
		
	var file = FileAccess.open("res://data/master_players_pool.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			players = json.get_data()
			var total_players = 0
			# PERFORMANCE: Build player index for O(1) lookups
			for tier_key in players.keys():
				var tier_players = players[tier_key]
				for player in tier_players:
					var player_id = player.get("player_id", "")
					if player_id != "":
						player_index[player_id] = player
					total_players += 1
			print("Players loaded: ", total_players)
			print("Player index built: ", player_index.size(), " entries")
			
		else:
			print("Error parsing players JSON")
	else:
		print("Could not open master_players_pool.json")

func get_team(team_id: String) -> Dictionary:
	assert(teams.has(team_id), "CRITICAL: Team ID '%s' not found! Check team generation." % team_id)
	return teams[team_id]

func get_player(player_id: String) -> Dictionary:
	# Sicherheitscheck für leere IDs
	if player_id == "" or player_id == null:
		print("WARNING: get_player called with empty player_id!")
		push_error("Stack trace for empty player_id")
		return {}
	
	# PERFORMANCE: Use index for O(1) lookup instead of O(n) search
	if player_index.has(player_id):
		return player_index[player_id]
	
	# Player nicht im Index gefunden - kritischer Fehler
	print("FEHLER: Player %s nicht im Index gefunden!" % player_id)
	
	assert(false, "CRITICAL: Player ID '%s' not found! Check player assignment." % player_id)
	return {}

func set_current_team(team_id: String):
	if teams.has(team_id):
		current_team_id = team_id
		print("Current team set to: ", teams[team_id].team_name)
	else:
		print("Team ID not found: ", team_id)

func get_current_team() -> Dictionary:
	return get_team(current_team_id)

func build_team_indices():
	# Future optimization: Build team player indices if needed
	pass

func _auto_fill_empty_eu_teams():
	"""Füllt leere EU-Teams und Amateur-Teams automatisch mit verfügbaren Spielern auf"""
	print("GameManager: Auto-filling empty EU teams and amateur teams...")
	
	# Sammle alle unassigned Spieler (nicht in deutschen Teams)
	var used_players = {}
	for team_id in teams.keys():
		if team_id.begins_with("t") and team_id.length() == 3:  # Deutsche Teams t01-t48
			var roster = teams[team_id].get("player_roster", [])
			for player_id in roster:
				if player_id != "" and player_id != null:
					used_players[player_id] = true
	
	# Alle verfügbaren Spieler sammeln (aus player_index, nicht players.keys())
	var available_players = []
	for player_id in player_index.keys():
		if player_id != "" and not used_players.has(player_id):
			available_players.append(player_id)
	
	available_players.shuffle()
	print("GameManager: %d verfügbare Spieler für EU-Teams und Amateur-Teams gefunden" % available_players.size())
	
	# Leere EU-Teams auffüllen
	var player_assignment_index = 0
	var teams_filled = 0
	
	for team_id in teams.keys():
		if team_id.begins_with("t-eur-") or team_id.begins_with("t-dfb-"):  # EU-Teams UND deutsche Amateur-Teams
			var roster = teams[team_id].get("player_roster", [])
			# Prüfe ob Spieler tatsächlich existieren
			var valid_players = 0
			for player_id in roster:
				if player_id != "" and player_index.has(player_id):
					valid_players += 1
			
			if valid_players < 11:  # Team braucht gültige Spieler
				# Erst: Ungültige IDs entfernen
				var clean_roster = []
				for player_id in roster:
					if player_id != "" and player_index.has(player_id):
						clean_roster.append(player_id)
				
				var needed = 11 - clean_roster.size()
				var new_roster = clean_roster.duplicate()
				
				# Spieler hinzufügen
				for i in range(needed):
					if player_assignment_index < available_players.size():
						new_roster.append(available_players[player_assignment_index])
						player_assignment_index += 1
					else:
						break
				
				# Team-Roster aktualisieren
				teams[team_id]["player_roster"] = new_roster
				if roster.size() == 0:
					teams_filled += 1
	
	print("GameManager: %d Teams (EU + Amateur) mit Spielern aufgefüllt" % teams_filled)

func initialize_game():
	# Verhindert mehrfache Initialisierung (schützt Form-Updates)
	if is_initialized:
		print("GameManager already initialized, keeping existing data")
		return
		
	load_teams()
	load_players()
	build_team_indices()  # Build additional indices if needed
	_auto_fill_empty_eu_teams()  # EU-Teams mit Spielern auffüllen
	current_season = 1
	current_matchday = 1
	current_week = 1  # Startet in Woche 1 der Saison
	is_initialized = true
	print("GameManager fully initialized")

func advance_week():
	"""Geht zur nächsten Woche im Saisonkalender"""
	current_week += 1
	current_matchday_of_week = 1  # Neue Woche startet mit Spieltag 1
	
	# Nach Woche 52: Neue Saison
	if current_week > 52:
		current_week = 1
		current_season += 1
		current_matchday = 1
		current_matchday_of_week = 1
		season_changed.emit(current_season)
		print("GameManager: Neue Saison %d beginnt!" % current_season)
	
	print("GameManager: Woche %d, Saison %d" % [current_week, current_season])

func advance_matchday_of_week():
	"""Geht zum nächsten Spieltag in derselben Woche"""
	current_matchday_of_week += 1
	print("GameManager: Woche %d, Spieltag %d von der Woche" % [current_week, current_matchday_of_week])

func get_week() -> int:
	"""Gibt aktuelle Woche zurück"""
	return current_week

func get_matchday_of_week() -> int:
	"""Gibt aktuellen Spieltag der Woche zurück (1 oder 2)"""
	return current_matchday_of_week
