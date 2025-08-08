class_name TeamData
extends RefCounted

var team_id: String
var team_name: String
var city: String
var tier: int
var player_roster: Array[String]
var starting_eleven: Array[String]
var morale: int
var default_einsatz: String
var default_tactic: String
var stadium: Dictionary
var league_stats: Dictionary
var popularity: Dictionary

# Neue Taktik-Optionen (Handbuch basiert)
var abseitsfalle_aktiv: bool = false
var schwalben_aktiv: bool = false
var current_spielweise: String = "Normal"
var current_einsatz: String = "Normal"

const MAX_PLAYERS = 22
const STARTING_ELEVEN_SIZE = 11

func _init(data: Dictionary = {}):
	team_id = data.team_id
	team_name = data.team_name
	city = data.city
	tier = data.tier
	
	var roster_array = data.player_roster as Array
	player_roster.assign(roster_array.slice(0, MAX_PLAYERS))
	
	# Validiere dass alle Spieler existieren
	for player_id in player_roster:
		var player_data = GameManager.get_player(player_id)
		# GameManager.get_player() wirft jetzt assert() wenn Player nicht existiert
	
	# Stelle sicher dass Team mindestens 11 Spieler hat
	assert(player_roster.size() >= 11, "CRITICAL: Team '%s' has only %d players, needs 11!" % [team_name, player_roster.size()])
	
	morale = data.morale
	default_einsatz = data.default_einsatz
	default_tactic = data.default_tactic
	stadium = data.stadium
	league_stats = data.league_stats
	popularity = data.popularity
	
	# Taktik-Einstellungen initialisieren
	current_einsatz = default_einsatz
	current_spielweise = default_tactic
	abseitsfalle_aktiv = data.get("abseitsfalle_aktiv", false)
	schwalben_aktiv = data.get("schwalben_aktiv", false)
	
	starting_eleven = []

func get_bank_players() -> Array[String]:
	var bank: Array[String] = []
	for player_id in player_roster:
		if not starting_eleven.has(player_id):
			bank.append(player_id)
	return bank

func calculate_team_strength(is_home: bool = false, spielweise: String = "Normal", einsatz: String = "Normal") -> float:
	var total_strength: float = 0.0
	
	var lineup = starting_eleven
	if lineup.is_empty():
		lineup = generate_lineup()
		starting_eleven = lineup  # Cachen für nächste Verwendung
	
	for player_id in lineup:
		var player_data = GameManager.get_player(player_id)
		# GameManager garantiert jetzt dass player_data niemals leer ist
		var player = PlayerData.new(player_data)
		var strength = player.get_effective_strength()
		total_strength += strength
	
	total_strength += float(morale)
	
	if is_home:
		total_strength += 4.0
	
	var spielweise_mod = get_spielweise_modifier(spielweise)
	total_strength *= spielweise_mod.total
	
	var einsatz_data = get_einsatz_modifier(einsatz)
	total_strength *= einsatz_data.strength_modifier
	
	var luck_factor = 0.2
	total_strength += total_strength * randf_range(-luck_factor, luck_factor)
	
	return total_strength

func calculate_offensive_strength(position_strengths: Dictionary) -> float:
	var counts = get_position_counts()
	
	var mf_strength = position_strengths["MF"] * counts["MF"] * 0.6
	var st_strength = position_strengths["ST"] * counts["ST"] * 0.8
	var ab_strength = position_strengths["AB"] * counts["AB"] * 0.2
	
	return (mf_strength + st_strength + ab_strength) / 11.0

func calculate_defensive_strength(position_strengths: Dictionary) -> float:
	var counts = get_position_counts()
	
	var tw_strength = position_strengths["TW"] * counts["TW"] * 1.0
	var ab_strength = position_strengths["AB"] * counts["AB"] * 0.8
	var mf_strength = position_strengths["MF"] * counts["MF"] * 0.4
	
	return (tw_strength + ab_strength + mf_strength) / 11.0

func get_position_counts() -> Dictionary:
	var counts = {"TW": 0, "AB": 0, "MF": 0, "ST": 0}
	
	for player_id in starting_eleven:
		var player_data = GameManager.get_player(player_id)
		var player = PlayerData.new(player_data)
		if counts.has(player.primary_position):
			counts[player.primary_position] += 1
	
	return counts

