class_name CupManager
extends RefCounted

# Singleton-Pattern für persistente Cup-Daten
static var _instance: CupManager = null

# Gespeicherte Spielpläne für die gesamte Saison
var saved_schedules: Dictionary = {}

static func get_instance() -> CupManager:
	if _instance == null:
		_instance = CupManager.new()
	return _instance

# Unified Cup Manager für DFB-Pokal und EU-Pokale
# Integriert mit ScheduleGenerator und automatischer Qualifikation

enum CupType {
	DFB_POKAL,
	CHAMPIONS_LEAGUE,     # Champions League 2025/26 
	EUROPA_LEAGUE,       # Europa League 2025/26
	CONFERENCE_LEAGUE    # Conference League 2025/26
}

var active_cups: Dictionary = {}
var current_season: int = 1

# DFB-Pokal: 64 Teams (48 Liga + 16 Amateure)
const DFB_POKAL_TEAMS = 64
const DFB_POKAL_ROUNDS = 6  # 64->32->16->8->4->2->1

# Champions League 2025/26: Liga-Phase Format
const CHAMPIONS_LEAGUE_TEAMS = 36
const CHAMPIONS_LEAGUE_MATCHDAYS = 8  # Swiss System

# Europa League 2025/26: Liga-Phase Format (wie Champions League)
const EUROPA_LEAGUE_TEAMS = 36
const EUROPA_LEAGUE_MATCHDAYS = 8  # Swiss System

# Conference League 2025/26: Liga-Phase Format
const CONFERENCE_LEAGUE_TEAMS = 36
const CONFERENCE_LEAGUE_MATCHDAYS = 6  # Weniger Spieltage als CL/EL

func _init():
	_initialize_cups()

func _initialize_cups():
	"""Initialisiert alle Pokal-Strukturen"""
	active_cups[CupType.DFB_POKAL] = {
		"name": "DFB-Pokal",
		"teams": [],
		"eliminated_teams": {},  # PERSISTENT: {team_id: elimination_round}
		"current_round": 1,
		"max_rounds": DFB_POKAL_ROUNDS,
		"matches": {},
		"winners": {}
	}
	
	active_cups[CupType.CHAMPIONS_LEAGUE] = {
		"name": "Champions League",
		"teams": [],
		"league_table": [],
		"current_matchday": 1,
		"max_matchdays": CHAMPIONS_LEAGUE_MATCHDAYS,
		"fixtures": {},
		"qualified_teams": [],
		"playoff_teams": [],
		"phase": "league_stage"
	}
	
	active_cups[CupType.EUROPA_LEAGUE] = {
		"name": "Europa League",
		"teams": [],
		"league_table": [],
		"current_matchday": 1,
		"max_matchdays": EUROPA_LEAGUE_MATCHDAYS,
		"fixtures": {},
		"qualified_teams": [],
		"playoff_teams": [],
		"phase": "league_stage"
	}
	
	active_cups[CupType.CONFERENCE_LEAGUE] = {
		"name": "Conference League",
		"teams": [],
		"league_table": [],
		"current_matchday": 1,
		"max_matchdays": CONFERENCE_LEAGUE_MATCHDAYS,
		"fixtures": {},
		"qualified_teams": [],
		"playoff_teams": [],
		"phase": "league_stage"
	}

func setup_new_season(season: int):
	"""Setup für neue Saison mit automatischer Qualifikation - NUR EINMAL pro Saison!"""
	print("🔍 DEBUG: setup_new_season(%d) aufgerufen!" % season)
	
	# KRITISCH: Überprüfen ob bereits für diese Saison initialisiert
	# Prüfe ob DFB-Pokal bereits Teams hat (nicht nur ob active_cups existiert)
	var dfb_already_setup = false
	if active_cups.has(CupType.DFB_POKAL):
		var dfb_teams = active_cups[CupType.DFB_POKAL].get("teams", [])
		dfb_already_setup = not dfb_teams.is_empty()
	
	if current_season == season and dfb_already_setup:
		print("CupManager: Saison %d bereits initialisiert - überspringe Setup" % season)
		var dfb_teams = active_cups[CupType.DFB_POKAL].get("teams", [])
		print("CupManager: DFB-Pokal hat %d aktive Teams: %s" % [dfb_teams.size(), str(dfb_teams.slice(0, 5))])
		return
	
	current_season = season
	print("=== CupManager: ERSTE Initialisierung für Saison %d ===" % season)
	
	# Lösche alte Spielpläne
	saved_schedules.clear()
	
	# DFB-Pokal: Alle deutschen Teams + Amateur-Vereine
	_setup_dfb_pokal()
	
	# Champions League 2025/26: Neues Liga-System
	_setup_champions_league()
	
	# Europa League 2025/26: Liga-System
	_setup_europa_league()
	
	# Conference League 2025/26: Liga-System
	_setup_conference_league()
	
	# WICHTIG: Generiere und speichere alle Spielpläne zu Saisonbeginn
	_generate_all_season_schedules()

func _setup_dfb_pokal():
	"""DFB-Pokal Setup: 48 Liga-Teams + 16 Amateure - NUR EINMAL bei Saison-Start!"""
	var cup_data = active_cups[CupType.DFB_POKAL]
	print("DEBUG: _setup_dfb_pokal() aufgerufen - Teams: %d" % cup_data.teams.size())
	
	# KRITISCH: Nur initialisieren wenn noch leer UND keine eliminierten Teams vorhanden
	var eliminated_dict = cup_data.get("eliminated_teams", {})
	if cup_data.teams.is_empty() and eliminated_dict.is_empty():
		print("DFB-Pokal: ERSTE INITIALISIERUNG - Teams werden gesetzt")
		
		# Alle 48 Liga-Teams (1./2./3. Liga)
		var league_teams = _get_all_league_teams()
		cup_data.teams.append_array(league_teams)
		
		# 16 Amateur-Teams (aus EU-Teams simulieren)
		var amateur_teams = _get_amateur_teams(16)
		cup_data.teams.append_array(amateur_teams)
		
		# ECHTE ZUFÄLLIGE AUSLOSUNG mit neuem Seed
		RandomNumberGenerator.new().randomize()
		cup_data.teams.shuffle()
		
		# ERSTE RUNDE DIREKT AUSLOSEN (realistische DFB-Pokal Auslosung)
		_generate_next_dfb_round(CupType.DFB_POKAL, 1)
		
		print("DFB-Pokal: %d Teams qualifiziert, 1. Runde ausgelost" % cup_data.teams.size())
	elif not eliminated_dict.is_empty():
		print("🚨 DFB-Pokal: BLOCKIERE RE-ADDING - %d Teams bereits eliminiert!" % eliminated_dict.size())
		print("🚨 Eliminierte Teams: %s" % str(eliminated_dict.keys()))
		if "t01" in eliminated_dict:
			print("💀 User-Team t01 wurde bereits in Runde %d eliminiert!" % eliminated_dict["t01"])
	else:
		print("DFB-Pokal: Teams bereits vorhanden (%d Teams) - KEINE Neuinitialisierung" % cup_data.teams.size())
		print("DFB-Pokal: Aktuelle Teams: %s" % str(cup_data.teams.slice(0, 5)))
	
	print("DFB-Pokal: %d Teams qualifiziert, 1. Runde ausgelost" % cup_data.teams.size())

func _setup_champions_league():
	"""Champions League 2025/26: Liga-Phase mit 36 Teams"""
	print("CupManager: Champions League 2025/26 Liga-Phase Setup...")
	
	var cup_data = active_cups[CupType.CHAMPIONS_LEAGUE]
	var german_teams = _get_german_champions_league_teams()
	
	# Alle 36 Teams zusammenstellen
	var all_teams = []
	all_teams.append_array(german_teams)
	
	# EU-Teams nach realistischen Länder-Regeln
	var remaining_slots = CHAMPIONS_LEAGUE_TEAMS - german_teams.size()
	var eu_teams = _get_champions_league_teams(remaining_slots)
	all_teams.append_array(eu_teams)
	
	# Liga-System initialisieren
	cup_data.teams = all_teams
	cup_data.league_table = _create_league_table(all_teams)
	# Fixtures werden später in _generate_all_season_schedules generiert
	
	print("Champions League: %d Teams in Liga-Phase" % all_teams.size())
	print("  → Plätze 1-8: Direkt ins Achtelfinale")
	print("  → Plätze 9-24: Play-offs")
	print("  → Plätze 25-36: Ausgeschieden")

func _setup_europa_league():
	"""Europa League 2025/26: Liga-Phase mit 36 Teams"""
	print("CupManager: Europa League 2025/26 Liga-Phase Setup...")
	
	var cup_data = active_cups[CupType.EUROPA_LEAGUE]
	var german_teams = _get_german_europa_league_teams()
	
	# Alle 36 Teams zusammenstellen
	var all_teams = []
	all_teams.append_array(german_teams)
	
	# EU-Teams nach realistischen Länder-Regeln
	var remaining_slots = EUROPA_LEAGUE_TEAMS - german_teams.size()
	var eu_teams = _get_europa_league_teams(remaining_slots)
	all_teams.append_array(eu_teams)
	
	# Liga-System initialisieren
	cup_data.teams = all_teams
	cup_data.league_table = _create_league_table(all_teams)
	# Fixtures werden später in _generate_all_season_schedules generiert
	
	print("Europa League: %d Teams in Liga-Phase" % all_teams.size())
	print("  → Plätze 1-8: Direkt im Achtelfinale")
	print("  → Plätze 9-24: Play-offs")
	print("  → Plätze 25-36: Ausgeschieden")

func _setup_conference_league():
	"""Conference League 2025/26: Liga-Phase mit 36 Teams"""
	print("CupManager: Conference League 2025/26 Liga-Phase Setup...")
	
	var cup_data = active_cups[CupType.CONFERENCE_LEAGUE]
	var german_teams = _get_german_conference_league_teams()
	
	# Alle 36 Teams zusammenstellen
	var all_teams = []
	all_teams.append_array(german_teams)
	
	# EU-Teams nach realistischen Länder-Regeln
	var remaining_slots = CONFERENCE_LEAGUE_TEAMS - german_teams.size()
	var eu_teams = _get_conference_league_teams(remaining_slots)
	all_teams.append_array(eu_teams)
	
	# Liga-System initialisieren
	cup_data.teams = all_teams
	cup_data.league_table = _create_league_table(all_teams)
	# Fixtures werden später in _generate_all_season_schedules generiert
	
	print("Conference League: %d Teams in Liga-Phase" % all_teams.size())
	print("  → Plätze 1-8: Direkt im Achtelfinale")
	print("  → Plätze 9-24: Play-offs")
	print("  → Plätze 25-36: Ausgeschieden")

func _get_german_champions_league_teams() -> Array:
	"""Deutsche Champions League Qualifikation 2025/26 (vereinfacht)"""
	var cl_teams = []
	
	# VEREINFACHT: Die besten 4 deutschen Teams für CL qualifizieren
	# (In echt wären das die Plätze 1-4 der letzten Saison)
	var german_cl_teams = ["t01", "t02", "t03", "t04"]  # Top 4 Teams
	
	for team_id in german_cl_teams:
		var team_data = GameManager.get_team(team_id)
		if not team_data.is_empty():
			cl_teams.append(team_id)
			print("CL: %s qualifiziert (Deutschland)" % team_id)
	
	print("Deutsche Champions League Teams: %s" % str(cl_teams))
	return cl_teams

func _get_german_europa_league_teams() -> Array:
	"""Deutsche Europa League Qualifikation 2025/26 (vereinfacht)"""
	var el_teams = []
	
	# VEREINFACHT: Platz 5 für EL qualifiziert
	var german_el_teams = ["t05"]  # Platz 5
	
	for team_id in german_el_teams:
		var team_data = GameManager.get_team(team_id)
		if not team_data.is_empty():
			el_teams.append(team_id)
			print("EL: %s qualifiziert (Deutschland)" % team_id)
	
	print("Deutsche Europa League Teams: %s" % str(el_teams))
	return el_teams

func _get_german_conference_league_teams() -> Array:
	"""Deutsche Conference League Qualifikation 2025/26 (vereinfacht)"""
	var ecl_teams = []
	
	# VEREINFACHT: Platz 6 für ECL qualifiziert
	var german_ecl_teams = ["t06"]  # Platz 6
	
	for team_id in german_ecl_teams:
		var team_data = GameManager.get_team(team_id)
		if not team_data.is_empty():
			ecl_teams.append(team_id)
			print("ECL: %s qualifiziert (Deutschland)" % team_id)
	
	print("Deutsche Conference League Teams: %s" % str(ecl_teams))
	return ecl_teams

func _get_german_europa_league_teams_old() -> Array:
	"""Deutsche Europa League Qualifikation 2025/26"""
	var el_teams = []
	
	# Deutsche 1. Liga Teams prüfen (t01-t18)
	for i in range(1, 19):
		var team_id = "t%02d" % i
		var team_data = GameManager.get_team(team_id)
		
		if team_data.has("last_season_placement"):
			var placement = team_data.last_season_placement
			
			# AUFSTEIGER-CHECK: t17 und t18 sind Aufsteiger aus 2. Liga
			if team_id in ["t17", "t18"]:
				# Aufsteiger können nicht EL-qualifiziert sein
				print("EL: %s ist Aufsteiger - nicht EL-berechtigt" % team_id)
				continue
			
			# Europa League: Nur Platz 5 (wie echte Bundesliga)
			if placement == 5:
				el_teams.append(team_id)
	
	print("Deutsche Europa League Teams: %s" % str(el_teams))
	return el_teams


