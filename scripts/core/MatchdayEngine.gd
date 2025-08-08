extends Node

# Multi-Liga Spieltag-Simulation Engine für KERN 3+4
# Simuliert User-Match detailliert + Konferenz + andere Ligen + POKALE

signal matchday_started(league_id: int, matchday: int)
signal user_match_started(home_team: String, away_team: String)
signal user_match_completed(result: Dictionary)
signal conference_match_completed(league_id: int, home_team: String, away_team: String, result: Dictionary)
signal cup_matches_completed(cup_results: Dictionary)
signal all_leagues_completed()
signal matchday_results_ready(results: Dictionary)

var current_simulation: Dictionary = {}
var is_simulating: bool = false
var cached_team_strengths: Dictionary = {}
var schedule_generator: ScheduleGenerator
var suspension_system_processed: bool = false  # Verhindert doppelte SuspensionSystem-Aufrufe

func _ready():
	# ScheduleGenerator ist bereits als Autoload/Singleton verfügbar
	schedule_generator = ScheduleGenerator

func simulate_current_matchday():
	if is_simulating:
		print("MatchdayEngine: Already simulating - wait for completion")
		return
	
	is_simulating = true
	suspension_system_processed = false  # Reset für neue Simulation
	current_simulation = {
		"user_match": {},
		"conference_results": {},
		"other_leagues_results": {},
		"cup_results": {},
		"week_info": {},
		"start_time": Time.get_ticks_msec()
	}
	
	# 0. REALISTISCHER SAISONABLAUF: Aktuelle Woche bestimmen
	var current_week = GameManager.get_week()
	var week_info = schedule_generator.get_current_week_info()
	current_simulation.week_info = week_info
	
	print("MatchdayEngine: WOCHE %d - %s" % [current_week, week_info.get("description", week_info.type)])
	
	# 0.5. KARTEN-STATISTIKEN zurücksetzen vor neuem Spieltag
	CardStatistics.reset_current_matchday_stats()
	
	# 0.6. PERFORMANCE: Team-Stärken für alle Teams vorab berechnen
	_cache_all_team_strengths()
	
	# 1. Je nach Spieltag: Liga ODER Pokal ODER Pause
	match week_info.type:
		"league":
			await _simulate_league_week(week_info)
		"cup":
			await _simulate_cup_week(week_info)
		"winter_break":
			await _simulate_winter_break(week_info)
		"summer_break":
			await _simulate_summer_break(week_info)
		_:
			print("MatchdayEngine: Unknown week type: %s" % week_info.type)
			is_simulating = false
			return
	
	# 3. Woche voranschreiten und Saison finalisieren
	_finalize_week()
	
	is_simulating = false
	print("MatchdayEngine: Matchday simulation completed")

func _simulate_user_league_matchday(league_id: int, user_team_id: String):
	var current_matchday = LeagueManager.get_current_matchday(league_id)
	var fixtures = ScheduleGenerator.get_current_matchday_fixtures(league_id)
	
	if fixtures.is_empty():
		print("MatchdayEngine: No fixtures found for league %d matchday %d" % [league_id, current_matchday])
		return
	
	# DEBUG: Fixtures und User-Team analysieren
	print("MatchdayEngine: DEBUG - User team: %s, Fixtures found: %d" % [user_team_id, fixtures.size()])
	for i in range(min(3, fixtures.size())):
		var match = fixtures[i]
		print("  Fixture %d: %s vs %s" % [i+1, match.home_team, match.away_team])
	
	matchday_started.emit(league_id, current_matchday)
	print("MatchdayEngine: Simulating League %d - Matchday %d" % [league_id, current_matchday])
	
	var user_match = null
	var conference_matches = []
	
	# User-Match und Konferenz-Matches trennen
	for match in fixtures:
		if match.home_team == user_team_id or match.away_team == user_team_id:
			user_match = match
		else:
			conference_matches.append(match)
	
	if not user_match:
		print("MatchdayEngine: Error - User team not found in fixtures")
		print("MatchdayEngine: DEBUG - All fixtures for this matchday:")
		for i in range(fixtures.size()):
			var match = fixtures[i]
			print("  Match %d: %s vs %s" % [i+1, match.home_team, match.away_team])
		return
	
	# User-Match und Konferenz zusammen
	print("MatchdayEngine: Processing USER MATCH + %d CONFERENCE matches..." % conference_matches.size())
	user_match_started.emit(user_match.home_team, user_match.away_team)
	
	# Vorbereitung: Alle Match-Daten sammeln
	current_simulation.conference_results[league_id] = []
	var all_league_matches = [user_match] + conference_matches
	
	# Alle Matches berechnen
	_process_user_league_matches(all_league_matches, league_id, current_matchday, user_match)
	
	user_match_completed.emit(current_simulation.user_match)
	# User League abgeschlossen

func _cache_all_team_strengths():
	print("MatchdayEngine: Starting FAST team strength caching...")
	cached_team_strengths.clear()
	
	# KRITISCHER FIX: Alle Teams benötigen starting_eleven für PerformanceRating
	_ensure_all_teams_have_lineups()
	
	# Schneller Batch-Cache - keine TeamData Objekte erstellen
	var total_cached = 0
	for league_id in [1, 2, 3]:
		var teams = LeagueManager.get_league_teams(league_id)
		for team in teams:
			var team_data = GameManager.get_team(team.id)
			if not team_data.is_empty():
				# SCHNELL: Direkte Berechnung ohne TeamData.new()
				var base_strength = _calculate_team_base_strength(team_data)
				cached_team_strengths[team.id] = {
					"home": base_strength + 5.0,  # Heimvorteil
					"away": base_strength
				}
				total_cached += 1
	
	# Team-Stärken gecacht: %d teams" % total_cached

func _ensure_all_teams_have_lineups():
	# KRITISCHER FIX: Alle Teams bekommen starting_eleven für PerformanceRating
	print("MatchdayEngine: Ensuring all teams have starting_eleven...")
	var teams_fixed = 0
	
	for league_id in [1, 2, 3]:
		var teams = LeagueManager.get_league_teams(league_id)
		for team in teams:
			var team_data = GameManager.get_team(team.id)
			if not team_data.is_empty():
				var current_lineup = team_data.get("starting_eleven", [])
				if current_lineup.is_empty():
					# PERFORMANCE: Direkte Lineup-Generierung ohne TeamData.new()
					var roster = team_data.get("player_roster", [])
					if roster.size() >= 11:
						var generated_lineup = roster.slice(0, 11)
						GameManager.teams[team.id]["starting_eleven"] = generated_lineup
						teams_fixed += 1
	
	print("MatchdayEngine: Fixed %d teams without starting_eleven" % teams_fixed)

