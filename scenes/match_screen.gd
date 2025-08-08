extends Control

# UI References - Scoreboard Panel
@onready var minute_label = $ScoreboardPanel/MinuteLabel
@onready var home_team_label = $ScoreboardPanel/HomeTeamLabel
@onready var away_team_label = $ScoreboardPanel/AwayTeamLabel
@onready var score_label = $ScoreboardPanel/ScoreLabel
@onready var stadion_info_label = $ScoreboardPanel/StadionInfoLabel
@onready var attendance_label = $ScoreboardPanel/AttendanceLabel

# Tactical Controls
@onready var playstyle_state = $ScoreboardPanel/PlaystyleState
@onready var playstyle_minus = $ScoreboardPanel/PlaystyleMinus
@onready var playstyle_plus = $ScoreboardPanel/PlaystylePlus
@onready var effort_state = $ScoreboardPanel/EffortState
@onready var effort_minus = $ScoreboardPanel/EffortMinus
@onready var effort_plus = $ScoreboardPanel/EffortPlus

# Commentary Panel
@onready var commentary_box = $CommentaryPanel/CommentaryMargin/CommentaryBox

# Conference Panel References
@onready var conference_panel = $ConferencePanel
@onready var conference_layout = $ConferencePanel/ConferenceLayout

# Control Buttons
@onready var continue_button = $ContinueButton
@onready var pause_button = $PauseButton
@onready var lineup_button = $LineupButton

# Match State
var home_team_id: String = ""
var away_team_id: String = ""
var current_home_goals: int = 0
var current_away_goals: int = 0
var is_match_running: bool = false
var is_match_paused: bool = false
var current_match_type: String = ""  # "league" or "cup"

# Conference Data
var conference_matches: Array = []
var conference_results: Dictionary = {}

# Tactical Settings
var current_spielweise: int = 2  # 0=Abwehr, 1=Defensiv, 2=Normal, 3=Offensiv, 4=Angriff
var current_einsatz: int = 2     # 0=Lieb&Nett, 1=Fair, 2=Normal, 3=Hart, 4=Brutal

var spielweise_names = ["Abwehrriegel", "Defensiv", "Normal", "Offensiv", "Angriff"]
var einsatz_names = ["Lieb & Nett", "Fair", "Normal", "Hart", "Brutal"]

func _ready():
	connect_signals()
	setup_tactical_controls()
	
	# KERN 5: Auto-start if called directly
	if not MatchdayEngine.is_matchday_simulation_running():
		_auto_setup_from_matchday_engine()