func _get_all_league_teams() -> Array:
	"""Holt alle 48 Liga-Teams (18+18+12)"""
	var teams = []
	
	# 1. Liga (18 Teams)
	for i in range(1, 19):
		teams.append("t%02d" % i)
	
	# 2. Liga (18 Teams) 
	for i in range(19, 37):
		teams.append("t%02d" % i)
	
	# 3. Liga (12 Teams)
	for i in range(37, 49):
		teams.append("t%02d" % i)
	
	return teams

func _get_amateur_teams(count: int) -> Array:
	"""Deutsche Amateur-Teams für DFB-Pokal (echte Amateur-Vereine)"""
	var amateur_teams = []
	
	# AUTHENTISCHER DFB-POKAL: Deutsche Amateur-Vereine (t-dfb-XX)
	# Sammle alle deutschen Amateurteams (nicht Liga-Teams)
	var available_amateur_teams = []
	
	for team_id in GameManager.teams.keys():
		if team_id.begins_with("t-dfb-"):  # Deutsche Amateur-Teams
			var team_data = GameManager.get_team(team_id)
			var roster = team_data.get("player_roster", [])
			# Nur Teams mit genügend Spielern
			if roster.size() >= 11:
				available_amateur_teams.append(team_id)
			else:
				print("CupManager: Amateur-Team %s ausgeschlossen - nur %d Spieler" % [team_data.get("team_name", team_id), roster.size()])
	
	# Zufällige Auswahl
	available_amateur_teams.shuffle()
	for i in range(min(count, available_amateur_teams.size())):
		amateur_teams.append(available_amateur_teams[i])
	
	print("CupManager: %d deutsche Amateur-Teams für DFB-Pokal aus %d verfügbaren" % [amateur_teams.size(), available_amateur_teams.size()])
	return amateur_teams

func _get_champions_league_teams(count: int) -> Array:
	"""Realistische Champions League Qualifikation nach Ländern"""
	var selected_teams = []
	var country_allocation = _get_cl_country_allocation()
	
	print("CupManager: Champions League Länder-Qualifikation:")
	
	# Für jedes Land die entsprechende Anzahl Teams auswählen
	for country_code in country_allocation.keys():
		var team_count = country_allocation[country_code]
		var country_teams = _get_teams_from_country(country_code, team_count)
		
		if country_teams.size() > 0:
			selected_teams.append_array(country_teams)
			var country_name = _get_country_name(country_code)
			print("  %s: %d Teams (%s)" % [country_name, country_teams.size(), str(country_teams)])
	
	# Falls nicht genug Teams, mit zufälligen EU-Teams auffüllen
	if selected_teams.size() < count:
		var remaining = count - selected_teams.size()
		var additional_teams = _get_random_eu_teams(remaining, selected_teams)
		selected_teams.append_array(additional_teams)
		print("  Zusätzlich: %d zufällige EU-Teams" % additional_teams.size())
	
	return selected_teams.slice(0, count)  # Maximal gewünschte Anzahl

func _get_europa_league_teams(count: int) -> Array:
	"""Realistische Europa League Qualifikation nach Ländern"""
	var selected_teams = []
	var country_allocation = _get_el_country_allocation()
	
	print("CupManager: Europa League Länder-Qualifikation:")
	
	# Für jedes Land die entsprechende Anzahl Teams auswählen
	for country_code in country_allocation.keys():
		var team_count = country_allocation[country_code]
		var country_teams = _get_teams_from_country(country_code, team_count)
		
		if country_teams.size() > 0:
			selected_teams.append_array(country_teams)
			var country_name = _get_country_name(country_code)
			print("  %s: %d Teams (%s)" % [country_name, country_teams.size(), str(country_teams)])
	
	# Falls nicht genug Teams, mit zufälligen EU-Teams auffüllen
	if selected_teams.size() < count:
		var remaining = count - selected_teams.size()
		var additional_teams = _get_random_eu_teams(remaining, selected_teams)
		selected_teams.append_array(additional_teams)
		print("  Zusätzlich: %d zufällige EU-Teams" % additional_teams.size())
	
	return selected_teams.slice(0, count)  # Maximal gewünschte Anzahl

func _get_conference_league_teams(count: int) -> Array:
	"""Realistische Conference League Qualifikation nach Ländern"""
	var selected_teams = []
	var country_allocation = _get_ecl_country_allocation()
	
	print("CupManager: Conference League Länder-Qualifikation:")
	
	# Für jedes Land die entsprechende Anzahl Teams auswählen
	for country_code in country_allocation.keys():
		var team_count = country_allocation[country_code]
		var country_teams = _get_teams_from_country(country_code, team_count)
		selected_teams.append_array(country_teams)
		
		print("  %s: %d Teams (%s)" % [country_code, team_count, str(country_teams)])
	
	# Falls nicht genug Teams, mit zufälligen EU-Teams auffüllen
	if selected_teams.size() < count:
		var remaining = count - selected_teams.size()
		var additional_teams = _get_random_eu_teams(remaining, selected_teams)
		selected_teams.append_array(additional_teams)
		print("  Zusätzlich: %d zufällige EU-Teams" % additional_teams.size())
	
	return selected_teams.slice(0, count)  # Maximal gewünschte Anzahl

func _get_cl_country_allocation() -> Dictionary:
	"""Champions League Plätze nach realen UEFA-Koeffizienten"""
	return {
		# Top 4 Länder: 4 Plätze
		"esp": 4,  # Spanien (Real Madrid, Barcelona, Atletico, Athletic)
		"eng": 4,  # England (Man City, Arsenal, Liverpool, Chelsea)
		"ger": 4,  # Deutschland (bereits implementiert)
		"ita": 4,  # Italien (Juventus, Milan, Inter, Napoli)
		
		# Plätze 5-6: 3 Plätze
		"fra": 3,  # Frankreich (PSG, Monaco, Lille)
		"ned": 3,  # Niederlande (Ajax, PSV, Feyenoord)
		
		# Plätze 7-15: 2 Plätze
		"por": 2,  # Portugal (Porto, Benfica)
		"aut": 2,  # Österreich (Red Bull Salzburg, Sturm Graz)
		"bel": 2,  # Belgien (Club Brügge, Anderlecht)
		"sco": 2,  # Schottland (Celtic, Rangers)
		"tur": 2,  # Türkei (Galatasaray, Fenerbahce)
		"cze": 2,  # Tschechien (Sparta Prag, Slavia Prag)
		"pol": 2,  # Polen (Legia Warschau, Cracovia)
		
		# Kleinere Länder: 1 Platz (Meister)
		"nor": 1,  # Norwegen
		"den": 1,  # Dänemark  
		"swe": 1,  # Schweden
		"fin": 1,  # Finnland
		"sui": 1   # Schweiz
	}

func _get_ecl_country_allocation() -> Dictionary:
	"""Conference League Plätze nach realen UEFA-Regeln"""
	return {
		# Mittlere Länder: 2-3 Plätze
		"ned": 2,  # Niederlande
		"bel": 2,  # Belgien
		"tur": 2,  # Türkei
		"sco": 2,  # Schottland
		"nor": 2,  # Norwegen
		"den": 2,  # Dänemark
		"swe": 2,  # Schweden
		"cze": 1,  # Tschechien
		"pol": 1,  # Polen
		"sui": 1,  # Schweiz
		"cro": 1,  # Kroatien
		"ser": 1,  # Serbien
		"gre": 1,  # Griechenland
		"ukr": 1,  # Ukraine
		"isr": 1,  # Israel
		"cyp": 1,  # Zypern
		"fin": 1,  # Finnland
		"ire": 1,  # Irland
		"nir": 1,  # Nordirland
		"wal": 1,  # Wales
	}

func _get_el_country_allocation() -> Dictionary:
	"""Europa League Plätze nach realen UEFA-Regeln"""
	return {
		# Top Länder: 2-3 weitere Plätze (zusätzlich zu CL)
		"esp": 2,  # Spanien (5.-6. Platz)
		"eng": 2,  # England (5.-6. Platz)
		"ita": 2,  # Italien (5.-6. Platz)
		"fra": 2,  # Frankreich (4.-5. Platz)
		"ned": 1,  # Niederlande (4. Platz)
		
		# Mittlere Länder: 1-2 Plätze
		"rus": 2,  # Russland
		"ukr": 2,  # Ukraine
		"gre": 2,  # Griechenland
		"cro": 1,  # Kroatien
		"ser": 1,  # Serbien
		"rou": 1,  # Rumänien
		"bul": 1,  # Bulgarien
		"hun": 1,  # Ungarn
		"svk": 1,  # Slowakei
		
		# Kleinere Länder: 1 Platz (Pokalsieger oder 2. Platz)
		"isr": 1,  # Israel
		"cyp": 1,  # Zypern
		"bih": 1,  # Bosnien
		"svn": 1,  # Slowenien
		"mkd": 1   # Nordmazedonien
	}

func _get_teams_from_country(country_code: String, count: int) -> Array:
	"""Wählt zufällige EU-Teams (ignoriert country_code, nimmt alle verfügbaren)"""
	var country_teams = []
	
	# LÖSUNG: Alle EU-Teams sammeln (echte Daten verwenden)
	for team_id in GameManager.teams.keys():
		if team_id.begins_with("t-eur-"):  # Alle EU-Teams nehmen
			var team_data = GameManager.get_team(team_id)
			var roster = team_data.get("player_roster", [])
			if roster.size() >= 11:  # Mindestens 11 Spieler für komplettes Team
				country_teams.append(team_id)
	
	# Zufällige Auswahl
	country_teams.shuffle()
	
	print("DEBUG: EU-Teams verfügbar: %d, gewünscht: %d" % [country_teams.size(), count])
	if country_teams.size() > 0:
		print("  Erste 5 EU-Teams: %s" % str(country_teams.slice(0, min(5, country_teams.size()))))
	
	# Gewünschte Anzahl zurückgeben
	var selected = []
	for i in range(min(count, country_teams.size())):
		selected.append(country_teams[i])
	
	return selected

func _get_country_name(country_code: String) -> String:
	"""Ländercode zu Ländername"""
	var country_names = {
		"esp": "Spanien", "eng": "England", "ger": "Deutschland", "ita": "Italien",
		"fra": "Frankreich", "ned": "Niederlande", "por": "Portugal", "aut": "Österreich",
		"bel": "Belgien", "sco": "Schottland", "tur": "Türkei", "cze": "Tschechien",
		"pol": "Polen", "nor": "Norwegen", "den": "Dänemark", "swe": "Schweden",
		"fin": "Finnland", "sui": "Schweiz", "rus": "Russland", "ukr": "Ukraine",
		"gre": "Griechenland", "cro": "Kroatien", "ser": "Serbien", "rou": "Rumänien",
		"bul": "Bulgarien", "hun": "Ungarn", "svk": "Slowakei", "isr": "Israel",
		"cyp": "Zypern", "bih": "Bosnien", "svn": "Slowenien", "mkd": "Nordmazedonien"
	}
	return country_names.get(country_code, country_code.to_upper())

func _get_random_eu_teams(count: int, exclude_teams: Array = []) -> Array:
	"""Zufällige EU-Teams als Auffüllung"""
	var available_teams = []
	
	for team_id in GameManager.teams.keys():
		if team_id.begins_with("t-eur-") and not exclude_teams.has(team_id):
			var team_data = GameManager.get_team(team_id)
			var roster = team_data.get("player_roster", [])
			if roster.size() >= 11:
				available_teams.append(team_id)
	
	available_teams.shuffle()
	
	var selected = []
	for i in range(min(count, available_teams.size())):
		selected.append(available_teams[i])
	
	return selected

# Tier-basierte Funktionen entfernt - jetzt länder-basierte Qualifikation

func _get_team_average_strength(team_id: String) -> float:
	"""AUTHENTISCHE Team-Stärke mit TeamData.calculate_team_strength()"""
	var team_data = GameManager.get_team(team_id)
	var team = TeamData.new(team_data)
	
	# CLAUDE.MD: Verwende authentische TeamData-Berechnung
	# calculate_team_strength(is_home, spielweise, einsatz)
	return team.calculate_team_strength(false, "Normal", "Normal")

func _create_league_table(teams: Array) -> Array:
	"""Erstellt Liga-Tabelle für EU-Pokale"""
	var table = []
	for team_id in teams:
		var team_data = GameManager.get_team(team_id)
		table.append({
			"team_id": team_id,
			"team_name": team_data.get("team_name", team_id),
			"matches": 0,
			"wins": 0,
			"draws": 0,
			"losses": 0,
			"goals_for": 0,
			"goals_against": 0,
			"goal_difference": 0,
			"points": 0,
			"position": 0
		})
	
	return table