func get_spielweise_modifier(spielweise: String) -> Dictionary:
	# Authentische Anstoss 1 Spielweisen (preparation_screen basiert)
	match spielweise:
		"Abwehrriegel":
			return {
				"total": 0.95, 
				"offensive": 0.7, 
				"defensive": 1.3,
				"event_modifiers": {"NORMAL_ATTACK": 0.8, "FREISTOSS": 1.1}
			}
		"Defensiv":
			return {
				"total": 0.98,
				"offensive": 0.85,
				"defensive": 1.2,
				"event_modifiers": {"NORMAL_ATTACK": 0.9, "TACKLING": 1.2}
			}
		"Normal":
			return {
				"total": 1.0,
				"offensive": 1.0,
				"defensive": 1.0,
				"event_modifiers": {}
			}
		"Offensiv":
			return {
				"total": 1.05,
				"offensive": 1.25,
				"defensive": 0.85,
				"event_modifiers": {"NORMAL_ATTACK": 1.2, "ALLEINGANG": 1.15}
			}
		"Angriff":
			return {
				"total": 1.08,
				"offensive": 1.4,
				"defensive": 0.7,
				"event_modifiers": {"NORMAL_ATTACK": 1.3, "ALLEINGANG": 1.25, "SPIELZUG": 1.2}
			}
		_:
			return {
				"total": 1.0,
				"offensive": 1.0,
				"defensive": 1.0,
				"event_modifiers": {}
			}

func get_einsatz_modifier(einsatz: String) -> Dictionary:
	# Authentische Anstoss 1 Einsatz-Stufen mit Kartenrisiko (Handbuch Seite 33)
	match einsatz:
		"Lieb & Nett":
			return {
				"strength_modifier": 0.9,
				"injury_risk": 0.5,
				"card_risk": 0.3,
				"form_loss": 0.0
			}
		"Fair":
			return {
				"strength_modifier": 0.95,
				"injury_risk": 0.7,
				"card_risk": 0.6,
				"form_loss": 0.0
			}
		"Normal":
			return {
				"strength_modifier": 1.0,
				"injury_risk": 1.0,
				"card_risk": 1.0,
				"form_loss": 0.0
			}
		"Hart":
			return {
				"strength_modifier": 1.05,
				"injury_risk": 1.4,
				"card_risk": 1.6,
				"form_loss": 0.1
			}
		"Brutal":
			return {
				"strength_modifier": 1.1,
				"injury_risk": 2.0,
				"card_risk": 2.5,
				"form_loss": 0.2
			}
		_:
			return {
				"strength_modifier": 1.0,
				"injury_risk": 1.0,
				"card_risk": 1.0,
				"form_loss": 0.0
			}

func generate_lineup_with_substitutions() -> Array[String]:
	# Aufstellung mit automatischen Ersatz-Spielern für Gesperrte/Verletzte
	var lineup: Array[String] = []
	
	var tw_players = get_available_players_by_position("TW")
	var ab_players = get_available_players_by_position("AB")
	var mf_players = get_available_players_by_position("MF") 
	var st_players = get_available_players_by_position("ST")
	
	# Standard Formation: 1 TW, 4 AB, 4 MF, 2 ST
	lineup.append_array(_select_best_players(tw_players, 1))
	lineup.append_array(_select_best_players(ab_players, 4))
	lineup.append_array(_select_best_players(mf_players, 4))
	lineup.append_array(_select_best_players(st_players, 2))
	
	# Falls nicht genug Spieler einer Position: Flexibel auffüllen
	while lineup.size() < 11:
		var all_available = get_available_players_by_position("ALL")
		var missing_player = _find_best_substitute(all_available, lineup)
		if missing_player != "":
			lineup.append(missing_player)
		else:
			break  # Keine weiteren Spieler verfügbar
	
	return lineup