func connect_signals():
	# KERN 5: MatchdayEngine Signale
	if not MatchdayEngine.user_match_started.is_connected(_on_user_match_started):
		MatchdayEngine.user_match_started.connect(_on_user_match_started)
	if not MatchdayEngine.user_match_completed.is_connected(_on_user_match_completed):
		MatchdayEngine.user_match_completed.connect(_on_user_match_completed)
	if not MatchdayEngine.conference_match_completed.is_connected(_on_conference_match_completed):
		MatchdayEngine.conference_match_completed.connect(_on_conference_match_completed)
	if not MatchdayEngine.all_leagues_completed.is_connected(_on_all_matches_completed):
		MatchdayEngine.all_leagues_completed.connect(_on_all_matches_completed)
	
	# EventEngine signals für Live-Updates
	if not EventEngine.event_generated.is_connected(_on_event_generated):
		EventEngine.event_generated.connect(_on_event_generated)
	if not EventEngine.match_minute_changed.is_connected(_on_minute_changed):
		EventEngine.match_minute_changed.connect(_on_minute_changed)
	if not EventEngine.live_ticker_message.is_connected(_on_live_ticker_message):
		EventEngine.live_ticker_message.connect(_on_live_ticker_message)
	
	# MatchEngine signals - NUR für User-Match
	if not MatchEngine.match_started.is_connected(_on_match_started):
		MatchEngine.match_started.connect(_on_match_started)
	# DEAKTIVIERT: match_ended wird über user_match_completed abgewickelt
	# if not MatchEngine.match_ended.is_connected(_on_match_ended):
	# 	MatchEngine.match_ended.connect(_on_match_ended)
	
	# Button signals
	continue_button.pressed.connect(_on_continue_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	lineup_button.pressed.connect(_on_lineup_pressed)

func setup_tactical_controls():
	# Spielweise Buttons
	playstyle_minus.pressed.connect(_on_spielweise_minus)
	playstyle_plus.pressed.connect(_on_spielweise_plus)
	
	# Einsatz Buttons  
	effort_minus.pressed.connect(_on_einsatz_minus)
	effort_plus.pressed.connect(_on_einsatz_plus)
	
	update_tactical_display()

func start_live_match(home_id: String, away_id: String, match_type: String = "league"):
	home_team_id = home_id
	away_team_id = away_id
	current_match_type = match_type
	current_home_goals = 0
	current_away_goals = 0
	
	setup_match_display()
	setup_conference_display()
	
	var week_summary = MatchdayEngine.get_week_summary()
	if match_type == "cup":
		commentary_box.text = "🏆 %s - Die Fans nehmen Ihre Plätze ein!" % week_summary.description
	else:
		var current_matchday = LeagueManager.get_current_matchday(LeagueManager.user_league)
		commentary_box.text = "⚽ %d. Spieltag Bundesliga - Die Fans nehmen Ihre Plätze ein und warten gespannt auf den ANPFIFF!" % current_matchday
	
	is_match_running = true
	is_match_paused = false
	
	# KERN 5: Integration mit MatchdayEngine statt direktem MatchEngine
	if not MatchdayEngine.is_matchday_simulation_running():
		MatchdayEngine.simulate_current_matchday()

func setup_match_display():
	var home_team_data = GameManager.get_team(home_team_id)
	var away_team_data = GameManager.get_team(away_team_id)
	
	if home_team_data.is_empty() or away_team_data.is_empty():
		return
	
	home_team_label.text = home_team_data.team_name
	away_team_label.text = away_team_data.team_name
	score_label.text = "0 : 0"
	minute_label.text = "0."
	
	# Stadium info
	var stadium_data = home_team_data.get("stadium", {})
	var stadium_name = stadium_data.get("stadium_name", "Stadion")
	var weather = "Sonnenschein"  # TODO: Weather system
	stadion_info_label.text = "%s\n%s" % [stadium_name, weather]
	
	# Attendance
	var capacity = stadium_data.get("stadium_capacity", 25000)
	var attendance = randi_range(int(capacity * 0.6), capacity)
	attendance_label.text = "Zuschauer: %d" % attendance

# KERN 5: MatchdayEngine Signal Handlers
func _on_user_match_started(home_id: String, away_id: String):
	print("MatchScreen: User-Match gestartet - %s vs %s" % [home_id, away_id])
	
	# Match-Typ automatisch aus week_info erkennen
	var week_info = ScheduleGenerator.get_current_week_info()
	var match_type = "league"  # Standard
	if week_info.get("type", "") == "cup":
		match_type = "cup"
	
	start_live_match(home_id, away_id, match_type)

func _on_user_match_completed(result: Dictionary):
	print("MatchScreen: User-Match abgeschlossen")
	# Match beenden (nur einmal für User-Match)
	is_match_running = false
	
	# NACHSPIELZEIT-ANZEIGE: Finale Minute aus Result übernehmen
	var final_minute = result.get("final_minute", 90)
	var injury_time = result.get("injury_time", 0)
	
	# Minute-Label korrekt setzen
	if injury_time > 0:
		minute_label.text = "90+%d'" % injury_time
		commentary_box.text += "\n\n⏱️ NACHSPIELZEIT: %d Minuten gespielt" % injury_time
		commentary_box.text += "\n90+%d' - ABPFIFF! Das Spiel ist beendet." % injury_time
	else:
		minute_label.text = "90'"
		commentary_box.text += "\n\n90' - ABPFIFF! Das Spiel ist beendet."
	
	# Extra-Time Behandlung für Pokale (falls vorhanden)
	if result.get("extra_time", false):
		minute_label.text = "120'"
		commentary_box.text += "\n\n120' - ABPFIFF nach Verlängerung!"
	
	# Match-Ergebnis final anzeigen (falls noch nicht durch Live-Events gesetzt)
	var final_home_goals = result.get("home_goals", 0)
	var final_away_goals = result.get("away_goals", 0)
	
	# Korrigiere falls Live-Events andere Werte haben
	if current_home_goals != final_home_goals or current_away_goals != final_away_goals:
		current_home_goals = final_home_goals
		current_away_goals = final_away_goals
		update_score_display()
	
	# Event-Zusammenfassung aus USER-MATCH hinzufügen (wie in test_kern1)
	if result.has("events") and result.events.size() > 0:
		commentary_box.text += "\n\nEVENT-ZUSAMMENFASSUNG:"
		var event_summary = generate_event_summary(result.events)
		commentary_box.text += event_summary
	
	# Spezielle Cup-Meldungen
	if result.get("extra_time", false):
		commentary_box.text += "\n\n🕐 NACH VERLÄNGERUNG!"
	if result.get("penalty_shootout", false):
		var penalty_score = result.get("penalty_score", "5:4")
		commentary_box.text += "\n\n🥅 ELFMETERSCHIEESSEN! (%s)" % penalty_score

func _on_conference_match_completed(league_id: int, home_team: String, away_team: String, result: Dictionary):
	print("MatchScreen: Konferenz-Match abgeschlossen - %s vs %s" % [home_team, away_team])
	update_conference_score(home_team, away_team, result.home_goals, result.away_goals)

func _on_all_matches_completed():
	print("MatchScreen: Alle Matches abgeschlossen")
	# ENTFERNT: Doppelte "Konferenz abgeschlossen" Meldung
	continue_button.text = "Spieltag beenden"
	continue_button.disabled = false

# Original MatchEngine Signal Handlers
func _on_match_started(home_id: String, away_id: String):
	commentary_box.text += "\n\n1' - ANPFIFF! Das Spiel beginnt!"

func _on_minute_changed(minute: int):
	if not is_match_paused:
		# NACHSPIELZEIT-ANZEIGE: 90+X statt normale Minuten
		if EventEngine.is_injury_time and minute > 90:
			var injury_min = minute - 90
			minute_label.text = "90+%d'" % injury_min
		else:
			minute_label.text = "%d'" % minute

func _on_event_generated(event_data: Dictionary):
	# Nur Events vom User-Match verarbeiten
	if not _is_user_match_event(event_data):
		return
	
	# Live-Updates für User-Match anzeigen
	var minute = event_data.get("minute", 0)
	var event_type = event_data.get("type", -1)
	var success = event_data.get("success", false)
	
	# Tore sofort aktualisieren (verschiedene Event-Typen können zu Toren führen)
	var is_goal = false
	if success:  # Nur erfolgreiche Events zählen als Tore
		if event_type == EventEngine.EventType.NORMAL_ATTACK:
			is_goal = true
		elif event_type == EventEngine.EventType.FREISTOSS:
			is_goal = true
		elif event_type == EventEngine.EventType.ALLEINGANG:
			is_goal = true
		elif event_type == EventEngine.EventType.ELFMETER:
			is_goal = true
		elif event_type == EventEngine.EventType.EIGENTOR:
			is_goal = true  # Eigentor zählt für gegnerisches Team
	
	if is_goal:
		var team_id = event_data.get("team_id", "")
		
		# Bei Eigentor: Tor für gegnerisches Team
		if event_type == EventEngine.EventType.EIGENTOR:
			if team_id == home_team_id:
				current_away_goals += 1  # Eigentor von Heim = Tor für Gast
			elif team_id == away_team_id:
				current_home_goals += 1  # Eigentor von Gast = Tor für Heim
		else:
			# Normale Tore
			if team_id == home_team_id:
				current_home_goals += 1
			elif team_id == away_team_id:
				current_away_goals += 1
		
		update_score_display()
		
		# Live-Commentary
		var player_name = _get_event_player_name(event_data)
		var team_name = _get_team_name(team_id)
		if event_type == EventEngine.EventType.EIGENTOR:
			commentary_box.text += "\n%d' - EIGENTOR! %s (%s)" % [minute, player_name, team_name]
		else:
			commentary_box.text += "\n%d' - TOR! %s (%s)" % [minute, player_name, team_name]

func _on_live_ticker_message(message: String, minute: int):
	# DEAKTIVIERT: Live-Ticker wird nur am Ende über generate_event_summary gezeigt
	# Verhindert Messages aus anderen Matches
	pass

func _is_user_match_event(event_data: Dictionary) -> bool:
	"""Prüft ob Event zum User-Match gehört"""
	# Prüfen ob Event von einem der User-Match Teams kommt
	var event_team = event_data.get("team_id", "")
	return event_team == home_team_id or event_team == away_team_id

func _get_event_player_name(event_data: Dictionary) -> String:
	"""Liefert Spielername für Event"""
	var player_id = event_data.get("player_id", "")
	if player_id == "":
		return "Spieler"
	
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return "Unbekannt"
	
	return player_data.get("first_name", "") + " " + player_data.get("last_name", "")

func _get_team_name(team_id: String) -> String:
	"""Liefert Teamname für ID"""
	var team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		return "Team"
	
	return team_data.get("team_name", "Team")

func _on_match_ended():
	# NICHT MEHR VERWENDET - wird durch user_match_completed ersetzt
	pass

func update_score_display():
	score_label.text = "%d : %d" % [current_home_goals, current_away_goals]

func _auto_setup_from_matchday_engine():
	"""KERN 5: Vollständige Initialisierung für eigenständige match_screen"""
	commentary_box.text = "Initialisiere Spiel-Systeme...\n"
	
	# KRITISCHER FIX: GameManager MUSS initialisiert werden für Teams/Players
	if GameManager.teams.is_empty():
		commentary_box.text += "GameManager wird geladen...\n"
		GameManager.initialize_game()
		await get_tree().process_frame
		commentary_box.text += "GameManager bereit (%d Teams, %d Spieler)\n" % [GameManager.teams.size(), GameManager.players.size()]
	
	# KERN 3: Warten auf Liga-System
	if LeagueManager.get_league_teams(1).is_empty():
		commentary_box.text += "Liga-System wird initialisiert...\n"
		if not LeagueManager.league_initialized.is_connected(_wait_for_league_then_start):
			LeagueManager.league_initialized.connect(_wait_for_league_then_start)
		return
	
	_complete_setup_and_start()

func _complete_setup_and_start():
	"""Vervollständigt Setup nach Liga-Initialisierung"""
	# User-Team prüfen und setzen
	if LeagueManager.user_team_id == "":
		var liga1_teams = LeagueManager.get_league_teams(1)
		if not liga1_teams.is_empty():
			LeagueManager.set_user_team(liga1_teams[0].id)
			commentary_box.text += "User-Team: %s\n" % liga1_teams[0].name
		else:
			commentary_box.text += "❌ Fehler: Keine Liga-Teams verfügbar\n"
			return
	
	# Spielpläne generieren
	commentary_box.text += "Generiere Spielpläne...\n"
	ScheduleGenerator.generate_all_schedules()
	commentary_box.text += "Spielpläne erstellt\n"
	
	# Lineup-Setup für alle Teams (wie in test_kern1)
	_setup_all_team_lineups()
	
	# Match starten
	_start_matchday_directly()

func _wait_for_league_then_start():
	"""Callback nach Liga-Initialisierung"""
	commentary_box.text += "Liga-System bereit!\n"
	_complete_setup_and_start()

func _setup_all_team_lineups():
	"""Setup Lineups für alle Teams (aus test_kern1 übernommen)"""
	commentary_box.text += "Generiere Team-Aufstellungen...\n"
	
	# Alle Liga-Teams bekommen Lineups
	var lineups_generated = 0
	for league_id in [1, 2, 3]:
		var teams = LeagueManager.get_league_teams(league_id)
		for team in teams:
			var team_data = GameManager.get_team(team.id)
			var team_obj = TeamData.new(team_data)
			
			# Lineup-Generierung mit ordentlicher 4-4-2 Formation
			var lineup = team_obj.generate_lineup()
			GameManager.teams[team.id]["starting_eleven"] = lineup
			lineups_generated += 1
	
	commentary_box.text += "Aufstellungen generiert: %d Teams\n" % lineups_generated

func _start_matchday_directly():
	"""Startet Matchday-Simulation direkt ohne weitere Checks"""
	var week_summary = MatchdayEngine.get_week_summary()
	commentary_box.text += "\n📅 WOCHE %d: %s\n\n" % [week_summary.week, week_summary.description]
	
	# User-Team Info anzeigen
	var user_team_data = GameManager.get_team(LeagueManager.user_team_id)
	if not user_team_data.is_empty():
		commentary_box.text += "Dein Team: %s\n" % user_team_data.team_name
	
	# Gegner-Info anzeigen
	var opponent_info = MatchdayEngine.get_user_match_opponent()
	if opponent_info.has("opponent") and opponent_info.opponent != "Keine Spiele":
		var opponent_data = GameManager.get_team(opponent_info.opponent)
		if not opponent_data.is_empty():
			var match_type = "Liga-Spiel" if opponent_info.get("type", "league") == "league" else "Pokal-Spiel"
			commentary_box.text += "Gegner: %s (%s)\n\n" % [opponent_data.team_name, match_type]
	
	# MatchdayEngine startet automatisch User-Match
	commentary_box.text += "Starte Spieltag-Simulation...\n"
	MatchdayEngine.simulate_current_matchday()

func setup_conference_display():
	"""KERN 5: Setup Konferenz-Anzeige mit echten Daten oder Pokal-Icon"""
	var week_matches = MatchdayEngine.get_current_week_matches()
	conference_matches.clear()
	
	# ABSTURZ-FIX: Prüfe ob week_matches gültig ist
	if week_matches.is_empty():
		print("Warning: Keine week_matches erhalten")
		return
	
	# Bestimme Match-Typ aus current_match_type oder week_matches
	var match_type = current_match_type
	if match_type == "" and week_matches.has("type"):
		match_type = week_matches.type
	elif match_type == "":
		# Fallback: Liga als Standard
		match_type = "league"
	
	match match_type:
		"league":
			conference_panel.visible = true
			_hide_cup_display()  # Pokal-Icon verstecken
			
			var league_matches = week_matches.get("matches", [])
			if not league_matches.is_empty():
				var user_team_id = LeagueManager.user_team_id
				
				# Alle Liga-Matches außer User-Match für Konferenz
				for match in league_matches:
					if match.get("home_team", "") != user_team_id and match.get("away_team", "") != user_team_id:
						conference_matches.append(match)
				
				# Konferenz-UI mit echten Team-Namen füllen
				update_conference_ui()
			
		"cup":
			# Nur bei echten Pokal-Spielen: Konferenz durch Pokal-Icon ersetzen
			conference_panel.visible = false
			_show_cup_display()
			
		_: # Fallback für unbekannte Typen
			conference_panel.visible = true
			_hide_cup_display()
	
func _show_cup_display():
	"""Zeigt Pokal-Icon anstelle der Konferenz bei Pokalspielen"""
	# Pokal-Icon erstellen falls noch nicht vorhanden
	if not has_node("CupIcon"):
		var cup_icon = TextureRect.new()
		cup_icon.name = "CupIcon"
		cup_icon.position = Vector2(1048, 600)
		cup_icon.size = Vector2(400, 400)
		
		# SVG laden
		var svg_path = "res://assets/icons/cup.svg"
		if ResourceLoader.exists(svg_path):
			cup_icon.texture = load(svg_path)
			cup_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			cup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			# Fallback: Label mit Pokal-Text
			var label = Label.new()
			label.text = "🏆\nPOKAL\nSPIEL"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 48)
			cup_icon.add_child(label)
		
		add_child(cup_icon)
	else:
		get_node("CupIcon").visible = true