func _create_swiss_system_fixtures(teams: Array, matchdays: int) -> Dictionary:
	"""Erstellt Swiss System Fixtures für EU-Pokale"""
	var fixtures = {}
	
	# Für jeden Spieltag: 18 Matches (36 Teams / 2)
	for matchday in range(1, matchdays + 1):
		fixtures[matchday] = []
		
		# Vereinfachtes Swiss System: Teams shuffeln
		var available_teams = teams.duplicate()
		available_teams.shuffle()
		
		# 18 Paarungen bilden
		for i in range(0, available_teams.size(), 2):
			if i + 1 < available_teams.size():
				fixtures[matchday].append({
					"home_team": available_teams[i],
					"away_team": available_teams[i + 1],
					"played": false,
					"home_goals": 0,
					"away_goals": 0
				})
	
	return fixtures

func generate_cup_matches(cup_type: CupType, round: int) -> Array:
	"""Generiert Pokal-Begegnungen für aktuelle Runde"""
	var cup_data = active_cups[cup_type]
	var matches = []
	
	# NEUE LIGA-PHASE für EU-Pokale
	if cup_type in [CupType.CHAMPIONS_LEAGUE, CupType.EUROPA_LEAGUE, CupType.CONFERENCE_LEAGUE]:
		return _generate_league_phase_matches(cup_type, round)
	
	# DFB-POKAL: Realistisches KO-System mit AUSLOSUNG
	var teams = cup_data.teams.duplicate()
	
	# ORIGINALGETREU: Zufällige Auslosung statt fester Reihenfolge
	teams.shuffle()  # Zufällige Auslosung!
	
	# Paare bilden aus der zufälligen Auslosung
	for i in range(0, teams.size(), 2):
		if i + 1 < teams.size():
			var team_1 = teams[i]
			var team_2 = teams[i + 1]
			
			# Heimrecht-Entscheidung (originalgetreu DFB-Pokal)
			var home_team = team_1
			var away_team = team_2
			
			if cup_type == CupType.DFB_POKAL:
				# DFB-Pokal Regel: Unterklassige Teams haben Heimrecht
				var tier_1 = _get_team_tier(team_1)
				var tier_2 = _get_team_tier(team_2)
				
				if tier_2 > tier_1:  # tier_2 ist unterklassiger (höhere Zahl = niedrigere Liga)
					# Unterklassiges Team bekommt Heimrecht
					home_team = team_2
					away_team = team_1
				elif tier_1 == tier_2:
					# Gleiche Liga: Zufälliges Heimrecht
					if randf() > 0.5:
						home_team = team_2
						away_team = team_1
			else:
				# Andere Pokale: Immer zufälliges Heimrecht
				if randf() > 0.5:
					home_team = team_2
					away_team = team_1
			
			matches.append({
				"home_team": home_team,
				"away_team": away_team,
				"round": round,
				"cup_type": cup_type
			})
	
	# ABSTURZ-FIX: Prüfen ob matches Dictionary existiert
	if not cup_data.has("matches") or cup_data.matches == null:
		cup_data.matches = {}
	cup_data.matches[round] = matches
	return matches

func _generate_league_phase_matches(cup_type: CupType, matchday: int) -> Array:
	"""Liefert Liga-Phase Matches für Spieltag - EINMALIGE Auslosung aller 8 Gegner zu Beginn"""
	var cup_data = active_cups[cup_type]
	var teams = cup_data.get("teams", [])
	
	if teams.size() < 2:
		print("FEHLER: Zu wenige Teams für %s Liga-Phase" % cup_data.name)
		return []
	
	# ✅ KOMPLETT-SCHEDULE EINMAL GENERIEREN (alle 8 Spieltage) 
	# Cache bleibt bestehen für alle 8 Spieltage
	
	if not cup_data.has("league_phase_fixtures"):
		print("🎯 EU-Pokal %s: EINMALIGE Auslosung aller Gegner für Liga-Phase (%d Teams)" % [cup_data.name, teams.size()])
		cup_data["league_phase_fixtures"] = _generate_complete_league_phase_schedule(cup_type, teams)
		print("✅ Liga-Phase Fixtures für alle 8 Spieltage generiert")
	
	# Matches für gewünschten Spieltag aus komplettem Schedule abrufen
	var fixtures = cup_data.get("league_phase_fixtures", {})
	if not fixtures.has(matchday):
		print("⚠️ Keine Fixtures für %s Spieltag %d gefunden" % [cup_data.name, matchday])
		return []
	
	var matches = fixtures[matchday]
	print("📋 Liga-Phase %s Spieltag %d: %d Matches aus festem Schedule" % [cup_data.name, matchday, matches.size()])
	
	# User-Team Match hervorheben
	for match in matches:
		if match.get("home_team") == "t01" or match.get("away_team") == "t01":
			var opponent = match.get("away_team") if match.get("home_team") == "t01" else match.get("home_team")
			var home_away = "Heim" if match.get("home_team") == "t01" else "Auswärts"
			print("  🎯 USER: %s vs %s (%s)" % [match.home_team, match.away_team, home_away])
			break
	
	return matches

func _generate_complete_league_phase_schedule(cup_type: CupType, teams: Array) -> Dictionary:
	"""ORIGINALGETREU: UEFA Liga-Phase (Swiss System) - jedes Team gegen 8 verschiedene Gegner"""
	var fixtures = {}
	var max_matchdays = 8
	if cup_type == CupType.CONFERENCE_LEAGUE:
		max_matchdays = 6  # Conference League hat nur 6 Spieltage
	
	print("🎯 EU-POKAL LIGA-PHASE: Originalgetreue Auslosung nach UEFA-System")
	print("📋 %d Teams, %d Spieltage" % [teams.size(), max_matchdays])
	
	# ORIGINALGETREU: Jedes Team bekommt genau 8 (bzw. 6) verschiedene Gegner
	# 4 Heimspiele, 4 Auswärtsspiele (bzw. 3/3 für Conference)
	var team_fixtures = {}  # team_id -> [{opponent, home/away, matchday}]
	
	for team in teams:
		team_fixtures[team] = []
	
	# REALISTISCHE AUSLOSUNG: Töpfe basierend auf Stärke (wie bei UEFA)
	var sorted_teams = teams.duplicate()
	sorted_teams.shuffle()  # Vorerst zufällig, später nach UEFA-Koeffizienten
	
	# Töpfe erstellen (4 Töpfe à 9 Teams bei 36 Teams)
	var pots = []
	var teams_per_pot = teams.size() / 4
	for pot_idx in range(4):
		var pot = []
		for i in range(teams_per_pot):
			var team_idx = pot_idx * teams_per_pot + i
			if team_idx < sorted_teams.size():
				pot.append(sorted_teams[team_idx])
		pots.append(pot)
		print("  Topf %d: %d Teams" % [pot_idx + 1, pot.size()])
	
	# AUSLOSUNG: Jedes Team zieht Gegner aus verschiedenen Töpfen
	for team in teams:
		var opponents = []
		var home_games = max_matchdays / 2
		var away_games = max_matchdays / 2
		
		# Aus jedem Topf 2 Gegner ziehen (1 Heim, 1 Auswärts) - MIT DUPLIKAT-CHECK
		var used_opponents = []  # Bereits verwendete Gegner speichern
		for pot in pots:
			var pot_opponents = pot.duplicate()
			pot_opponents.erase(team)  # Nicht gegen sich selbst
			
			# DUPLIKAT-CHECK: Bereits verwendete Gegner ausschließen
			for used in used_opponents:
				pot_opponents.erase(used)
			
			pot_opponents.shuffle()
			
			# 2 Gegner aus diesem Topf (keine Duplikate möglich)
			for i in range(min(2, pot_opponents.size())):
				if opponents.size() < max_matchdays:
					var opponent = pot_opponents[i]
					used_opponents.append(opponent)  # Als verwendet markieren
					opponents.append({
						"opponent": opponent,
						"is_home": (i == 0 and home_games > 0) or away_games <= 0
					})
					if opponents.back().is_home:
						home_games -= 1
					else:
						away_games -= 1
		
		# Gegner auf Spieltage verteilen
		opponents.shuffle()
		for i in range(min(opponents.size(), max_matchdays)):
			team_fixtures[team].append({
				"opponent": opponents[i].opponent,
				"is_home": opponents[i].is_home,
				"matchday": i + 1
			})
	
	# SPIELTAGE ERSTELLEN: Aus den individuellen Fixtures
	for matchday in range(1, max_matchdays + 1):
		fixtures[matchday] = []
		var scheduled_teams = {}
		
		for team in teams:
			if scheduled_teams.has(team):
				continue
			
			# Finde Match für dieses Team an diesem Spieltag
			for fixture in team_fixtures[team]:
				if fixture.matchday != matchday:
					continue
				
				var opponent = fixture.opponent
				if scheduled_teams.has(opponent):
					continue
				
				# Match erstellen
				if fixture.is_home:
					fixtures[matchday].append({
						"home_team": team,
						"away_team": opponent,
						"cup_type": cup_type,
						"matchday": matchday
					})
				else:
					fixtures[matchday].append({
						"home_team": opponent,
						"away_team": team,
						"cup_type": cup_type,
						"matchday": matchday
					})
				
				scheduled_teams[team] = true
				scheduled_teams[opponent] = true
				break
		
		print("  Spieltag %d: %d Matches" % [matchday, fixtures[matchday].size()])
	
	return fixtures

func _show_user_team_opponents(fixtures: Dictionary, max_matchdays: int):
	"""Zeigt alle Gegner des User-Teams für die Liga-Phase an"""
	print("👤 USER-TEAM Liga-Phase Gegner:")
	for matchday in range(1, max_matchdays + 1):
		if fixtures.has(matchday):
			for match in fixtures[matchday]:
				if match.get("home_team") == "t01":
					var opponent_data = GameManager.get_team(match.get("away_team"))
					print("  Spieltag %d: vs %s (Heim)" % [matchday, opponent_data.get("team_name", match.get("away_team"))])
				elif match.get("away_team") == "t01":
					var opponent_data = GameManager.get_team(match.get("home_team"))
					print("  Spieltag %d: bei %s (Auswärts)" % [matchday, opponent_data.get("team_name", match.get("home_team"))])

func _create_simple_random_schedule(teams: Array, cup_type: CupType = CupType.CHAMPIONS_LEAGUE) -> Dictionary:
	"""Erstellt einfache Zufallsgegner-Liga-Phase: Jeder Spieltag komplett neue Zufallspaarungen"""
	var schedule = {}
	var team_count = teams.size()
	
	print("DEBUG: Einfache Zufallsgegner Liga-Phase für %d Teams wird generiert" % team_count)
	
	# Verschiedene Spieltag-Anzahlen je nach Pokal
	var matchdays = 8  # Standard für CL/EL
	if cup_type == CupType.CONFERENCE_LEAGUE:
		matchdays = 6  # ECL hat nur 6 Spieltage
	
	# EINFACHE ZUFALLSAUSLOSUNG: Jeder Spieltag komplett neu auslosen
	var rng = RandomNumberGenerator.new()
	
	for matchday in range(1, matchdays + 1):
		rng.randomize()  # Neue Seed für jeden Spieltag
		var teams_copy = teams.duplicate()
		teams_copy.shuffle()  # Komplett neue Reihenfolge
		
		var matches = []
		
		# Paarweise Teams zuordnen
		for i in range(0, team_count, 2):
			if i + 1 < team_count:
				var home_team = teams_copy[i] 
				var away_team = teams_copy[i + 1]
				
				matches.append({
					"home_team": home_team,
					"away_team": away_team,
					"played": false,
					"home_goals": 0,
					"away_goals": 0
				})
		
		schedule[matchday] = matches
		print("Liga-Phase Spieltag %d: %d Matches generiert" % [matchday, matches.size()])
	
	return schedule

func _sort_teams_by_tier(teams: Array) -> Array:
	"""Sortiert Teams nach Tier für Heimrecht-Bestimmung"""
	teams.sort_custom(func(a, b):
		var tier_a = _get_team_tier(a)
		var tier_b = _get_team_tier(b)
		return tier_a > tier_b  # Höherer Tier = niedriger klassig
	)
	return teams

func _get_team_tier(team_id: String) -> int:
	"""Bestimmt Tier eines Teams für Heimrecht"""
	if team_id.begins_with("t"):
		var team_num = int(team_id.substr(1))
		if team_num <= 18: return 1  # 1. Liga
		elif team_num <= 36: return 4  # 2. Liga
		else: return 7  # 3. Liga
	elif team_id.begins_with("eu"):
		return 8  # Amateur/EU-Teams
	
	return 5  # Default

func simulate_eu_league_matchday(cup_type: CupType, matchday: int, user_team_id: String = "") -> Dictionary:
	"""Simuliert EU-Pokal Liga-Spieltag (Champions League oder Europa League)"""
	var cup_data = active_cups[cup_type]
	var results = {
		"cup_type": cup_type,
		"matchday": matchday,
		"user_match": null,
		"league_results": []
	}
	
	# Alle Matches dieses Spieltags simulieren
	var matches = cup_data.fixtures.get(matchday, [])
	
	for game_match in matches:
		if not game_match.played:
			# User-Match: Vollständige Simulation
			if user_team_id != "" and (game_match.home_team == user_team_id or game_match.away_team == user_team_id):
				var detailed_result = _simulate_user_eu_match(game_match)
				results.user_match = detailed_result
				# Match-Daten aktualisieren
				game_match.played = true
				game_match.home_goals = detailed_result.home_goals
				game_match.away_goals = detailed_result.away_goals
			else:
				# Andere Matches: Lightning-Simulation
				var result = _simulate_eu_match_lightning(game_match)
				game_match.played = true
				game_match.home_goals = result.home_goals
				game_match.away_goals = result.away_goals
			
			results.league_results.append({
				"home_team": game_match.home_team,
				"away_team": game_match.away_team,
				"home_goals": game_match.home_goals,
				"away_goals": game_match.away_goals
			})
	
	# Liga-Tabelle aktualisieren
	_update_eu_league_table(cup_data, matchday)
	
	# Spieltag voranschreiten
	cup_data.current_matchday += 1
	
	# Liga-Phase beendet?
	if cup_data.current_matchday > cup_data.max_matchdays:
		_finalize_eu_league_stage(cup_type)
	
	return results