func _calculate_team_base_strength(team_data: Dictionary) -> float:
	# Ultra-schnelle Team-Stärke: Basis(1-8) + Form(0-20) = Gesamtstärke
	var player_roster = team_data.get("player_roster", [])
	if player_roster.is_empty():
		return 50.0  # Default
	
	# Top 11 Spieler-Stärken sammeln mit korrekter Formel
	var player_strengths = []
	for player_id in player_roster:
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			var base = player_data.get("strength_overall_base", 4)  # 1-8
			var form = int(player_data.get("current_form", 10))     # 0-20
			var strength = float(base) + float(form)  # Beispiel: 4 + 14 = 18.0
			player_strengths.append(strength)
	
	# Top 11 nehmen
	player_strengths.sort()
	player_strengths.reverse()
	var top11 = player_strengths.slice(0, 11)
	
	# Durchschnitt der Top 11
	var total = 0.0
	for strength in top11:
		total += strength
	
	return total / top11.size() if top11.size() > 0 else 14.0  # Default: 4+10

# ENTFERNT: _simulate_cup_matches() - wurde durch _simulate_unified_cup_matches() ersetzt

func _simulate_league_week(week_info: Dictionary):
	"""Simuliert eine Liga-Woche (wie bisherige Implementierung)"""
	print("MatchdayEngine: Liga-Spieltag %d wird simuliert..." % week_info.league_matchday)
	
	# 1. User-Liga bestimmen und User-Match starten
	var user_league = LeagueManager.user_league
	var user_team_id = LeagueManager.user_team_id
	
	if user_team_id == "":
		print("MatchdayEngine: Error - No user team selected")
		is_simulating = false
		return
	
	# 1.Liga + Konferenz simulieren
	_simulate_user_league_matchday(user_league, user_team_id)
	
	# 2.Liga + 3.Liga simulieren NACH 1.Liga
	await _simulate_other_leagues_async(user_league)

