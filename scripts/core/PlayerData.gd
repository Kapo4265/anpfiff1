class_name PlayerData
extends RefCounted

var player_id: String
var first_name: String
var last_name: String
var strength_overall_base: int
var current_form: float
var primary_position: String
var age: int
var moral: int
var zustand: String
var ist_gesperrt: bool
var verletzungsart: String
var frische: int
var kondition_basis: int

func _init(data: Dictionary = {}):
	# Sicherheitscheck für leere oder unvollständige Daten
	if data.is_empty():
		print("WARNING: PlayerData initialized with empty data!")
		player_id = ""
		first_name = "Unknown"
		last_name = "Player"
		strength_overall_base = 50
		current_form = 10
		primary_position = "MF"
		return
	
	player_id = data.get("player_id", "")
	first_name = data.get("first_name", "Unknown")
	last_name = data.get("last_name", "Player")
	strength_overall_base = data.get("strength_overall_base", 50)
	current_form = data.get("current_form", 10)
	primary_position = _map_position(data.get("primary_position", "Mittelfeld"))
	age = data.get("age", 25)
	
	var status = data.get("status", {})
	moral = status.get("moral", 5)
	zustand = status.get("zustand", 5)
	ist_gesperrt = status.get("ist_gesperrt", false)
	verletzungsart = status.get("verletzungsart", "")
	frische = status.get("frische", 100)
	kondition_basis = data.get("kondition_basis", 80)

func _map_position(json_position: String) -> String:
	# Mapping von JSON-Position zu Code-Abkürzung
	match json_position:
		"Torwart":
			return "TW"
		"Abwehr":
			return "AB"  
		"Mittelfeld":
			return "MF"
		"Sturm":
			return "ST"
		_:
			assert(false, "CRITICAL: Invalid position '%s' in player data! Check generator." % json_position)
			return ""

func get_full_name() -> String:
	return first_name + " " + last_name

func get_effective_strength() -> float:
	# Authentische Handbuch-Formel: Basis ± (Form-10)/10
	# Beispiele: Stärke 4, Form 8 → 4 - 0.2 = 3.8 | Stärke 5, Form 15 → 5 + 0.5 = 5.5
	return float(strength_overall_base) + (current_form - 10.0) * 0.1

func is_available() -> bool:
	return not ist_gesperrt and verletzungsart == ""

func update_form_after_match(won: bool, scored_goal: bool = false, own_goal: bool = false):
	if won:
		current_form += 1.0
	elif not won:
		current_form -= 1.0
	
	if scored_goal:
		current_form += 0.5
	
	if own_goal:
		current_form -= 1.0
	
	current_form = clamp(current_form, 0.0, 20.0)