func _hide_cup_display():
	"""Versteckt Pokal-Icon bei Liga-Spielen"""
	if has_node("CupIcon"):
		get_node("CupIcon").visible = false

func update_conference_ui():
	"""Aktualisiert Konferenz-Panel mit echten Team-Namen"""
	var conference_rows = conference_layout.get_children()
	
	for i in range(min(conference_matches.size(), conference_rows.size())):
		var match = conference_matches[i]
		var row = conference_rows[i]
		
		var home_label = row.get_node("HomeTeamLabel")
		var score_label_node = row.get_node("ScoreLabel")
		var away_label = row.get_node("AwayTeamLabel")
		
		var home_team_data = GameManager.get_team(match.get("home_team", ""))
		var away_team_data = GameManager.get_team(match.get("away_team", ""))
		
		home_label.text = home_team_data.get("team_name", "Team A")
		away_label.text = away_team_data.get("team_name", "Team B")
		score_label_node.text = "0:0"

func update_conference_score(home_team_id: String, away_team_id: String, home_goals: int, away_goals: int):
	"""Aktualisiert Konferenz-Ergebnis"""
	var conference_rows = conference_layout.get_children()
	
	for i in range(min(conference_matches.size(), conference_rows.size())):
		var match = conference_matches[i]
		if match.get("home_team") == home_team_id and match.get("away_team") == away_team_id:
			var row = conference_rows[i]
			var score_label_node = row.get_node("ScoreLabel")
			score_label_node.text = "%d:%d" % [home_goals, away_goals]
			break