func _simulate_cup_week(week_info: Dictionary):
	"""Simuliert eine Pokal-Woche mit User-Match (volle Events) + andere (Lightning)"""
	print("MatchdayEngine: %s wird simuliert..." % week_info.description)
	print("DEBUG: week_info = %s" % week_info)
	
	# User-Team für detaillierte Pokal-Simulation
	var user_team_id = LeagueManager.user_team_id
	
	# WICHTIG: Prüfe ob User-Team überhaupt in diesem Pokal spielt
	var cup_type = week_info.get("cup_type", -1)
	var user_plays_in_cup = false
	
	# Spezialbehandlung für EU_CUPS (alle EU-Pokale in einer Woche)
	if typeof(cup_type) == TYPE_STRING and cup_type == "EU_CUPS":
		# LÖSUNG: Direkt prüfen ob User-Team in den EU-Matches ist (wie bei DFB-Pokal)
		var week_matches = schedule_generator.get_cup_matches_for_week(week_info.week)
		
		# Prüfe alle EU-Cup-Matches nach User-Team
		if week_matches.has("EU_CHAMPIONS"):
			for match in week_matches["EU_CHAMPIONS"]:
				if match.get("home_team", "") == user_team_id or match.get("away_team", "") == user_team_id:
					cup_type = CupManager.CupType.CHAMPIONS_LEAGUE
					user_plays_in_cup = true
					week_info["cup_type"] = cup_type
					week_info["description"] = "Champions League Spieltag %d" % week_info.get("cup_round", 1)
					print("DEBUG: User-Team %s spielt Champions League: %s vs %s" % [user_team_id, match.get("home_team"), match.get("away_team")])
					break
		
		if not user_plays_in_cup and week_matches.has("EU_EUROPA"):
			for match in week_matches["EU_EUROPA"]:
				if match.get("home_team", "") == user_team_id or match.get("away_team", "") == user_team_id:
					cup_type = CupManager.CupType.EUROPA_LEAGUE
					user_plays_in_cup = true
					week_info["cup_type"] = cup_type
					week_info["description"] = "Europa League Spieltag %d" % week_info.get("cup_round", 1)
					print("DEBUG: User-Team %s spielt Europa League: %s vs %s" % [user_team_id, match.get("home_team"), match.get("away_team")])
					break
		
		if not user_plays_in_cup and week_matches.has("EU_CONFERENCE"):
			for match in week_matches["EU_CONFERENCE"]:
				if match.get("home_team", "") == user_team_id or match.get("away_team", "") == user_team_id:
					cup_type = CupManager.CupType.CONFERENCE_LEAGUE
					user_plays_in_cup = true
					week_info["cup_type"] = cup_type
					week_info["description"] = "Conference League Spieltag %d" % week_info.get("cup_round", 1)
					print("DEBUG: User-Team %s spielt Conference League: %s vs %s" % [user_team_id, match.get("home_team"), match.get("away_team")])
					break
	elif cup_type >= 0:  # Gültiger CupType (DFB-Pokal)
		# LÖSUNG: Direkt prüfen ob User-Team in den Matches ist
		var week_matches = schedule_generator.get_cup_matches_for_week(week_info.week)
		user_plays_in_cup = false
		
		# Prüfe alle Cup-Matches dieser Woche nach User-Team
		for matches_cup_type in week_matches.keys():
			var matches = week_matches[matches_cup_type]
			for match in matches:
				if match.home_team == user_team_id or match.away_team == user_team_id:
					user_plays_in_cup = true
					print("DEBUG: User-Team %s gefunden in Match: %s vs %s" % [user_team_id, match.home_team, match.away_team])
					break
			if user_plays_in_cup:
				break
		
		print("DEBUG: User-Team %s in DFB-Pokal? %s" % [user_team_id, user_plays_in_cup])
	
	# Cup-Results Variable deklarieren
	var cup_results = {}
	
	if not user_plays_in_cup:
		print("MatchdayEngine: User-Team %s spielt nicht in %s - simuliere andere Teams" % [user_team_id, week_info.description])
		# Trotzdem andere Matches simulieren (Lightning)
		cup_results = _simulate_unified_cup_matches(week_info, "")  # Leere team_id = kein User-Match
		current_simulation.cup_results = cup_results
		# WICHTIG: Setze leeres user_match damit UI nicht blockiert
		current_simulation.user_match = {}
		# Signal senden dass kein User-Match stattfand
		user_match_completed.emit({})
	else:
		# KERN 5: Unified Pokal-Simulation
		# User-Match: Volle Events, Andere Pokalspiele: Lightning-Modus
		cup_results = _simulate_unified_cup_matches(week_info, user_team_id)
		current_simulation.cup_results = cup_results
	
	# Cup-Ergebnisse ausgeben
	for result_cup_type in cup_results.keys():
		var result = cup_results[result_cup_type]
		var cup_name = _get_cup_name(result_cup_type)
		
		# EU-Pokale haben andere Struktur als DFB-Pokal
		if typeof(result_cup_type) == TYPE_STRING and (result_cup_type == "EU_CHAMPIONS" or result_cup_type == "EU_EUROPA" or result_cup_type == "EU_CONFERENCE"):
			# European Cup: Liga-Spieltag (2025/26 Format)
			var match_count = result.get("other_results", []).size()
			if result.has("user_match") and result.user_match != null:
				match_count += 1
			print("MatchdayEngine: %s Liga-Spieltag %d - %d Matches simuliert" % [
				cup_name, result.get("round", 1), match_count
			])
			
			# User-Match hervorheben (EU-Format)
			if result.has("user_match") and result.user_match != null:
				var user_match = result.user_match
				# Sichere Team-Namen abrufen
				var home_name = user_match.get("home_team_name", "")
				var away_name = user_match.get("away_team_name", "")
				if home_name == "" and user_match.has("home_team"):
					var home_data = GameManager.get_team(user_match.home_team)
					home_name = home_data.get("team_name", user_match.home_team)
				if away_name == "" and user_match.has("away_team"):
					var away_data = GameManager.get_team(user_match.away_team)
					away_name = away_data.get("team_name", user_match.away_team)
				
				print("MatchdayEngine: USER EU-POKAL-MATCH - %s %d:%d %s" % [
					home_name, user_match.home_goals,
					user_match.away_goals, away_name
				])
				
				# User-Match Signal senden
				user_match_completed.emit(user_match)
		else:
			# DFB-Pokal: Normale KO-Runden
			var winners_count = result.get("winners", []).size()
			print("MatchdayEngine: %s Runde %d - %d Sieger ermittelt" % [
				cup_name, result.round, winners_count
			])
			
			# User-Match hervorheben (DFB-Format)
			if result.user_match != null:
				var user_match = result.user_match
				# ABSTURZ-FIX: Prüfen ob Team-Namen vorhanden, sonst aus IDs generieren
				var home_name = user_match.get("home_team_name", "")
				var away_name = user_match.get("away_team_name", "")
				if home_name == "" and user_match.has("home_team"):
					var home_data = GameManager.get_team(user_match.home_team)
					home_name = home_data.get("team_name", user_match.home_team)
				if away_name == "" and user_match.has("away_team"):
					var away_data = GameManager.get_team(user_match.away_team)
					away_name = away_data.get("team_name", user_match.away_team)
				
				print("MatchdayEngine: USER POKAL-MATCH - %s %d:%d %s" % [
					home_name, user_match.home_goals,
					user_match.away_goals, away_name
				])
				if user_match.get("extra_time", false):
					print("  → Nach Verlängerung!")
				if user_match.get("penalty_shootout", false):
					print("  → Nach Elfmeterschießen (%s)!" % user_match.get("penalty_score", ""))
				
				# User-Match Signal senden
				user_match_completed.emit(user_match)
	
	# KRITISCH: CupManager-Elimination NUR für K.O.-Spiele, NICHT für Liga-Phase!
	for result_cup_type in cup_results.keys():
		var result = cup_results[result_cup_type]
		var round = result.get("round", 1)
		
		# Prüfe ob es Liga-Phase oder K.O.-Phase ist
		var is_league_phase = false
		if typeof(result_cup_type) == TYPE_STRING:
			# EU-Pokale: Liga-Phase ist Spieltag 1-8 (Swiss System)
			if result_cup_type in ["EU_CHAMPIONS", "EU_EUROPA", "EU_CONFERENCE"]:
				is_league_phase = round <= 8
				print("MatchdayEngine: %s Spieltag %d - Liga-Phase: %s" % [_get_cup_name(result_cup_type), round, is_league_phase])
		
		# SPEZIAL: EU-Pokale Liga-Phase Ende (Spieltag 8) -> Playoff-Auslosung!
		if is_league_phase and round == 8 and typeof(result_cup_type) == TYPE_STRING and result_cup_type in ["EU_CHAMPIONS", "EU_EUROPA", "EU_CONFERENCE"]:
			print("🏆 LIGA-PHASE ENDE: %s Spieltag %d - starte Playoff-Auslosung!" % [_get_cup_name(result_cup_type), round])
			
			var cup_manager_instance = CupManager.get_instance()
			if cup_manager_instance:
				# CupType konvertieren
				var actual_cup_type = result_cup_type
				match result_cup_type:
					"EU_CHAMPIONS": actual_cup_type = CupManager.CupType.CHAMPIONS_LEAGUE
					"EU_EUROPA": actual_cup_type = CupManager.CupType.EUROPA_LEAGUE  
					"EU_CONFERENCE": actual_cup_type = CupManager.CupType.CONFERENCE_LEAGUE
				
				# Playoff-Auslosung basierend auf Tabellenplatzierung
				cup_manager_instance.finalize_league_phase_and_draw_playoffs(actual_cup_type)
		
		# NUR für K.O.-Spiele Elimination aufrufen (DFB-Pokal oder EU-Pokale nach Liga-Phase)
		elif not is_league_phase:
			var cup_winners = result.get("winners", [])
			print("🔥 CRITICAL: Rufe CupManager-Elimination für %s auf mit %d Gewinnern" % [_get_cup_name(result_cup_type), cup_winners.size()])
			
			# CupManager für Team-Updates und Elimination verwenden
			var cup_manager_instance = CupManager.get_instance()
			if cup_manager_instance:
				# DFB-Pokal verwendet int cup_type, EU-Pokale String -> in int konvertieren
				var actual_cup_type = result_cup_type
				if typeof(result_cup_type) == TYPE_STRING:
					match result_cup_type:
						"EU_CHAMPIONS": actual_cup_type = CupManager.CupType.CHAMPIONS_LEAGUE
						"EU_EUROPA": actual_cup_type = CupManager.CupType.EUROPA_LEAGUE
						"EU_CONFERENCE": actual_cup_type = CupManager.CupType.CONFERENCE_LEAGUE
						_: actual_cup_type = CupManager.CupType.DFB_POKAL
				
				cup_manager_instance._update_cup_after_matchday_simulation(actual_cup_type, round, cup_winners)
		else:
			print("MatchdayEngine: Liga-Phase - KEINE Elimination, alle Teams spielen weiter")
	
	# Signal für Cup-Updates senden
	cup_matches_completed.emit(cup_results)
	
	# Kurze Pause für Cup-Wochen
	await get_tree().process_frame

