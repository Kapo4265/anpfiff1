extends Node

# Spielplan-Generator für 3-Liga-System + Pokale
# 1./2. Liga: 34 Spieltage (17 Hin-, 17 Rückrunde)  
# 3. Liga: 22 Spieltage (11 Hin-, 11 Rückrunde)
# + DFB-Pokal und EU-Pokale integriert

signal schedule_generated(league_id: int)
signal cup_schedule_generated(cup_type: int)

var schedules: Dictionary = {}
var cup_manager: CupManager

func _ready():
	cup_manager = CupManager.get_instance()

func generate_all_schedules():
	print("ScheduleGenerator: Generating schedules for all leagues...")
	
	for league_id in [1, 2, 3]:
		generate_league_schedule(league_id)
	
	# Pokale für neue Saison initialisieren
	generate_cup_schedules()
	
	print("ScheduleGenerator: All schedules generated")

func generate_cup_schedules():
	"""Generiert realistische Liga/Pokal Abwechslung über die Saison"""
	var current_season = GameManager.current_season
	cup_manager.setup_new_season(current_season)
	
	# Realistische Bundesliga-Saison (August - Mai):
	# AUGUST-DEZEMBER (Hinrunde): 17 Liga-Spieltage + Pokal-Runden
	# DEZEMBER-JANUAR: Winterpause (3 Wochen)
	# JANUAR-MAI (Rückrunde): 17 Liga-Spieltage + Pokal-Runden
	# MAI-AUGUST: Sommerpause + Transferzeit
	
	_create_realistic_season_schedule()
	
	print("ScheduleGenerator: Realistic season schedule with winter/summer breaks created")

func _schedule_cup_round(cup_type: int, round: int, matchday: int):
	"""Plant Pokal-Runde für bestimmten Spieltag"""
	var matches = cup_manager.generate_cup_matches(cup_type, round)
	
	# Integriere in Spieltag-Ablauf (später bei MatchdayEngine)
	var cup_schedule_key = "cup_%d_round_%d" % [cup_type, round]
	schedules[cup_schedule_key] = {
		"matchday": matchday,
		"matches": matches,
		"cup_type": cup_type,
		"round": round
	}
	
	cup_schedule_generated.emit(cup_type)

func generate_league_schedule(league_id: int):
	var teams = LeagueManager.get_league_teams(league_id)
	if teams.is_empty():
		print("ScheduleGenerator: No teams found for league %d" % league_id)
		return
	
	var team_count = teams.size()
	var expected_matchdays = _calculate_rounds(team_count)
	
# Teams korrekt geladen
	
	print("ScheduleGenerator: Generating realistic random schedule for League %d (%d teams, %d matchdays)" % [league_id, team_count, expected_matchdays])
	
	# REALISTISCH: Zufälliger Spielplan wie in echter Bundesliga
	var schedule = _generate_realistic_random_schedule(teams, league_id)
	
	# VALIDATION: Prüfe ob alle erwarteten Spieltage generiert wurden
	if schedule.size() != expected_matchdays:
		print("ERROR: Schedule size mismatch! Expected %d, got %d matchdays" % [expected_matchdays, schedule.size()])
	
	# Spieltage nummerieren
	for i in range(schedule.size()):
		var matchday = {
			"matchday": i + 1,
			"matches": schedule[i],
			"is_winter_break": _is_winter_break_matchday(league_id, i + 1)
		}
		schedule[i] = matchday
	
	schedules[league_id] = schedule
	
	print("ScheduleGenerator: League %d schedule completed - %d matchdays" % [league_id, schedule.size()])
	
	# DEBUG: Erste paar Spieltage ausgeben für Validierung
	for i in range(min(3, schedule.size())):
		var matchday_info = schedule[i]
		var matches = matchday_info.get("matches", [])
		print("  Spieltag %d: %d Matches" % [i + 1, matches.size()])
		if matches.size() > 0:
			var first_match = matches[0]
			var home_name = GameManager.get_team(first_match.home_team).get("team_name", first_match.home_team)
			var away_name = GameManager.get_team(first_match.away_team).get("team_name", first_match.away_team)
			print("    Erstes Match: %s vs %s" % [home_name, away_name])
	
	schedule_generated.emit(league_id)

func _calculate_rounds(team_count: int) -> int:
	# Jedes Team spielt gegen jedes andere 2x (Hin + Rück)
	return (team_count - 1) * 2

