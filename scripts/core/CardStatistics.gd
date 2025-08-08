extends Node

# Card statistics tracking system
# Tracks yellow/red cards for teams and leagues per matchday and season

# Statistics structure:
# {
#   "current_matchday": {
#     "team_id": {"yellow": int, "red": int},
#     "league_totals": {
#       "1": {"yellow": int, "red": int},  # Liga 1
#       "2": {"yellow": int, "red": int}   # Liga 2
#     }
#   },
#   "season_totals": {
#     "team_id": {"yellow": int, "red": int},
#     "league_totals": {
#       "1": {"yellow": int, "red": int},
#       "2": {"yellow": int, "red": int}
#     }
#   }
# }

var card_statistics: Dictionary = {}

func _ready():
	reset_current_matchday_stats()
	
	# Events verbinden
	if EventEngine and not EventEngine.event_generated.is_connected(_on_event_generated):
		EventEngine.event_generated.connect(_on_event_generated)

func _on_event_generated(event_data: Dictionary):
	"""Verarbeitet Events und zählt Karten"""
	if not event_data.get("success", false):
		return  # Nur erfolgreiche Events zählen
		
	var event_type = event_data.get("type", -1)
	var team_id = event_data.get("team_id", "")
	
	if event_type in [EventEngine.EventType.GELBE_KARTE, EventEngine.EventType.ROTE_KARTE] and team_id != "":
		_record_card(team_id, event_type)

func _record_card(team_id: String, card_type: int):
	"""Zeichnet eine Karte für ein Team auf"""
	var card_key = "yellow" if card_type == EventEngine.EventType.GELBE_KARTE else "red"
	var league_id = _get_team_league(team_id)
	
	# Current matchday statistics
	if not card_statistics.has("current_matchday"):
		card_statistics["current_matchday"] = {}
		
	if not card_statistics["current_matchday"].has(team_id):
		card_statistics["current_matchday"][team_id] = {"yellow": 0, "red": 0}
	
	if not card_statistics["current_matchday"].has("league_totals"):
		card_statistics["current_matchday"]["league_totals"] = {}
		
	if not card_statistics["current_matchday"]["league_totals"].has(league_id):
		card_statistics["current_matchday"]["league_totals"][league_id] = {"yellow": 0, "red": 0}
	
	# Season totals
	if not card_statistics.has("season_totals"):
		card_statistics["season_totals"] = {}
		
	if not card_statistics["season_totals"].has(team_id):
		card_statistics["season_totals"][team_id] = {"yellow": 0, "red": 0}
		
	if not card_statistics["season_totals"].has("league_totals"):
		card_statistics["season_totals"]["league_totals"] = {}
		
	if not card_statistics["season_totals"]["league_totals"].has(league_id):
		card_statistics["season_totals"]["league_totals"][league_id] = {"yellow": 0, "red": 0}
	
	# Increment counters
	card_statistics["current_matchday"][team_id][card_key] += 1
	card_statistics["current_matchday"]["league_totals"][league_id][card_key] += 1
	card_statistics["season_totals"][team_id][card_key] += 1
	card_statistics["season_totals"]["league_totals"][league_id][card_key] += 1
	
	print("CardStatistics: %s Karte für Team %s (Liga %s)" % [card_key.capitalize(), team_id, league_id])

func _get_team_league(team_id: String) -> String:
	"""Bestimmt Liga basierend auf Team-ID"""
	if team_id.begins_with("t") and team_id.length() == 3:
		var team_num = int(team_id.substr(1))
		if team_num >= 1 and team_num <= 18:
			return "1"  # 1. Liga
		elif team_num >= 19 and team_num <= 36:
			return "2"  # 2. Liga
		elif team_num >= 37 and team_num <= 48:
			return "3"  # 3. Liga
	elif team_id.begins_with("t-dfb-"):
		return "amateur"  # Amateur
	elif team_id.begins_with("t-eur-"):
		return "european"  # Europäisch
	
	return "unknown"

func reset_current_matchday_stats():
	"""Setzt Spieltag-Statistiken zurück (vor neuem Spieltag aufrufen)"""
	card_statistics["current_matchday"] = {}
	print("CardStatistics: Spieltag-Statistiken zurückgesetzt")

func get_team_matchday_cards(team_id: String) -> Dictionary:
	"""Gibt Karten des Teams für aktuellen Spieltag zurück"""
	return card_statistics.get("current_matchday", {}).get(team_id, {"yellow": 0, "red": 0})

func get_team_season_cards(team_id: String) -> Dictionary:
	"""Gibt Karten des Teams für gesamte Saison zurück"""
	return card_statistics.get("season_totals", {}).get(team_id, {"yellow": 0, "red": 0})

func get_league_matchday_cards(league_id: String) -> Dictionary:
	"""Gibt Liga-Karten für aktuellen Spieltag zurück"""
	return card_statistics.get("current_matchday", {}).get("league_totals", {}).get(league_id, {"yellow": 0, "red": 0})

func get_league_season_cards(league_id: String) -> Dictionary:
	"""Gibt Liga-Karten für gesamte Saison zurück"""
	return card_statistics.get("season_totals", {}).get("league_totals", {}).get(league_id, {"yellow": 0, "red": 0})

func get_all_league_matchday_cards() -> Dictionary:
	"""Gibt alle Liga-Karten für aktuellen Spieltag zurück"""
	return card_statistics.get("current_matchday", {}).get("league_totals", {})

func get_statistics_summary() -> String:
	"""Erstellt zusammenfassende Statistik als String"""
	var summary = "=== KARTEN-STATISTIKEN ===\n"
	
	# Aktueller Spieltag
	summary += "\nAKTUELLER SPIELTAG:\n"
	var matchday_leagues = get_all_league_matchday_cards()
	for league_id in matchday_leagues.keys():
		var stats = matchday_leagues[league_id]
		var league_name = _get_league_name(league_id)
		summary += "%s: %d Gelbe, %d Rote Karten\n" % [league_name, stats.yellow, stats.red]
	
	# Saison gesamt
	summary += "\nGESAMTE SAISON:\n"
	var season_leagues = card_statistics.get("season_totals", {}).get("league_totals", {})
	for league_id in season_leagues.keys():
		var stats = season_leagues[league_id]
		var league_name = _get_league_name(league_id)
		summary += "%s: %d Gelbe, %d Rote Karten\n" % [league_name, stats.yellow, stats.red]
	
	return summary

func _get_league_name(league_id: String) -> String:
	"""Konvertiert Liga-ID zu Anzeige-Name"""
	match league_id:
		"1": return "1. Liga"
		"2": return "2. Liga"  
		"3": return "3. Liga"
		"amateur": return "Amateur-Teams"
		"european": return "Europäische Teams"
		_: return "Liga " + league_id