func _simulate_next_matchday():
	"""TEMPORÄR: Simuliert nächsten Spieltag exakt wie in test_kern1"""
	commentary_box.text = "Nächste Woche wird vorbereitet...\n"
	
	# WICHTIG: NICHT advance_week() hier aufrufen!
	# MatchdayEngine.simulate_current_matchday() macht das bereits am Ende
	
	# Match-Status zurücksetzen
	current_home_goals = 0
	current_away_goals = 0
	current_match_type = ""  # Zurücksetzen für neue Erkennung
	update_score_display()
	minute_label.text = "0."
	
	# Aktuelle Woche OHNE advance (wird von MatchdayEngine gemacht)
	var current_week = GameManager.get_week()
	var week_info = ScheduleGenerator.get_current_week_info()
	var week_type = week_info.get("type", "unknown")
	var week_desc = week_info.get("description", week_type)
	
	commentary_box.text += "KERN 4: WOCHE %d - %s\n" % [current_week, week_desc]
	
	var user_team_data = GameManager.get_team(LeagueManager.user_team_id)
	if not user_team_data.is_empty():
		commentary_box.text += "Team: %s\n(REALISTISCHER SAISONABLAUF)\n\n" % user_team_data.team_name
	
	# Signale sind bereits verbunden, direkt simulieren
	is_match_running = true
	commentary_box.text += "Starte Spieltag-Simulation...\n"
	MatchdayEngine.simulate_current_matchday()