func _generate_realistic_random_schedule(teams: Array, league_id: int) -> Array:
	"""Generiert realistischen Bundesliga-Spielplan mit zufälliger Verteilung"""
	
	var team_ids = []
	for team in teams:
		team_ids.append(team.id)
	
	var team_count = team_ids.size()
	var schedule = []
	
	# Für 1./2. Liga: 34 Spieltage (17 Hin-, 17 Rückrunde)
	# Für 3. Liga (12 Teams): 22 Spieltage (11 Hin-, 11 Rückrunde)
	var matchdays_per_half = (team_count - 1) if team_count % 2 == 0 else team_count
	if league_id == 3 and team_count == 12:
		matchdays_per_half = 11
	
	# Generiere alle möglichen Paarungen für Hinrunde
	var all_matches = []
	for i in range(team_ids.size()):
		for j in range(i + 1, team_ids.size()):
			all_matches.append({
				"team_a": team_ids[i],
				"team_b": team_ids[j],
				"assigned": false
			})
	
	print("ScheduleGenerator: Generiere %d Hinrunden-Spieltage mit %d Paarungen" % [matchdays_per_half, all_matches.size()])
	
	# HINRUNDE: Verteile Matches zufällig auf Spieltage
	var hinrunde = _distribute_matches_to_matchdays(all_matches.duplicate(true), matchdays_per_half, team_ids)
	
	# RÜCKRUNDE: Gleiche Paarungen aber Heim/Auswärts vertauscht
	var rueckrunde = _generate_rueckrunde(hinrunde)
	
	# Kombiniere beide Hälften
	schedule = hinrunde + rueckrunde
	
	return schedule

func _distribute_matches_to_matchdays(matches: Array, num_matchdays: int, team_ids: Array) -> Array:
	"""Verteilt Matches zufällig aber fair auf Spieltage"""
	var matchdays = []
	var matches_per_matchday = team_ids.size() / 2
	
	# Track Heim/Auswärts-Balance pro Team
	var home_count = {}
	var away_count = {}
	for team_id in team_ids:
		home_count[team_id] = 0
		away_count[team_id] = 0
	
	for matchday_num in range(num_matchdays):
		var matchday_matches = []
		var teams_used_this_matchday = {}
		var available_matches = []
		
		# Finde alle verfügbaren Matches für diesen Spieltag
		for pairing in matches:
			if not pairing.assigned and not teams_used_this_matchday.has(pairing.team_a) and not teams_used_this_matchday.has(pairing.team_b):
				available_matches.append(pairing)
		
		print("ScheduleGenerator: Spieltag %d - %d verfügbare Matches, brauche %d" % [matchday_num + 1, available_matches.size(), matches_per_matchday])
		
		# Wähle zufällig Matches aus
		available_matches.shuffle()
		
		# EINFACHE GREEDY-STRATEGIE: Nimm verfügbare Matches bis alle Teams eingeplant
		for match_data in available_matches:
			if matchday_matches.size() >= matches_per_matchday:
				break  # Genug Matches für diesen Spieltag
			
			# Teams noch verfügbar?
			if teams_used_this_matchday.has(match_data.team_a) or teams_used_this_matchday.has(match_data.team_b):
				continue
			
			# Einfache Heim/Auswärts Entscheidung (50/50 Zufall)
			var home_team = match_data.team_a
			var away_team = match_data.team_b
			if randf() > 0.5:
				home_team = match_data.team_b
				away_team = match_data.team_a
			
			home_count[home_team] += 1
			away_count[away_team] += 1
			
			matchday_matches.append({
				"home_team": home_team,
				"away_team": away_team,
				"played": false,
				"home_goals": 0,
				"away_goals": 0
			})
			
			teams_used_this_matchday[home_team] = true
			teams_used_this_matchday[away_team] = true
			match_data.assigned = true
		
		# FAILSAFE: Falls noch Teams übrig sind, zwinge sie zusammen
		var unused_teams = []
		for team_id in team_ids:
			if not teams_used_this_matchday.has(team_id):
				unused_teams.append(team_id)
		
		# Paarweise Teams zusammenfügen
		while unused_teams.size() >= 2:
			var team_a = unused_teams.pop_front()
			var team_b = unused_teams.pop_front()
			
			matchday_matches.append({
				"home_team": team_a,
				"away_team": team_b,
				"played": false,
				"home_goals": 0,
				"away_goals": 0
			})
			
			# Markiere als assigned in matches Array
			for match_data in matches:
				if (match_data.team_a == team_a and match_data.team_b == team_b) or (match_data.team_a == team_b and match_data.team_b == team_a):
					match_data.assigned = true
					break
		
		matchdays.append(matchday_matches)
		print("ScheduleGenerator: Spieltag %d generiert mit %d Matches" % [matchday_num + 1, matchday_matches.size()])
	
	# VALIDIERUNG: Prüfe ob alle Teams in jedem Spieltag vorkommen
	for matchday_num in range(matchdays.size()):
		var teams_in_matchday = {}
		for match in matchdays[matchday_num]:
			teams_in_matchday[match.home_team] = true
			teams_in_matchday[match.away_team] = true
		
		if teams_in_matchday.size() != team_ids.size():
			print("WARNUNG: Spieltag %d hat nur %d von %d Teams!" % [matchday_num + 1, teams_in_matchday.size(), team_ids.size()])
	
	return matchdays