func simulate_cup_round(cup_type: CupType, round: int, user_team_id: String = "") -> Dictionary:
	"""Simuliert eine komplette Pokal-Runde mit User-Match Fokus"""
	var matches = active_cups[cup_type].matches.get(round, [])
	var winners = []
	var user_match_result = null
	var other_results = []
	
	var eliminated_teams = []  # Liste der ausgeschiedenen Teams
	
	for match in matches:
		# User-Team Match: Vollständige Event-Simulation
		if user_team_id != "" and (match.home_team == user_team_id or match.away_team == user_team_id):
			var detailed_result = _simulate_user_cup_match(match)
			var winner = detailed_result.winner
			var loser = match.home_team if winner == match.away_team else match.away_team
			
			print("CupManager: User-Match Winner: %s (von %s vs %s, %d:%d)" % [
				winner, match.home_team, match.away_team, 
				detailed_result.home_goals, detailed_result.away_goals
			])
			
			# KRITISCHER BUG-FIX: User-Team nicht zu winners hinzufügen wenn es verliert!
			if loser == user_team_id:
				print("💀💀💀 USER-TEAM VERLIERT und scheidet aus %s aus! 💀💀💀" % _get_cup_name(cup_type))
				print("💀 VERLIERER: %s, GEWINNER: %s" % [loser, winner])
				print("💀 USER-TEAM wird NICHT zu winners hinzugefügt!")
				# Nur Gewinner hinzufügen, User-Team ist raus
				if winner != user_team_id:  # Sicherheitscheck
					winners.append(winner)
			else:
				# Normaler Fall: Gewinner hinzufügen
				winners.append(winner)
			
			eliminated_teams.append(loser)
			user_match_result = detailed_result
			
			print("CupManager: USER MATCH - %s %d:%d %s" % [
				detailed_result.home_team_name, detailed_result.home_goals,
				detailed_result.away_goals, detailed_result.away_team_name
			])
		else:
			# Andere Matches: Schnelle Lightning-Simulation
			var winner = _simulate_cup_match_lightning(match)
			var loser = match.home_team if winner == match.away_team else match.away_team
			
			winners.append(winner)
			eliminated_teams.append(loser)
			other_results.append({
				"match": match,
				"winner": winner
			})
	
	# Statistik speichern
	active_cups[cup_type].winners[round] = winners
	
	# KRITISCH: Verlierer explizit aus teams entfernen (Sicherheitsmaßnahme)
	print("CupManager: %d Verlierer werden entfernt: %s" % [eliminated_teams.size(), str(eliminated_teams)])
	for loser in eliminated_teams:
		remove_team_from_cup(loser, cup_type, "KO-Runde Niederlage")
	
	# KERN 3: Vollständiges Team-Update für alle Phasen
	var team_update = update_cup_teams_for_phase(cup_type, "after_round_%d" % round)
	if team_update.phase_change:
		print("🔄 PHASEN-WECHSEL in %s erkannt!" % _get_cup_name(cup_type))
	
	# Sieger für nächste Runde setzen
	if round < active_cups[cup_type].max_rounds:
		print("CupManager: Runde %d → Runde %d: %d Sieger übernommen" % [round, round + 1, winners.size()])
		print("CupManager: Sieger-Liste: %s" % str(winners))
		
		# KRITISCHES DEBUG: Prüfe ob User-Team weiterkommt
		var user_team_advances = "t01" in winners
		var old_teams = active_cups[cup_type].teams.duplicate()
		var user_was_in_old = "t01" in old_teams
		
		# KRITISCHE SICHERHEIT: Nur echte Gewinner dürfen weiter
		var verified_winners = []
		
		for winner in winners:
			if winner in old_teams:
				verified_winners.append(winner)
			else:
				print("🚨 KRITISCHER FEHLER: Team %s ist kein legitimer Gewinner (war nicht in vorheriger Runde)!" % winner)
				push_error("Illegitimer Gewinner entdeckt: %s" % winner)
		
		active_cups[cup_type].teams = verified_winners
		active_cups[cup_type].current_round = round + 1
		
		# FINALE VERIFIKATION: Alle Verlierer sind wirklich eliminiert
		var losers_still_in_cup = []
		for old_team in old_teams:
			if not (old_team in verified_winners) and (old_team in active_cups[cup_type].teams):
				losers_still_in_cup.append(old_team)
		
		if not losers_still_in_cup.is_empty():
			print("🚨 KRITISCHE WARNUNG: Verlierer sind immer noch im Pokal: %s" % str(losers_still_in_cup))
			# Verlierer gewaltsam entfernen
			for loser in losers_still_in_cup:
				active_cups[cup_type].teams.erase(loser)
				print("🔨 ZWANGSENTFERNUNG: %s aus %s entfernt" % [loser, _get_cup_name(cup_type)])
		
		print("DEBUG: User-Team war in Runde %d: %s" % [round, str(user_was_in_old)])
		print("DEBUG: User-Team kommt in Runde %d: %s" % [round + 1, str(user_team_advances)])
		if user_was_in_old and not user_team_advances:
			print("✅ KORREKT: User-Team ist ausgeschieden!")
		elif not user_was_in_old and user_team_advances:
			print("🚨 BUG: User-Team kommt weiter obwohl es nicht teilgenommen hat!")
		elif user_was_in_old and user_team_advances:
			print("✅ User-Team hat gewonnen und kommt weiter")
		else:
			print("ℹ️ User-Team war nicht dabei und ist nicht dabei")
		
		# REALISTISCHE DFB-POKAL AUSLOSUNG: Nach jeder Runde neu auslosen
		if cup_type == CupType.DFB_POKAL:
			_generate_next_dfb_round(cup_type, round + 1)
			print("DFB-Pokal: Auslosung für Runde %d abgeschlossen (%d Teams)" % [round + 1, winners.size()])
	
	return {
		"winners": winners,
		"user_match": user_match_result,
		"other_matches": other_results,
		"cup_type": cup_type,
		"round": round
	}

func _simulate_user_cup_match(match: Dictionary) -> Dictionary:
	"""Simuliert User-Pokalspiel mit vollständiger Event-Simulation (NUR KO-MODUS)"""
	var home_team = match.home_team
	var away_team = match.away_team
	
	# Vollständige Event-Simulation für User-Match
	var result = MatchEngine.simulate_match_instant(home_team, away_team)
	
	# NUR IM KO-MODUS: Bei Unentschieden Verlängerung und Elfmeterschießen
	# DFB-Pokal ist immer KO-Modus, daher immer Verlängerung bei Unentschieden
	if result.home_goals == result.away_goals:
		result = _simulate_extra_time(home_team, away_team, result)
		
		# Immer noch unentschieden: Elfmeterschießen
		if result.home_goals == result.away_goals:
			result = _simulate_penalty_shootout(home_team, away_team, result)
	
	# Team-Namen für Anzeige
	var home_team_data = GameManager.get_team(home_team)
	var away_team_data = GameManager.get_team(away_team)
	
	# Erweiterte Rückgabe für User-Match
	var match_result = {
		"home_team": home_team,
		"away_team": away_team,
		"home_team_name": home_team_data.get("team_name", home_team),
		"away_team_name": away_team_data.get("team_name", away_team),
		"home_goals": result.home_goals,
		"away_goals": result.away_goals,
		"winner": _determine_winner(home_team, away_team, result.home_goals, result.away_goals),
		"events": result.get("events", []),
		"extra_time": result.get("extra_time", false),
		"penalty_shootout": result.get("penalty_shootout", false),
		"penalty_score": result.get("penalty_score", ""),
		"penalty_events": result.get("penalty_events", []),
		"regular_time_goals": result.get("regular_time_goals", {}),
		"extra_time_goals": result.get("extra_time_goals", {})
	}
	
	# Detaillierte Spielstand-Anzeige für Verlängerung/Elfmeter
	if result.get("extra_time", false):
		print("⏱️ VERLÄNGERUNG: %s %d:%d %s (nach 90 Min: %d:%d)" % [
			match_result.home_team_name, result.home_goals, result.away_goals,
			match_result.away_team_name,
			result.get("regular_time_goals", {}).get("home", 0),
			result.get("regular_time_goals", {}).get("away", 0)
		])
	
	if result.get("penalty_shootout", false):
		print("🥅 ELFMETERSCHIESSEN: %s nach Elfmeter (%s)" % [
			match_result.home_team_name if match_result.winner == home_team else match_result.away_team_name,
			result.get("penalty_score", "")
		])
	
	return match_result

func _simulate_cup_match_lightning(match: Dictionary) -> String:
	"""Simuliert Pokalspiel im Lightning-Modus (NUR KO-MODUS)"""
	var home_team = match.home_team
	var away_team = match.away_team
	
	# Lightning-Simulation (nur Ergebnis, keine Events)
	var result = MatchEngine.simulate_match_lightning(home_team, away_team)
	
	# NUR IM KO-MODUS: Bei Unentschieden Verlängerung und Elfmeterschießen
	# DFB-Pokal ist immer KO-Modus, daher immer Verlängerung bei Unentschieden
	if result.home_goals == result.away_goals:
		result = _simulate_extra_time(home_team, away_team, result)
		
		# Immer noch unentschieden: Elfmeterschießen
		if result.home_goals == result.away_goals:
			result = _simulate_penalty_shootout(home_team, away_team, result)
	
	# Sieger bestimmen
	return _determine_winner(home_team, away_team, result.home_goals, result.away_goals)

func _simulate_extra_time(home_team: String, away_team: String, regular_result: Dictionary) -> Dictionary:
	"""Simuliert Verlängerung (2x15 Min)"""
	var extra_goals_home = 0
	var extra_goals_away = 0
	
	# Vereinfachte Verlängerung: 20% Chance auf Tor pro Team
	if randf() < 0.2:
		extra_goals_home += 1
	if randf() < 0.15:  # Auswärtsteam etwas schwächer
		extra_goals_away += 1
	
	return {
		"home_goals": regular_result.home_goals + extra_goals_home,
		"away_goals": regular_result.away_goals + extra_goals_away,
		"regular_time_goals": {"home": regular_result.home_goals, "away": regular_result.away_goals},
		"extra_time_goals": {"home": extra_goals_home, "away": extra_goals_away},
		"extra_time": true
	}

func _simulate_penalty_shootout(home_team: String, away_team: String, result: Dictionary) -> Dictionary:
	"""Simuliert Elfmeterschießen mit PlayerIDs und Event-System"""
	var home_penalties = 0
	var away_penalties = 0
	var penalty_events = []
	
	# Spieler-Listen für Elfmeterschützen holen
	var home_team_data = GameManager.get_team(home_team)
	var away_team_data = GameManager.get_team(away_team)
	var home_roster = home_team_data.get("player_roster", [])
	var away_roster = away_team_data.get("player_roster", [])
	
	if home_roster.is_empty() or away_roster.is_empty():
		print("FEHLER: Leere Player-Roster für Elfmeterschießen!")
		assert(false, "CRITICAL: Teams müssen gültige Player-Roster haben für Elfmeterschießen")
	
	# 5 Elfmeter pro Team (75% Erfolgsquote)
	var penalty_round = 1
	for i in range(5):
		# Heimteam Elfmeter
		var home_shooter = home_roster[i % home_roster.size()]
		var home_scored = randf() < 0.75
		if home_scored: 
			home_penalties += 1
		
		var home_player_data = GameManager.get_player(home_shooter)
		var home_player_name = "%s %s" % [
			home_player_data.get("first_name", "Unknown"), 
			home_player_data.get("last_name", "Player")
		]
		
		penalty_events.append({
			"player_id": home_shooter,
			"player_name": home_player_name,
			"team_id": home_team,
			"round": penalty_round,
			"minute": 120,  # Elfmeterschießen nach Verlängerung
			"type": "penalty_scored" if home_scored else "penalty_missed"
		})
		
		# Auswärtsteam Elfmeter  
		var away_shooter = away_roster[i % away_roster.size()]
		var away_scored = randf() < 0.75
		if away_scored: 
			away_penalties += 1
			
		var away_player_data = GameManager.get_player(away_shooter)
		var away_player_name = "%s %s" % [
			away_player_data.get("first_name", "Unknown"),
			away_player_data.get("last_name", "Player")
		]
		
		penalty_events.append({
			"player_id": away_shooter,
			"player_name": away_player_name,
			"team_id": away_team,
			"round": penalty_round,
			"minute": 120,  # Elfmeterschießen nach Verlängerung
			"type": "penalty_scored" if away_scored else "penalty_missed"
		})
		
		penalty_round += 1
	
	# Bei Gleichstand: Sudden Death
	var sudden_death_round = 6
	while home_penalties == away_penalties:
		var home_shooter = home_roster[sudden_death_round % home_roster.size()]
		var away_shooter = away_roster[sudden_death_round % away_roster.size()]
		
		var home_scored = randf() < 0.75
		var away_scored = randf() < 0.75
		
		if home_scored: home_penalties += 1
		if away_scored: away_penalties += 1
		
		# Events für Sudden Death hinzufügen
		var home_player_data = GameManager.get_player(home_shooter)
		var away_player_data = GameManager.get_player(away_shooter)
		
		penalty_events.append({
			"player_id": home_shooter,
			"player_name": "%s %s" % [home_player_data.get("first_name", "Unknown"), home_player_data.get("last_name", "Player")],
			"team_id": home_team,
			"round": sudden_death_round,
			"scored": home_scored,
			"type": "penalty_sudden_death"
		})
		
		penalty_events.append({
			"player_id": away_shooter,
			"player_name": "%s %s" % [away_player_data.get("first_name", "Unknown"), away_player_data.get("last_name", "Player")],
			"team_id": away_team,
			"round": sudden_death_round,
			"scored": away_scored,
			"type": "penalty_sudden_death"
		})
		
		sudden_death_round += 1
	
	# Finale Tore: Regulär + Elfmeterschießen-Sieger
	var final_home_goals = result.home_goals
	var final_away_goals = result.away_goals
	
	if home_penalties > away_penalties:
		final_home_goals += 1  # Elfmeter-Sieg zählt als 1 Tor
		print("🥅 ELFMETERSCHIESSEN: %s gewinnt %d:%d" % [home_team, home_penalties, away_penalties])
	else:
		final_away_goals += 1
		print("🥅 ELFMETERSCHIESSEN: %s gewinnt %d:%d" % [away_team, away_penalties, home_penalties])
	
	# Elfmeter-Events ausgeben
	print("⚽ ELFMETER ZUSAMMENFASSUNG:")
	for event in penalty_events:
		var result_text = "⚽ TOR" if event.scored else "❌ VERSCHOSSEN"
		print("  Runde %d: %s (%s) - %s" % [event.round, event.player_name, event.team_id, result_text])
	
	return {
		"home_goals": final_home_goals,
		"away_goals": final_away_goals,
		"penalty_shootout": true,
		"penalty_score": "%d:%d" % [home_penalties, away_penalties],
		"penalty_events": penalty_events
	}