func _go_to_results_screen():
	"""KERN 5: Navigation zu Ergebnis-Szene"""
	get_tree().change_scene_to_file("res://scenes/results_and_table.tscn")

# Control Button Handlers
func _on_continue_pressed():
	if not is_match_running:
		# TEMPORÄR: Nächsten Spieltag simulieren (wie in test_kern1)
		_simulate_next_matchday()
		return
		
	if is_match_paused:
		is_match_paused = false
		continue_button.text = "Laufend..."
		continue_button.disabled = true
		pause_button.disabled = false
	else:
		# Match ist bereits gestartet
		pass

func _on_pause_pressed():
	if is_match_running and not is_match_paused:
		is_match_paused = true
		continue_button.text = "Weiter"
		pause_button.disabled = true

func _on_lineup_pressed():
	# KERN 5: Öffne Auswechslungs-Szene
	get_tree().change_scene_to_file("res://scenes/substitution_screen.tscn")

# Tactical Control Handlers
func _on_spielweise_minus():
	if current_spielweise > 0:
		current_spielweise -= 1
		update_tactical_display()
		apply_tactical_changes()

func _on_spielweise_plus():
	if current_spielweise < 4:
		current_spielweise += 1
		update_tactical_display()
		apply_tactical_changes()

func _on_einsatz_minus():
	if current_einsatz > 0:
		current_einsatz -= 1
		update_tactical_display()
		apply_tactical_changes()