func _generate_rueckrunde(hinrunde: Array) -> Array:
	"""Generiert Rückrunde mit vertauschten Heim/Auswärts-Rollen - EXAKT wie in echter Bundesliga"""
	var rueckrunde = []
	
	# ORIGINALGETREU: Rückrunde in GLEICHER Reihenfolge wie Hinrunde (Bundesliga-Standard)
	# Spieltag 18 = Spieltag 1 mit vertauschten Heim/Auswärts
	# Spieltag 19 = Spieltag 2 mit vertauschten Heim/Auswärts, etc.
	
	for hinrunde_matchday in hinrunde:
		var rueckrunde_matches = []
		
		for game in hinrunde_matchday:
			# Heim und Auswärts vertauschen
			rueckrunde_matches.append({
				"home_team": game.away_team,
				"away_team": game.home_team,
				"played": false,
				"home_goals": 0,
				"away_goals": 0
			})
		
		# Matches bleiben in gleicher Reihenfolge innerhalb des Spieltags
		rueckrunde.append(rueckrunde_matches)
	
	return rueckrunde

# ENTFERNT: _generate_reverse_matches() - ersetzt durch _generate_rueckrunde()

func _is_winter_break_matchday(league_id: int, matchday: int) -> bool:
	# Nur 1./2. Liga haben Winterpause nach Spieltag 17
	if league_id in [1, 2]:
		return matchday == 18  # Erster Spieltag nach Winterpause
	return false

func get_league_schedule(league_id: int) -> Array:
	return schedules.get(league_id, [])

func get_matchday_fixtures(league_id: int, matchday: int) -> Array:
	var schedule = get_league_schedule(league_id)
	
	if matchday <= 0 or matchday > schedule.size():
		return []
	
	return schedule[matchday - 1].matches

func get_current_matchday_fixtures(league_id: int) -> Array:
	var current_matchday = LeagueManager.get_current_matchday(league_id)
	var fixtures = get_matchday_fixtures(league_id, current_matchday)
	
	print("ScheduleGenerator: Liga %d, Spieltag %d → %d Fixtures" % [league_id, current_matchday, fixtures.size()])
	if fixtures.is_empty():
		var schedule = get_league_schedule(league_id)
		print("  DEBUG: Schedule hat %d Spieltage, current_matchday=%d" % [schedule.size(), current_matchday])
	
	return fixtures

func update_match_result(league_id: int, matchday: int, home_team: String, away_team: String, home_goals: int, away_goals: int):
	var schedule = get_league_schedule(league_id)
	
	if matchday <= 0 or matchday > schedule.size():
		return
	
	var matches = schedule[matchday - 1].matches
	
	for match_data in matches:
		if match_data.home_team == home_team and match_data.away_team == away_team:
			match_data.played = true
			match_data.home_goals = home_goals
			match_data.away_goals = away_goals
			# print("ScheduleGenerator: Match result updated - %s %d:%d %s" % [home_team, home_goals, away_goals, away_team])
			return
	
	print("ScheduleGenerator: Match not found in schedule")

func is_matchday_complete(league_id: int, matchday: int) -> bool:
	var fixtures = get_matchday_fixtures(league_id, matchday)
	
	for match_data in fixtures:
		if not match_data.played:
			return false
	
	return true