func generate_lineup() -> Array[String]:
	# Formation-basierte Lineup-Generierung
	var lineup: Array[String] = []
	
	# Standard-Formation für Team bestimmen
	var formation = get_team_formation()
	var formation_setup = parse_formation(formation)
	
	var tw_players = get_players_by_position("TW")
	var ab_players = get_players_by_position("AB")
	var mf_players = get_players_by_position("MF") 
	var st_players = get_players_by_position("ST")
	
	# 1 Torwart (immer)
	if tw_players.size() > 0:
		lineup.append(tw_players[0])
	
	# Formation anwenden
	var ab_needed = formation_setup.defenders
	var mf_needed = formation_setup.midfielders  
	var st_needed = formation_setup.forwards
	
	# Abwehrspieler
	for i in range(min(ab_needed, ab_players.size())):
		lineup.append(ab_players[i])
	
	# Mittelfeldspieler
	for i in range(min(mf_needed, mf_players.size())):
		lineup.append(mf_players[i])
	
	# Stürmer
	for i in range(min(st_needed, st_players.size())):
		lineup.append(st_players[i])
	
	# Auffüllen mit stärksten verfügbaren Spielern wenn nicht genug in Position
	while lineup.size() < 11 and lineup.size() < player_roster.size():
		var best_available = get_best_available_player(lineup)
		if best_available != "":
			lineup.append(best_available)
		else:
			break
	
	return lineup

func get_team_formation() -> String:
	"""Bestimmt Standard-Formation für Team basierend auf Eigenschaften"""
	
	# Formation basierend auf Team-Eigenschaften ableiten
	# (In Zukunft könnte default_formation als Property hinzugefügt werden)
	
	# Liga 1 Teams (deutsche Profi-Teams)
	if team_id.begins_with("t0") and team_id.length() == 3:  # t01-t48
		return get_bundesliga_formation(city)
	
	# EU-Teams - Internationale Formationen
	elif team_id.begins_with("t-eur-"):
		return get_european_formation()
	
	# DFB-Amateur-Teams - Defensive Formationen  
	elif team_id.begins_with("t-dfb-"):
		return "4-5-1"  # Defensiv für Amateur-Teams
	
	# Standard für alle anderen
	return "4-4-2"

func get_bundesliga_formation(city: String) -> String:
	"""Authentische Formationen für deutsche Teams basierend auf Stadt"""
	
	# Großstädte tendieren zu offensiveren Formationen
	var major_cities = ["München", "Berlin", "Hamburg", "Köln", "Frankfurt", "Stuttgart", "Düsseldorf", "Dortmund", "Leipzig", "Bremen", "Hannover", "Nürnberg"]
	
	if city in major_cities:
		# Offensive Formationen für Großstadt-Teams
		var formations = ["4-3-3", "3-4-3", "4-2-3-1"]
		return formations[city.hash() % formations.size()]
	else:
		# Ausgewogenere Formationen für kleinere Städte
		var formations = ["4-4-2", "4-5-1", "5-4-1"]
		return formations[city.hash() % formations.size()]

func get_european_formation() -> String:
	"""Internationale Formationen für EU-Teams"""
	var formations = ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1", "5-3-2"]
	return formations[randi() % formations.size()]

func parse_formation(formation: String) -> Dictionary:
	"""Parsed Formation String zu Spieler-Anzahl pro Position"""
	
	var parts = formation.split("-")
	if parts.size() != 3:
		print("TeamData: Ungültige Formation '%s' - verwende 4-4-2" % formation)
		return {"defenders": 4, "midfielders": 4, "forwards": 2}
	
	return {
		"defenders": int(parts[0]),
		"midfielders": int(parts[1]), 
		"forwards": int(parts[2])
	}

func get_players_by_position(position: String) -> Array[String]:
	var position_players: Array[String] = []
	
	for player_id in player_roster:
		# Sicherheitscheck für leere IDs
		if player_id == "" or player_id == null:
			print("WARNING: Empty player_id in roster for position %s" % position)
			continue
		
		var player_data = GameManager.get_player(player_id)
		if player_data.is_empty():
			continue
			
		var player = PlayerData.new(player_data)
		if player.primary_position == position and player.is_available():
			position_players.append(player_id)
	
	# Nach Stärke sortieren (stärkste zuerst)
	position_players.sort_custom(func(a, b): 
		var player_a = PlayerData.new(GameManager.get_player(a))
		var player_b = PlayerData.new(GameManager.get_player(b))
		return player_a.get_effective_strength() > player_b.get_effective_strength()
	)
	
	return position_players

