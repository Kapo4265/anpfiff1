extends Control

const PerformanceRating = preload("res://scripts/core/PerformanceRating.gd")

@onready var team_info_label = $VBox/TeamInfoLabel
@onready var result_label = $VBox/ScrollContainer/ResultLabel
@onready var form_label = $VBox/FormLabel

var test_home_team: String = ""
var test_away_team: String = ""

func _ready():
	# KRITISCHER FIX: GameManager MUSS initialisiert werden für Teams/Players
	GameManager.initialize_game()
	await get_tree().process_frame
	setup_test_teams()
	
	# KERN 3: Warten auf Liga-System
	if not LeagueManager.league_initialized.is_connected(_on_league_system_ready):
		LeagueManager.league_initialized.connect(_on_league_system_ready)

func _on_league_system_ready():
	print("Test: Liga-System ist bereit!")
	# Spielpläne automatisch generieren
	ScheduleGenerator.generate_all_schedules()

func setup_test_teams():
	# KRITISCHER FIX: Verwende Liga-konforme Team-IDs (t01-t48) statt erste Teams aus der Datei
	# Die erste Teams (t-dfb-01, etc.) sind nicht Teil des Liga-Systems
	
	# Debug: Prüfe GameManager-Status
	print("Debug: GameManager.teams.size() = ", GameManager.teams.size())
	print("Debug: GameManager.players.size() = ", GameManager.players.size())
	
	if GameManager.teams.has("t01") and GameManager.teams.has("t02"):
		test_home_team = "t01"  # Liga-Team: Dynamo München
		test_away_team = "t02"  # Liga-Team: SV Leverkusen Pharma
		
		var home_name = GameManager.teams[test_home_team]["team_name"]
		var away_name = GameManager.teams[test_away_team]["team_name"]
		
		team_info_label.text = "Test Teams: %s vs %s" % [home_name, away_name]
		
		setup_test_lineups()
	else:
		team_info_label.text = "Fehler: Liga-Teams t01 oder t02 nicht gefunden"

func setup_test_lineups():
	var home_team_data = GameManager.get_team(test_home_team)
	var away_team_data = GameManager.get_team(test_away_team)
	
	var home_team = TeamData.new(home_team_data)
	var away_team = TeamData.new(away_team_data)
	
	# LineUp-Generierung mit ordentlicher 4-4-2 Formation (11 stärkste nach Position)
	var home_lineup = home_team.generate_lineup()
	var away_lineup = away_team.generate_lineup()
	
	GameManager.teams[test_home_team]["starting_eleven"] = home_lineup
	GameManager.teams[test_away_team]["starting_eleven"] = away_lineup
	
	print("Home lineup size: ", home_lineup.size())
	print("Away lineup size: ", away_lineup.size())

func _on_simulate_button_pressed():
	# KERN 5: Öffne echte Match-Screen UI
	if MatchdayEngine.is_matchday_simulation_running():
		print("Simulation läuft bereits!")
		return
	
	# Direkt zur Match-Screen wechseln
	get_tree().change_scene_to_file("res://scenes/match_screen.tscn")

func _on_instant_match_pressed():
	# Console-basierte Simulation für Debug
	if MatchdayEngine.is_matchday_simulation_running():
		print("Simulation läuft bereits!")
		return
		
	_start_simulation()