func get_team_next_opponent(league_id: int, team_id: String) -> Dictionary:
	var current_matchday = LeagueManager.get_current_matchday(league_id)
	var fixtures = get_matchday_fixtures(league_id, current_matchday)
	
	for match_data in fixtures:
		if match_data.home_team == team_id:
			return {"opponent": match_data.away_team, "home": true, "type": "league"}
		elif match_data.away_team == team_id:
			return {"opponent": match_data.home_team, "home": false, "type": "league"}
	
	return {"opponent": "Keine Spiele", "type": "none"}

func get_team_next_cup_opponent(team_id: String, week_info: Dictionary) -> Dictionary:
	"""KERN 5: Ermittelt nächsten Pokal-Gegner für User-Team"""
	var cup_matches = get_cup_matches_for_week(week_info.week)
	
	for cup_type in cup_matches.keys():
		var matches = cup_matches[cup_type]
		for fixture in matches:
			if fixture.get("home_team", "") == team_id:
				return {"opponent": fixture.get("away_team", ""), "home": true, "type": "cup", "cup_type": cup_type}
			elif fixture.get("away_team", "") == team_id:
				return {"opponent": fixture.get("home_team", ""), "home": false, "type": "cup", "cup_type": cup_type}
	
	return {"opponent": "Keine Pokalspiele", "type": "none"}

func get_cup_matches_for_week(week: int) -> Dictionary:
	"""KERN 5: Liefert alle Pokalspiele für eine bestimmte Woche (neues combined System)"""
	var cup_matches = {}
	
	# Prüfe season_calendar für Pokal-Wochen (auch combined Wochen)
	var season_calendar = schedules.get("season_calendar", [])
	for week_data in season_calendar:
		if week_data.week == week:
			# Neue "combined" Wochen mit cup_matches
			if week_data.type == "combined" and week_data.has("cup_matches"):
				var cup_data = week_data.cup_matches
				
				# DFB-Pokal Matches
				if cup_data.has("DFB_POKAL"):
					cup_matches["DFB_POKAL"] = cup_manager.get_current_round_matches(CupManager.CupType.DFB_POKAL)
				
				# EU-Pokale Matches
				if cup_data.has("EU_CHAMPIONS"):
					var champions_matches = cup_manager.get_current_round_matches(CupManager.CupType.CHAMPIONS_LEAGUE)
					if not champions_matches.is_empty():
						cup_matches["EU_CHAMPIONS"] = champions_matches
				
				if cup_data.has("EU_EUROPA"):
					var europa_matches = cup_manager.get_current_round_matches(CupManager.CupType.EUROPA_LEAGUE)
					if not europa_matches.is_empty():
						cup_matches["EU_EUROPA"] = europa_matches
				
				if cup_data.has("EU_CONFERENCE"):
					var conference_matches = cup_manager.get_current_round_matches(CupManager.CupType.CONFERENCE_LEAGUE)
					if not conference_matches.is_empty():
						cup_matches["EU_CONFERENCE"] = conference_matches
				
				break
			
			# Legacy: Alte "cup" Wochen (für Kompatibilität)
			elif week_data.type == "cup":
				var cup_type = week_data.get("cup_type", -1)
				if typeof(cup_type) == TYPE_INT and cup_type == CupManager.CupType.DFB_POKAL:
					cup_matches["DFB_POKAL"] = cup_manager.get_current_round_matches(CupManager.CupType.DFB_POKAL)
				elif typeof(cup_type) == TYPE_STRING and cup_type == "EU_CUPS":
					# Multi-Cup String
					var champions_matches = cup_manager.get_current_round_matches(CupManager.CupType.CHAMPIONS_LEAGUE)
					var europa_matches = cup_manager.get_current_round_matches(CupManager.CupType.EUROPA_LEAGUE)
					var conference_matches = cup_manager.get_current_round_matches(CupManager.CupType.CONFERENCE_LEAGUE)
					
					if not champions_matches.is_empty():
						cup_matches["EU_CHAMPIONS"] = champions_matches
					if not europa_matches.is_empty():
						cup_matches["EU_EUROPA"] = europa_matches
					if not conference_matches.is_empty():
						cup_matches["EU_CONFERENCE"] = conference_matches
				break
	
	return cup_matches

func get_team_matches_played(league_id: int, team_id: String) -> int:
	var schedule = get_league_schedule(league_id)
	var matches_played = 0
	
	for matchday in schedule:
		for match_data in matchday.matches:
			if match_data.played and (match_data.home_team == team_id or match_data.away_team == team_id):
				matches_played += 1
	
	return matches_played