func get_cup_status(cup_type: CupType) -> Dictionary:
	"""Gibt aktuellen Pokal-Status zurück"""
	var cup_data = active_cups[cup_type]
	
	# EU-Pokale (Liga-Phase)
	if cup_type == CupType.CHAMPIONS_LEAGUE or cup_type == CupType.EUROPA_LEAGUE:
		return {
			"name": cup_data.name,
			"current_matchday": cup_data.current_matchday,
			"max_matchdays": cup_data.max_matchdays,
			"teams_count": cup_data.teams.size(),
			"phase": cup_data.phase,
			"is_league_stage": cup_data.phase == "league_stage"
		}
	# DFB-Pokal (KO-Runden)
	else:
		return {
			"name": cup_data.name,
			"current_round": cup_data.current_round,
			"max_rounds": cup_data.max_rounds,
			"teams_remaining": cup_data.teams.size(),
			"is_finished": cup_data.current_round > cup_data.max_rounds
		}

func get_cup_winner(cup_type: CupType) -> String:
	"""Gibt Pokal-Sieger zurück (wenn Turnier beendet)"""
	var cup_data = active_cups[cup_type]
	if cup_data.current_round > cup_data.max_rounds and cup_data.teams.size() == 1:
		return cup_data.teams[0]
	return ""

func _simulate_user_eu_match(game_match: Dictionary) -> Dictionary:
	"""Simuliert User-EU-Match OHNE Verlängerung (Liga-Phase wie normale Liga)"""
	var home_team = game_match.home_team
	var away_team = game_match.away_team
	
	print("CupManager: _simulate_user_eu_match aufgerufen für %s vs %s (LIGA-PHASE)" % [home_team, away_team])
	
	# WICHTIG: Liga-Phase wie normale Liga-Spiele (OHNE Verlängerung/Elfmeter)
	var result = MatchEngine.simulate_match_instant(home_team, away_team)
	
	# KEIN Extra-Time oder Penalty für Liga-Phase!
	
	# Team-Namen für Anzeige
	var home_team_data = GameManager.get_team(home_team)
	var away_team_data = GameManager.get_team(away_team)
	
	var final_result = {
		"home_team": home_team,
		"away_team": away_team,
		"home_team_name": home_team_data.get("team_name", home_team),
		"away_team_name": away_team_data.get("team_name", away_team),
		"home_goals": result.home_goals,
		"away_goals": result.away_goals,
		"events": result.get("events", [])
		# EXPLIZIT KEINE extra_time/penalty_shootout Flags für Liga-Phase!
	}
	
	print("CupManager: Liga-Phase Ergebnis - %s %d:%d %s (OHNE Verlängerung)" % [
		home_team, result.home_goals, result.away_goals, away_team
	])
	
	return final_result

func _simulate_eu_match_lightning(game_match: Dictionary) -> Dictionary:
	"""Simuliert EU-Match im Lightning-Modus"""
	var home_team = game_match.home_team
	var away_team = game_match.away_team
	
	# Lightning-Simulation
	var result = MatchEngine.simulate_match_lightning(home_team, away_team)
	
	return {
		"home_goals": result.home_goals,
		"away_goals": result.away_goals
	}

func _update_eu_league_table(cup_data: Dictionary, matchday: int):
	"""Aktualisiert EU-Liga-Tabelle"""
	var matches = cup_data.fixtures.get(matchday, [])
	var table = cup_data.league_table
	
	# Alle Matches verarbeiten
	for game_match in matches:
		if game_match.played:
			_update_eu_team_stats(table, game_match)
	
	# Tabelle sortieren
	table.sort_custom(func(a, b): 
		if a.points != b.points: return a.points > b.points
		return a.goal_difference > b.goal_difference
	)
	
	# Positionen aktualisieren
	for i in range(table.size()):
		table[i].position = i + 1

func _update_eu_team_stats(table: Array, game_match: Dictionary):
	"""Aktualisiert Team-Statistiken in EU-Liga-Tabelle"""
	var home_team = game_match.home_team
	var away_team = game_match.away_team
	var home_goals = game_match.home_goals
	var away_goals = game_match.away_goals
	
	for team_entry in table:
		if team_entry.team_id == home_team:
			team_entry.matches += 1
			team_entry.goals_for += home_goals
			team_entry.goals_against += away_goals
			team_entry.goal_difference = team_entry.goals_for - team_entry.goals_against
			
			if home_goals > away_goals:
				team_entry.wins += 1
				team_entry.points += 3
			elif home_goals == away_goals:
				team_entry.draws += 1
				team_entry.points += 1
			else:
				team_entry.losses += 1
		
		elif team_entry.team_id == away_team:
			team_entry.matches += 1
			team_entry.goals_for += away_goals
			team_entry.goals_against += home_goals
			team_entry.goal_difference = team_entry.goals_for - team_entry.goals_against
			
			if away_goals > home_goals:
				team_entry.wins += 1
				team_entry.points += 3
			elif away_goals == home_goals:
				team_entry.draws += 1
				team_entry.points += 1
			else:
				team_entry.losses += 1

func _finalize_eu_league_stage(cup_type: CupType):
	"""Beendet EU-Liga-Phase und qualifiziert Teams für KO-Phase"""
	var cup_data = active_cups[cup_type]
	var table = cup_data.league_table
	
	# Qualifikation
	var direct_qualified = []  # Plätze 1-8
	var playoff_teams = []     # Plätze 9-24
	var eliminated = []        # Plätze 25-36
	
	for i in range(table.size()):
		var team = table[i]
		if team.position <= 8:
			direct_qualified.append(team.team_id)
		elif team.position >= 9 and team.position <= 24:
			playoff_teams.append(team.team_id)
		else:
			eliminated.append(team.team_id)
	
	cup_data.qualified_teams = direct_qualified
	cup_data.playoff_teams = playoff_teams
	cup_data.phase = "playoff_round"
	
	print("%s Liga-Phase beendet!" % cup_data.name)
	print("  → Direkt qualifiziert: %d Teams" % direct_qualified.size())
	print("  → Play-off Teams: %d Teams" % playoff_teams.size())
	print("  → Ausgeschieden: %d Teams" % eliminated.size())
	
	# KO-Phase Fixtures generieren
	_setup_knockout_phase(cup_type)

func _setup_knockout_phase(cup_type: CupType):
	"""Generiert KO-Phase Auslosung nach Liga-Phase"""
	var cup_data = active_cups[cup_type]
	var direct_qualified = cup_data.qualified_teams
	var playoff_teams = cup_data.playoff_teams
	
	# Play-off Runde: 16 Teams kämpfen um 8 Plätze
	var playoff_fixtures = _draw_playoff_matches(playoff_teams)
	cup_data["playoff_fixtures"] = playoff_fixtures
	
	print("%s KO-Phase Setup:" % cup_data.name)
	print("  → Play-offs: %d Paarungen generiert" % playoff_fixtures.size())
	print("  → Achtelfinale: 8 direkt + 8 aus Play-offs = 16 Teams")

func _draw_playoff_matches(teams: Array) -> Array:
	"""Auslosung der Play-off Paarungen (Plätze 9-24)"""
	var fixtures = []
	
	# Teams shuffeln für faire Auslosung
	var shuffled_teams = teams.duplicate()
	shuffled_teams.shuffle()
	
	# 8 Paarungen bilden (16 Teams)
	for i in range(0, shuffled_teams.size(), 2):
		if i + 1 < shuffled_teams.size():
			fixtures.append({
				"home_team": shuffled_teams[i],
				"away_team": shuffled_teams[i + 1],
				"leg": 1,  # Hinspiel
				"played": false,
				"home_goals": 0,
				"away_goals": 0,
				"return_leg": {
					"home_team": shuffled_teams[i + 1],
					"away_team": shuffled_teams[i],
					"leg": 2,  # Rückspiel
					"played": false,
					"home_goals": 0,
					"away_goals": 0
				}
			})
	
	return fixtures

func simulate_eu_playoff_round(cup_type: CupType, user_team_id: String = "") -> Dictionary:
	"""Simuliert EU-Pokal Play-off Runde (Hin- und Rückspiel)"""
	var cup_data = active_cups[cup_type]
	var playoff_fixtures = cup_data.get("playoff_fixtures", [])
	var results = {
		"cup_type": cup_type,
		"playoff_winners": [],
		"user_match": null,
		"playoff_results": []
	}
	
	# Alle Play-off Paarungen simulieren
	for fixture in playoff_fixtures:
		var playoff_result = _simulate_two_leg_playoff(fixture, user_team_id)
		results.playoff_results.append(playoff_result)
		results.playoff_winners.append(playoff_result.winner)
		
		# User-Match speichern
		if playoff_result.user_involved:
			results.user_match = playoff_result
	
	# Achtelfinale Setup: 8 direkte + 8 Play-off Sieger
	var achtelfinale_teams = []
	achtelfinale_teams.append_array(cup_data.qualified_teams)  # Direkt qualifiziert
	achtelfinale_teams.append_array(results.playoff_winners)   # Play-off Sieger
	
	cup_data.qualified_teams = achtelfinale_teams
	cup_data.phase = "round_of_16"
	
	print("%s Play-offs beendet - %d Teams im Achtelfinale" % [cup_data.name, achtelfinale_teams.size()])
	
	return results

func _simulate_two_leg_playoff(fixture: Dictionary, user_team_id: String) -> Dictionary:
	"""Simuliert Hin- und Rückspiel für Play-offs"""
	var team1 = fixture.home_team
	var team2 = fixture.away_team
	var user_involved = (user_team_id == team1 or user_team_id == team2)
	
	# HINSPIEL
	var first_leg = null
	if user_involved:
		first_leg = MatchEngine.simulate_match_instant(team1, team2)
	else:
		first_leg = MatchEngine.simulate_match_lightning(team1, team2)
	
	# RÜCKSPIEL
	var second_leg = null
	if user_involved:
		second_leg = MatchEngine.simulate_match_instant(team2, team1)
	else:
		second_leg = MatchEngine.simulate_match_lightning(team2, team1)
	
	# Gesamtergebnis berechnen
	var team1_total = first_leg.home_goals + second_leg.away_goals
	var team2_total = first_leg.away_goals + second_leg.home_goals
	
	var winner = ""
	if team1_total > team2_total:
		winner = team1
	elif team2_total > team1_total:
		winner = team2
	else:
		# MODERNE UEFA-REGELN 2025/2026: Keine Auswärtstorregel mehr
		# Bei Gleichstand → Verlängerung + Elfmeterschießen im Rückspiel
		var extra_time_result = _simulate_extra_time_and_penalties(second_leg)
		
		if extra_time_result.has_winner:
			winner = extra_time_result.winner
			# Verlängerungs-Tore zum Rückspiel hinzufügen
			second_leg.home_goals += extra_time_result.extra_home_goals
			second_leg.away_goals += extra_time_result.extra_away_goals
			second_leg.extra_time = extra_time_result
		else:
			# Fallback (sollte nicht passieren)
			winner = team1 if randf() < 0.5 else team2
	
	# Team-Namen für Anzeige
	var team1_data = GameManager.get_team(team1)
	var team2_data = GameManager.get_team(team2)
	
	return {
		"team1": team1,
		"team2": team2,
		"team1_name": team1_data.get("team_name", team1),
		"team2_name": team2_data.get("team_name", team2),
		"first_leg": first_leg,
		"second_leg": second_leg,
		"team1_total": team1_total,
		"team2_total": team2_total,
		"winner": winner,
		"user_involved": user_involved
	}