func _simulate_unified_cup_matches(week_info: Dictionary, user_team_id: String) -> Dictionary:
	"""KERN 5: Unified Pokal-Simulation mit User-Match (Events) + andere (Lightning)"""
	var cup_results = {}
	
	# Alle Pokalspiele für diese Woche abrufen
	var week_matches = schedule_generator.get_cup_matches_for_week(week_info.week)
	
	# Wenn keine Matches existieren, leeres Dictionary zurückgeben
	if week_matches.is_empty():
		print("MatchdayEngine: WARNUNG - Keine Cup-Matches für Woche %d gefunden!" % week_info.week)
		return {}
	
	# Korrekte Anzahl der tatsächlichen Matches zählen
	var total_matches = 0
	for cup_type in week_matches.keys():
		total_matches += week_matches[cup_type].size()
	
	print("MatchdayEngine: UNIFIED CUP - Woche %d, %d Matches in %d Pokalen" % [week_info.week, total_matches, week_matches.size()])
	
	# Pro Pokaltyp: User-Match vs andere Matches trennen
	for cup_type in week_matches.keys():
		var matches = week_matches[cup_type]
		var user_match = null
		var other_matches = []
		
		# User-Match identifizieren
		print("DEBUG: Suche User-Match für %s in %s (%d Matches)" % [user_team_id, cup_type, matches.size()])
		for match in matches:
			print("DEBUG: Match %s vs %s" % [match.home_team, match.away_team])
			# Nur wenn user_team_id nicht leer ist, nach User-Match suchen
			if user_team_id != "" and (match.home_team == user_team_id or match.away_team == user_team_id):
				user_match = match
				print("DEBUG: USER-MATCH gefunden!")
			else:
				other_matches.append(match)
		
		# Cup-Simulation starten
		var cup_result = {
			"cup_type": cup_type,
			"round": week_info.get("cup_round", 1),
			"user_match": null,
			"other_results": [],
			"winners": []
		}
		
		# 1. USER-MATCH: Volle EventEngine Simulation
		if user_match:
			print("MatchdayEngine: USER POKAL-MATCH - %s vs %s" % [user_match.home_team, user_match.away_team])
			
			# Vollständige Event-Simulation für User
			var user_result = MatchEngine.simulate_match_instant(user_match.home_team, user_match.away_team)
			
			# Pokal-spezifische Erweiterung (Verlängerung/Elfmeterschießen)
			if user_result.draw:
				user_result = _apply_cup_overtime_rules(user_result, user_match)
			
			cup_result.user_match = user_result
			cup_result.winners.append(user_result.winner)
			
			# User-Match Signal (für UI-Integration)
			user_match_started.emit(user_match.home_team, user_match.away_team)
		
		# 2. ANDERE POKAL-MATCHES: Lightning-Simulation
		for match in other_matches:
			var lightning_result = MatchEngine.simulate_match_lightning(match.home_team, match.away_team)
			
			# Pokal-Regeln auch für Lightning-Matches
			if lightning_result.draw:
				lightning_result = _apply_cup_overtime_rules(lightning_result, match)
			
			cup_result.other_results.append(lightning_result)
			cup_result.winners.append(lightning_result.winner)
		
		cup_results[cup_type] = cup_result
	
	return cup_results