func get_current_week_info() -> Dictionary:
	"""KERN 5: Liefert Info über aktuellen Spieltag basierend auf Woche + Spieltag der Woche"""
	var current_week = GameManager.get_week()
	var matchday_of_week = GameManager.get_matchday_of_week()
	var season_calendar = schedules.get("season_calendar", [])
	
	# Standardwerte
	var week_info = {
		"week": current_week,
		"type": "league",
		"description": "Liga-Spieltag",
		"league_matchday": LeagueManager.get_current_matchday(1)
	}
	
	# Suche spezifische Woche im realistischen Kalender
	for week_data in season_calendar:
		if week_data.week == current_week:
			# NEUE LOGIK: Basierend auf matchday_of_week entscheiden
			if week_data.type == "combined":
				if matchday_of_week == 1:
					# Erster Spieltag der Woche: Liga (falls vorhanden)
					if week_data.get("league_matchday") != null:
						week_info = {
							"week": current_week,
							"type": "league",
							"league_matchday": week_data.league_matchday,
							"description": str(week_data.league_matchday) + ". Spieltag Bundesliga"
						}
					else:
						# Kein Liga-Spieltag -> Cup als ersten Spieltag
						week_info = _get_cup_info_from_combined(week_data, current_week)
				
				elif matchday_of_week == 2:
					# Zweiter Spieltag der Woche: Cup (falls vorhanden)
					week_info = _get_cup_info_from_combined(week_data, current_week)
			else:
				# Normale Wochen (league, cup, winter_break, etc.)
				week_info = week_data.duplicate()
			
			break
	
	return week_info

func _get_cup_info_from_combined(week_data: Dictionary, current_week: int) -> Dictionary:
	"""Extrahiert Cup-Info aus combined week_data"""
	if not week_data.has("cup_matches") or week_data.cup_matches.is_empty():
		return {"week": current_week, "type": "league", "description": "Kein Pokal-Spiel"}
	
	# Erstes verfügbares Cup-Match nehmen
	for cup_type in week_data.cup_matches.keys():
		var cup_data = week_data.cup_matches[cup_type]
		var round = cup_data.get("round", 1)
		
		return {
			"week": current_week,
			"type": "cup",
			"cup_type": _parse_cup_type_string(cup_type),
			"cup_round": round,
			"description": _get_cup_name(cup_type) + " Spieltag " + str(round)
		}
	
	return {"week": current_week, "type": "league", "description": "Kein Pokal-Spiel"}

func _parse_cup_type_string(cup_type_string: String) -> int:
	"""Konvertiert Cup-Type String zu CupManager Enum"""
	match cup_type_string:
		"DFB_POKAL":
			return CupManager.CupType.DFB_POKAL
		"EU_CHAMPIONS":
			return CupManager.CupType.CHAMPIONS_LEAGUE
		"EU_EUROPA":
			return CupManager.CupType.EUROPA_LEAGUE
		"EU_CONFERENCE":
			return CupManager.CupType.CONFERENCE_LEAGUE
		_:
			return CupManager.CupType.DFB_POKAL

func get_matchdays_count_for_week(week: int) -> int:
	"""Gibt zurück wie viele Spieltage eine Woche hat (1 oder 2)"""
	var season_calendar = schedules.get("season_calendar", [])
	
	for week_data in season_calendar:
		if week_data.week == week:
			if week_data.type == "combined":
				var count = 0
				if week_data.get("league_matchday") != null:
					count += 1
				if week_data.has("cup_matches") and not week_data.cup_matches.is_empty():
					count += 1
				return count
			else:
				# Normale Wochen haben nur 1 Spieltag
				return 1
	
	return 1  # Standard: 1 Spieltag pro Woche

func _get_cup_name(cup_type) -> String:
	"""Gibt Cup-Namen für Display zurück"""
	if typeof(cup_type) == TYPE_STRING:
		match cup_type:
			"DFB_POKAL": return "DFB-Pokal"
			"EU_CHAMPIONS": return "Champions League"
			"EU_EUROPA": return "Europa League"
			"EU_CONFERENCE": return "Conference League"
			_: return "DFB-Pokal"  # Default für String ist DFB-Pokal
	else:
		match cup_type:
			CupManager.CupType.DFB_POKAL: return "DFB-Pokal"
			CupManager.CupType.CHAMPIONS_LEAGUE: return "Champions League"
			CupManager.CupType.EUROPA_LEAGUE: return "Europa League"
			CupManager.CupType.CONFERENCE_LEAGUE: return "Conference League"
			_: return "Unbekannter Pokal"

