extends SceneTree

# Script zum Hinzufügen von Standard-Formationen zu allen Teams in master_teams.json

func _init():
	add_formations_to_teams()
	quit()

func add_formations_to_teams():
	print("=== FORMATION UPDATE SCRIPT ===")
	
	var file_path = "res://data/master_teams.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("FEHLER: Kann master_teams.json nicht öffnen!")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("FEHLER: JSON Parse-Fehler!")
		return
	
	var teams_data = json.get_data()
	var teams_updated = 0
	
	print("Gefunden: %d Teams" % teams_data.size())
	
	# Standard-Formationen basierend auf Team-Typ
	for team_id in teams_data.keys():
		var team_data = teams_data[team_id]
		var formation = get_formation_for_team(team_id, team_data)
		
		# Formation hinzufügen falls nicht vorhanden
		if not team_data.has("default_formation"):
			team_data["default_formation"] = formation
			teams_updated += 1
			
			if teams_updated <= 10:  # Erste 10 Teams anzeigen
				print("Team %s: %s → Formation %s" % [team_id, team_data.get("team_name", "Unknown"), formation])
	
	print("Teams mit neuer Formation: %d" % teams_updated)
	
	# JSON zurück schreiben
	var json_string_new = JSON.stringify(teams_data, "\t")
	var file_write = FileAccess.open(file_path, FileAccess.WRITE)
	if file_write:
		file_write.store_string(json_string_new)
		file_write.close()
		print("✅ master_teams.json erfolgreich aktualisiert!")
	else:
		print("❌ FEHLER: Konnte Datei nicht schreiben!")

func get_formation_for_team(team_id: String, team_data: Dictionary) -> String:
	"""Bestimmt Standard-Formation basierend auf Team-Eigenschaften"""
	
	var city = team_data.get("city", "")
	var team_name = team_data.get("team_name", "")
	var tier = team_data.get("tier", 1)
	
	# Liga 1 Teams (Profi-Teams) - Verschiedene Formationen
	if team_id.begins_with("t0") and team_id.length() == 3:  # t01-t48
		return get_bundesliga_formation(city, team_name)
	
	# EU-Teams - Internationale Standard-Formationen  
	elif team_id.begins_with("t-eur-"):
		return get_european_formation()
	
	# DFB-Amateur-Teams - Defensive Formationen
	elif team_id.begins_with("t-dfb-"):
		return "4-5-1"  # Defensiv für Amateur-Teams
	
	# Standard für alle anderen
	return "4-4-2"

func get_bundesliga_formation(city: String, team_name: String) -> String:
	"""Authentische Formationen für deutsche Profi-Teams basierend auf Stadt"""
	
	# Großstädte tendieren zu offensiveren Formationen
	var major_cities = ["München", "Berlin", "Hamburg", "Köln", "Frankfurt", "Stuttgart", "Düsseldorf", "Dortmund", "Essen", "Leipzig", "Bremen", "Dresden", "Hannover", "Nürnberg"]
	
	if city in major_cities:
		# Offensive Formationen für Großstadt-Teams
		var formations = ["4-3-3", "3-4-3", "4-2-3-1"]
		return formations[city.hash() % formations.size()]
	else:
		# Ausgewogenere Formationen für kleinere Städte
		var formations = ["4-4-2", "4-5-1", "5-4-1", "3-5-2"]
		return formations[city.hash() % formations.size()]

func get_european_formation() -> String:
	"""Zufällige internationale Formationen für EU-Teams"""
	var formations = ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1", "5-3-2", "3-4-3"]
	return formations[randi() % formations.size()]