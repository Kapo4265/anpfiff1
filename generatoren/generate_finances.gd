# res://scripts/generators/generate_finances.gd
# FINALE VERSION 3.0: Erweitert um Phase 1 Finanzplan mit variablen Schuldengrenzen
@tool
extends EditorScript

func _run():
	var generator = FinanceGenerator.new()
	generator.generate_and_save()

class FinanceGenerator:
	const MASTER_TEAM_DB_PATH = "res://data/master_teams.json"
	const MASTER_PLAYER_DB_PATH = "res://data/master_players_pool.json"
	const MASTER_FINANCE_DB_PATH = "res://data/master_finances.json"
	
	@export_range(1, 5) var game_difficulty_level: int = 3
	
	var finances_database: Dictionary = {}
	var finance_calculator = preload("res://scripts/modules/FinanceCalculator.gd")

	func generate_and_save():
		print("--- STARTE GENERIERUNG: Finanzen (Schwierigkeit: %d) ---" % game_difficulty_level)
		var teams_db = _load_json_from_path(MASTER_TEAM_DB_PATH)
		var players_db = _load_json_from_path(MASTER_PLAYER_DB_PATH)

		if not teams_db or not players_db:
			printerr("FEHLER: master_teams.json oder master_players.json nicht gefunden!")
			return

		finances_database.clear()
		for team_id in teams_db:
			var team_data = teams_db[team_id]
			finances_database[team_id] = _calculate_finances_for_team(team_data, players_db)
		
		_save_database_to_file(finances_database, MASTER_FINANCE_DB_PATH)
		print("--- FERTIG: Finanz-Datenbank wurde erstellt ---")

	func _calculate_finances_for_team(team_data: Dictionary, players_db: Dictionary) -> Dictionary:
		var tier = team_data.tier
		
		# Bestehende Berechnungen
		var player_salaries = _calculate_total_squad_salary(team_data, players_db)
		var staff_salaries = _calculate_staff_salaries(tier)
		var stadium_maintenance = _calculate_stadium_maintenance(team_data.stadium.get("stadium_capacity", 20000))
		var youth_cost = _calculate_youth_academy_cost(tier)
		var other_costs = _calculate_other_fixed_costs(tier)
		var total_monthly_expenses = player_salaries + staff_salaries + stadium_maintenance + youth_cost + other_costs
		
		var sponsor_income = _calculate_sponsor_income(tier, team_data)
		var tv_money = _calculate_tv_money(tier)
		var merchandising = _calculate_merchandising_income(tier, team_data)
		var total_yearly_income_base = sponsor_income + tv_money + merchandising
		
		# PHASE 1: Neue Finanzberechnung mit FinanceCalculator
		var team_value = FinanceCalculator.calculate_team_value(team_data, {})
		var debt_limit = FinanceCalculator.calculate_debt_limit(team_value, tier, game_difficulty_level, total_yearly_income_base)
		var starting_balance = _calculate_starting_balance(tier, team_data.get("last_season_placement", 10), game_difficulty_level)
		
		# Warnstufen berechnen
		var transfer_ban_threshold = int(debt_limit * 0.2)
		var stadium_ban_threshold = int(debt_limit * 0.3)
		
		var yearly_expenses_base = total_monthly_expenses * 12
		var yearly_surplus_or_deficit = total_yearly_income_base - yearly_expenses_base
		
		return {
			"team_id": team_data.team_id,
			"team_name": team_data.team_name,
			"team_tier": tier,
			"difficulty_level": game_difficulty_level,
			"current_balance": starting_balance,
			"sponsor_income_per_season": _round_to_nearest(sponsor_income, 100000),
			"tv_money_per_season": _round_to_nearest(tv_money, 100000),
			"merchandising_income_per_season": _round_to_nearest(merchandising, 50000),
			"staff_salaries_total_per_month": _round_to_nearest(staff_salaries, 10000),
			"stadium_maintenance_per_month": _round_to_nearest(stadium_maintenance, 10000),
			"youth_academy_cost_per_month": _round_to_nearest(youth_cost, 5000),
			"other_fixed_costs_per_month": _round_to_nearest(other_costs, 5000),
			"player_salaries_total_per_month": _round_to_nearest(player_salaries, 10000),
			"spectator_income": 0, "cup_income": 0, "transfer_income": 0, "loan_interest": 0,
			# PHASE 1: Neue Felder
			"team_value": team_value,
			"last_season_placement": team_data.get("last_season_placement", 10),
			"debt_limit": debt_limit,
			"transfer_ban_threshold": int(debt_limit * 0.2),
			"stadium_ban_threshold": int(debt_limit * 0.3),
			"current_debt": 0,
			"europa_tv_money": 0,
			"europa_prize_money": 0,
			"europa_gate_receipts": 0
		}

	func _calculate_total_squad_salary(team_data: Dictionary, players_db: Dictionary) -> int:
		var total_salary = 0
		if not players_db.has(team_data.team_id): return 0
		var player_list_for_team = players_db[team_data.team_id]
		for player_dict in player_list_for_team:
			total_salary += player_dict.get("monthly_salary_eur", 0)
		return total_salary

	# --- BERECHNUNGSFUNKTIONEN (MIT KORRIGIERTER SYNTAX) ---
	
	func _calculate_initial_balance_base(tier: int, team_name: String) -> float:
		var base_balance: float
		match tier:
			1: base_balance = 25_000_000
			2: base_balance = 12_000_000
			3: base_balance = 6_000_000
			4: base_balance = 3_000_000
			5: base_balance = 1_500_000
			6: base_balance = 500_000
		if team_name == "Dynamo München": base_balance *= 2.5
		
		var difficulty_modifier = 1.0 - (game_difficulty_level - 3) * 0.20
		return base_balance * difficulty_modifier

	func _calculate_sponsor_income(tier: int, team_data: Dictionary) -> float:
		var base: float
		match tier:
			1: base = 35_000_000
			2: base = 18_000_000
			3: base = 10_000_000
			4: base = 4_000_000
			5: base = 1_500_000
			6: base = 500_000
		var pop_mod = 1.0 + (team_data.popularity.fans - 50) / 100.0
		var difficulty_modifier = 1.0 - (game_difficulty_level - 3) * 0.15
		return base * pop_mod * difficulty_modifier * randf_range(0.9, 1.1)

	func _calculate_tv_money(tier: int) -> float:
		var base: float
		match tier:
			1: base = 65_000_000
			2: base = 50_000_000
			3: base = 35_000_000
			4: base = 20_000_000
			5: base = 12_000_000
			6: base = 1_500_000
		var difficulty_modifier = 1.0 - (game_difficulty_level - 3) * 0.10
		return base * difficulty_modifier * randf_range(0.95, 1.05)

	func _calculate_merchandising_income(tier: int, team_data: Dictionary) -> float:
		var base: float
		match tier:
			1: base = 20_000_000
			2: base = 10_000_000
			3: base = 4_000_000
			4: base = 1_500_000
			5: base = 600_000
			6: base = 150_000
		var pop_mod = 1.0 + (team_data.popularity.fans - 50) / 50.0
		var difficulty_modifier = 1.0 - (game_difficulty_level - 3) * 0.15
		return base * pop_mod * difficulty_modifier * randf_range(0.8, 1.2)

	func _calculate_staff_salaries(tier: int) -> float:
		var base: float
		match tier:
			1: base = 1_500_000
			2: base = 900_000
			3: base = 600_000
			4: base = 300_000
			5: base = 180_000
			6: base = 100_000
		var difficulty_modifier = 1.0 + (game_difficulty_level - 3) * 0.10
		return base * difficulty_modifier * randf_range(0.9, 1.1)

	func _calculate_stadium_maintenance(capacity: int) -> float:
		var base_cost_per_1000_seats = 5000.0
		var base = (float(capacity) / 1000.0) * base_cost_per_1000_seats
		var difficulty_modifier = 1.0 + (game_difficulty_level - 3) * 0.05
		return base * difficulty_modifier

	func _calculate_youth_academy_cost(tier: int) -> float:
		var base: float
		match tier:
			1: base = 300_000
			2: base = 200_000
			3: base = 150_000
			4: base = 100_000
			5: base = 60_000
			6: base = 30_000
		var difficulty_modifier = 1.0 + (game_difficulty_level - 3) * 0.10
		return base * difficulty_modifier * randf_range(0.9, 1.1)

	func _calculate_other_fixed_costs(tier: int) -> float:
		var base: float
		match tier:
			1: base = 350_000
			2: base = 250_000
			3: base = 180_000
			4: base = 100_000
			5: base = 70_000
			6: base = 40_000
		var difficulty_modifier = 1.0 + (game_difficulty_level - 3) * 0.10
		return base * difficulty_modifier * randf_range(0.9, 1.1)
	
	# NEUE PHASE 1 HILFSFUNKTIONEN
	
	func _get_tier_multiplier(tier: int) -> float:
		# Tier-Multiplikator für Schuldengrenze
		match tier:
			1: return 1.5 # Top-Teams
			2: return 1.2 # Mittelfeld
			3: return 1.0 # Abstiegskampf
			_: return 0.8 # Unterklassig
	
	func _get_difficulty_multiplier(difficulty: int) -> float:
		# Schwierigkeitsgrad-Multiplikator für Schuldengrenze
		match difficulty:
			1: return 1.3 # Einfach
			2: return 1.15
			3: return 1.0 # Normal
			4: return 0.85
			5: return 0.7 # Schwer
			_: return 1.0
	
	func _calculate_starting_balance(tier: int, last_placement: int, difficulty: int) -> int:
		# Basis-Startguthaben nach Schwierigkeitsgrad
		var base_balance = 0
		match difficulty:
			1: base_balance = 2_000_000 # Einfach
			2: base_balance = 1_500_000
			3: base_balance = 1_000_000 # Normal
			4: base_balance = 750_000
			5: base_balance = 500_000 # Schwer
			_: base_balance = 1_000_000
		
		# Platzierungs-Multiplikator
		var placement_multiplier = 1.0
		if last_placement <= 3: # Top 3
			placement_multiplier = 1.8
		elif last_placement <= 6: # Europa-Plätze
			placement_multiplier = 1.5
		elif last_placement <= 10: # Mittelfeld
			placement_multiplier = 1.2
		elif last_placement <= 15: # Unteres Mittelfeld
			placement_multiplier = 1.0
		else: # Abstiegskampf
			placement_multiplier = 0.8
		
		# Tier-Bonus
		var tier_bonus = 0
		match tier:
			1: tier_bonus = 1_000_000 # Top-Teams
			2: tier_bonus = 500_000 # Mittelfeld
			3: tier_bonus = 0 # Abstiegskampf
			_: tier_bonus = 0
		
		return int(base_balance * placement_multiplier + tier_bonus)
		
	# --- Allgemeine Hilfs- und Datei-Funktionen ---
	func _round_to_nearest(val: float, nearest: int) -> int:
		if nearest == 0: return int(round(val))
		return int(round(val / float(nearest))) * nearest

	func _load_json_from_path(path: String) -> Variant:
		if not FileAccess.file_exists(path): return null
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		return JSON.parse_string(content)

	func _save_database_to_file(data: Variant, path: String):
		var dir_path = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Master-Datei gespeichert: %s" % path)
