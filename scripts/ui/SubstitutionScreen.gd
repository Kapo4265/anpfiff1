extends Control

# SubstitutionScreen für authentische ANSTOSS 1 Auswechslung + Einsatz/Spielweise
# Verwendet GameManager, TeamData und SuspensionSystem aus CLAUDE.md

@onready var team_name_label = $"_Label_16"
@onready var status_label = $"_Label_47" 
@onready var startelf_container = $"StartelfPanel/StartelfScrollContainer/StartelfScrollContainer#StartelfListVBox"
@onready var bank_container = $"BankPanel/BankScrollContainer/BankScrollContainer#BankListVBox"

# Einsatz-System (authentisch aus CLAUDE.md)
@onready var effort_minus = $"EffortPanel/EffortMinus"
@onready var effort_state = $"EffortPanel/EffortState"  
@onready var effort_plus = $"EffortPanel/EffortPlus"

# Spielweise-System
@onready var playstyle_minus = $"PlaystylePanel/PlaystyleMinus"
@onready var playstyle_state = $"PlaystylePanel/PlaystyleState"
@onready var playstyle_plus = $"PlaystylePanel/PlaystylePlus"

# Button-Referenzen
@onready var cancel_button = $"_Button_49"
@onready var execute_button = $"_Button_48"
@onready var continue_button = $"_Button_50"

# Team-Daten (aus CLAUDE.md authentische Variablen)
var current_team_id: String = ""
var team_data: Dictionary = {}
var selected_out_player: String = ""
var selected_in_player: String = ""

# Authentische ANSTOSS 1 Einsatz-Stufen (aus CLAUDE.md)
var einsatz_levels: Array[String] = ["Lieb & Nett", "Fair", "Normal", "Hart", "Brutal"]
var current_einsatz_index: int = 2  # Start: "Normal"

# Spielweise-Optionen  
var spielweise_options: Array[String] = ["Abwehrriegel", "Normal", "Offensiv", "Kontrolliert Offensiv", "Konter"]
var current_spielweise_index: int = 1  # Start: "Normal"

func _ready():
	# Button-Verbindungen
	cancel_button.pressed.connect(_on_cancel_pressed)
	execute_button.pressed.connect(_on_execute_substitution)
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Einsatz-Controls
	effort_minus.pressed.connect(_on_effort_minus)
	effort_plus.pressed.connect(_on_effort_plus)
	
	# Spielweise-Controls  
	playstyle_minus.pressed.connect(_on_playstyle_minus)
	playstyle_plus.pressed.connect(_on_playstyle_plus)
	
	# User-Team laden (aus CLAUDE.md: current_team_id verwenden)
	if LeagueManager and LeagueManager.user_team_id != "":
		load_team_data(LeagueManager.user_team_id)
	else:
		status_label.text = "Fehler: Kein Team ausgewählt"
		status_label.modulate = Color.RED

func load_team_data(team_id: String):
	current_team_id = team_id
	
	# GameManager.get_team() aus CLAUDE.md verwenden
	team_data = GameManager.get_team(team_id)
	if team_data.is_empty():
		status_label.text = "Fehler: Team nicht gefunden"
		status_label.modulate = Color.RED
		return
	
	# Team-Namen anzeigen
	team_name_label.text = team_data.get("team_name", "Unbekannt")
	
	# Aktuelle Team-Einstellungen laden
	var current_einsatz = team_data.get("default_einsatz", "Normal")
	var current_spielweise = team_data.get("default_tactic", "Normal")
	
	# Einsatz-Index finden
	current_einsatz_index = einsatz_levels.find(current_einsatz)
	if current_einsatz_index == -1:
		print("FEHLER: Unbekannter Einsatz '%s'!" % current_einsatz)
		assert(false, "CRITICAL: Team muss gültigen Einsatz haben")
	
	# Spielweise-Index finden
	current_spielweise_index = spielweise_options.find(current_spielweise)
	if current_spielweise_index == -1:
		print("FEHLER: Unbekannte Spielweise '%s'!" % current_spielweise)
		assert(false, "CRITICAL: Team muss gültige Spielweise haben")
	
	# UI aktualisieren
	_update_effort_display()
	_update_playstyle_display()
	_refresh_player_lists()

func _refresh_player_lists():
	# Listen leeren
	for child in startelf_container.get_children():
		child.queue_free()
	for child in bank_container.get_children():
		child.queue_free()
		
	await get_tree().process_frame  # Warten bis Nodes gelöscht sind
	
	# TeamData.new() aus CLAUDE.md verwenden
	var team = TeamData.new(team_data)
	
	# Aktuelle Startelf (mit automatischen Auswechslungen bei Ausfällen)
	var starting_eleven = team_data.get("starting_eleven", [])
	if starting_eleven.is_empty():
		starting_eleven = team.generate_lineup_with_substitutions()
		# Aktualisierte Startelf speichern
		GameManager.teams[current_team_id]["starting_eleven"] = starting_eleven
	
	# Startelf anzeigen
	status_label.text = "Startelf wird geladen..."
	status_label.modulate = Color.WHITE
	
	for player_id in starting_eleven:
		_add_player_to_startelf(player_id)
	
	# Bank-Spieler (alle anderen verfügbaren Spieler)
	var all_available = team.get_available_players_by_position("ALL")
	var bench_players = []
	
	for player_id in all_available:
		if not player_id in starting_eleven:
			bench_players.append(player_id)
	
	for player_id in bench_players:
		_add_player_to_bench(player_id)
	
	status_label.text = "Bitte Spieler auswählen..."
	status_label.modulate = Color.YELLOW

