extends Node

func update_team_after_match(team_id: String, result: Dictionary):
	var team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		return
	
	var team = TeamData.new(team_data)
	var won = false
	var draw = false
	
	if result.winner == team_id:
		won = true
	elif result.draw:
		draw = true
	
	team.update_morale_after_match(won, draw)
	
	GameManager.teams[team_id].morale = team.morale
	
	update_players_after_match(team_id, won, result)

func update_players_after_match(team_id: String, won: bool, result: Dictionary):
	var team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		return
	
	var team = TeamData.new(team_data)
	
	for player_id in team.starting_eleven:
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			var player = PlayerData.new(player_data)
			
			var scored_goal = false
			var own_goal = false
			
			player.update_form_after_match(won, scored_goal, own_goal)
			
			GameManager.players[player_id].current_form = player.current_form
			
			print("%s new form: %.1f" % [player.get_full_name(), player.current_form])

func get_form_description(form_value: float) -> String:
	if form_value >= 18.0:
		return "Überragend"
	elif form_value >= 15.0:
		return "Sehr gut"
	elif form_value >= 12.0:
		return "Gut"
	elif form_value >= 8.0:
		return "Durchschnitt"
	elif form_value >= 5.0:
		return "Schwach"
	else:
		return "Sehr schwach"