func _apply_cup_overtime_rules(match_result: Dictionary, match_data: Dictionary) -> Dictionary:
	"""Wendet Pokal-Regeln an: Verlängerung + Elfmeterschießen bei Unentschieden"""
	if not match_result.draw:
		return match_result  # Kein Unentschieden, keine Verlängerung nötig
	
	# WICHTIG: Liga-Phase (Swiss System) erlaubt Unentschieden - KEINE Verlängerung!
	# Nur KO-Phase benötigt zwingend einen Sieger
	if _is_league_phase_match(match_data):
		print("  → Liga-Phase: Unentschieden bleibt bestehen (kein Extra-Time)")
		print("  → DEBUG: Woche-Info: %s" % str(schedule_generator.get_current_week_info()))
		return match_result  # Liga-Phase erlaubt Draws
	
	# VERLÄNGERUNG (30 Minuten)
	print("  → VERLÄNGERUNG für %s vs %s" % [match_data.home_team, match_data.away_team])
	
	# Verlängerung simulieren (vereinfacht)
	var overtime_home = 0
	var overtime_away = 0
	
	if randf() < 0.3:  # 30% Chance auf Tor in Verlängerung
		if randf() < match_result.home_strength / (match_result.home_strength + match_result.away_strength):
			overtime_home = 1
			# Event für Verlängerungstor hinzufügen
			if not match_result.has("events"):
				match_result.events = []
			var home_scorer = _get_random_team_player(match_result.home_team)
			match_result.events.append({
				"minute": 90 + randi_range(1, 30),  # Zwischen 91-120
				"type": EventEngine.EventType.NORMAL_ATTACK,  # Korrekter EventType
				"team_id": match_result.home_team,
				"player_id": home_scorer,
				"success": true,
				"description": "Tor in der Verlängerung",
				"extra_time": true
			})
		else:
			overtime_away = 1
			# Event für Verlängerungstor hinzufügen
			if not match_result.has("events"):
				match_result.events = []
			var away_scorer = _get_random_team_player(match_result.away_team)
			match_result.events.append({
				"minute": 90 + randi_range(1, 30),  # Zwischen 91-120
				"type": EventEngine.EventType.NORMAL_ATTACK,  # Korrekter EventType
				"team_id": match_result.away_team,
				"player_id": away_scorer,
				"success": true,
				"description": "Tor in der Verlängerung",
				"extra_time": true
			})
	
	match_result.home_goals += overtime_home
	match_result.away_goals += overtime_away
	match_result.extra_time = true
	
	# Immer noch Unentschieden? → ELFMETERSCHIESSEN
	if match_result.home_goals == match_result.away_goals:
		print("  → ELFMETERSCHIESSEN!")
		
		# Elfmeterschießen simulieren (5 + evtl. mehr)
		var penalty_home = randi_range(3, 5)
		var penalty_away = randi_range(3, 5)
		
		# Bei Gleichstand: Sudden Death
		while penalty_home == penalty_away:
			penalty_home += randi_range(0, 1)
			penalty_away += randi_range(0, 1)
		
		match_result.penalty_shootout = true
		match_result.penalty_score = "%d:%d" % [penalty_home, penalty_away]
		
		# Elfmeter-Events hinzufügen
		if not match_result.has("events"):
			match_result.events = []
		
		# Vereinfachte Elfmeter-Events (5 pro Team) - mit echten Spieler-IDs
		var home_players = _get_team_players_for_penalties(match_result.home_team)
		var away_players = _get_team_players_for_penalties(match_result.away_team)
		
		for i in range(5):
			# Heim-Elfmeter
			var home_shooter = home_players[i % home_players.size()] if home_players.size() > 0 else ""
			if i < penalty_home:
				match_result.events.append({
					"minute": 120,
					"type": EventEngine.EventType.ELFMETER,
					"team_id": match_result.home_team,
					"player_id": home_shooter,
					"success": true,
					"description": "Elfmeter verwandelt",
					"penalty_shootout": true
				})
			elif i < 5:  # Verschossener Elfmeter
				match_result.events.append({
					"minute": 120,
					"type": EventEngine.EventType.ELFMETER,
					"team_id": match_result.home_team,
					"player_id": home_shooter,
					"success": false,
					"description": "Elfmeter verschossen",
					"penalty_shootout": true
				})
			
			# Gast-Elfmeter
			var away_shooter = away_players[i % away_players.size()] if away_players.size() > 0 else ""
			if i < penalty_away:
				match_result.events.append({
					"minute": 120,
					"type": EventEngine.EventType.ELFMETER,
					"team_id": match_result.away_team,
					"player_id": away_shooter,
					"success": true,
					"description": "Elfmeter verwandelt",
					"penalty_shootout": true
				})
			elif i < 5:  # Verschossener Elfmeter
				match_result.events.append({
					"minute": 120,
					"type": EventEngine.EventType.ELFMETER,
					"team_id": match_result.away_team,
					"player_id": away_shooter,
					"success": false,
					"description": "Elfmeter verschossen",
					"penalty_shootout": true
				})
		
		# Sieger durch Elfmeterschießen
		if penalty_home > penalty_away:
			match_result.winner = match_result.home_team
		else:
			match_result.winner = match_result.away_team
	else:
		# Sieger durch Verlängerung
		if match_result.home_goals > match_result.away_goals:
			match_result.winner = match_result.home_team
		else:
			match_result.winner = match_result.away_team
	
	match_result.draw = false  # Kein Unentschieden mehr nach Verlängerung/Elfmeter
	return match_result

func _is_league_phase_match(match_data: Dictionary) -> bool:
	"""Prüft ob es ein Liga-Phase Match ist (Swiss System) - erlaubt Unentschieden"""
	# Champions League Liga-Phase: Erste 8 Spieltage (Swiss System)
	# Europa League Liga-Phase: Erste 8 Spieltage (Swiss System)
	# Conference League Liga-Phase: Erste 6 Spieltage (Swiss System)
	
	var week_info = schedule_generator.get_current_week_info()
	if not week_info.has("cup_type"):
		print("  → DEBUG: week_info hat kein cup_type")
		return false
	
	var cup_type = week_info.cup_type
	var round = week_info.get("round", 0)
	
	print("  → DEBUG: Liga-Phase Check - cup_type=%s, round=%d" % [str(cup_type), round])
	
	# EU_CUPS String bedeutet alle EU-Pokale gleichzeitig - immer Liga-Phase in den ersten Runden
	if typeof(cup_type) == TYPE_STRING and cup_type == "EU_CUPS":
		var is_league_phase = round <= 8  # EU-Pokale Liga-Phase: Spieltag 1-8
		print("  → DEBUG: EU_CUPS Liga-Phase? %s (Round %d <= 8)" % [str(is_league_phase), round])
		return is_league_phase
	
	# Liga-Phase Spieltage für einzelne EU-Pokale (Swiss System)
	match cup_type:
		CupManager.CupType.CHAMPIONS_LEAGUE:
			return round <= 8  # CL Liga-Phase: Spieltag 1-8
		CupManager.CupType.EUROPA_LEAGUE:
			return round <= 8  # EL Liga-Phase: Spieltag 1-8
		CupManager.CupType.CONFERENCE_LEAGUE:
			return round <= 6  # ECL Liga-Phase: Spieltag 1-6
		_:
			print("  → DEBUG: Kein EU-Pokal - KO-Spiel")
			return false  # DFB-Pokal etc. sind immer KO-Spiele

func _get_team_players_for_penalties(team_id: String) -> Array:
	"""Liefert 5 beste Spieler eines Teams für Elfmeterschießen"""
	var team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		return []
	
	var starting_eleven = team_data.get("starting_eleven", [])
	if starting_eleven.size() >= 5:
		return starting_eleven.slice(0, 5)
	
	# Fallback: Aus Kader die ersten 5
	var player_roster = team_data.get("player_roster", [])
	return player_roster.slice(0, min(5, player_roster.size()))

func _get_random_team_player(team_id: String) -> String:
	"""Liefert zufälligen Spieler aus Team für Events"""
	var team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		return ""
	
	var starting_eleven = team_data.get("starting_eleven", [])
	if starting_eleven.size() > 0:
		return starting_eleven[randi() % starting_eleven.size()]
	
	# Fallback: Aus Kader
	var player_roster = team_data.get("player_roster", [])
	if player_roster.size() > 0:
		return player_roster[randi() % player_roster.size()]
	
	return ""

# ENTFERNT: Combined week functions - zurück zu separaten Liga/Cup Spieltagen