func _start_simulation():
	# POKAL & TAKTIK TEST vor Liga-Simulation
	test_new_systems()
	
	# KERN 3: Komplettes Liga-System (beinhaltet KERN 1+2)
	var available_teams = LeagueManager.get_user_available_teams()
	if available_teams.is_empty():
		result_label.text = "❌ Liga-System nicht bereit. Warten auf Initialisierung..."
		return
	
	# User-Team aus verfügbaren Teams wählen (erstes Team für Test)
	var user_team = available_teams[0]
	if not LeagueManager.set_user_team(user_team.id):
		result_label.text = "❌ Fehler beim Team-Setup"
		return
	
	var current_week = GameManager.get_week()
	var week_info = ScheduleGenerator.get_current_week_info()
	var week_type = week_info.get("type", "unknown")
	var week_desc = week_info.get("description", week_type)
	
	result_label.text = "KERN 4: WOCHE %d - %s\nTeam: %s\n(REALISTISCHER SAISONABLAUF)" % [current_week, week_desc, user_team.name]
	
	# Signale verbinden
	if not MatchdayEngine.user_match_completed.is_connected(_on_match_completed):
		MatchdayEngine.user_match_completed.connect(_on_match_completed)
		MatchdayEngine.all_leagues_completed.connect(_on_matchday_completed)
	
	# Kompletten Liga-Spieltag simulieren
	MatchdayEngine.simulate_current_matchday()

func _on_match_completed(result: Dictionary):
	# Liga-Match oder Pokal-Match unterscheiden
	if result.has("home_team_name"):
		# Pokal-Match (hat bereits Team-Namen)
		var home_name = result.home_team_name
		var away_name = result.away_team_name
		var cup_info = ""
		if result.get("extra_time", false):
			cup_info += " n.V."
		if result.get("penalty_shootout", false):
			cup_info += " n.E. (%s)" % result.get("penalty_score", "")
		
		result_label.text += "\n\n🏆 POKAL-MATCH ERGEBNIS:\n%s %d:%d %s%s" % [
			home_name, result.home_goals, result.away_goals, away_name, cup_info
		]
		
		# Pokal-Events werden in der normalen Event-Zusammenfassung angezeigt
	else:
		# Liga-Match (normale Behandlung)
		var home_name = GameManager.get_team(result.home_team)["team_name"]
		var away_name = GameManager.get_team(result.away_team)["team_name"]
		
		result_label.text = "USER-MATCH: %s %d:%d %s" % [
			home_name, result.home_goals, result.away_goals, away_name
		]
	result_label.text += "\nEvents: %d (KERN 2 integriert)" % result.events.size()
	
	# Event-Zusammenfassung hinzufügen
	if result.events.size() > 0:
		result_label.text += "\n\nEVENT-ZUSAMMENFASSUNG:"
		var event_summary = generate_event_summary(result.events)
		result_label.text += event_summary

func _on_matchday_completed():
	result_label.text += "\n\n✅ KOMPLETTER SPIELTAG ABGESCHLOSSEN!"
	result_label.text += "\n(User-Match + 8 Konferenz + andere Ligen)"
	
	# Liga-Tabelle anzeigen  
	var table = LeagueManager.get_league_table(1)
	if not table.is_empty():
		result_label.text += "\n\n=== 1. LIGA TABELLE (Top 5) ===\n"
		
		for i in range(min(5, table.size())):
			var entry = table[i]
			var marker = "👤" if entry.team_id == LeagueManager.user_team_id else "  "
			result_label.text += "%s %d. %s (%d P)\n" % [
				marker, entry.position, entry.team_name.substr(0, 15), entry.points
			]
		
		var current_matchday = LeagueManager.get_current_matchday(1)
		result_label.text += "\nNächster Spieltag: %d/34" % current_matchday
		
		# Karten-Statistiken anzeigen
		_show_card_statistics()
		
		# Spielerform und -bewertungen anzeigen
		_show_player_ratings()

func update_form_display():
	var home_team_data = GameManager.get_team(test_home_team)
	var away_team_data = GameManager.get_team(test_away_team)
	
	var home_moral = home_team_data["morale"] if home_team_data.has("morale") else 0
	var away_moral = away_team_data["morale"] if away_team_data.has("morale") else 0
	
	form_label.text = "Team-Moral: %s (%d) vs %s (%d)" % [
		home_team_data["team_name"], home_moral,
		away_team_data["team_name"], away_moral
	]

