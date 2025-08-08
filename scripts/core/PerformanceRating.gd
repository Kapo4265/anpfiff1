extends Node

# PerformanceRating für KERN 3: Leistungsbewertung 0-10 pro Spieler/Match
# AUTHENTISCHE ANSTOSS 1 BEWERTUNG basierend auf Event-Performance

# KEINE SINGLETON - wird von StatisticsCollector und test_kern1.gd verwendet

static func calculate_player_match_rating(player_id: String, events: Array) -> float:
	# AUTHENTISCHE ANSTOSS 1 BEWERTUNG (0-10 Skala)
	var base_rating = 6.0  # Grundnote
	var bonus_points = 0.0
	var penalty_points = 0.0
	
	for event in events:
		if event.get("player_id", "") == player_id:
			match event.get("type"):
				EventEngine.EventType.NORMAL_ATTACK:
					if event.get("success", false):
						bonus_points += 2.0  # Tor: +2.0
					else:
						bonus_points += 0.3  # Torchance: +0.3
				
				EventEngine.EventType.FREISTOSS:
					if event.get("success", false):
						bonus_points += 1.8  # Freistoß-Tor: +1.8
					else:
						bonus_points += 0.2  # Freistoß: +0.2
				
				EventEngine.EventType.ALLEINGANG:
					if event.get("success", false):
						bonus_points += 2.5  # Alleingang-Tor: +2.5
					else:
						bonus_points += 0.5  # Alleingang-Versuch: +0.5
				
				EventEngine.EventType.ELFMETER:
					if event.get("success", false):
						bonus_points += 1.5  # Elfmeter verwandelt: +1.5
					else:
						penalty_points += 1.0  # Elfmeter verschossen: -1.0
				
				EventEngine.EventType.VERLETZUNG:
					penalty_points += 0.5  # Verletzung: -0.5
				
				EventEngine.EventType.TACKLING:
					if event.get("success", false):
						penalty_points += 0.8  # Karte: -0.8
					else:
						bonus_points += 0.1  # Sauberes Tackling: +0.1
				
				EventEngine.EventType.GELBE_KARTE:
					penalty_points += 0.8  # Gelbe Karte: -0.8
				
				EventEngine.EventType.ROTE_KARTE:
					penalty_points += 2.5  # Rote Karte: -2.5
	
	var final_rating = base_rating + bonus_points - penalty_points
	return clamp(final_rating, 1.0, 10.0)  # Note zwischen 1.0 und 10.0

static func get_rating_text(rating: float) -> String:
	# Textuelle Bewertung für UI-Anzeige
	if rating >= 9.0:
		return "⭐⭐⭐"
	elif rating >= 7.5:
		return "⭐⭐"
	elif rating >= 6.0:
		return "⭐"
	elif rating >= 4.0:
		return "👍"
	else:
		return "👎"

static func calculate_eleven_of_the_day(all_events: Array) -> Dictionary:
	# 11 of the day System: Beste Formation basierend auf Match-Bewertungen
	print("PerformanceRating: Calculating 11 of the day...")
	
	# Alle 1. Liga Spieler bewerten (198 Spieler aus 18 Teams)
	var all_player_ratings = []
	var liga1_teams = LeagueManager.get_league_teams(1)
	
	for team in liga1_teams:
		var team_data = GameManager.get_team(team.id)
		
		# KORREKT: starting_eleven MUSS vorhanden sein (von MatchdayEngine gesetzt)
		var starting_eleven = team_data.get("starting_eleven", [])
		if starting_eleven.is_empty():
			print("PerformanceRating: FEHLER - Team %s hat keine starting_eleven! Keys: %s" % [team.id, team_data.keys()])
			continue  # Team überspringen
		
		print("PerformanceRating: Team %s - %d Spieler verarbeitet" % [team.id, starting_eleven.size()])
		
		# Alle 11 Startspieler bewerten
		for player_id in starting_eleven:
			if player_id == "" or player_id == null:
				print("PerformanceRating: FEHLER - Team %s hat leeren player_id in starting_eleven!" % team.id)
				continue
				
			var player_data = GameManager.get_player(player_id)
			if player_data.is_empty():
				print("PerformanceRating: WARNING - Spieler %s nicht gefunden" % player_id)
				continue
			
			# PERFORMANCE: Direkte Dictionary-Zugriffe statt PlayerData.new()
			var first_name = player_data.get("first_name", "")
			var last_name = player_data.get("last_name", "")
			var full_name = first_name + " " + last_name
			var position = player_data.get("primary_position", "MF")
			var match_rating = calculate_player_match_rating(player_id, all_events)
			
			all_player_ratings.append({
				"id": player_id,
				"name": full_name,
				"position": position,
				"team_id": team.id,
				"match_rating": match_rating
			})
	
	print("PerformanceRating: Gesamt %d Spieler-Bewertungen gesammelt" % all_player_ratings.size())
	
	# DEBUG: Erste 5 Spieler-Positionen prüfen
	for i in range(min(5, all_player_ratings.size())):
		var rating = all_player_ratings[i]
		print("PerformanceRating: DEBUG - Spieler %s hat Position '%s'" % [rating.name, rating.position])
	
	# Nach Position gruppieren und beste Spieler auswählen
	# FIXED: Map deutsche Positionen zu internen Codes
	var positions = {"TW": [], "AB": [], "MF": [], "ST": []}
	
	for rating in all_player_ratings:
		var pos = rating.position
		# Map deutsche Bezeichnungen zu internen Codes
		var mapped_pos = ""
		match pos:
			"Torwart": mapped_pos = "TW"
			"Abwehr": mapped_pos = "AB"
			"Mittelfeld": mapped_pos = "MF"
			"Sturm": mapped_pos = "ST"
			_: 
				print("FEHLER: Unbekannte Position '%s'!" % pos)
				assert(false, "CRITICAL: Unbekannte Spielerposition")
				mapped_pos = "MF"
		
		if positions.has(mapped_pos):
			positions[mapped_pos].append(rating)
		else:
			print("PerformanceRating: UNBEKANNTE POSITION '%s' für Spieler %s" % [pos, rating.name])
	
	# DEBUG: Positions-Verteilung anzeigen
	for pos in positions.keys():
		print("PerformanceRating: Position %s hat %d Spieler" % [pos, positions[pos].size()])
	
	# Beste Spieler pro Position sortieren und auswählen
	var eleven_of_the_day = {
		"TW": get_best_players_by_position(positions["TW"], 1),
		"AB": get_best_players_by_position(positions["AB"], 4), 
		"MF": get_best_players_by_position(positions["MF"], 4),
		"ST": get_best_players_by_position(positions["ST"], 2)
	}
	
	var total_players = _count_eleven_players(eleven_of_the_day)
	print("PerformanceRating: 11 of the day calculated - %d players total" % total_players)
	
	return eleven_of_the_day

static func get_best_players_by_position(position_players: Array, count: int) -> Array:
	# Hilfsfunktion für 11 of the day System
	position_players.sort_custom(func(a, b): return a.match_rating > b.match_rating)
	
	var result = []
	for i in range(min(count, position_players.size())):
		result.append(position_players[i])
	
	return result

static func _count_eleven_players(eleven_dict: Dictionary) -> int:
	var total = 0
	for position in eleven_dict.values():
		total += position.size()
	return total