func _add_player_to_startelf(player_id: String):
	# PlayerData.new() aus CLAUDE.md verwenden
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return
		
	var player = PlayerData.new(player_data)
	var button = Button.new()
	
	# Spieler-Info mit authentischen ANSTOSS 1 Daten
	var player_text = "%s %s (%s) - Stärke: %.1f" % [
		player.first_name,
		player.last_name, 
		player.primary_position,
		player.get_effective_strength()
	]
	
	# Verfügbarkeits-Status prüfen (SuspensionSystem Integration)
	if not player.is_available():
		var suspension_info = ""
		if player.ist_gesperrt:
			suspension_info = " [GESPERRT]"
		if player.verletzungsart != "":
			suspension_info += " [VERLETZT: %s]" % player.verletzungsart
		
		player_text += suspension_info
		button.modulate = Color.GRAY
		button.disabled = true
	
	button.text = player_text
	button.pressed.connect(func(): _on_startelf_player_selected(player_id))
	
	startelf_container.add_child(button)

func _add_player_to_bench(player_id: String):
	var player_data = GameManager.get_player(player_id)
	if player_data.is_empty():
		return
		
	var player = PlayerData.new(player_data)
	var button = Button.new()
	
	var player_text = "%s %s (%s) - Stärke: %.1f" % [
		player.first_name,
		player.last_name,
		player.primary_position, 
		player.get_effective_strength()
	]
	
	button.text = player_text
	button.pressed.connect(func(): _on_bench_player_selected(player_id))
	
	bank_container.add_child(button)

func _on_startelf_player_selected(player_id: String):
	selected_out_player = player_id
	var player_data = GameManager.get_player(player_id)
	var player = PlayerData.new(player_data)
	
	status_label.text = "Auswechseln: %s %s → Jetzt Ersatzspieler wählen" % [player.first_name, player.last_name]
	status_label.modulate = Color.ORANGE

func _on_bench_player_selected(player_id: String):
	selected_in_player = player_id
	var player_data = GameManager.get_player(player_id)
	var player = PlayerData.new(player_data)
	
	if selected_out_player != "":
		status_label.text = "Einwechseln: %s %s → WECHSEL DURCHFÜHREN klicken" % [player.first_name, player.last_name]
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Erst Spieler aus Startelf zum Auswechseln auswählen!"
		status_label.modulate = Color.RED

func _on_execute_substitution():
	if selected_out_player == "" or selected_in_player == "":
		status_label.text = "Bitte beide Spieler auswählen (raus + rein)"
		status_label.modulate = Color.RED
		return
	
	# Auswechslung durchführen
	var starting_eleven = team_data.get("starting_eleven", [])
	var out_index = starting_eleven.find(selected_out_player)
	
	if out_index != -1:
		starting_eleven[out_index] = selected_in_player
		GameManager.teams[current_team_id]["starting_eleven"] = starting_eleven
		
		var out_player = PlayerData.new(GameManager.get_player(selected_out_player))
		var in_player = PlayerData.new(GameManager.get_player(selected_in_player))
		
		status_label.text = "Wechsel: %s %s ↔ %s %s" % [
			out_player.first_name, out_player.last_name,
			in_player.first_name, in_player.last_name
		]
		status_label.modulate = Color.GREEN
		
		# Listen aktualisieren
		selected_out_player = ""
		selected_in_player = ""
		_refresh_player_lists()

# Authentisches ANSTOSS 1 Einsatz-System (aus CLAUDE.md)
func _on_effort_minus():
	if current_einsatz_index > 0:
		current_einsatz_index -= 1
		_update_effort_display()
		_save_team_settings()

func _on_effort_plus():
	if current_einsatz_index < einsatz_levels.size() - 1:
		current_einsatz_index += 1
		_update_effort_display()
		_save_team_settings()

func _update_effort_display():
	effort_state.text = einsatz_levels[current_einsatz_index]

func _on_playstyle_minus():
	if current_spielweise_index > 0:
		current_spielweise_index -= 1
		_update_playstyle_display()
		_save_team_settings()

func _on_playstyle_plus():
	if current_spielweise_index < spielweise_options.size() - 1:
		current_spielweise_index += 1
		_update_playstyle_display()
		_save_team_settings()

func _update_playstyle_display():
	playstyle_state.text = spielweise_options[current_spielweise_index]

func _save_team_settings():
	# Team-Einstellungen in GameManager speichern (authentisch aus CLAUDE.md)
	if not team_data.is_empty():
		GameManager.teams[current_team_id]["default_einsatz"] = einsatz_levels[current_einsatz_index]
		GameManager.teams[current_team_id]["default_tactic"] = spielweise_options[current_spielweise_index]

func _on_cancel_pressed():
	# Zurück ohne Speichern
	queue_free()

func _on_continue_pressed():
	# Weiter mit aktuellen Einstellungen
	_save_team_settings()
	queue_free()