func generate_event_summary(events: Array) -> String:
	var summary = ""
	
	# Alle Events chronologisch sortieren
	var sorted_events = events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.minute < b.minute)
	
	for event in sorted_events:
		var player_data = GameManager.get_player(event.player_id)
		var player = PlayerData.new(player_data)
		var team_data = GameManager.get_team(event.team_id)
		var team_name = team_data["team_name"]
		
		match event.type:
			EventEngine.EventType.NORMAL_ATTACK:
				if event.success:
					summary += "\n%d' ⚽ TOR - %s (%s)" % [event.minute, player.get_full_name(), team_name]
				else:
					summary += "\n%d' 🎯 Torchance - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.FREISTOSS:
				if event.success:
					summary += "\n%d' ⚽ FREISTOSS-TOR - %s (%s)" % [event.minute, player.get_full_name(), team_name]
				else:
					summary += "\n%d' 🎯 Freistoß - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.ALLEINGANG:
				if event.success:
					summary += "\n%d' ⚽ ALLEINGANG-TOR - %s (%s)" % [event.minute, player.get_full_name(), team_name]
				else:
					summary += "\n%d' 🏃 Alleingang - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.ELFMETER:
				if event.success:
					summary += "\n%d' ⚽ ELFMETER-TOR - %s (%s)" % [event.minute, player.get_full_name(), team_name]
				else:
					summary += "\n%d' ❌ ELFMETER VERSCHOSSEN - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.VERLETZUNG:
				summary += "\n%d' 🤕 VERLETZUNG - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.TACKLING:
				if event.success:
					summary += "\n%d' 🟨 GELBE KARTE - %s (%s)" % [event.minute, player.get_full_name(), team_name]
				else:
					summary += "\n%d' ⚔️ Tackling - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.ABSEITSFALLE:
				summary += "\n%d' 🚩 Abseits - %s (%s)" % [event.minute, player.get_full_name(), team_name]
			
			EventEngine.EventType.GELBE_KARTE:
				if event.success:
					var reason = event.get("reason", "Unsportliches Verhalten")
					summary += "\n%d' 🟨 GELBE KARTE - %s (%s) - %s" % [event.minute, player.get_full_name(), team_name, reason]
			
			EventEngine.EventType.ROTE_KARTE:
				if event.success:
					var reason = event.get("reason", "Tätlichkeit")
					summary += "\n%d' 🟥 ROTE KARTE - %s (%s) - %s" % [event.minute, player.get_full_name(), team_name, reason]
	
	return summary if summary != "" else "\nKeine Events"