func get_schedule_info(league_id: int) -> Dictionary:
	var schedule = get_league_schedule(league_id)
	var current_matchday = LeagueManager.get_current_matchday(league_id)
	
	var total_matches = 0
	var played_matches = 0
	
	for matchday in schedule:
		total_matches += matchday.matches.size()
		for match_data in matchday.matches:
			if match_data.played:
				played_matches += 1
	
	return {
		"total_matchdays": schedule.size(),
		"current_matchday": current_matchday,
		"total_matches": total_matches,
		"played_matches": played_matches,
		"completion_percentage": float(played_matches) / total_matches * 100.0 if total_matches > 0 else 0.0
	}

func debug_print_schedule(league_id: int, max_matchdays: int = 3):
	var schedule = get_league_schedule(league_id)
	print("=== LEAGUE %d SCHEDULE DEBUG ===" % league_id)
	
	for i in range(min(schedule.size(), max_matchdays)):
		var matchday = schedule[i]
		print("Matchday %d:" % matchday.matchday)
		for match_data in matchday.matches:
			var home_name = "Unknown"
			var away_name = "Unknown"
			
			# Team-Namen aus LeagueManager holen
			for team in LeagueManager.get_league_teams(league_id):
				if team.id == match_data.home_team:
					home_name = team.name
				elif team.id == match_data.away_team:
					away_name = team.name
			
			print("  %s vs %s" % [home_name, away_name])
		print()

func get_all_schedules_info() -> Dictionary:
	var info = {}
	
	for league_id in schedules.keys():
		if typeof(league_id) == TYPE_INT:  # Nur Liga-IDs, nicht Cup-Keys
			info[league_id] = get_schedule_info(league_id)
	
	return info

func get_cup_matches_for_matchday(matchday: int) -> Array:
	"""Gibt alle Pokal-Spiele für einen bestimmten Spieltag zurück"""
	var cup_matches = []
	
	for key in schedules.keys():
		if typeof(key) == TYPE_STRING and key.begins_with("cup_"):
			var cup_data = schedules[key]
			if cup_data.matchday == matchday:
				cup_matches.append_array(cup_data.matches)
	
	return cup_matches

func simulate_cup_matches_for_matchday(matchday: int, user_team_id: String = "") -> Dictionary:
	"""Simuliert alle Pokal-Spiele für einen Spieltag mit User-Team Fokus"""
	var results = {}
	
	# WICHTIG: EU-Pokale werden bereits von MatchdayEngine._simulate_cup_week() behandelt!
	# Nur noch DFB-Pokal hier simulieren für Legacy-Unterstützung
	var week_info = get_current_week_info()
	if week_info.has("cup_type"):
		var cup_type = week_info.cup_type
		
		# EU-Pokale ÜBERSPRINGEN - bereits in _simulate_cup_week() simuliert
		if cup_type == CupManager.CupType.CHAMPIONS_LEAGUE or cup_type == CupManager.CupType.EUROPA_LEAGUE or cup_type == "EU_CUPS":
			print("ScheduleGenerator: EU-Pokale bereits von MatchdayEngine simuliert - überspringe")
			return {}
		
		# Nur DFB-Pokal hier simulieren
		elif typeof(cup_type) == TYPE_INT and cup_type == CupManager.CupType.DFB_POKAL:
			var round = week_info.get("round", 1)
			var cup_result = cup_manager.simulate_cup_round(cup_type, round, user_team_id)
			results[cup_type] = {
				"round": round,
				"winners": cup_result.winners,
				"user_match": cup_result.user_match,
				"other_matches": cup_result.other_matches,
				"status": cup_manager.get_cup_status(cup_type)
			}
	
	# Legacy: Alte Methode für bereits geplante Cup-Matches (nur DFB-Pokal)
	for key in schedules.keys():
		if typeof(key) == TYPE_STRING and key.begins_with("cup_"):
			var cup_data = schedules[key]
			if cup_data.matchday == matchday:
				var cup_type_legacy = cup_data.cup_type
				var round = cup_data.round
				
				# EU-Pokale überspringen - werden bereits in _simulate_cup_week() behandelt
				if cup_type_legacy == CupManager.CupType.CHAMPIONS_LEAGUE or cup_type_legacy == CupManager.CupType.EUROPA_LEAGUE:
					print("ScheduleGenerator: EU-Pokal Legacy-Match übersprungen - %s" % cup_type_legacy)
					continue
				
				# Nur DFB-Pokal simulieren
				var cup_result = cup_manager.simulate_cup_round(cup_type_legacy, round, user_team_id)
				
				results[cup_type_legacy] = {
					"round": round,
					"winners": cup_result.winners,
					"user_match": cup_result.user_match,
					"other_matches": cup_result.other_matches,
					"status": cup_manager.get_cup_status(cup_type_legacy)
				}
	
	return results