func _simulate_extra_time_and_penalties(match_result: Dictionary) -> Dictionary:
	"""MODERNE UEFA-REGELN: Verlängerung + Elfmeterschießen bei Gleichstand"""
	var home_team = match_result.home_team
	var away_team = match_result.away_team
	
	# VERLÄNGERUNG (2x 15 Min)
	var extra_home_goals = 0
	var extra_away_goals = 0
	
	# Vereinfachte Verlängerungs-Simulation (je 15% Chance pro Team pro Halbzeit)
	for half in range(2):  # 2 Halbzeiten á 15 Min
		if randf() < 0.15:  # 15% Chance auf Tor für Heimteam
			extra_home_goals += 1
		if randf() < 0.15:  # 15% Chance auf Tor für Auswärtsteam  
			extra_away_goals += 1
	
	if extra_home_goals != extra_away_goals:
		# Verlängerung entscheidet
		var winner = home_team if extra_home_goals > extra_away_goals else away_team
		return {
			"has_winner": true,
			"winner": winner,
			"extra_home_goals": extra_home_goals,
			"extra_away_goals": extra_away_goals,
			"decided_by": "extra_time"
		}
	
	# ELFMETERSCHIEESSEN - nutze bestehende Funktion
	var penalty_result = {
		"home_goals": extra_home_goals,
		"away_goals": extra_away_goals
	}
	var penalty_final = _simulate_penalty_shootout(home_team, away_team, penalty_result)
	
	return {
		"has_winner": true,
		"winner": penalty_final.winner,
		"extra_home_goals": extra_home_goals,
		"extra_away_goals": extra_away_goals,
		"penalty_result": penalty_final,
		"decided_by": "penalties"
	}

func simulate_eu_ko_round(cup_type: CupType, round_name: String, user_team_id: String = "") -> Dictionary:
	"""Universelle Funktion für alle EU-Pokal KO-Runden mit Hin/Rückspiel"""
	var cup_data = active_cups[cup_type]
	var qualified_teams = cup_data.get("qualified_teams", [])
	
	var fixtures = _draw_knockout_matches(qualified_teams)
	var ko_results = []
	var ko_winners = []
	var user_match = null
	
	# Alle KO-Paarungen simulieren (Hin + Rück)
	for fixture in fixtures:
		var ko_result = _simulate_two_leg_playoff(fixture, user_team_id)
		ko_results.append(ko_result)
		ko_winners.append(ko_result.winner)
		
		if ko_result.user_involved:
			user_match = ko_result
	
	# Sieger für nächste Runde qualifizieren
	cup_data.qualified_teams = ko_winners
	cup_data.current_round += 1
	
	print("%s %s beendet - %d Teams weiter" % [cup_data.name, round_name, ko_winners.size()])
	
	return {
		"cup_type": cup_type,
		"round_name": round_name,
		"ko_winners": ko_winners,
		"user_match": user_match,
		"ko_results": ko_results
	}

func _draw_knockout_matches(teams: Array) -> Array:
	"""Auslosung für KO-Runden (Hin/Rück-Paarungen)"""
	var fixtures = []
	var shuffled_teams = teams.duplicate()
	shuffled_teams.shuffle()
	
	# Paarungen bilden
	for i in range(0, shuffled_teams.size(), 2):
		if i + 1 < shuffled_teams.size():
			fixtures.append({
				"home_team": shuffled_teams[i],
				"away_team": shuffled_teams[i + 1]
			})
	
	return fixtures

func _generate_next_dfb_round(cup_type: CupType, next_round: int):
	"""Generiert realistische Neuauslosung für DFB-Pokal nach jeder Runde"""
	var cup_data = active_cups[cup_type]
	var remaining_teams = cup_data.teams.duplicate()
	
	# Realistische DFB-Pokal Regeln:
	# - Heimrecht für unterklassige Teams
	# - Zufällige Auslosung ohne Setzliste
	
	print("DFB-Pokal Runde %d: Auslosung von %d Teams..." % [next_round, remaining_teams.size()])
	
	# ECHTE ZUFÄLLIGE AUSLOSUNG!
	# Wichtig: Neue Seed für Zufallsgenerator setzen
	RandomNumberGenerator.new().randomize()
	remaining_teams.shuffle()
	
	# Neue Paarungen für nächste Runde generieren
	var new_matches = []
	for i in range(0, remaining_teams.size(), 2):
		if i + 1 < remaining_teams.size():
			var team_a = remaining_teams[i]
			var team_b = remaining_teams[i + 1]
			
			# Heimrecht für unterklassigen Team
			var tier_a = _get_team_tier(team_a)
			var tier_b = _get_team_tier(team_b)
			
			var home_team = team_a
			var away_team = team_b
			
			# Höherer Tier = unterklassiger → bekommt Heimrecht
			if tier_b > tier_a:
				home_team = team_b
				away_team = team_a
			
			new_matches.append({
				"home_team": home_team,
				"away_team": away_team,
				"round": next_round,
				"cup_type": cup_type
			})
			
			var home_name = GameManager.get_team(home_team).get("team_name", home_team)
			var away_name = GameManager.get_team(away_team).get("team_name", away_team)
			
			# Markiere User-Team Paarung
			if home_team == "t01" or away_team == "t01":
				print("  >>> USER-PAARUNG: %s - %s <<<" % [home_name, away_name])
			else:
				print("  Paarung: %s - %s" % [home_name, away_name])
	
	# Neue Matches speichern
	cup_data.matches[next_round] = new_matches
	print("DFB-Pokal: %d Paarungen für Runde %d ausgelost" % [new_matches.size(), next_round])

func is_team_in_cup(team_id: String, cup_type: CupType) -> bool:
	"""Prüft ob Team noch im Pokal ist"""
	var cup_data = active_cups[cup_type]
	var is_in_cup = cup_data.teams.has(team_id)
	
	# ZUSÄTZLICHE SICHERHEIT: Prüfe auch eliminated_teams (für DFB-Pokal)
	if cup_type == CupType.DFB_POKAL and cup_data.has("eliminated_teams"):
		if team_id in cup_data.eliminated_teams:
			is_in_cup = false  # Eliminiert = nicht mehr im Pokal
			if team_id == "t01":
				print("🚨 User-Team t01 wurde bereits eliminiert (Runde %d) - BLOCKIERE!" % cup_data.eliminated_teams[team_id])
	
	# DEBUG: User-Team Status loggen
	if team_id == "t01":
		print("DEBUG: is_team_in_cup(%s, %s) = %s (Runde %d)" % [
			team_id, _get_cup_name(cup_type), str(is_in_cup), 
			active_cups[cup_type].get("current_round", 0)
		])
		print("DEBUG: Teams in cup: %d, eliminated_teams: %d" % [
			cup_data.teams.size(), 
			cup_data.get("eliminated_teams", {}).size()
		])
		print("DEBUG: t01 in teams: %s, t01 in eliminated: %s" % [
			str("t01" in cup_data.teams), 
			str("t01" in cup_data.get("eliminated_teams", {}))
		])
	
	return is_in_cup

func _update_cup_after_matchday_simulation(cup_type: CupType, round: int, winners: Array):
	"""KRITISCHE BRÜCKE: Führt CupManager-Elimination basierend auf MatchdayEngine-Ergebnissen durch"""
	print("🔄 CupManager: _update_cup_after_matchday_simulation - %s Runde %d" % [_get_cup_name(cup_type), round])
	
	var cup_data = active_cups[cup_type]
	var old_teams = cup_data.teams.duplicate()
	
	# Eliminierte Teams ermitteln (alle die nicht gewonnen haben)
	var eliminated_teams = []
	for team_id in old_teams:
		if not (team_id in winners):
			eliminated_teams.append(team_id)
	
	print("CupManager: %d Teams eliminiert: %s" % [eliminated_teams.size(), str(eliminated_teams)])
	
	# Eliminierte Teams entfernen (mit persistent tracking)
	for loser in eliminated_teams:
		remove_team_from_cup(loser, cup_type, "MatchdayEngine-Elimination Runde %d" % round)
	
	# Gewinner für nächste Runde setzen
	cup_data.teams = winners
	cup_data.current_round = round + 1
	
	# Debug für User-Team
	var user_eliminated = "t01" in eliminated_teams
	var user_advances = "t01" in winners
	if user_eliminated:
		print("💀💀💀 USER-TEAM ELIMINIERT durch MatchdayEngine! 💀💀💀")
	elif user_advances:
		print("✅ User-Team kommt weiter in Runde %d" % (round + 1))
	
	# Nächste Runde generieren (für DFB-Pokal)
	if cup_type == CupType.DFB_POKAL and round < cup_data.max_rounds:
		_generate_next_dfb_round(cup_type, round + 1)
		print("DFB-Pokal: Auslosung für Runde %d abgeschlossen (%d Teams)" % [round + 1, winners.size()])

func force_eliminate_team(team_id: String, cup_type: CupType, reason: String = ""):
	"""NOTFALL-FUNKTION: Entfernt Team gewaltsam aus Pokal (für kritische Bugs)"""
	var cup_data = active_cups[cup_type]
	var teams_before = cup_data.teams.size()
	
	if team_id in cup_data.teams:
		cup_data.teams.erase(team_id)
		
		# PERSISTENT: Team zu eliminated_teams hinzufügen (für DFB-Pokal)
		if cup_type == CupType.DFB_POKAL:
			var current_round = cup_data.get("current_round", 1)
			cup_data.eliminated_teams[team_id] = current_round
			print("🔒 PERSISTENT FORCE-ELIMINATION: %s in Runde %d eliminiert" % [team_id, current_round])
		
		print("🚨 GEWALTSAME ELIMINATION: %s aus %s entfernt (%s)" % [team_id, _get_cup_name(cup_type), reason])
		print("🔥 Teams: %d → %d (-%d)" % [teams_before, cup_data.teams.size(), 1])
		
		if team_id == "t01":
			print("💀💀💀 USER-TEAM ZWANGSELIMINIERT aus %s! 💀💀💀" % _get_cup_name(cup_type))
			print("💀 USER-TEAM sollte NIEMALS mehr in diesem Pokal erscheinen!")
		
		return true
	else:
		print("⚠️ Team %s war bereits nicht in %s" % [team_id, _get_cup_name(cup_type)])
		return false

func remove_team_from_cup(team_id: String, cup_type: CupType, reason: String = ""):
	"""SICHERHEITSFUNKTION: Entfernt Team explizit aus Pokal (bei Niederlage)"""
	if not active_cups.has(cup_type):
		return
		
	var teams_list = active_cups[cup_type].teams
	if team_id in teams_list:
		teams_list.erase(team_id)
		
		# PERSISTENT: Team zu eliminated_teams hinzufügen (für DFB-Pokal)
		if cup_type == CupType.DFB_POKAL:
			var cup_data = active_cups[cup_type]
			var current_round = cup_data.get("current_round", 1)
			cup_data.eliminated_teams[team_id] = current_round
			print("🔒 PERSISTENT ELIMINATION: %s in Runde %d eliminiert" % [team_id, current_round])
		
		print("🚨 TEAM AUSGESCHIEDEN: %s aus %s entfernt (%s)" % [team_id, _get_cup_name(cup_type), reason])
		
		# Spezielle Warnung für User-Team
		if team_id == "t01":
			print("💀 USER-TEAM AUSGESCHIEDEN aus %s!" % _get_cup_name(cup_type))
	else:
		print("DEBUG: Team %s war bereits nicht in %s" % [team_id, _get_cup_name(cup_type)])

func _get_cup_name(cup_type) -> String:
	"""Gibt lesbaren Namen für Pokal-Typ zurück"""
	if typeof(cup_type) == TYPE_STRING:
		match cup_type:
			"EU_CHAMPIONS": return "Champions League"
			"EU_EUROPA": return "Europa League" 
			"EU_CONFERENCE": return "Conference League"
			_: return "DFB-Pokal"
	else:
		match cup_type:
			CupType.DFB_POKAL: return "DFB-Pokal"
			CupType.CHAMPIONS_LEAGUE: return "Champions League"
			CupType.EUROPA_LEAGUE: return "Europa League"
			CupType.CONFERENCE_LEAGUE: return "Conference League"
			_: return "Unbekannter Pokal"

func get_dfb_pokal_draw(round: int) -> Array:
	"""Gibt DFB-Pokal Auslosung für bestimmte Runde zurück"""
	var cup_data = active_cups[CupType.DFB_POKAL]
	return cup_data.matches.get(round, [])

func get_current_dfb_round() -> int:
	"""Gibt aktuelle DFB-Pokal Runde zurück"""
	return active_cups[CupType.DFB_POKAL].current_round