func _simulate_winter_break(week_info: Dictionary):
	"""Simuliert Winterpause - überspringt automatisch 3 Wochen"""
	var current_week = GameManager.get_week()
	print("MatchdayEngine: WINTERPAUSE beginnt (Woche %d)" % current_week)
	current_simulation.cup_results = {}
	current_simulation.user_match = {}  # Leeres Match für UI
	
	# Spieler-Regeneration während Winterpause
	_apply_winter_break_effects()
	
	# WINTERPAUSE: Überspringe automatisch zur Woche 24 (Ende der Winterpause)
	# Wochen 21-23 sind Winterpause, Woche 24 ist erste Woche nach Pause
	if current_week >= 21 and current_week <= 23:
		print("MatchdayEngine: Überspringe Winterpause-Wochen %d-%d" % [current_week, 23])
		# Setze Woche direkt auf 23, _finalize_week() macht dann +1 auf 24
		while GameManager.get_week() < 23:
			GameManager.advance_week()
		print("MatchdayEngine: Winterpause beendet - nächste Woche: %d" % (GameManager.get_week() + 1))
	
	# Signal senden damit UI weiß dass Simulation fertig ist
	user_match_completed.emit({})
	await get_tree().process_frame

func _simulate_summer_break(week_info: Dictionary):
	"""Simuliert Sommerpause - überspringt automatisch zur neuen Saison"""
	var current_week = GameManager.get_week()
	print("MatchdayEngine: SOMMERPAUSE beginnt (Woche %d)" % current_week)
	current_simulation.cup_results = {}
	current_simulation.user_match = {}  # Leeres Match für UI
	
	# Sommerpause-Effekte (Transfers, Regeneration, etc.)
	_apply_summer_break_effects()
	
	# SOMMERPAUSE: Überspringe automatisch zur neuen Saison (Woche 1)
	# Wochen 44-52 sind Sommerpause, dann neue Saison
	if current_week >= 44 and current_week <= 52:
		print("MatchdayEngine: Überspringe Sommerpause-Wochen %d-52" % current_week)
		# Setze Woche direkt auf 52, _finalize_week() macht dann +1 und startet neue Saison
		while GameManager.get_week() < 52:
			GameManager.advance_week()
		print("MatchdayEngine: Sommerpause beendet - neue Saison beginnt!")
	
	# Signal senden damit UI weiß dass Simulation fertig ist
	user_match_completed.emit({})
	await get_tree().process_frame

func _apply_winter_break_effects():
	"""Wendet Winterpause-Effekte an (Regeneration)"""
	# Alle Spieler regenerieren sich
	for player_id in GameManager.player_index.keys():
		var player_data = GameManager.get_player(player_id)
		var player = PlayerData.new(player_data)
		
		# Leichte Form-Regeneration
		if player.current_form < 12:
			player.current_form = min(15, player.current_form + 2)
		
		# Verletzungen heilen schneller
		if player.verletzungsart != "":
			# 50% Chance auf verkürzte Heilung
			if randf() < 0.5:
				print("Winterpause: %s erholt sich schneller von Verletzung" % player.get_display_name())

func _apply_summer_break_effects():
	"""Wendet Sommerpause-Effekte an (Transfers, Vollregeneration)"""
	# Vollständige Regeneration aller Spieler
	for player_id in GameManager.player_index.keys():
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			var player = PlayerData.new(player_data)
			
			# Form auf Standard zurücksetzen
			player.current_form = 10
			
			# Alle Verletzungen heilen
			player.verletzungsart = ""
			player.zustand = "Fit"

func _get_cup_name(cup_type) -> String:
	if typeof(cup_type) == TYPE_STRING:
		match cup_type:
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

func _simulate_other_leagues_async(user_league_id: int):
	print("MatchdayEngine: Simulating other leagues PARALLEL after user league...")
	current_simulation.other_leagues_results = {}
	
	var leagues_to_simulate = []
	for league_id in [1, 2, 3]:
		if league_id != user_league_id:
			leagues_to_simulate.append(league_id)
	
	# 2.Liga + 3.Liga echte parallele Berechnung mit await
	await _simulate_leagues_parallel(leagues_to_simulate)


func _simulate_match_cached(home_team_id: String, away_team_id: String) -> Dictionary:
	# Ultra-schnelle Match-Simulation mit gecachten Team-Stärken
	var home_strength = cached_team_strengths.get(home_team_id, {}).get("home", 50.0)
	var away_strength = cached_team_strengths.get(away_team_id, {}).get("away", 50.0)
	
	var total_strength = home_strength + away_strength
	var home_win_chance = home_strength / total_strength
	
	var random_value = randf()
	var home_goals: int
	var away_goals: int
	
	if random_value < home_win_chance * 0.6:  # 60% der theoretischen Chance
		home_goals = randi_range(1, 3)
		away_goals = randi_range(0, 1)
	elif random_value > (1.0 - (1.0 - home_win_chance) * 0.4):  # 40% Auswärts-Chance
		away_goals = randi_range(1, 3)
		home_goals = randi_range(0, 1)
	else:  # Unentschieden-Bereich
		var draw_goals = randi_range(0, 2)
		home_goals = draw_goals
		away_goals = draw_goals
	
	var winner = ""
	if home_goals > away_goals:
		winner = home_team_id
	elif away_goals > home_goals:
		winner = away_team_id
	
	return {
		"home_team": home_team_id,
		"away_team": away_team_id,
		"home_goals": max(0, home_goals),
		"away_goals": max(0, away_goals),
		"home_strength": home_strength,
		"away_strength": away_strength,
		"winner": winner,
		"draw": home_goals == away_goals,
		"events": []
	}

func _process_user_league_matches(all_matches: Array, league_id: int, current_matchday: int, user_match: Dictionary):
	# KERN 5: User + Konferenz mit vollen Events (Liga-Matches)
	print("MatchdayEngine: Processing %d Liga-matches for User League %d..." % [all_matches.size(), league_id])
	
	# VOLLSTÄNDIGE EventEngine für GESAMTE Liga (User + Konferenz)
	# KORREKTUR: Liga-Konferenz auch mit vollen Events (wie User-Match)
	var all_results = []
	
	for match in all_matches:
		var result = MatchEngine.simulate_match_instant(match.home_team, match.away_team)
		all_results.append({
			"match_data": match,
			"result": result
		})
	
	# User-Match identifizieren und speichern
	var user_result = null
	for match_result in all_results:
		if match_result.match_data == user_match:
			user_result = match_result.result
			break
	
	# User-Match speichern
	current_simulation.user_match = user_result
	
	# Konferenz-Matches speichern (alle anderen Matches außer User-Match)
	for match_result in all_results:
		if match_result.match_data != user_match:
			var match_data = match_result.match_data
			var result = match_result.result
			
			current_simulation.conference_results[league_id].append({
				"home_team": match_data.home_team,
				"away_team": match_data.away_team,
				"result": result
			})
			conference_match_completed.emit(league_id, match_data.home_team, match_data.away_team, result)
	
	# User League Matches abgeschlossen