func test_new_systems():
	print("\n=== KERN 4: POKAL & TAKTIK SYSTEM TEST ===")
	
	# 1. EU-POKALE 2025/26 TEST (im CupManager)
	var cup_manager_test = CupManager.new()
	cup_manager_test.setup_new_season(GameManager.current_season)
	
	var cl_status = cup_manager_test.get_cup_status(CupManager.CupType.CHAMPIONS_LEAGUE)
	var el_status = cup_manager_test.get_cup_status(CupManager.CupType.EUROPA_LEAGUE)
	
	print("Champions League 2025/26: %s, Liga-Spieltag %d/%d" % [cl_status.name, cl_status.get("current_matchday", 1), cl_status.get("max_matchdays", 8)])
	print("  → %d Teams in LIGA-PHASE (Swiss System)" % cl_status.get("teams_count", 36))
	print("  → Liga-Phase: Plätze 1-8 direkt ins Achtelfinale")
	print("  → Play-offs: Plätze 9-24 um Achtelfinale")
	print("Europa League 2025/26: %s, Liga-Spieltag %d/%d" % [el_status.name, el_status.get("current_matchday", 1), el_status.get("max_matchdays", 8)])
	print("  → %d Teams in LIGA-PHASE (Swiss System)" % el_status.get("teams_count", 36))
	
	# 2. DFB-POKAL SYSTEM TEST mit last_season_placement
	var cup_manager = CupManager.new()
	cup_manager.setup_new_season(GameManager.current_season)
	
	var dfb_status = cup_manager.get_cup_status(CupManager.CupType.DFB_POKAL)
	
	print("DFB-Pokal: %d Teams, Runde %d/%d" % [dfb_status.teams_remaining, dfb_status.current_round, dfb_status.max_rounds])
	
	# 2. TAKTIK SYSTEM TEST
	var test_team_data = GameManager.get_team("t01")
	var team = TeamData.new(test_team_data)
	
	print("\nTeam: %s (Vorjahresplatz: %d)" % [team.team_name, test_team_data.get("last_season_placement", 0)])
	print("Standard: Einsatz=%s, Spielweise=%s" % [team.current_einsatz, team.current_spielweise])
	
	# Taktik ändern
	team.set_einsatz("Hart")
	team.set_spielweise("Angriff")
	team.toggle_abseitsfalle()
	
	var tactic_summary = team.get_tactic_summary()
	print("Geändert: Einsatz=%s (Stärke %s×), Spielweise=%s (Total %s×)" % [
		tactic_summary.einsatz, tactic_summary.einsatz_effects.strength_modifier,
		tactic_summary.spielweise, tactic_summary.spielweise_effects.total
	])
	print("Abseitsfalle: %s, Schwalben: %s" % [
		"AN" if tactic_summary.abseitsfalle else "AUS",
		"AN" if tactic_summary.schwalben else "AUS"
	])
	
	# 3. INTEGRIERTE POKAL-SIMULATION TEST
	# ScheduleGenerator ist bereits als Autoload/Singleton verfügbar
	ScheduleGenerator.generate_cup_schedules()
	
	print("\n--- REALISTISCHER SAISONKALENDER ---")
	print("Aktuelle Woche: %d" % GameManager.get_week())
	var week_info = ScheduleGenerator.get_current_week_info()
	print("Wochentyp: %s" % week_info.get("description", week_info.type))
	
	# Zeige nächste Wochen
	print("\nNächste 10 Wochen:")
	var season_calendar = ScheduleGenerator.schedules.get("season_calendar", [])
	var current_week = GameManager.get_week()
	
	for i in range(10):
		var check_week = current_week + i
		if check_week > 52:
			check_week = check_week - 52  # Neue Saison
		
		for week_data in season_calendar:
			if week_data.week == check_week:
				var desc = week_data.get("description", week_data.type)
				if week_data.type == "league":
					desc = "Liga-Spieltag %d" % week_data.league_matchday
				print("  Woche %d: %s" % [check_week, desc])
				break
	
	print("\n=== KERN 4: REALISTISCHE SAISON IMPLEMENTIERT ===")
	print("Test-Script kann jetzt durch die Wochen navigieren:")
	print("- Liga-Wochen: Normale Liga-Simulation")
	print("- Pokal-Wochen: Nur Pokalspiele")
	print("- Winterpause: Regeneration")
	print("- Sommerpause: Transfers + Reset")
	print("=== KERN 4 TEST ABGESCHLOSSEN ===\n")