func get_current_round_matches(cup_type: CupType) -> Array:
	"""KERN 5: Gibt Matches für aktuelle Runde eines bestimmten Pokals zurück - NUR für aktive Teams"""
	var cup_data = active_cups.get(cup_type, {})
	if cup_data.is_empty():
		return []
	
	# KERN 3: Proaktive Team-Updates vor Match-Abruf
	# (Nur gelegentlich ausführen für Performance)
	if randf() < 0.15:  # 15% Chance - nicht bei jedem Aufruf
		var team_update = update_cup_teams_for_phase(cup_type, "match_retrieval")
		if team_update.eliminated.size() > 0:
			print("🧹 PROAKTIV: %d Teams aus %s bereinigt" % [team_update.eliminated.size(), _get_cup_name(cup_type)])
	
	var all_matches = []
	
	# DFB-Pokal: KO-Runden (ausgeloste Matches zurückgeben)
	if cup_type == CupType.DFB_POKAL:
		var current_round = cup_data.get("current_round", 1)
		if current_round <= cup_data.get("max_rounds", 6):
			# WICHTIG: Bereits ausgeloste Matches zurückgeben, nicht neu generieren
			if cup_data.has("matches") and cup_data.matches.has(current_round):
				all_matches = cup_data.matches[current_round]
			else:
				# Falls noch nicht ausgelost, jetzt auslosen
				all_matches = generate_cup_matches(cup_type, current_round)
	
	# EU-Pokale: Liga-Phase (Swiss System Matches zurückgeben)
	elif cup_type in [CupType.CHAMPIONS_LEAGUE, CupType.EUROPA_LEAGUE, CupType.CONFERENCE_LEAGUE]:
		# LÖSUNG: Matchday basierend auf aktueller Woche berechnen
		var current_matchday = _calculate_current_eu_matchday_from_week()
		var max_matchdays = cup_data.get("max_matchdays", 8)
		if current_matchday > 0 and current_matchday <= max_matchdays:
			print("EU-POKALE: Woche %d → Matchday %d für %s" % [GameManager.get_week(), current_matchday, cup_data.name])
			# Liga-Phase Matches abrufen (generiert Swiss System beim ersten Aufruf)
			all_matches = _generate_league_phase_matches(cup_type, current_matchday)
		else:
			print("EU-POKALE: Keine aktive Woche für %s (Woche %d → Matchday %d)" % [cup_data.name, GameManager.get_week(), current_matchday])
			return []
	
	# KRITISCHER FIX: Matches filtern - nur aktive Teams dürfen spielen
	var filtered_matches = _filter_matches_for_active_teams(all_matches, cup_type)
	
	return filtered_matches

func _filter_matches_for_active_teams(matches: Array, cup_type: CupType) -> Array:
	"""KRITISCHE FUNKTION: Filtert Matches - nur aktive Teams dürfen spielen"""
	var active_teams = active_cups[cup_type].teams
	var filtered_matches = []
	var removed_count = 0
	
	for match in matches:
		var home_team = match.get("home_team", "")
		var away_team = match.get("away_team", "")
		
		# Prüfen ob beide Teams noch im Pokal sind
		var home_active = home_team in active_teams
		var away_active = away_team in active_teams
		
		if home_active and away_active:
			# Match ist gültig - beide Teams sind aktiv
			filtered_matches.append(match)
		else:
			# Match entfernt - mindestens ein Team ist ausgeschieden
			removed_count += 1
			var reason = ""
			if not home_active and not away_active:
				reason = "beide Teams ausgeschieden"
			elif not home_active:
				reason = "%s ausgeschieden" % home_team
			else:
				reason = "%s ausgeschieden" % away_team
			
			print("🚫 MATCH ENTFERNT: %s vs %s (%s) aus %s" % [
				home_team, away_team, reason, _get_cup_name(cup_type)
			])
			
			# Spezielle Warnung für User-Team
			if home_team == "t01" or away_team == "t01":
				print("💀 USER-TEAM MATCH ENTFERNT: %s ist ausgeschieden!" % ("t01" if ("t01" == home_team and not home_active) else "t01"))
	
	if removed_count > 0:
		print("✅ MATCH FILTERUNG: %d von %d Matches entfernt (%d verbleibend) für %s" % [
			removed_count, matches.size(), filtered_matches.size(), _get_cup_name(cup_type)
		])
	
	return filtered_matches

func update_cup_teams_for_phase(cup_type: CupType, phase: String = "") -> Dictionary:
	"""KERN 3: Vollständiges Team-Management für alle Pokal-Phasen"""
	var cup_data = active_cups[cup_type]
	var result = {
		"teams_before": cup_data.teams.duplicate(),
		"teams_after": [],
		"eliminated": [],
		"qualified": [],
		"phase_change": false
	}
	
	print("=== POKAL PHASE UPDATE: %s (%s) ===" % [_get_cup_name(cup_type), phase])
	
	match cup_type:
		CupType.CHAMPIONS_LEAGUE, CupType.EUROPA_LEAGUE, CupType.CONFERENCE_LEAGUE:
			result = _update_eu_cup_teams(cup_type, phase)
		CupType.DFB_POKAL:
			result = _update_dfb_pokal_teams(cup_type, phase)
	
	# Teams-Liste aktualisieren
	cup_data.teams = result.teams_after
	
	# User-Team Status prüfen
	var user_eliminated = "t01" in result.eliminated
	var user_qualified = "t01" in result.qualified
	
	if user_eliminated:
		print("💀💀💀 USER-TEAM AUSGESCHIEDEN aus %s! 💀💀💀" % _get_cup_name(cup_type))
	elif user_qualified:
		print("✅ USER-TEAM qualifiziert für nächste Phase in %s!" % _get_cup_name(cup_type))
	
	print("ERGEBNIS: %d → %d Teams (-%d eliminiert, +%d qualifiziert)" % [
		result.teams_before.size(), result.teams_after.size(), 
		result.eliminated.size(), result.qualified.size()
	])
	
	return result

func _update_eu_cup_teams(cup_type: CupType, phase: String) -> Dictionary:
	"""EU-Pokal Team-Management für alle Phasen: Liga→Playoffs→KO"""
	var cup_data = active_cups[cup_type]
	var current_phase = cup_data.get("phase", "league")
	var current_matchday = _calculate_current_eu_matchday_from_week()
	
	var result = {
		"teams_before": cup_data.teams.duplicate(),
		"teams_after": [],
		"eliminated": [],
		"qualified": [],
		"phase_change": false
	}
	
	match current_phase:
		"league", "league_stage":
			# Liga-Phase: Nach Spieltag 8 qualifizieren
			if current_matchday > 8:
				result = _finalize_eu_league_phase(cup_type)
				result.phase_change = true
			else:
				# Noch in Liga-Phase - alle Teams aktiv
				result.teams_after = result.teams_before.duplicate()
		
		"playoff":
			# Playoff-Phase: Verlierer eliminieren nach KO-Matches
			result = _update_eu_playoff_teams(cup_type)
		
		"knockout":
			# KO-Phase: Verlierer eliminieren nach jeder Runde
			result = _update_eu_knockout_teams(cup_type)
		
		_:
			print("WARNUNG: Unbekannte EU-Pokal Phase: %s" % current_phase)
			result.teams_after = result.teams_before.duplicate()
	
	return result

func _finalize_eu_league_phase(cup_type: CupType) -> Dictionary:
	"""Beendet Liga-Phase und qualifiziert Teams basierend auf Tabelle"""
	print("🏁 LIGA-PHASE ABGESCHLOSSEN: Qualifikation für %s" % _get_cup_name(cup_type))
	
	var cup_data = active_cups[cup_type]
	var league_table = _calculate_eu_league_table(cup_type)
	
	var direct_qualified = []    # Plätze 1-8: Direkt ins Achtelfinale
	var playoff_teams = []       # Plätze 9-24: Playoffs
	var eliminated = []          # Plätze 25-36: Ausgeschieden
	
	# Qualifikation nach Tabellen-Position
	for i in range(league_table.size()):
		var team_entry = league_table[i]
		var team_id = team_entry.team_id
		var position = i + 1
		
		if position <= 8:
			direct_qualified.append(team_id)
			print("🏆 Platz %d: %s → ACHTELFINALE" % [position, team_id])
		elif position <= 24:
			playoff_teams.append(team_id)  
			print("⚔️ Platz %d: %s → PLAYOFFS" % [position, team_id])
		else:
			eliminated.append(team_id)
			print("💀 Platz %d: %s → AUSGESCHIEDEN" % [position, team_id])
	
	# Phase auf Playoffs setzen
	cup_data.phase = "playoff"
	cup_data.qualified_teams = direct_qualified
	cup_data.playoff_teams = playoff_teams
	
	return {
		"teams_before": cup_data.teams.duplicate(),
		"teams_after": playoff_teams + direct_qualified,  # Nur qualifizierte Teams bleiben
		"eliminated": eliminated,
		"qualified": direct_qualified,
		"phase_change": true
	}

func _calculate_eu_league_table(cup_type: CupType) -> Array:
	"""Berechnet Liga-Phase Tabelle basierend auf allen Spieltagen"""
	# TODO: Implementierung der Swiss System Tabellen-Berechnung
	# Für jetzt: Dummy-Implementation mit zufälliger Reihenfolge
	var cup_data = active_cups[cup_type]
	var teams = cup_data.teams.duplicate()
	teams.shuffle()  # Temporär: Zufällige Reihenfolge
	
	var table = []
	for i in range(teams.size()):
		table.append({
			"team_id": teams[i],
			"position": i + 1,
			"points": randi_range(15, 24),  # Dummy-Punkte
			"goal_difference": randi_range(-10, 15)
		})
	
	return table

func _update_dfb_pokal_teams(cup_type: CupType, phase: String) -> Dictionary:
	"""DFB-Pokal: Nur KO-Runden - Verlierer sind sofort raus"""
	var cup_data = active_cups[cup_type]
	
	# DFB-Pokal: Teams werden bereits in simulate_cup_round() korrekt gesetzt
	# Hier nur Konsistenz-Check
	return {
		"teams_before": cup_data.teams.duplicate(),
		"teams_after": cup_data.teams.duplicate(),
		"eliminated": [],
		"qualified": [],
		"phase_change": false
	}

func _update_eu_playoff_teams(cup_type: CupType) -> Dictionary:
	"""EU-Pokal Playoff-Phase: Verlierer eliminieren"""
	var cup_data = active_cups[cup_type]
	var playoff_teams = cup_data.get("playoff_teams", [])
	
	# Nach Playoff-Matches: Nur Gewinner bleiben
	var winners = cup_data.get("playoff_winners", [])
	var direct_qualified = cup_data.get("qualified_teams", [])
	var eliminated = []
	
	# Alle Playoff-Teams die nicht gewonnen haben sind eliminiert
	for team in playoff_teams:
		if not (team in winners):
			eliminated.append(team)
	
	# Alle qualifizierten Teams (direkt + Playoff-Sieger) für KO-Phase
	var all_qualified = direct_qualified + winners
	
	# Phase auf KO-Runden setzen wenn Playoffs abgeschlossen
	if not winners.is_empty():
		cup_data.phase = "knockout"
		cup_data.knockout_teams = all_qualified
	
	return {
		"teams_before": playoff_teams.duplicate(),
		"teams_after": all_qualified,
		"eliminated": eliminated,
		"qualified": winners,
		"phase_change": true
	}

func _update_eu_knockout_teams(cup_type: CupType) -> Dictionary:
	"""EU-Pokal KO-Phase: Verlierer nach jeder Runde eliminieren"""
	var cup_data = active_cups[cup_type]
	var current_round = cup_data.get("current_round", 1)
	var winners = cup_data.get("winners", {}).get(current_round, [])
	
	var teams_before = cup_data.teams.duplicate()
	var eliminated = []
	
	# Alle Teams die nicht gewonnen haben sind eliminiert
	for team in teams_before:
		if not (team in winners):
			eliminated.append(team)
	
	return {
		"teams_before": teams_before,
		"teams_after": winners,
		"eliminated": eliminated, 
		"qualified": winners,
		"phase_change": false
	}

func _is_team_really_active(team_id: String, cup_type: CupType) -> bool:
	"""Prüft ob Team wirklich noch aktiv im Pokal ist (erweiterte Logik)"""
	var cup_data = active_cups[cup_type]
	
	# Basis-Check: Ist Team in teams-Liste?
	if not (team_id in cup_data.teams):
		return false
	
	# Zusätzliche Checks können hier implementiert werden
	# z.B. für EU-Pokale: Liga-Phase Tabellen-Position prüfen
	
	return true

func _calculate_current_eu_matchday_from_week() -> int:
	"""Berechnet aktuellen EU-Pokal Matchday basierend auf der Woche"""
	var current_week = GameManager.get_week()
	
	# EU-Pokal Wochen aus ScheduleGenerator (siehe _get_cup_for_week)
	var eu_matchday_schedule = {
		5: 1,   # Woche 5 → Matchday 1
		8: 2,   # Woche 8 → Matchday 2
		14: 3,  # Woche 14 → Matchday 3
		17: 4,  # Woche 17 → Matchday 4
		25: 5,  # Woche 25 → Matchday 5
		28: 6,  # Woche 28 → Matchday 6
		34: 7,  # Woche 34 → Matchday 7
		37: 8   # Woche 37 → Matchday 8
	}
	
	# Exakte Woche gefunden?
	if eu_matchday_schedule.has(current_week):
		print("DEBUG: CL Matchday - Exakte Woche %d → Matchday %d" % [current_week, eu_matchday_schedule[current_week]])
		return eu_matchday_schedule[current_week]
	
	# Finde NÄCHSTEN geplanten Matchday (nicht letzten vergangenen)
	var next_matchday = 0
	for week in eu_matchday_schedule.keys():
		if current_week < week:  # Nächste geplante Woche
			next_matchday = eu_matchday_schedule[week]
			print("DEBUG: CL Matchday - Woche %d → Nächster Matchday %d (Woche %d)" % [current_week, next_matchday, week])
			return next_matchday
	
	# Alle Matchdays sind vorbei → Liga-Phase beendet
	print("DEBUG: CL Matchday - Woche %d → Liga-Phase beendet, kein aktiver Matchday" % current_week)
	return 0