func _simulate_leagues_parallel(league_ids: Array):
	print("MatchdayEngine: PARALLEL processing leagues %s..." % str(league_ids))
	
	var league_data = {}
	
	# Vorbereitung: Alle Liga-Daten sammeln
	for league_id in league_ids:
		if LeagueManager.is_season_finished(league_id):
			continue
			
		var current_matchday = LeagueManager.get_current_matchday(league_id)
		var fixtures = ScheduleGenerator.get_current_matchday_fixtures(league_id)
		
		if not fixtures.is_empty():
			league_data[league_id] = {
				"matchday": current_matchday,
				"fixtures": fixtures
			}
			current_simulation.other_leagues_results[league_id] = []
	
	# PARALLEL: Alle Ligen gleichzeitig berechnen mit await
	print("MatchdayEngine: PARALLEL processing %d leagues..." % league_data.size())
	
	# PARALLEL: Alle Ligen gleichzeitig starten (ohne await)
	for league_id in league_data.keys():
		var data = league_data[league_id]
		_process_league_matches_instant(league_id, data.fixtures)
	
	# PERFORMANCE FIX: Keine await-Schleife nötig, da alles synchron läuft
	# Alle Matches werden direkt in _process_league_matches_instant berechnet
	
	# Alle Ligen abgeschlossen


func _process_league_matches_instant(league_id: int, fixtures: Array):
	# Liga-Matches instant berechnen
	print("MatchdayEngine: Processing %d matches for League %d..." % [fixtures.size(), league_id])
	
	# Alle Matches in einem Schritt
	for match_data in fixtures:
		# Authentisch stärkebasiert ohne Random wie im Original
		var result = MatchEngine.simulate_match_lightning(match_data.home_team, match_data.away_team)
		
		# Ergebnis speichern
		current_simulation.other_leagues_results[league_id].append({
			"home_team": match_data.home_team,
			"away_team": match_data.away_team,
			"result": result
		})
	
	# Liga %d abgeschlossen (%d Matches)" % [league_id, fixtures.size()]

func _finalize_week():
	"""KERN 5: Schließt Spieltag ab - prüft ob noch weitere Spieltage in der Woche"""
	# Form-Updates für alle Spieler nach jedem Spiel
	_update_all_teams_form()
	
	var current_week = GameManager.get_week()
	var current_matchday_of_week = GameManager.get_matchday_of_week()
	var total_matchdays_this_week = ScheduleGenerator.get_matchdays_count_for_week(current_week)
	
	print("MatchdayEngine: Spieltag %d von %d in Woche %d beendet" % [current_matchday_of_week, total_matchdays_this_week, current_week])
	
	# Prüfen: Noch weitere Spieltage in dieser Woche?
	if current_matchday_of_week < total_matchdays_this_week:
		# Noch ein Spieltag in derselben Woche
		GameManager.advance_matchday_of_week()
		print("MatchdayEngine: Nächster Spieltag in derselben Woche")
	else:
		# Woche abgeschlossen - zur nächsten Woche
		GameManager.advance_week()
		print("MatchdayEngine: Woche beendet - nächste Woche")
	
	# Je nach Wochentyp: verschiedene Finalisierung
	var week_info = current_simulation.get("week_info", {})
	match week_info.get("type"):
		"league":
			_finalize_league_matchday()
		"cup":
			_finalize_cup_week()
		"combined":
			# Combined wird behandelt wie der aktuelle Spieltag-Typ
			pass
		"winter_break":
			_finalize_winter_break()
		"summer_break":
			_finalize_summer_break()
	
	# Simulation abgeschlossen - nur senden wenn Woche wirklich fertig
	if current_matchday_of_week >= total_matchdays_this_week:
		all_leagues_completed.emit()
	matchday_results_ready.emit(current_simulation)

func _finalize_cup_week():
	"""Finalisiert Pokal-Woche (keine Liga-Spieltag-Avancement)"""
	print("MatchdayEngine: Pokal-Woche abgeschlossen")
	# Pokal-Runden werden vom CupManager/ScheduleGenerator verwaltet
	# Keine Liga-Spieltag-Änderungen

func _finalize_winter_break():
	"""Finalisiert Winterpause"""
	print("MatchdayEngine: Winterpause-Woche abgeschlossen")
	# Regenerations-Effekte bereits in _simulate_winter_break angewandt

func _finalize_summer_break():
	"""Finalisiert Sommerpause"""
	print("MatchdayEngine: Sommerpause-Woche abgeschlossen")
	# Transfer/Regenerations-Effekte bereits in _simulate_summer_break angewandt

func _finalize_league_matchday():
	"""Ursprüngliche Matchday-Finalisierung für Liga-Wochen"""
	print("MatchdayEngine: Finalizing matchday...")
	
	# 3.3 SPIELTAG-ABLAUF IMPLEMENTIERUNG - Schritt 7-8:
	# 7. Form-Updates, Verletzungen behandeln
	_update_all_teams_form()
	
	# 8. Nächster Spieltag vorbereiten
	_prepare_next_matchday()
	
	# Simulation abschließen
	var simulation_time = Time.get_ticks_msec() - current_simulation.start_time
	print("MatchdayEngine: Matchday simulation completed in %d ms" % simulation_time)
	
	matchday_results_ready.emit(current_simulation)
	# all_leagues_completed wird bereits in _finalize_week() gesendet

func _prepare_next_matchday():
	# Spieltage in allen Ligen voranschreiten
	for league_id in [1, 2, 3]:
		if not LeagueManager.is_season_finished(league_id):
			LeagueManager.advance_matchday(league_id)
	
	print("MatchdayEngine: Next matchday prepared for all leagues")

