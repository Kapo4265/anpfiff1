extends SceneTree

func _init():
	print("=== PERFORMANCE TEST START ===")
	
	# Initialisierung wie in test_kern1.gd
	GameManager.load_teams()
	GameManager.load_players()
	GameManager.build_team_indices()
	
	# Liga-System initialisieren
	LeagueManager._init_leagues()
	ScheduleGenerator.generate_all_leagues_schedule()
	LeagueManager.set_user_team("t01")
	
	print("Setup complete, starting performance test...")
	
	# 5 Spieltage simulieren für Performance-Test
	var total_time = 0
	var runs = 5
	
	for i in range(runs):
		var start_time = Time.get_ticks_msec()
		
		# Spieltag simulieren
		await MatchdayEngine.simulate_matchday()
		
		var elapsed = Time.get_ticks_msec() - start_time
		total_time += elapsed
		print("Spieltag %d: %d ms" % [i+1, elapsed])
	
	var avg_time = total_time / runs
	print("\n=== PERFORMANCE RESULTS ===")
	print("Total time: %d ms" % total_time)
	print("Average per matchday: %d ms" % avg_time)
	print("Matches per matchday: 24 (9+9+6)")
	print("Average per match: %d ms" % (avg_time / 24))
	
	if avg_time < 2000:
		print("✅ EXCELLENT: < 2 seconds per matchday")
	elif avg_time < 5000:
		print("⚠️ ACCEPTABLE: < 5 seconds per matchday")
	else:
		print("❌ TOO SLOW: > 5 seconds per matchday")
	
	quit()