func get_available_players_by_position(position: String) -> Array:
	# Wie get_players_by_position, aber für alle Positionen ("ALL") nutzbar
	var players = []
	
	for player_id in player_roster:
		var player_data = GameManager.get_player(player_id)
		if not player_data.is_empty():
			var player = PlayerData.new(player_data)
			
			# Verwende PlayerData.is_available() (prüft ist_gesperrt + verletzungsart)
			if not player.is_available():
				continue  # Spieler gesperrt/verletzt
			
			if position == "ALL" or player.primary_position == position:
				players.append(player_id)
	
	# Nach effective_strength sortieren (beste zuerst)
	players.sort_custom(func(a, b):
		var player_a = PlayerData.new(GameManager.get_player(a))
		var player_b = PlayerData.new(GameManager.get_player(b))
		return player_a.get_effective_strength() > player_b.get_effective_strength()
	)
	
	return players

func _select_best_players(player_list: Array, count: int) -> Array:
	# Wählt die besten N Spieler aus Liste
	var result = []
	for i in range(min(count, player_list.size())):
		result.append(player_list[i])
	return result

func _find_best_substitute(available_players: Array, current_lineup: Array) -> String:
	# Findet besten Ersatzspieler der nicht schon in Aufstellung ist
	for player_id in available_players:
		if not player_id in current_lineup:
			return player_id
	return ""

func get_best_available_player(current_lineup: Array[String]) -> String:
	var available_players: Array[String] = []
	
	for player_id in player_roster:
		# Sicherheitscheck für leere IDs
		if player_id == "" or player_id == null:
			print("WARNING: Empty player_id in roster")
			continue
			
		if not current_lineup.has(player_id):
			var player_data = GameManager.get_player(player_id)
			if player_data.is_empty():
				continue
				
			var player = PlayerData.new(player_data)
			if player.is_available():
				available_players.append(player_id)
	
	# Nach Stärke sortieren
	available_players.sort_custom(func(a, b): 
		var player_a = PlayerData.new(GameManager.get_player(a))
		var player_b = PlayerData.new(GameManager.get_player(b))
		return player_a.get_effective_strength() > player_b.get_effective_strength()
	)
	
	assert(available_players.size() > 0, "CRITICAL: Team '%s' has no available players for lineup!" % team_name)
	return available_players[0]

func calculate_position_strengths() -> Dictionary:
	var strengths = {"TW": 0.0, "AB": 0.0, "MF": 0.0, "ST": 0.0}
	var counts = {"TW": 0, "AB": 0, "MF": 0, "ST": 0}
	
	for player_id in starting_eleven:
		var player_data = GameManager.get_player(player_id)
		var player = PlayerData.new(player_data)
		var pos = player.primary_position
		if strengths.has(pos):
			strengths[pos] += player.get_effective_strength()
			counts[pos] += 1
	
	for pos in strengths.keys():
		if counts[pos] > 0:
			strengths[pos] = strengths[pos] / counts[pos]
		else:
			assert(false, "CRITICAL: Position '%s' has no players in starting eleven!" % pos)
	
	return strengths

func calculate_formation_balance(position_strengths: Dictionary) -> float:
	var tw_count = 0
	var ab_count = 0
	var mf_count = 0
	var st_count = 0
	
	for player_id in starting_eleven:
		var player_data = GameManager.get_player(player_id)
		var player = PlayerData.new(player_data)
		match player.primary_position:
			"TW": tw_count += 1
			"AB": ab_count += 1
			"MF": mf_count += 1
			"ST": st_count += 1
	
	var balance_factor = 1.0
	
	if tw_count != 1:
		balance_factor *= 0.5
	
	if ab_count < 3:
		balance_factor *= 0.8
	elif ab_count > 6:
		balance_factor *= 0.9
	
	if mf_count < 2:
		balance_factor *= 0.7
	elif mf_count > 6:
		balance_factor *= 0.9
	
	if st_count < 1:
		balance_factor *= 0.6
	elif st_count > 4:
		balance_factor *= 0.8
	
	return balance_factor