func _update_all_teams_form():
	# Form-Updates basierend auf Ergebnissen
	var user_result = current_simulation.get("user_match", {})
	
	if not user_result.is_empty():
		FormSystem.update_team_after_match(user_result.home_team, user_result)
		FormSystem.update_team_after_match(user_result.away_team, user_result)
	
	# Conference und andere Liga Form-Updates
	for league_id in current_simulation.get("conference_results", {}).keys():
		for match_data in current_simulation.conference_results[league_id]:
			FormSystem.update_team_after_match(match_data.home_team, match_data.result)
			FormSystem.update_team_after_match(match_data.away_team, match_data.result)
	
	for league_id in current_simulation.get("other_leagues_results", {}).keys():
		for match_data in current_simulation.other_leagues_results[league_id]:
			FormSystem.update_team_after_match(match_data.home_team, match_data.result)
			FormSystem.update_team_after_match(match_data.away_team, match_data.result)
	
	# Sperren und Verletzungen nach Spieltag abarbeiten (nur einmal pro Simulation)
	if not suspension_system_processed:
		var suspension_system = get_node_or_null("/root/SuspensionSystem")
		if suspension_system:
			suspension_system.advance_matchday()
			suspension_system_processed = true
			print("MatchdayEngine: SuspensionSystem.advance_matchday() ausgeführt")

func get_current_simulation_results() -> Dictionary:
	return current_simulation

func get_user_match_opponent() -> Dictionary:
	"""KERN 5: Ermittelt nächsten Gegner basierend auf Wochentyp"""
	var user_team_id = LeagueManager.user_team_id
	var user_league = LeagueManager.user_league
	var current_week = GameManager.get_week()
	var week_info = schedule_generator.get_current_week_info()
	
	match week_info.type:
		"league":
			return ScheduleGenerator.get_team_next_opponent(user_league, user_team_id)
		"cup":
			return ScheduleGenerator.get_team_next_cup_opponent(user_team_id, week_info)
		_:
			return {"opponent": "Keine Spiele", "type": week_info.type}

func get_current_week_matches() -> Dictionary:
	"""KERN 5: Liefert alle Spiele für aktuelle Woche (Liga oder Pokal)"""
	var current_week = GameManager.get_week()
	var week_info = schedule_generator.get_current_week_info()
	var user_team_id = LeagueManager.user_team_id
	
	match week_info.type:
		"league":
			return {
				"type": "league",
				"matches": ScheduleGenerator.get_current_matchday_fixtures(LeagueManager.user_league),
				"matchday": week_info.get("league_matchday", 1)
			}
		"cup":
			return {
				"type": "cup",
				"matches": schedule_generator.get_cup_matches_for_week(current_week),
				"cup_info": week_info
			}
		_:
			return {"type": week_info.type, "matches": []}

func can_advance_week() -> bool:
	"""KERN 5: Prüft ob Woche voranschreiten kann (max 2 Spiele pro Woche)"""
	var current_week = GameManager.get_week()
	var week_info = schedule_generator.get_current_week_info()
	
	# In Pausen: immer voranschreiten möglich
	if week_info.type in ["winter_break", "summer_break"]:
		return true
	
	# Liga/Pokal: max 2 Spiele pro Woche checken
	# TODO: Implementierung abhängig von ScheduleGenerator Struktur
	return true  # Vorerst immer erlauben

func get_matchday_summary(league_id: int) -> Dictionary:
	var current_matchday = LeagueManager.get_current_matchday(league_id) - 1  # Letzte simulierte Matchday
	var fixtures = ScheduleGenerator.get_matchday_fixtures(league_id, current_matchday)
	
	var goals_total = 0
	var matches_played = 0
	var biggest_win = {"difference": 0, "match": ""}
	
	for match in fixtures:
		if match.played:
			matches_played += 1
			goals_total += match.home_goals + match.away_goals
			
			var goal_diff = abs(match.home_goals - match.away_goals)
			if goal_diff > biggest_win.difference:
				biggest_win.difference = goal_diff
				biggest_win.match = "%s %d:%d %s" % [match.home_team, match.home_goals, match.away_goals, match.away_team]
	
	return {
		"matchday": current_matchday,
		"matches_played": matches_played,
		"total_goals": goals_total,
		"average_goals": float(goals_total) / matches_played if matches_played > 0 else 0.0,
		"biggest_win": biggest_win
	}

func is_matchday_simulation_running() -> bool:
	return is_simulating

func get_week_summary() -> Dictionary:
	"""KERN 5: Zusammenfassung der aktuellen Woche für UI-Anzeige"""
	var current_week = GameManager.get_week()
	var week_info = schedule_generator.get_current_week_info()
	var user_team_id = LeagueManager.user_team_id
	
	var summary = {
		"week": current_week,
		"type": week_info.type,
		"description": week_info.get("description", week_info.type),
		"user_team": GameManager.get_team(user_team_id).get("team_name", "Unbekannt"),
		"next_opponent": null,
		"matches_this_week": 0
	}
	
	# Nächster Gegner je nach Wochentyp
	var opponent_info = get_user_match_opponent()
	if opponent_info.has("opponent") and opponent_info.opponent != "Keine Spiele":
		summary.next_opponent = opponent_info
	
	# Spiele zählen (Liga vs Pokal unterscheiden)
	var week_matches = get_current_week_matches()
	if week_matches.has("matches"):
		var user_matches = 0
		var matches = week_matches.matches
		
		match week_matches.type:
			"league":
				# Liga: matches ist Array
				if typeof(matches) == TYPE_ARRAY:
					for match in matches:
						if match.get("home_team", "") == user_team_id or match.get("away_team", "") == user_team_id:
							user_matches += 1
			"cup":
				# Pokal: matches ist Dictionary mit cup_type -> Array
				if typeof(matches) == TYPE_DICTIONARY:
					for cup_type in matches.keys():
						var match_list = matches[cup_type]
						if typeof(match_list) == TYPE_ARRAY:
							for match in match_list:
								if match.get("home_team", "") == user_team_id or match.get("away_team", "") == user_team_id:
									user_matches += 1
		
		summary.matches_this_week = user_matches
	
	return summary

func get_simulation_progress() -> Dictionary:
	if not is_simulating:
		return {"running": false}
	
	var week_info = current_simulation.get("week_info", {})
	var progress = {
		"running": true,
		"week_type": week_info.get("type", "unknown"),
		"user_match_completed": not current_simulation.user_match.is_empty(),
		"conference_count": current_simulation.get("conference_results", {}).size(),
		"other_leagues_count": current_simulation.get("other_leagues_results", {}).size(),
		"cup_results_count": current_simulation.get("cup_results", {}).size()
	}
	
	return progress
