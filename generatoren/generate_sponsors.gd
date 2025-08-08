# res://generate_sponsors.gd
@tool
extends EditorScript

func _run():
	var generator = SponsorGenerator.new()
	generator.generate_and_save()

class SponsorGenerator:
	const MASTER_SPONSORS_DB_PATH = "res://data/master_sponsors_database.json"
	
	func generate_and_save():
		print("--- STARTE GENERIERUNG: Sponsoren ---")
		var sponsors_database: Dictionary = {}
		var name_pool = [ "Blue Cow", "Kornkönig", "Koka-Gaula", "Bitt-Bürger", "Klebrig & Kaustark", "Volkswaren", "BWM (Bayerische Wurst-Manufaktur)", "Meersalzes-Benz", "Räucher-Bahn", "Wuffhansa", "Audienz Versicherungen", "Debit Bank", "Spaßkasse", "Telekoma", "ZAP! Software", "Adios", "Mops", "Typico", "Wedl", "Baldi Süd" ]
		name_pool.shuffle()
		var tiers_data = {
			"tier_1": {"count": 2, "base_min": 20000000, "base_max": 40000000, "bonuses": {"Meisterschaft": 10000000, "Pokalsieg": 4000000, "Champions League Quali": 5000000}},
			"tier_2": {"count": 2, "base_min": 5000000, "base_max": 15000000, "bonuses": {"Europa League Quali": 1500000, "Pokal Halbfinale": 750000}},
			"tier_3": {"count": 2, "base_min": 2000000, "base_max": 5000000, "bonuses": {"Klassenerhalt": 750000, "Pokal Achtelfinale": 200000}}
		}
		for tier_key in tiers_data:
			var info = tiers_data[tier_key]
			var offers = []
			for i in range(info.count):
				if name_pool.is_empty(): break
				offers.append({
					"id": "offer_%s_%s" % [tier_key, i], "offer_name": "ANGEBOT " + "ABCD"[i],
					"sponsor_name": name_pool.pop_front(),
					"base_amount": _round_to_nearest_power_of_ten(randi_range(info.base_min, info.base_max)),
					"bonus_details": info.bonuses.duplicate(true)
				})
			sponsors_database[tier_key] = offers
			
		_save_database_to_file(sponsors_database, MASTER_SPONSORS_DB_PATH)
		print("--- FERTIG: Sponsoren ---")
	
	func _round_to_nearest_power_of_ten(val: float) -> int:
		if val >= 10e6: return int(round(val / 100e3)) * 100e3
		elif val >= 100e3: return int(round(val / 10e3)) * 10e3
		return int(round(val))
	func _save_database_to_file(data: Variant, path: String):
		var dir_path = path.get_base_dir(); if not DirAccess.dir_exists_absolute(dir_path): DirAccess.make_dir_recursive_absolute(dir_path)
		var file = FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(data, "\t")); file.close()