func _show_player_ratings():
	result_label.text += "\n\n=== 1. LIGA SPIELER-BEWERTUNGEN ===\n"
	
	# Alle Events aus 1. Liga sammeln
	var simulation_results = MatchdayEngine.get_current_simulation_results()
	var all_events = []
	
	# User-Match Events
	var user_match_events = simulation_results.get("user_match", {}).get("events", [])
	all_events.append_array(user_match_events)
	
	# Konferenz-Match Events
	var conference_results = simulation_results.get("conference_results", {}).get(1, [])
	for conf_match in conference_results:
		var conf_events = conf_match.get("result", {}).get("events", [])
		all_events.append_array(conf_events)
	
	print("Debug: Gesammelt %d Events aus 1. Liga" % all_events.size())
	
	# ALLE Spieler aus 1. Liga bewerten (nicht nur die mit Events)
	var player_ratings = []
	var liga1_teams = LeagueManager.get_league_teams(1)
	
	for team in liga1_teams:
		var team_data = GameManager.get_team(team.id)
		var team_obj = TeamData.new(team_data)
		# Sicherstellen dass Lineup existiert
		if team_obj.starting_eleven.is_empty():
			team_obj.starting_eleven = team_obj.generate_lineup()
		
		# Alle 11 Startspieler bewerten
		for player_id in team_obj.starting_eleven:
			var player_data = GameManager.get_player(player_id)
			var player = PlayerData.new(player_data)
			player_ratings.append({
				"id": player_id,
				"name": player.get_full_name(),
				"position": player.primary_position,
				"team_id": team.id,
				"match_rating": PerformanceRating.calculate_player_match_rating(player_id, all_events)
			})
	
	# Nach Bewertung sortieren
	player_ratings.sort_custom(func(a, b): return a.match_rating > b.match_rating)
	
	result_label.text += "Top 10 Spieler des Spieltags:\n"
	for i in range(min(10, player_ratings.size())):
		var p = player_ratings[i]
		var rating_text = PerformanceRating.get_rating_text(p.match_rating)
		var team_name = GameManager.get_team(p.team_id).get("team_name", "Unbekannt")
		result_label.text += "%d. %s (%s, %s) - %.1f %s\n" % [
			i + 1, p.name, p.position, team_name.substr(0, 12), p.match_rating, rating_text
		]
	
	result_label.text += "\n📊 Gesamt: %d Spieler aus 1. Liga bewertet\n" % player_ratings.size()
	
	# Form-Änderungen für 1. Liga anzeigen
	_show_league_form_changes()

func _show_league_form_changes():
	result_label.text += "\n\n=== 1. LIGA FORM-ÄNDERUNGEN ===\n"
	
	# Alle Events sammeln für Event-basierte Boni
	var simulation_results = MatchdayEngine.get_current_simulation_results()
	var all_events = []
	
	var user_match_events = simulation_results.get("user_match", {}).get("events", [])
	all_events.append_array(user_match_events)
	
	var conference_results = simulation_results.get("conference_results", {}).get(1, [])
	for conf_match in conference_results:
		var conf_events = conf_match.get("result", {}).get("events", [])
		all_events.append_array(conf_events)
	
	# Match-Ergebnisse sammeln
	var match_results = {}
	var user_match = simulation_results.get("user_match", {})
	if not user_match.is_empty():
		match_results[user_match.get("home_team", "")] = {"winner": user_match.get("winner", ""), "draw": user_match.get("draw", false)}
		match_results[user_match.get("away_team", "")] = {"winner": user_match.get("winner", ""), "draw": user_match.get("draw", false)}
	
	for conf_match in conference_results:
		var result = conf_match.get("result", {})
		if not result.is_empty():
			match_results[result.get("home_team", "")] = {"winner": result.get("winner", ""), "draw": result.get("draw", false)}
			match_results[result.get("away_team", "")] = {"winner": result.get("winner", ""), "draw": result.get("draw", false)}
	
	# ALLE 198 Spieler (18 Teams * 11) bearbeiten
	var form_changes = []
	var liga1_teams = LeagueManager.get_league_teams(1)
	
	for team in liga1_teams:
		var team_data = GameManager.get_team(team.id)
		var team_obj = TeamData.new(team_data)
		if team_obj.starting_eleven.is_empty():
			team_obj.starting_eleven = team_obj.generate_lineup()
		
		# Form-Änderung für alle 11 Spieler berechnen
		for player_id in team_obj.starting_eleven:
			var player_data = GameManager.get_player(player_id)
			var player = PlayerData.new(player_data)
			var old_form = int(player.current_form)  # Ganzzahl
			
			# Base Form-Änderung basierend auf Team-Ergebnis
			var form_change = 0
			var match_info = match_results.get(team.id, {})
			var winner = match_info.get("winner", "")
			var is_draw = match_info.get("draw", false)
			
			if winner == team.id:
				form_change = randi_range(1, 2)  # Sieg: +1 oder +2
			elif is_draw:
				form_change = randi_range(-1, 1)  # Unentschieden: -1, 0, +1
			else:
				form_change = randi_range(-2, -1)  # Niederlage: -2 oder -1
			
			# Event-basierte Boni (ganzzahlig)
			for event in all_events:
				if event.get("player_id", "") == player_id and event.get("success", false):
					if event.get("type") in [EventEngine.EventType.NORMAL_ATTACK, EventEngine.EventType.FREISTOSS, EventEngine.EventType.ALLEINGANG, EventEngine.EventType.ELFMETER]:
						form_change += 1  # Tor-Bonus: +1
			
			var new_form = clamp(old_form + form_change, 0, 20)  # 0-20 ganzzahlig
			
			if form_change != 0:  # Nur Änderungen anzeigen
				form_changes.append({
					"name": player.get_full_name(),
					"position": player.primary_position,
					"team_id": team.id,
					"old_form": old_form,
					"new_form": new_form,
					"change": form_change
				})
	
	# Nach größter Änderung sortieren
	form_changes.sort_custom(func(a, b): return abs(a.change) > abs(b.change))
	
	result_label.text += "Top 10 Form-Änderungen:\n"
	for i in range(min(10, form_changes.size())):
		var fc = form_changes[i]
		var arrow = "⬆️" if fc.change > 0 else "⬇️" if fc.change < 0 else "➡️"
		var change_text = ("+" if fc.change > 0 else "") + str(fc.change)
		var team_name = GameManager.get_team(fc.team_id).get("team_name", "")
		
		result_label.text += "%s %s (%s, %s): %d → %d (%s)\n" % [
			arrow, fc.name, fc.position, team_name.substr(0, 8), fc.old_form, fc.new_form, change_text
		]
	
	result_label.text += "\n📊 Gesamt: %d Spieler mit Form-Änderungen (von 198)\n" % form_changes.size()

