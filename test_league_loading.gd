extends Node

func _ready():
	print("=== KERN 3 LEAGUE LOADING TEST ===")
	
	# Initialize GameManager first
	GameManager.initialize_game()
	await get_tree().process_frame
	
	print("GameManager teams loaded: %d" % GameManager.teams.size())
	
	# Initialize LeagueManager
	LeagueManager.initialize_leagues()
	await get_tree().process_frame
	
	# Check all leagues
	for league_id in [1, 2, 3]:
		var teams = LeagueManager.get_league_teams(league_id)
		var config = LeagueManager.league_config[league_id]
		print("\n%s: %d teams" % [config.name, teams.size()])
		
		if teams.size() > 0:
			print("  First team: %s (%s)" % [teams[0].name, teams[0].id])
			print("  Last team: %s (%s)" % [teams[-1].name, teams[-1].id])
		
		if teams.size() != config.teams:
			print("  ❌ ERROR: Expected %d teams, got %d" % [config.teams, teams.size()])
		else:
			print("  ✅ OK: Correct team count")
	
	# Test user team selection
	print("\n=== USER TEAM SELECTION TEST ===")
	var available_teams = LeagueManager.get_user_available_teams()
	print("Available teams for user: %d" % available_teams.size())
	
	if available_teams.size() > 0:
		var test_team = available_teams[0]
		if LeagueManager.set_user_team(test_team.id):
			print("✅ User team set to: %s" % test_team.name)
		else:
			print("❌ Failed to set user team")
	
	print("\n=== TEST COMPLETED ===")
	get_tree().quit()