func _create_realistic_season_schedule():
	"""Erstellt realistischen Saisonablauf nach echter Bundesliga 2025/26"""
	
	var season_weeks = []
	var league_matchday = 1
	
	# SAISON 2025/26: August 2025 - Mai 2026 (basierend auf echten UEFA/DFB Terminen)
	
	# **AUGUST 2025 (Wochen 1-4)**
	season_weeks.append({"week": 1, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 2, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + DFB-Pokal 1. Runde", "cup_matches": {"DFB_POKAL": {"round": 1}}}); league_matchday += 1
	season_weeks.append({"week": 3, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 4, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **SEPTEMBER 2025 (Wochen 5-8)**
	season_weeks.append({"week": 5, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD1", "cup_matches": {"EU_CHAMPIONS": {"round": 1}, "EU_EUROPA": {"round": 1}, "EU_CONFERENCE": {"round": 1}}}); league_matchday += 1
	season_weeks.append({"week": 6, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 7, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD2", "cup_matches": {"EU_CHAMPIONS": {"round": 2}, "EU_EUROPA": {"round": 2}, "EU_CONFERENCE": {"round": 2}}}); league_matchday += 1
	season_weeks.append({"week": 8, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **OKTOBER 2025 (Wochen 9-12)**
	season_weeks.append({"week": 9, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD3", "cup_matches": {"EU_CHAMPIONS": {"round": 3}, "EU_EUROPA": {"round": 3}, "EU_CONFERENCE": {"round": 3}}}); league_matchday += 1
	season_weeks.append({"week": 10, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 11, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 12, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD4", "cup_matches": {"EU_CHAMPIONS": {"round": 4}, "EU_EUROPA": {"round": 4}, "EU_CONFERENCE": {"round": 4}}}); league_matchday += 1
	
	# **NOVEMBER 2025 (Wochen 13-16)**
	season_weeks.append({"week": 13, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD5", "cup_matches": {"EU_CHAMPIONS": {"round": 5}, "EU_EUROPA": {"round": 5}, "EU_CONFERENCE": {"round": 5}}}); league_matchday += 1
	season_weeks.append({"week": 14, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 15, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 16, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **DEZEMBER 2025 (Wochen 17-20)**
	season_weeks.append({"week": 17, "type": "combined", "league_matchday": league_matchday, "description": "DFB-Pokal 2. Runde + " + str(league_matchday) + ". Spieltag", "cup_matches": {"DFB_POKAL": {"round": 2}}}); league_matchday += 1
	season_weeks.append({"week": 18, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD6", "cup_matches": {"EU_CHAMPIONS": {"round": 6}, "EU_EUROPA": {"round": 6}, "EU_CONFERENCE": {"round": 6}}}); league_matchday += 1
	season_weeks.append({"week": 19, "type": "winter_break", "description": "WINTERPAUSE"})
	season_weeks.append({"week": 20, "type": "winter_break", "description": "WINTERPAUSE"})
	
	# **JANUAR 2026 (Wochen 21-24)**
	season_weeks.append({"week": 21, "type": "winter_break", "description": "WINTERPAUSE"})
	season_weeks.append({"week": 22, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD7", "cup_matches": {"EU_CHAMPIONS": {"round": 7}, "EU_EUROPA": {"round": 7}, "EU_CONFERENCE": {"round": 7}}}); league_matchday += 1
	season_weeks.append({"week": 23, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + Champions League MD8 (Liga-Phase Ende)", "cup_matches": {"EU_CHAMPIONS": {"round": 8}, "EU_EUROPA": {"round": 8}, "EU_CONFERENCE": {"round": 8}}}); league_matchday += 1
	season_weeks.append({"week": 24, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **FEBRUAR 2026 (Wochen 25-28)**
	season_weeks.append({"week": 25, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + DFB-Pokal Achtelfinale", "cup_matches": {"DFB_POKAL": {"round": 3}}}); league_matchday += 1
	season_weeks.append({"week": 26, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Playoffs Hinspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 9}, "EU_EUROPA": {"round": 9}}}); league_matchday += 1
	season_weeks.append({"week": 27, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Playoffs Rückspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 10}, "EU_EUROPA": {"round": 10}}}); league_matchday += 1
	season_weeks.append({"week": 28, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **MÄRZ 2026 (Wochen 29-32)**
	season_weeks.append({"week": 29, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Achtelfinale Hinspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 11}}}); league_matchday += 1
	season_weeks.append({"week": 30, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Achtelfinale Rückspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 12}}}); league_matchday += 1
	season_weeks.append({"week": 31, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	season_weeks.append({"week": 32, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag Bundesliga"}); league_matchday += 1
	
	# **APRIL 2026 (Wochen 33-36)**
	season_weeks.append({"week": 33, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Viertelfinale Hinspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 13}}}); league_matchday += 1
	season_weeks.append({"week": 34, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Viertelfinale Rückspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 14}}}); league_matchday += 1
	season_weeks.append({"week": 35, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + DFB-Pokal Halbfinale", "cup_matches": {"DFB_POKAL": {"round": 4}}}); league_matchday += 1
	season_weeks.append({"week": 36, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Halbfinale Hinspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 15}}}); league_matchday += 1
	
	# **MAI 2026 (Wochen 37-40)**
	season_weeks.append({"week": 37, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag + CL Halbfinale Rückspiel", "cup_matches": {"EU_CHAMPIONS": {"round": 16}}}); league_matchday += 1
	season_weeks.append({"week": 38, "type": "combined", "league_matchday": league_matchday, "description": str(league_matchday) + ". Spieltag (SAISONENDE)"}) # 34. Spieltag
	season_weeks.append({"week": 39, "type": "combined", "league_matchday": null, "description": "DFB-Pokal FINALE Berlin", "cup_matches": {"DFB_POKAL": {"round": 5}}})
	season_weeks.append({"week": 40, "type": "combined", "league_matchday": null, "description": "CHAMPIONS LEAGUE FINALE Budapest", "cup_matches": {"EU_CHAMPIONS": {"round": 99}}})
	
	# **JUNI-AUGUST 2026 (Wochen 41-52) - Sommerpause**
	for week in range(41, 53):
		season_weeks.append({"week": week, "type": "summer_break", "description": "Sommerpause + Transfers"})
	
	schedules["season_calendar"] = season_weeks
	
	print("🏆 REALISTISCHE SAISON 2025/26 erstellt: %d Wochen" % season_weeks.size())
	print("📅 Bundesliga: %d Spieltage (Aug-Mai)" % (league_matchday - 1))
	var combined_weeks = season_weeks.filter(func(w): return w.type == "combined" and w.has("cup_matches"))
	print("⚽ Liga + Pokal kombiniert: %d Wochen" % combined_weeks.size())

# ENTFERNT: Alte Cup-Week-Funktionen - ersetzt durch _create_realistic_season_schedule()
# Die neuen "combined" Wochen aus dem realistischen Kalender ersetzen diese Logik


func is_team_in_cup(team_id: String) -> Dictionary:
	"""Prüft in welchen Pokalen ein Team noch aktiv ist"""
	var cups = {}
	cups[CupManager.CupType.DFB_POKAL] = cup_manager.is_team_in_cup(team_id, CupManager.CupType.DFB_POKAL)
	cups[CupManager.CupType.CHAMPIONS_LEAGUE] = cup_manager.is_team_in_cup(team_id, CupManager.CupType.CHAMPIONS_LEAGUE)
	cups[CupManager.CupType.EUROPA_LEAGUE] = cup_manager.is_team_in_cup(team_id, CupManager.CupType.EUROPA_LEAGUE)
	cups[CupManager.CupType.CONFERENCE_LEAGUE] = cup_manager.is_team_in_cup(team_id, CupManager.CupType.CONFERENCE_LEAGUE)
	return cups