func _show_card_statistics():
	result_label.text += "\n\n=== KARTEN-STATISTIKEN ===\n"
	
	# User-Team Karten
	var user_team_id = LeagueManager.user_team_id
	if user_team_id != "":
		var user_matchday = CardStatistics.get_team_matchday_cards(user_team_id)
		var user_season = CardStatistics.get_team_season_cards(user_team_id)
		var user_team_name = GameManager.get_team(user_team_id).get("team_name", "Unbekannt")
		
		result_label.text += "👤 %s:\n" % user_team_name
		result_label.text += "  Spieltag: 🟨%d 🟥%d\n" % [user_matchday.yellow, user_matchday.red]
		result_label.text += "  Saison: 🟨%d 🟥%d\n" % [user_season.yellow, user_season.red]
	
	# Liga-Gesamtstatistiken
	var liga1_matchday = CardStatistics.get_league_matchday_cards("1")
	var liga1_season = CardStatistics.get_league_season_cards("1")
	
	result_label.text += "\n🏆 1. Liga Gesamt:\n"
	result_label.text += "  Spieltag: 🟨%d 🟥%d\n" % [liga1_matchday.yellow, liga1_matchday.red]
	result_label.text += "  Saison: 🟨%d 🟥%d\n" % [liga1_season.yellow, liga1_season.red]
	
	# Alle Ligen
	var all_leagues_matchday = CardStatistics.get_all_league_matchday_cards()
	var total_yellow_matchday = 0
	var total_red_matchday = 0
	
	for league_id in all_leagues_matchday.keys():
		var stats = all_leagues_matchday[league_id]
		total_yellow_matchday += stats.yellow
		total_red_matchday += stats.red
	
	result_label.text += "\n🌍 Alle Ligen heute: 🟨%d 🟥%d\n" % [total_yellow_matchday, total_red_matchday]

# BEWERTUNGSFUNKTIONEN WURDEN NACH PerformanceRating.gd AUSGELAGERT