func update_morale_after_match(won: bool, draw: bool = false):
	if won:
		morale = clamp(morale + 1, 0, 8)
	elif not draw:
		morale = clamp(morale - 1, 0, 8)

func set_starting_eleven(player_ids: Array):
	if player_ids.size() == STARTING_ELEVEN_SIZE:
		starting_eleven.assign(player_ids)
		return true
	return false

func add_player(player_id: String) -> bool:
	if player_roster.size() < MAX_PLAYERS and not player_roster.has(player_id):
		player_roster.append(player_id)
		return true
	return false

func remove_player(player_id: String) -> bool:
	var index = player_roster.find(player_id)
	if index != -1:
		player_roster.remove_at(index)
		if starting_eleven.has(player_id):
			starting_eleven.erase(player_id)
		return true
	return false

# === NEUE TAKTIK-FUNKTIONEN ===

func set_spielweise(new_spielweise: String):
	"""Setzt neue Spielweise (Abwehrriegel, Defensiv, Normal, Offensiv, Angriff)"""
	var valid_spielweisen = ["Abwehrriegel", "Defensiv", "Normal", "Offensiv", "Angriff"]
	if new_spielweise in valid_spielweisen:
		current_spielweise = new_spielweise
		print("TeamData: %s Spielweise geändert auf: %s" % [team_name, current_spielweise])

func set_einsatz(new_einsatz: String):
	"""Setzt neuen Einsatz (Lieb & Nett, Fair, Normal, Hart, Brutal)"""
	var valid_einsaetze = ["Lieb & Nett", "Fair", "Normal", "Hart", "Brutal"]
	if new_einsatz in valid_einsaetze:
		current_einsatz = new_einsatz
		print("TeamData: %s Einsatz geändert auf: %s" % [team_name, current_einsatz])

func toggle_abseitsfalle():
	"""Schaltet Abseitsfalle AN/AUS"""
	abseitsfalle_aktiv = !abseitsfalle_aktiv
	print("TeamData: %s Abseitsfalle: %s" % [team_name, "AN" if abseitsfalle_aktiv else "AUS"])

func toggle_schwalben():
	"""Schaltet Schwalben AN/AUS"""
	schwalben_aktiv = !schwalben_aktiv
	print("TeamData: %s Schwalben: %s" % [team_name, "AN" if schwalben_aktiv else "AUS"])

func get_tactic_summary() -> Dictionary:
	"""Gibt vollständige Taktik-Übersicht zurück"""
	return {
		"spielweise": current_spielweise,
		"einsatz": current_einsatz,
		"abseitsfalle": abseitsfalle_aktiv,
		"schwalben": schwalben_aktiv,
		"spielweise_effects": get_spielweise_modifier(current_spielweise),
		"einsatz_effects": get_einsatz_modifier(current_einsatz)
	}

func apply_einsatz_form_loss():
	"""Wendet Form-Verlust durch harten Einsatz an (nach Match)"""
	var einsatz_data = get_einsatz_modifier(current_einsatz)
	var form_loss = einsatz_data.form_loss
	
	if form_loss > 0:
		for player_id in starting_eleven:
			var player_data = GameManager.get_player(player_id)
			var player = PlayerData.new(player_data)
			
			# Chance auf Form-Verlust basierend auf Einsatz
			if randf() < form_loss:
				player.current_form = max(0, player.current_form - 1)
				print("TeamData: %s verliert Form durch harten Einsatz (%s)" % [player.get_display_name(), current_einsatz])

func get_event_risk_modifiers() -> Dictionary:
	"""Gibt Risiko-Modifikatoren für Events zurück"""
	var einsatz_data = get_einsatz_modifier(current_einsatz)
	var spielweise_data = get_spielweise_modifier(current_spielweise)
	
	return {
		"injury_risk": einsatz_data.injury_risk,
		"card_risk": einsatz_data.card_risk,
		"event_modifiers": spielweise_data.get("event_modifiers", {}),
		"abseitsfalle_aktiv": abseitsfalle_aktiv,
		"schwalben_aktiv": schwalben_aktiv
	}