func _on_einsatz_plus():
	if current_einsatz < 4:
		current_einsatz += 1
		update_tactical_display()
		apply_tactical_changes()

func generate_event_summary(events: Array) -> String:
	var summary = ""
	
	# Alle Events chronologisch sortieren
	var sorted_events = events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.minute < b.minute)
	
	for event in sorted_events:
		# Handle leere player_id für Lightning-Matches (Verlängerung/Elfmeter)
		var player_name = "Unbekannt"
		if event.has("player_id") and event.player_id != "":
			var player_data = GameManager.get_player(event.player_id)
			var player = PlayerData.new(player_data)
			player_name = player.get_full_name()
		
		var team_data = GameManager.get_team(event.team_id)
		var team_name = team_data["team_name"]
		
		match event.type:
			EventEngine.EventType.NORMAL_ATTACK:
				if event.success:
					summary += "\n%d' ⚽ TOR - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' 🎯 Torchance - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.FREISTOSS:
				if event.success:
					summary += "\n%d' ⚽ FREISTOSS-TOR - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' 🎯 Freistoß - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.ALLEINGANG:
				if event.success:
					summary += "\n%d' ⚽ ALLEINGANG-TOR - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' 🏃 Alleingang - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.ELFMETER:
				if event.success:
					summary += "\n%d' ⚽ ELFMETER-TOR - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' ❌ ELFMETER VERSCHOSSEN - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.VERLETZUNG:
				summary += "\n%d' 🤕 VERLETZUNG - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.TACKLING:
				if event.success:
					summary += "\n%d' 🟨 GELBE KARTE - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' ⚔️ Tackling - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.ABSEITSFALLE:
				summary += "\n%d' 🚩 Abseits - %s (%s)" % [event.minute, player_name, team_name]
			
			EventEngine.EventType.GELBE_KARTE:
				if event.success:
					var reason = event.get("reason", "Unsportliches Verhalten")
					summary += "\n%d' 🟨 GELBE KARTE - %s (%s) - %s" % [event.minute, player_name, team_name, reason]
			
			EventEngine.EventType.ROTE_KARTE:
				if event.success:
					var reason = event.get("reason", "Tätlichkeit")
					summary += "\n%d' 🟥 ROTE KARTE - %s (%s) - %s" % [event.minute, player_name, team_name, reason]
			
			# Verlängerungs- und Elfmeter-Events (Lightning-Matches)
			"goal":
				if event.get("extra_time", false):
					summary += "\n%d' ⚽ TOR (Verlängerung) - %s (%s)" % [event.minute, player_name, team_name]
				else:
					summary += "\n%d' ⚽ TOR - %s (%s)" % [event.minute, player_name, team_name]
			
			"penalty_scored":
				summary += "\n120' ⚽ ELFMETER VERWANDELT - %s (%s)" % [player_name, team_name]
			
			"penalty_missed":
				summary += "\n120' ❌ ELFMETER VERSCHOSSEN - %s (%s)" % [player_name, team_name]
	
	return summary if summary != "" else "\nKeine Events"

func update_tactical_display():
	playstyle_state.text = spielweise_names[current_spielweise]
	effort_state.text = einsatz_names[current_einsatz]

func apply_tactical_changes():
	# KERN 5: Taktik-Änderungen an Team-Data weiterleiten
	var user_team_id = LeagueManager.user_team_id
	var user_team_data = GameManager.get_team(user_team_id)
	
	if not user_team_data.is_empty():
		var team = TeamData.new(user_team_data)
		
		# Spielweise/Einsatz setzen (authentische deutsche Begriffe aus CLAUDE.md)
		team.set_spielweise(spielweise_names[current_spielweise])
		team.set_einsatz(einsatz_names[current_einsatz])
		
		print("Taktik geändert: %s, %s" % [spielweise_names[current_spielweise], einsatz_names[current_einsatz]])
		
		# Taktik-Update im Commentary anzeigen
		var tactic_message = "⚙️ TAKTIK-WECHSEL: %s + %s" % [
			spielweise_names[current_spielweise], 
			einsatz_names[current_einsatz]
		]
		commentary_box.text += "\n" + tactic_message
