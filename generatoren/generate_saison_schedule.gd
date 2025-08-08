# res://scripts/generators/generate_season_schedule.gd
# FINALE VERSION: Erstellt den kompletten Saisonplan für Ligen, DFB-Pokal und Europapokal.
@tool
extends EditorScript

func _run():
	var generator = SeasonGenerator.new()
	generator.generate_and_save()

class SeasonGenerator:
	const MASTER_TEAM_DB_PATH = "res://data/master_teams.json"
	const OUTPUT_PATH = "res://data/season_schedule.json"

	# Definition der Qualifikationsplätze für den Europapokal
	const QUALIFICATION_SPOTS = {
		"champions_league": [1, 2, 3, 4], # Plätze 1-4 der Vorsaison
		"europa_league": [5, 6],        # Plätze 5-6 (inkl. Pokalsieger-Platz)
		"conference_league": [7]         # Platz 7
	}

	var teams_database: Dictionary = {}

	# Hauptfunktion, die den gesamten Prozess steuert
	func generate_and_save():
		print("--- STARTE GENERIERUNG: Kompletter Saison-Spielplan ---")
		self.teams_database = _load_json_from_path(MASTER_TEAM_DB_PATH)
		if not self.teams_database:
			printerr("FEHLER: master_teams.json konnte nicht geladen werden. Bitte Team-Generator zuerst ausführen.")
			return

		var full_schedule = {
			"season_year": "2025/2026",
			"leagues": {},
			"cups": {},
			"playoffs": {}
		}

		var teams_by_league = _sort_teams_into_leagues(self.teams_database)
		
		# 1. Liga-Spielpläne generieren
		for league_name in ["1. Bundesliga", "2. Bundesliga", "3. Liga"]:
			if teams_by_league.has(league_name):
				print("Generiere Spielplan für: %s" % league_name)
				full_schedule.leagues[league_name] = _generate_round_robin_schedule(teams_by_league[league_name])

		# 2. Relegations-Platzhalter generieren
		full_schedule.playoffs["relegation_1_2"] = {"name": "Relegation 1./2. Liga", "round_1": [{"home": "16_1_liga", "away": "3_2_liga"}]}
		full_schedule.playoffs["relegation_2_3"] = {"name": "Relegation 2./3. Liga", "round_1": [{"home": "16_2_liga", "away": "3_3_liga"}]}
		print("Relegations-Platzhalter erstellt.")
		
		# 3. DFB-Pokal generieren (erste Runde)
		full_schedule.cups["dfb_pokal"] = _generate_dfb_pokal_first_round(teams_by_league)
		print("DFB-Pokal (1. Runde) generiert.")

		# 4. Europapokale generieren
		var european_cups = _generate_all_european_cups(teams_by_league)
		for cup_name in european_cups:
			full_schedule.cups[cup_name] = european_cups[cup_name]
		print("Alle Europapokale generiert: %s" % ", ".join(european_cups.keys()))

		_save_database_to_file(full_schedule, OUTPUT_PATH)
		print("--- FERTIG: Kompletter Saison-Spielplan gespeichert in %s ---" % OUTPUT_PATH)

	# Sortiert alle Teams aus der DB in ihre jeweiligen Wettbewerbe
	func _sort_teams_into_leagues(p_teams_db: Dictionary) -> Dictionary:
		var leagues = {}
		for team_id in p_teams_db:
			var team_data = p_teams_db[team_id]
			var league_name = team_data.get("league_name")
			if not league_name: continue
			
			if not leagues.has(league_name):
				leagues[league_name] = []
			leagues[league_name].append(team_id)
		return leagues

	# Erstellt einen kompletten Hin- und Rückrunden-Spielplan
	func _generate_round_robin_schedule(p_team_ids: Array) -> Dictionary:
		var schedule = {}
		var teams = p_team_ids.duplicate()
		if teams.size() % 2 != 0:
			teams.append("spielfrei") # Dummy für ungerade Team-Anzahl

		var num_teams = teams.size()
		var num_matchdays = num_teams - 1
		
		# Korrigierter Round-Robin-Algorithmus
		for day in range(num_matchdays):
			var matchday_key = "Spieltag_%d" % (day + 1)
			schedule[matchday_key] = []
			
			# Erstelle Paarungen für diesen Spieltag
			for i in range(num_teams / 2):
				var home = teams[i]
				var away = teams[num_teams - 1 - i]
				if home != "spielfrei" and away != "spielfrei":
					# Alterniere Heimrecht basierend auf Spieltag und Paarung
					if (day + i) % 2 == 0:
						schedule[matchday_key].append({"home": home, "away": away})
					else:
						schedule[matchday_key].append({"home": away, "away": home})
			
			# Rotiere Teams für nächsten Spieltag (erstes Team bleibt fix)
			if teams.size() > 1:
				var last_team = teams.pop_back()
				teams.insert(1, last_team)
			
		# Rückrunde erstellen durch Tausch des Heimrechts
		for i in range(num_matchdays):
			var hinrunde_day = i + 1
			var rueckrunde_day = i + 1 + num_matchdays
			var hinrunde_key = "Spieltag_%d" % hinrunde_day
			var rueckrunde_key = "Spieltag_%d" % rueckrunde_day
			schedule[rueckrunde_key] = []
			for fixture in schedule[hinrunde_key]:
				schedule[rueckrunde_key].append({"home": fixture.away, "away": fixture.home})
				
		return schedule

	# Erstellt die 1. Runde des DFB-Pokals mit Lostöpfen
	func _generate_dfb_pokal_first_round(p_teams_by_league: Dictionary) -> Dictionary:
		var profi_pot = p_teams_by_league.get("1. Bundesliga", []) + p_teams_by_league.get("2. Bundesliga", [])
		var amateur_pot = p_teams_by_league.get("DFB-Pokal", []).duplicate()
		
		profi_pot.shuffle()
		amateur_pot.shuffle()
		
		var fixtures = []
		while not profi_pot.is_empty() and not amateur_pot.is_empty():
			var amateur_team = amateur_pot.pop_back()
			var profi_team = profi_pot.pop_back()
			fixtures.append({"home": amateur_team, "away": profi_team})
		
		var remaining_teams = profi_pot + amateur_pot
		remaining_teams.shuffle()
		while remaining_teams.size() >= 2:
			var team1 = remaining_teams.pop_back()
			var team2 = remaining_teams.pop_back()
			fixtures.append({"home": team1, "away": team2})
			
		return {"round_1": fixtures}

	# Hauptfunktion zur Erstellung aller drei europäischen Wettbewerbe
	func _generate_all_european_cups(p_teams_by_league: Dictionary) -> Dictionary:
		var cups = {}
		
		var bundesliga_teams = []
		if p_teams_by_league.has("1. Bundesliga"):
			for team_id in p_teams_by_league["1. Bundesliga"]:
				var team_data = self.teams_database[team_id]
				team_data["team_id"] = team_id  # Füge team_id hinzu
				bundesliga_teams.append(team_data)
		
		bundesliga_teams.sort_custom(func(a,b): return a.last_season_placement < b.last_season_placement)
		
		var cl_qualifiers = []; var el_qualifiers = []; var ecl_qualifiers = []
		for team_data in bundesliga_teams:
			var placement = int(team_data.get("last_season_placement", 99))
			var team_id = team_data.get("team_id")
			if placement in QUALIFICATION_SPOTS.champions_league: cl_qualifiers.append(team_id)
			elif placement in QUALIFICATION_SPOTS.europa_league: el_qualifiers.append(team_id)
			elif placement in QUALIFICATION_SPOTS.conference_league: ecl_qualifiers.append(team_id)
			
		print("Deutsche Qualifikanten - CL: %s, EL: %s, ECL: %s" % [cl_qualifiers, el_qualifiers, ecl_qualifiers])
			
		var international_pool = p_teams_by_league.get("European Clubs", []).duplicate()
		international_pool.shuffle()
		
		# Generiere Europapokale mit Terminierung
		cups["champions_league"] = _generate_cl_league_phase_with_schedule(cl_qualifiers, 36, international_pool)
		cups["europa_league"] = _generate_classic_group_stage_with_schedule("Europa League", el_qualifiers, 32, international_pool, 4) # Donnerstag
		cups["conference_league"] = _generate_classic_group_stage_with_schedule("Conference League", ecl_qualifiers, 32, international_pool, 4) # Donnerstag
		
		return cups

	# Funktion für das CL "Schweizer Modell" mit Terminierung
	func _generate_cl_league_phase_with_schedule(german_teams: Array, total_teams: int, international_pool: Array) -> Dictionary:
		print("  - Generiere CL-Liga-Phase mit Terminierung")
		var participants = german_teams.duplicate()
		var needed_internationals = total_teams - participants.size()
		for _i in range(needed_internationals):
			if international_pool.is_empty(): break
			participants.append(international_pool.pop_back())

		participants.sort_custom(func(a, b): return self.teams_database[a].tier < self.teams_database[b].tier)

		var pots = [[], [], [], []]
		for i in range(participants.size()):
			var pot_index = i / (total_teams / 4)
			if pot_index < 4: pots[pot_index].append(participants[i])
		
		for pot in pots: pot.shuffle()

		var schedule = {}
		var all_fixtures = []
		# Für jedes Team 8 Gegner auslosen (2 pro Topf)
		for i in range(participants.size()):
			var team = participants[i]
			var team_pot_index = i / (total_teams / 4)
			var opponents = []
			for pot_idx in range(4):
				var pot = pots[pot_idx].duplicate()
				# Entferne das eigene Team aus dem Topf, falls es drin ist
				if team_pot_index == pot_idx: pot.erase(team)
				
				for _j in range(2):
					if pot.is_empty(): break
					var opponent = pot.pick_random()
					if not opponent in opponents:
						opponents.append(opponent)
						pot.erase(opponent)
			
			# Weise Heim/Auswärts zu
			for j in range(opponents.size()):
				if j < 4: all_fixtures.append({"home": team, "away": opponents[j]})
				else: all_fixtures.append({"home": opponents[j], "away": team})
		
		all_fixtures.shuffle()
		
		# CL-Terminierung: Dienstag/Mittwoch, Kalenderwochen 37-44 (September-Dezember)
		var cl_calendar_weeks = [37, 38, 40, 41, 43, 44, 46, 47] # 8 Spieltage
		var cl_weekdays = [2, 3] # Dienstag, Mittwoch
		
		for i in range(8): # 8 Spieltage
			var matchday_fixtures = []
			for _j in range(total_teams / 2):
				if not all_fixtures.is_empty():
					matchday_fixtures.append(all_fixtures.pop_back())
			
			schedule[str(i+1)] = {
				"fixtures": matchday_fixtures,
				"calendar_week": cl_calendar_weeks[i],
				"weekday": cl_weekdays[i % 2], # Alternierend Di/Mi
				"kickoff_time": "21:00"
			}
		
		return {"format": "league_phase", "participants": participants, "schedule": schedule}

	# Klassisches Gruppen-System für EL und ECL mit Terminierung
	func _generate_classic_group_stage_with_schedule(cup_name: String, german_teams: Array, total_teams: int, international_pool: Array, weekday: int) -> Dictionary:
		print("  - Generiere Gruppen für: %s mit Terminierung" % cup_name)
		var participants = german_teams.duplicate()
		var needed_internationals = total_teams - participants.size()
		for _i in range(needed_internationals):
			if international_pool.is_empty(): break
			participants.append(international_pool.pop_back())
		
		participants.sort_custom(func(a, b): return self.teams_database[a].tier < self.teams_database[b].tier)

		var pots = [[], [], [], []]
		for i in range(participants.size()):
			var pot_index = i / (total_teams / 4)
			if pot_index < 4: pots[pot_index].append(participants[i])
		
		for pot in pots: pot.shuffle()

		var groups = {}
		var num_groups = total_teams / 4
		for i in range(num_groups):
			var group_name = "Group %s" % char(65 + i)
			groups[group_name] = []
			for pot_index in range(4):
				if not pots[pot_index].is_empty():
					groups[group_name].append(pots[pot_index].pop_back())
		
		# EL/ECL-Terminierung: Donnerstag, Kalenderwochen 37-46
		var el_calendar_weeks = [37, 39, 41, 43, 45, 47] # 6 Spieltage
		
		var schedule = {}
		for group_name in groups:
			var group_schedule = _generate_round_robin_schedule(groups[group_name])
			for i in range(1, 7): # 6 Spieltage
				var day_key = str(i)
				var matchday_fixtures = []
				if group_schedule.has(day_key):
					matchday_fixtures = group_schedule[day_key]
				
				if not schedule.has(day_key):
					schedule[day_key] = {
						"fixtures": [],
						"calendar_week": el_calendar_weeks[i-1],
						"weekday": weekday, # Donnerstag für EL/ECL
						"kickoff_time": "21:00"
					}
				
				schedule[day_key]["fixtures"].append_array(matchday_fixtures)

		return {"format": "group_stage", "groups": groups, "schedule": schedule}

	# --- Allgemeine Hilfsfunktionen ---
	func _load_json_from_path(path: String) -> Variant:
		if not FileAccess.file_exists(path): return null
		var file = FileAccess.open(path, FileAccess.READ); var content = file.get_as_text(); file.close()
		return JSON.parse_string(content)

	func _save_database_to_file(data: Variant, path: String):
		var dir_path = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path): DirAccess.make_dir_recursive_absolute(dir_path)
		var file = FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(data, "\t")); file.close()
		print("Saison-Spielplan gespeichert: %s" % path)
