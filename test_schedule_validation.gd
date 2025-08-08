extends SceneTree

func _init():
	print("=== SCHEDULE VALIDATION TEST ===")
	
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
	
	# WICHTIG: Spielpläne generieren
	ScheduleGenerator.generate_all_schedules()
	
	# Test 1: Liga 1 Schedule Größe
	var liga1_schedule = ScheduleGenerator.get_league_schedule(1)
	print("Liga 1 Schedule: %d Spieltage (erwartet: 34)" % liga1_schedule.size())
	
	if liga1_schedule.size() != 34:
		print("ERROR: Liga 1 hat %d statt 34 Spieltage!" % liga1_schedule.size())
	
	# Test 2: Jeder Spieltag hat Matches
	for i in range(min(5, liga1_schedule.size())):  # Erste 5 Spieltage testen
		var matchday = i + 1
		var fixtures = ScheduleGenerator.get_matchday_fixtures(1, matchday)
		print("Spieltag %d: %d Matches" % [matchday, fixtures.size()])
		
		if fixtures.is_empty():
			print("ERROR: Spieltag %d hat keine Matches!" % matchday)
		
		# Prüfe ob User-Team spielt
		var user_team_id = LeagueManager.user_team_id
		var user_match_found = false
		
		for match in fixtures:
			if match.home_team == user_team_id or match.away_team == user_team_id:
				user_match_found = true
				break
		
		if user_match_found:
			print("  ✓ User-Match gefunden")
		else:
			print("  ✗ User-Match NICHT gefunden!")
	
	# Test 3: Current matchday Test
	print("\n=== CURRENT MATCHDAY TEST ===")
	var initial_matchday = LeagueManager.get_current_matchday(1)
	print("Initial current_matchday: %d" % initial_matchday)
	
	# Advance und teste
	LeagueManager.advance_matchday(1)
	var after_advance = LeagueManager.get_current_matchday(1)
	print("After advance_matchday: %d" % after_advance)
	
	if after_advance != initial_matchday + 1:
		print("ERROR: advance_matchday funktioniert nicht korrekt!")
	
	# Test fixtures für Spieltag 2
	var matchday2_fixtures = ScheduleGenerator.get_current_matchday_fixtures(1)
	print("Spieltag 2 Fixtures: %d" % matchday2_fixtures.size())
	
	if matchday2_fixtures.is_empty():
		print("ERROR: Keine Fixtures für Spieltag 2!")
	else:
		print("✓ Spieltag 2 Fixtures OK")
	
	quit()