func get_next_cup_matches() -> Array:
	"""Gibt alle nächsten Pokal-Spiele zurück"""
	var all_matches = []
	
	for cup_type in active_cups.keys():
		var matches = get_current_round_matches(cup_type)
		all_matches.append_array(matches)
	
	return all_matches

func _generate_all_season_schedules():
	"""Generiert und speichert alle Pokal-Spielpläne zu Saisonbeginn"""
	print("=== GENERIERE ALLE SAISON-SPIELPLÄNE ===")
	
	# Champions League Swiss-System Schedule
	if active_cups.has(CupType.CHAMPIONS_LEAGUE):
		var cl_data = active_cups[CupType.CHAMPIONS_LEAGUE]
		if cl_data.teams.size() > 0:
			var cl_schedule = _create_simple_random_schedule(cl_data.teams, CupType.CHAMPIONS_LEAGUE)
			saved_schedules["eu_%d_schedule" % CupType.CHAMPIONS_LEAGUE] = cl_schedule
			print("Champions League: %d Spieltage generiert und gespeichert" % cl_schedule.size())
	
	# Europa League Swiss-System Schedule  
	if active_cups.has(CupType.EUROPA_LEAGUE):
		var el_data = active_cups[CupType.EUROPA_LEAGUE]
		if el_data.teams.size() > 0:
			var el_schedule = _create_simple_random_schedule(el_data.teams, CupType.EUROPA_LEAGUE)
			saved_schedules["eu_%d_schedule" % CupType.EUROPA_LEAGUE] = el_schedule
			print("Europa League: %d Spieltage generiert und gespeichert" % el_schedule.size())
	
	# Conference League Swiss-System Schedule
	if active_cups.has(CupType.CONFERENCE_LEAGUE):
		var ecl_data = active_cups[CupType.CONFERENCE_LEAGUE]
		if ecl_data.teams.size() > 0:
			var ecl_schedule = _create_simple_random_schedule(ecl_data.teams, CupType.CONFERENCE_LEAGUE)
			saved_schedules["eu_%d_schedule" % CupType.CONFERENCE_LEAGUE] = ecl_schedule
			print("Conference League: %d Spieltage generiert und gespeichert" % ecl_schedule.size())
	
	print("=== ALLE SPIELPLÄNE GENERIERT ===")
	
	# Debug: Zeige User-Team Gegner in allen Pokalen
	_debug_user_cup_opponents()

func _debug_user_cup_opponents():
	"""Debug-Funktion: Zeigt alle User-Team Pokal-Gegner"""
	print("\n=== USER-TEAM (t01) POKAL-GEGNER ===")
	
	# DFB-Pokal
	if is_team_in_cup("t01", CupType.DFB_POKAL):
		print("DFB-Pokal: Team t01 ist qualifiziert")
		var dfb_matches = active_cups[CupType.DFB_POKAL].matches
		for round in dfb_matches.keys():
			for match in dfb_matches[round]:
				if match.home_team == "t01" or match.away_team == "t01":
					var opponent = match.home_team if match.away_team == "t01" else match.away_team
					var opponent_data = GameManager.get_team(opponent)
					print("  Runde %d: %s" % [round, opponent_data.get("team_name", opponent)])
	
	# Champions League
	if saved_schedules.has("eu_%d_schedule" % CupType.CHAMPIONS_LEAGUE):
		if is_team_in_cup("t01", CupType.CHAMPIONS_LEAGUE):
			print("\nChampions League: Team t01 Gegner")
			var cl_schedule = saved_schedules["eu_%d_schedule" % CupType.CHAMPIONS_LEAGUE]
			for matchday in cl_schedule.keys():
				for match in cl_schedule[matchday]:
					if match.home_team == "t01" or match.away_team == "t01":
						var opponent = match.home_team if match.away_team == "t01" else match.away_team
						var opponent_data = GameManager.get_team(opponent)
						var home_away = "H" if match.home_team == "t01" else "A"
						print("  Spieltag %d (%s): %s" % [matchday, home_away, opponent_data.get("team_name", opponent)])
	
	print("=================================\n")

func _determine_winner(home_team: String, away_team: String, home_goals: int, away_goals: int) -> String:
	"""Bestimmt Sieger eines Pokalspiels - DEBUG für DFB-Pokal Bug"""
	var winner = ""
	
	# KRITISCHER BUG-FIX: Unentschieden darf in KO-Runde nicht vorkommen!
	if home_goals == away_goals:
		print("KRITISCHER FEHLER: Unentschieden in KO-Runde! %s %d:%d %s" % [home_team, home_goals, away_goals, away_team])
		print("Das sollte durch Verlängerung/Elfmeter verhindert werden!")
		push_error("Unentschieden in KO-Runde nicht erlaubt!")
		# Heimteam gewinnt bei Unentschieden
		winner = home_team
	elif home_goals > away_goals:
		winner = home_team
	else:
		winner = away_team
	
	# DEBUG: Log für DFB-Pokal User-Matches
	if home_team == "t01" or away_team == "t01":
		var user_won = (winner == "t01")
		var home_team_data = GameManager.get_team(home_team)
		var away_team_data = GameManager.get_team(away_team)
		print("DEBUG: USER-MATCH ERGEBNIS - %s (%s) %d:%d %s (%s) → SIEGER: %s (USER WON: %s)" % [
			home_team, home_team_data.get("team_name", home_team), 
			home_goals, away_goals, 
			away_team, away_team_data.get("team_name", away_team), 
			winner, str(user_won)
		])
	
	return winner

func finalize_league_phase_and_draw_playoffs(cup_type: CupType):
	"""Beendet Liga-Phase nach Spieltag 8 und startet Playoff-Auslosung"""
	if not active_cups.has(cup_type):
		print("CupManager: FEHLER - Cup nicht gefunden: %s" % cup_type)
		return
	
	var cup_data = active_cups[cup_type]
	var cup_name = cup_data.get("name", "Unbekannter Pokal")
	
	print("🏆 LIGA-PHASE ENDE: %s - starte Playoff-Auslosung!" % cup_name)
	
	# 1. Tabelle erstellen basierend auf bisherigen Ergebnissen
	var teams_standings = _calculate_league_phase_standings(cup_type)
	
	# 2. Playoff-Plätze bestimmen
	var top8_teams = teams_standings.slice(0, 8)      # Plätze 1-8: Direkt ins Achtelfinale
	var playoff_teams = teams_standings.slice(8, 24)  # Plätze 9-24: Playoff-Runde
	var eliminated_teams = teams_standings.slice(24, 36) # Plätze 25-36: Eliminiert
	
	print("%s: Top 8 direkt qualifiziert: %d Teams" % [cup_name, top8_teams.size()])
	print("%s: Playoff-Teams: %d Teams" % [cup_name, playoff_teams.size()])
	print("%s: Eliminiert: %d Teams" % [cup_name, eliminated_teams.size()])
	
	# 3. Eliminierte Teams aus Cup entfernen
	for team_standing in eliminated_teams:
		var team_id = team_standing.team_id
		remove_team_from_cup(team_id, cup_type)
		print("   ❌ ELIMINIERT: %s (Platz %d)" % [team_id, team_standing.position])
	
	# 4. Cup in Playoff-Phase überführen 
	cup_data.current_round = 9  # Nach Liga-Phase beginnen Playoffs
	cup_data.league_phase_complete = true
	cup_data.phase = "playoff"
	
	# 5. Playoff-Auslosung durchführen (Platz 9-24)
	_draw_playoff_round(cup_type, playoff_teams)
	
	# 6. Top 8 Teams für Achtelfinale speichern
	cup_data.qualified_for_round16 = []
	for team_standing in top8_teams:
		cup_data.qualified_for_round16.append(team_standing.team_id)
	
	print("🎯 %s: Liga-Phase abgeschlossen - %d Teams qualifiziert für K.O.-Phase" % [cup_name, top8_teams.size() + playoff_teams.size()])

func _draw_playoff_round(cup_type: CupType, playoff_teams: Array):
	"""ORIGINALGETREU: UEFA Playoff-Auslosung nach Liga-Phase"""
	var cup_data = active_cups[cup_type]
	var cup_name = cup_data.get("name", "")
	
	print("🎲 %s PLAYOFF-AUSLOSUNG: 16 Teams (Plätze 9-24)" % cup_name)
	
	# UEFA-REGEL: Gesetzt vs Ungesetzt
	# Plätze 9-16 sind gesetzt (spielen Rückspiel zuhause)
	# Plätze 17-24 sind ungesetzt
	var seeded_teams = playoff_teams.slice(0, 8)    # Plätze 9-16
	var unseeded_teams = playoff_teams.slice(8, 16) # Plätze 17-24
	
	# Zufällige Paarungen (aber gesetzt vs ungesetzt)
	unseeded_teams.shuffle()
	
	var playoff_matches = []
	for i in range(seeded_teams.size()):
		playoff_matches.append({
			"home_team": unseeded_teams[i].team_id,  # Hinspiel: Ungesetzt zuhause
			"away_team": seeded_teams[i].team_id,
			"seeded_team": seeded_teams[i].team_id,
			"round": 9,  # Playoff-Runde
			"is_first_leg": true
		})
		
		print("  PLAYOFF: %s (Platz %d) vs %s (Platz %d)" % [
			unseeded_teams[i].team_id, unseeded_teams[i].position,
			seeded_teams[i].team_id, seeded_teams[i].position
		])
	
	# Speichere Playoff-Paarungen
	if not cup_data.has("ko_fixtures"):
		cup_data.ko_fixtures = {}
	cup_data.ko_fixtures[9] = playoff_matches

func draw_ko_round(cup_type: CupType, round: int):
	"""ORIGINALGETREU: UEFA K.O.-Runden Auslosung"""
	var cup_data = active_cups[cup_type]
	var cup_name = cup_data.get("name", "")
	
	print("🎲 %s K.O.-RUNDEN AUSLOSUNG: Runde %d" % [cup_name, round])
	
	var qualified_teams = []
	
	# Je nach Runde: Teams sammeln
	if round == 10:  # Achtelfinale
		# Top 8 aus Liga-Phase + 8 Playoff-Sieger
		qualified_teams = cup_data.get("qualified_for_round16", [])
		# TODO: Playoff-Sieger hinzufügen nach Simulation
	elif round == 11:  # Viertelfinale
		# 8 Achtelfinale-Sieger
		# TODO: Aus vorheriger Runde
		pass
	elif round == 12:  # Halbfinale
		# 4 Viertelfinale-Sieger
		# TODO: Aus vorheriger Runde
		pass
	elif round == 13:  # Finale
		# 2 Halbfinale-Sieger
		# TODO: Aus vorheriger Runde
		pass
	
	# ORIGINALGETREU: Offene Auslosung ohne Setzliste
	qualified_teams.shuffle()
	
	var ko_matches = []
	for i in range(0, qualified_teams.size(), 2):
		if i + 1 < qualified_teams.size():
			# Zufälliges Heimrecht für Hinspiel
			var team_1 = qualified_teams[i]
			var team_2 = qualified_teams[i + 1]
			
			if randf() > 0.5:
				var temp = team_1
				team_1 = team_2
				team_2 = temp
			
			ko_matches.append({
				"home_team": team_1,
				"away_team": team_2,
				"round": round,
				"is_first_leg": true
			})
			
			print("  AUSLOSUNG: %s vs %s" % [team_1, team_2])
	
	# Speichere K.O.-Paarungen
	if not cup_data.has("ko_fixtures"):
		cup_data.ko_fixtures = {}
	cup_data.ko_fixtures[round] = ko_matches

func _calculate_league_phase_standings(cup_type: CupType) -> Array:
	"""Berechnet Tabelle nach Liga-Phase (Punkte, Tordifferenz, etc.)"""
	# VEREINFACHT: Für jetzt alle Teams mit Zufalls-Platzierung
	# TODO: Echte Tabellen-Berechnung basierend auf Match-Ergebnissen
	
	var cup_data = active_cups[cup_type]
	var teams = cup_data.get("teams", [])
	var standings = []
	
	# Alle Teams mit Zufalls-Punkten (vereinfacht)
	for i in range(teams.size()):
		var team_id = teams[i]
		standings.append({
			"team_id": team_id,
			"position": i + 1,
			"points": randi_range(6, 18),  # 6-18 Punkte nach 8 Spielen
			"goals_for": randi_range(8, 20),
			"goals_against": randi_range(5, 15)
		})
	
	# Nach Punkten sortieren (vereinfacht)
	standings.sort_custom(func(a, b): return a.points > b.points)
	
	# Positionen neu vergeben
	for i in range(standings.size()):
		standings[i].position = i + 1
	
	return standings
