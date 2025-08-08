extends Node

# Neuer realistischer Spielplan-Generator mit mehreren Spielen pro Woche

func create_realistic_season_schedule() -> Array:
	"""Erstellt realistischen Saisonkalender wie im echten Fußball"""
	var season_weeks = []
	
	# AUGUST (Wochen 1-4): Saisonstart
	season_weeks.append({
		"week": 1, 
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 1, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 2,
		"type": "match_week", 
		"matches": [
			{"type": "league", "matchday": 2, "day": "saturday"},
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 1, "day": "tuesday"}
		]
	})
	
	season_weeks.append({
		"week": 3,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 3, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 4,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 4, "day": "saturday"}
		]
	})
	
	# SEPTEMBER (Wochen 5-8): CL/EL startet
	season_weeks.append({
		"week": 5,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 5, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 1, "day": "tuesday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 6,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 6, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 1, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 7,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 7, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 8,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 8, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 2, "day": "wednesday", "phase": "liga"}
		]
	})
	
	# OKTOBER (Wochen 9-12)
	season_weeks.append({
		"week": 9,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 9, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 2, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 10,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 10, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 11,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 11, "day": "saturday"},
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 2, "day": "tuesday"}
		]
	})
	
	season_weeks.append({
		"week": 12,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 12, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 3, "day": "tuesday", "phase": "liga"}
		]
	})
	
	# NOVEMBER (Wochen 13-16)
	season_weeks.append({
		"week": 13,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 13, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 3, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 14,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 14, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 15,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 15, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 4, "day": "wednesday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 16,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 16, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 4, "day": "thursday", "phase": "liga"}
		]
	})
	
	# DEZEMBER (Wochen 17-20): Hinrunden-Ende
	season_weeks.append({
		"week": 17,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 17, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 18,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 3, "day": "tuesday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 5, "day": "wednesday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 19,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 5, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 20,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 6, "day": "tuesday", "phase": "liga"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 6, "day": "thursday", "phase": "liga"}
		]
	})
	
	# WINTERPAUSE (Wochen 21-23)
	for week in range(21, 24):
		season_weeks.append({
			"week": week,
			"type": "winter_break",
			"description": "Winterpause"
		})
	
	# JANUAR (Wochen 24-27): Rückrunden-Start
	season_weeks.append({
		"week": 24,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 18, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 25,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 19, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 7, "day": "tuesday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 26,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 20, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 7, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 27,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 21, "day": "saturday"}
		]
	})
	
	# FEBRUAR (Wochen 28-31): Liga-Phase endet, Playoffs beginnen
	season_weeks.append({
		"week": 28,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 22, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 8, "day": "wednesday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 29,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 23, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 8, "day": "thursday", "phase": "liga"}
		]
	})
	
	season_weeks.append({
		"week": 30,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 9, "day": "tuesday", "phase": "playoff"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 9, "day": "thursday", "phase": "playoff"}
		]
	})
	
	season_weeks.append({
		"week": 31,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 24, "day": "saturday"},
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 4, "day": "tuesday"}
		]
	})
	
	# MÄRZ (Wochen 32-35): K.O.-Phase
	season_weeks.append({
		"week": 32,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 25, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 16, "day": "tuesday", "phase": "achtelfinale"}
		]
	})
	
	season_weeks.append({
		"week": 33,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 26, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 16, "day": "thursday", "phase": "achtelfinale"}
		]
	})
	
	season_weeks.append({
		"week": 34,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 27, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 35,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 28, "day": "saturday"},
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 5, "day": "wednesday"}
		]
	})
	
	# APRIL (Wochen 36-39): Viertel- und Halbfinale
	season_weeks.append({
		"week": 36,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 29, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 8, "day": "tuesday", "phase": "viertelfinale"}
		]
	})
	
	season_weeks.append({
		"week": 37,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 30, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 8, "day": "thursday", "phase": "viertelfinale"}
		]
	})
	
	season_weeks.append({
		"week": 38,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 31, "day": "saturday"},
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 4, "day": "wednesday", "phase": "halbfinale"}
		]
	})
	
	season_weeks.append({
		"week": 39,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 32, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 4, "day": "thursday", "phase": "halbfinale"}
		]
	})
	
	# MAI (Wochen 40-43): Saison-Finale
	season_weeks.append({
		"week": 40,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 33, "day": "saturday"}
		]
	})
	
	season_weeks.append({
		"week": 41,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "DFB_POKAL", "round": 6, "day": "saturday", "phase": "finale"}
		]
	})
	
	season_weeks.append({
		"week": 42,
		"type": "match_week",
		"matches": [
			{"type": "league", "matchday": 34, "day": "saturday"},
			{"type": "cup", "cup_type": "EUROPA_LEAGUE", "round": 1, "day": "wednesday", "phase": "finale"}
		]
	})
	
	season_weeks.append({
		"week": 43,
		"type": "match_week",
		"matches": [
			{"type": "cup", "cup_type": "CHAMPIONS_LEAGUE", "round": 1, "day": "saturday", "phase": "finale"}
		]
	})
	
	# SOMMERPAUSE (Wochen 44-52)
	for week in range(44, 53):
		season_weeks.append({
			"week": week,
			"type": "summer_break",
			"description": "Sommerpause + Transfers"
		})
	
	return season_weeks

func get_cup_draw_info(cup_type: String, round: int) -> Dictionary:
	"""Info für automatische Auslosung der jeweiligen Pokalrunde"""
	
	match cup_type:
		"DFB_POKAL":
			match round:
				1: return {"teams": 64, "format": "ko", "description": "1. Runde (64 Teams)"}
				2: return {"teams": 32, "format": "ko", "description": "2. Runde (32 Teams)"}
				3: return {"teams": 16, "format": "ko", "description": "Achtelfinale"}
				4: return {"teams": 8, "format": "ko", "description": "Viertelfinale"}
				5: return {"teams": 4, "format": "ko", "description": "Halbfinale"}
				6: return {"teams": 2, "format": "ko", "description": "Finale"}
		
		"CHAMPIONS_LEAGUE":
			if round <= 8:
				return {"teams": 36, "format": "liga", "description": "Liga-Phase Spieltag %d" % round}
			elif round == 9:
				return {"teams": 16, "format": "playoff", "description": "Playoffs (Plätze 9-24)"}
			elif round == 16:
				return {"teams": 16, "format": "ko", "description": "Achtelfinale"}
			elif round == 8:
				return {"teams": 8, "format": "ko", "description": "Viertelfinale"}
			elif round == 4:
				return {"teams": 4, "format": "ko", "description": "Halbfinale"}
			elif round == 1:
				return {"teams": 2, "format": "ko", "description": "Finale"}
		
		"EUROPA_LEAGUE":
			# Gleiches Format wie Champions League
			return get_cup_draw_info("CHAMPIONS_LEAGUE", round)
	
	return {}