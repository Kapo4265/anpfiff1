extends SceneTree

func _init():
	print("=== SCHEDULE DEBUG TEST ===")
	
	# GameManager initialisieren
	GameManager.initialize_game()
	await get_process_frame()
	
	# Liga-System initialisieren
	if LeagueManager.get_league_teams(1).is_empty():
		print("Warte auf Liga-Initialisierung...")
		await LeagueManager.league_initialized
	
	# User-Team setzen
	var liga1_teams = LeagueManager.get_league_teams(1)
	LeagueManager.set_user_team(liga1_teams[0].id)
	print("User-Team: %s" % liga1_teams[0].name)
	
	# Spielpläne generieren
	ScheduleGenerator.generate_all_schedules()
	print("Spielpläne generiert")
	
	# Test: Erste 3 Spieltage von Liga 1 prüfen
	for matchday in range(1, 4):
		print("\n=== LIGA 1 SPIELTAG %d ===" % matchday)
		var fixtures = ScheduleGenerator.get_matchday_fixtures(1, matchday)
		print("Fixtures gefunden: %d" % fixtures.size())
		
		var user_team_id = LeagueManager.user_team_id
		var user_match_found = false
		
		for match in fixtures:
			if match.home_team == user_team_id or match.away_team == user_team_id:
				var home_name = GameManager.get_team(match.home_team).team_name
				var away_name = GameManager.get_team(match.away_team).team_name
				print("USER-MATCH: %s vs %s" % [home_name, away_name])
				user_match_found = true
			
		if not user_match_found:
			print("ERROR: User-Match nicht gefunden!")
		else:
			print("OK: User-Match gefunden")
	
	# Test: current_matchday prüfen
	print("\n=== CURRENT MATCHDAY TEST ===")
	for league_id in [1, 2, 3]:
		var current = LeagueManager.get_current_matchday(league_id)
		print("Liga %d: Aktueller Spieltag = %d" % [league_id, current])
	
	quit()