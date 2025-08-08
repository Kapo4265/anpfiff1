# res://scripts/generators/generate_teams.gd
# FINALE VERSION: Mit überarbeiteter und realistischerer Teammoral-Berechnung.
@tool
extends EditorScript

func _run():
	var generator = TeamGenerator.new()
	generator.generate_and_save()

class TeamGenerator:
	const MASTER_PLAYER_POOL_PATH = "res://data/master_players_pool.json"
	const MASTER_TEAM_DB_PATH = "res://data/master_teams.json"
	
	# KRITISCHER FIX: Global verwendete Spieler verfolgen (identisch zu _used_names im Player Generator)
	var _assigned_players: Dictionary = {}
	
	# EU-TEAM LÄNDER-MAPPING für authentische Spielerzuweisung
	var _eu_country_mapping: Dictionary = {}

	const ALL_LEAGUE_DATA = {
		"1. Bundesliga": [
			# Etablierte Bundesliga-Teams (tier 1-3) mit realistischen Vorjahresplätzen 1-16
			{"id": "t01", "city": "München", "tier": 1, "squad_size": 22, "fantasy_name": "Dynamo München", "stadium_name": "Frauenkirche-Arena", "stadium_capacity": 75024, "last_season_placement": 1, "default_tactic": "Offensiv", "default_einsatz": "Normal"},
			{"id": "t02", "city": "Leverkusen", "tier": 1, "squad_size": 22, "fantasy_name": "SV Leverkusen Pharma", "stadium_name": "Bergische Löwen-Arena", "stadium_capacity": 30210, "last_season_placement": 2, "default_tactic": "Offensiv", "default_einsatz": "Normal"},
			{"id": "t06", "city": "Frankfurt", "tier": 2, "squad_size": 22, "fantasy_name": "1.FC Frankfurt Main", "stadium_name": "Römerberg-Stadion", "stadium_capacity": 58000, "last_season_placement": 3, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t04", "city": "Dortmund", "tier": 1, "squad_size": 22, "fantasy_name": "Hansa Dortmund", "stadium_name": "Florian-Turm-Stadion", "stadium_capacity": 81365, "last_season_placement": 4, "default_tactic": "Offensiv", "default_einsatz": "Normal"},
			{"id": "t11", "city": "Freiburg", "tier": 3, "squad_size": 22, "fantasy_name": "FC Freiburg 05", "stadium_name": "Bächle-Stadion", "stadium_capacity": 34700, "last_season_placement": 5, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t13", "city": "Mainz", "tier": 3, "squad_size": 22, "fantasy_name": "Holstein Mainz", "stadium_name": "Domberg-Stadion", "stadium_capacity": 33305, "last_season_placement": 6, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t03", "city": "Leipzig", "tier": 1, "squad_size": 22, "fantasy_name": "FC Leipzig Sachsen", "stadium_name": "Völkerschlacht-Stadion", "stadium_capacity": 47069, "last_season_placement": 7, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t10", "city": "Bremen", "tier": 3, "squad_size": 22, "fantasy_name": "FC Bremen 1955", "stadium_name": "Weser-Stadion", "stadium_capacity": 42100, "last_season_placement": 8, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t05", "city": "Stuttgart", "tier": 2, "squad_size": 22, "fantasy_name": "Eintracht Stuttgart", "stadium_name": "Rössle-Arena", "stadium_capacity": 60449, "last_season_placement": 9, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t07", "city": "Mönchengladbach", "tier": 3, "squad_size": 22, "fantasy_name": "Real Mönchengladbach", "stadium_name": "Wasserturm-Stadion", "stadium_capacity": 54042, "last_season_placement": 10, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t09", "city": "Wolfsburg", "tier": 2, "squad_size": 22, "fantasy_name": "FC Sporting Wolfsburg", "stadium_name": "Wölfe-Festung", "stadium_capacity": 30000, "last_season_placement": 11, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t12", "city": "Augsburg", "tier": 3, "squad_size": 22, "fantasy_name": "Eintracht Augsburg", "stadium_name": "Fuggerei-Arena", "stadium_capacity": 30660, "last_season_placement": 12, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t16", "city": "Berlin", "tier": 3, "squad_size": 22, "fantasy_name": "SV Einheit Berlin", "stadium_name": "Brandenburger-Tor-Arena", "stadium_capacity": 22012, "last_season_placement": 13, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t14", "city": "St. Pauli", "tier": 4, "squad_size": 22, "fantasy_name": "TSG Pauli United", "stadium_name": "Millerntor-Stadion", "stadium_capacity": 29546, "last_season_placement": 14, "default_tactic": "Offensiv", "default_einsatz": "Hart"},
			{"id": "t08", "city": "Hoffenheim", "tier": 3, "squad_size": 22, "fantasy_name": "Borussia Hoffenheim", "stadium_name": "Kraichgau-Hügel-Arena", "stadium_capacity": 30150, "last_season_placement": 15, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t15", "city": "Heidenheim", "tier": 4, "squad_size": 22, "fantasy_name": "Inter Heidenheim", "stadium_name": "Hellenstein-Arena", "stadium_capacity": 15000, "last_season_placement": 16, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			# Aufsteiger aus der 2. Liga (tier 4) - haben Plätze 1+2 aus der 2. Liga, nicht für Europa qualifiziert
			{"id": "t17", "city": "Köln", "tier": 4, "squad_size": 22, "fantasy_name": "SV Geißbock Köln", "stadium_name": "Dom-Stadion", "stadium_capacity": 50000, "last_season_placement": 1, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t18", "city": "Hamburg", "tier": 4, "squad_size": 22, "fantasy_name": "Hanseaten Hamburg", "stadium_name": "Volksparkstadion", "stadium_capacity": 57000, "last_season_placement": 2, "default_tactic": "Offensiv", "default_einsatz": "Normal"}
		],
		"2. Bundesliga": [
			{"id": "t19", "city": "Kiel", "tier": 4, "squad_size": 22, "fantasy_name": "FC Kieler Störche", "stadium_name": "Förde-Stadion", "stadium_capacity": 15034, "last_season_placement": 17, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t20", "city": "Bochum", "tier": 4, "squad_size": 22, "fantasy_name": "FC Ruhrpott Bochum", "stadium_name": "Ruhrstadion", "stadium_capacity": 26000, "last_season_placement": 18, "default_tactic": "Defensiv", "default_einsatz": "Hart"},
			{"id": "t21", "city": "Düsseldorf", "tier": 4, "squad_size": 22, "fantasy_name": "Rheinstadt Düsseldorf", "stadium_name": "Rheinturm-Arena", "stadium_capacity": 54600, "last_season_placement": 6, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t22", "city": "Berlin", "tier": 4, "squad_size": 22, "fantasy_name": "TSV Berlin", "stadium_name": "Olympiastadion", "stadium_capacity": 74475, "last_season_placement": 11, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t23", "city": "Gelsenkirchen", "tier": 4, "squad_size": 22, "fantasy_name": "FC Gelsenkirchen", "stadium_name": "Veltins-Arena", "stadium_capacity": 62271, "last_season_placement": 14, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t24", "city": "Karlsruhe", "tier": 5, "squad_size": 22, "fantasy_name": "Badener Karlsruhe", "stadium_name": "Wildparkstadion", "stadium_capacity": 34302, "last_season_placement": 8, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t25", "city": "Hannover", "tier": 5, "squad_size": 22, "fantasy_name": "Hannover United", "stadium_name": "Niedersachsenstadion", "stadium_capacity": 49200, "last_season_placement": 9, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t26", "city": "Kaiserslautern", "tier": 5, "squad_size": 22, "fantasy_name": "Königslautern", "stadium_name": "Fritz-Walter-Stadion", "stadium_capacity": 49850, "last_season_placement": 7, "default_tactic": "Offensiv", "default_einsatz": "Hart"},
			{"id": "t27", "city": "Paderborn", "tier": 5, "squad_size": 22, "fantasy_name": "Paderborn 07", "stadium_name": "Home-Deluxe-Arena", "stadium_capacity": 15000, "last_season_placement": 4, "default_tactic": "Offensiv", "default_einsatz": "Normal"},
			{"id": "t28", "city": "Nürnberg", "tier": 5, "squad_size": 22, "fantasy_name": "Inter Nürnberg", "stadium_name": "Max-Morlock-Stadion", "stadium_capacity": 50000, "last_season_placement": 10, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t29", "city": "Fürth", "tier": 5, "squad_size": 22, "fantasy_name": "Fürth Calcio", "stadium_name": "Sportpark Ronhof", "stadium_capacity": 16626, "last_season_placement": 13, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t30", "city": "Magdeburg", "tier": 5, "squad_size": 22, "fantasy_name": "Real Magdeburg", "stadium_name": "MDCC-Arena", "stadium_capacity": 30098, "last_season_placement": 5, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t31", "city": "Elversberg", "tier": 5, "squad_size": 22, "fantasy_name": "Athletico Elversberg", "stadium_name": "Ursapharm-Arena", "stadium_capacity": 10000, "last_season_placement": 3, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t32", "city": "Münster", "tier": 5, "squad_size": 22, "fantasy_name": "1.FC Münster 08", "stadium_name": "Preußenstadion", "stadium_capacity": 14300, "last_season_placement": 15, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t33", "city": "Braunschweig", "tier": 5, "squad_size": 22, "fantasy_name": "Sporting Braunschweig", "stadium_name": "Eintracht-Stadion", "stadium_capacity": 23325, "last_season_placement": 16, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t34", "city": "Bielefeld", "tier": 6, "squad_size": 22, "fantasy_name": "FC Bielefeld NRW", "stadium_name": "Schüco-Arena", "stadium_capacity": 27332, "last_season_placement": 1, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t35", "city": "Dresden", "tier": 6, "squad_size": 22, "fantasy_name": "SV Dresden Kickers", "stadium_name": "Rudolf-Harbig-Stadion", "stadium_capacity": 32269, "last_season_placement": 2, "default_tactic": "Offensiv", "default_einsatz": "Normal"},
			{"id": "t36", "city": "Saarbrücken", "tier": 6, "squad_size": 22, "fantasy_name": "Saarbrücken Calcio", "stadium_name": "Ludwigsparkstadion", "stadium_capacity": 16003, "last_season_placement": 3, "default_tactic": "Vorsichtig", "default_einsatz": "Hart"}
		],
		"3. Liga": [
			{"id": "t37", "city": "Darmstadt", "tier": 6, "squad_size": 22, "fantasy_name": "Darmstadt United", "stadium_name": "Merck-Stadion", "stadium_capacity": 17810, "last_season_placement": 16, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t38", "city": "Ulm", "tier": 6, "squad_size": 22, "fantasy_name": "Ulm United", "stadium_name": "Donaustadion", "stadium_capacity": 17000, "last_season_placement": 17, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t39", "city": "Regensburg", "tier": 6, "squad_size": 22, "fantasy_name": "Fortuna Regensburg", "stadium_name": "Jahnstadion", "stadium_capacity": 15210, "last_season_placement": 18, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t40", "city": "Cottbus", "tier": 6, "squad_size": 22, "fantasy_name": "Real Cottbus", "stadium_name": "Stadion der Freundschaft", "stadium_capacity": 22528, "last_season_placement": 4, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"},
			{"id": "t41", "city": "Rostock", "tier": 6, "squad_size": 22, "fantasy_name": "FC Kogge Rostock", "stadium_name": "Ostseestadion", "stadium_capacity": 29000, "last_season_placement": 5, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t42", "city": "Köln", "tier": 6, "squad_size": 22, "fantasy_name": "SV Köln Glück", "stadium_name": "Sportpark Höhenberg", "stadium_capacity": 6214, "last_season_placement": 6, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t43", "city": "Verl", "tier": 6, "squad_size": 22, "fantasy_name": "Athletico Verl", "stadium_name": "Sportclub-Arena", "stadium_capacity": 5207, "last_season_placement": 7, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t44", "city": "Essen", "tier": 6, "squad_size": 22, "fantasy_name": "1.FC Essen", "stadium_name": "Stadion an der Hafenstraße", "stadium_capacity": 19962, "last_season_placement": 8, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Hart"},
			{"id": "t45", "city": "Wiesbaden", "tier": 6, "squad_size": 22, "fantasy_name": "Sporting Wiesbaden", "stadium_name": "Brita-Arena", "stadium_capacity": 15295, "last_season_placement": 9, "default_tactic": "Defensiv", "default_einsatz": "Normal"},
			{"id": "t46", "city": "Ingolstadt", "tier": 6, "squad_size": 22, "fantasy_name": "Ingolstadt United", "stadium_name": "Audi-Sportpark", "stadium_capacity": 15200, "last_season_placement": 10, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t47", "city": "München", "tier": 6, "squad_size": 22, "fantasy_name": "SV München Tiger", "stadium_name": "Grünwalder Stadion", "stadium_capacity": 15000, "last_season_placement": 11, "default_tactic": "Vorsichtig", "default_einsatz": "Normal"},
			{"id": "t48", "city": "Aachen", "tier": 6, "squad_size": 22, "fantasy_name": "1.FC Germania Aachen", "stadium_name": "Tivoli", "stadium_capacity": 32960, "last_season_placement": 12, "default_tactic": "Kontrolliert Offensiv", "default_einsatz": "Normal"}
		]
	}

	const ALL_CUP_DATA = {
		"DFB-Pokal": [
			{"id": "t-dfb-01", "city": "Offenbach", "tier": 7, "squad_size": 22, "fantasy_name": "Offenbacher Leder-Kicker", "stadium_name": "Offenbach Stadion", "stadium_capacity": 20500},
			{"id": "t-dfb-02", "city": "Lübeck", "tier": 7, "squad_size": 22, "fantasy_name": "Marzipan-Bomber Lübeck", "stadium_name": "Lübeck Arena", "stadium_capacity": 17849},
			{"id": "t-dfb-03", "city": "Havelse", "tier": 8, "squad_size": 22, "fantasy_name": "Grashüpfer Havelse", "stadium_name": "Havelse Park", "stadium_capacity": 3500},
			{"id": "t-dfb-04", "city": "Meppen", "tier": 7, "squad_size": 22, "fantasy_name": "Emsland United", "stadium_name": "Meppen Arena", "stadium_capacity": 13696},
			{"id": "t-dfb-05", "city": "Homburg", "tier": 8, "squad_size": 22, "fantasy_name": "Karlsberg-Kicker Homburg", "stadium_name": "Homburg Waldstadion", "stadium_capacity": 16488},
			{"id": "t-dfb-06", "city": "Dorfmark", "tier": 8, "squad_size": 22, "fantasy_name": "Heidjer-Stolz Dorfmark", "stadium_name": "Dorfmark Arena", "stadium_capacity": 1500},
			{"id": "t-dfb-07", "city": "Großaspach", "tier": 8, "squad_size": 22, "fantasy_name": "Dorfklub Großaspach", "stadium_name": "Großaspach Arena", "stadium_capacity": 10001},
			{"id": "t-dfb-08", "city": "Jena", "tier": 7, "squad_size": 22, "fantasy_name": "Jenenser Lichtstadt-Kicker", "stadium_name": "Jena Stadion", "stadium_capacity": 12990},
			{"id": "t-dfb-09", "city": "Wuppertal", "tier": 7, "squad_size": 22, "fantasy_name": "Schwebebahn-Kicker", "stadium_name": "Wuppertal Stadion", "stadium_capacity": 23067},
			{"id": "t-dfb-10", "city": "Flensburg", "tier": 8, "squad_size": 22, "fantasy_name": "Förde-Kicker Flensburg", "stadium_name": "Flensburg Stadion", "stadium_capacity": 4000},
			{"id": "t-dfb-11", "city": "Ulm", "tier": 7, "squad_size": 22, "fantasy_name": "Ulmer Münster-Spatzen", "stadium_name": "Ulm Stadion", "stadium_capacity": 19500},
			{"id": "t-dfb-12", "city": "Trier", "tier": 8, "squad_size": 22, "fantasy_name": "Porta Nigra Kickers", "stadium_name": "Trier Moselstadion", "stadium_capacity": 10256},
			{"id": "t-dfb-13", "city": "Potsdam", "tier": 8, "squad_size": 22, "fantasy_name": "Babelsberger Film-Kicker", "stadium_name": "Potsdam Park", "stadium_capacity": 10787},
			{"id": "t-dfb-14", "city": "Chemnitz", "tier": 7, "squad_size": 22, "fantasy_name": "Himmelblaue Legenden", "stadium_name": "Chemnitz Arena", "stadium_capacity": 15000},
			{"id": "t-dfb-15", "city": "Oldenburg", "tier": 8, "squad_size": 22, "fantasy_name": "Oldenburger Stiere", "stadium_name": "Oldenburg Stadion", "stadium_capacity": 15200},
			{"id": "t-dfb-16", "city": "Bayreuth", "tier": 7, "squad_size": 22, "fantasy_name": "Wagner-Festspiel-Kicker", "stadium_name": "Bayreuth Stadion", "stadium_capacity": 21500},
			{"id": "t-dfb-17", "city": "Illertissen", "tier": 8, "squad_size": 22, "fantasy_name": "Illertal-Stürmer", "stadium_name": "Illertissen Stadion", "stadium_capacity": 3000},
			{"id": "t-dfb-18", "city": "Berlin", "tier": 8, "squad_size": 22, "fantasy_name": "Weinrote Dynamos", "stadium_name": "Berlin Sportforum", "stadium_capacity": 12400},
			{"id": "t-dfb-19", "city": "Würzburg", "tier": 7, "squad_size": 22, "fantasy_name": "Dallenberg-Kicker", "stadium_name": "Würzburg Arena", "stadium_capacity": 13090},
			{"id": "t-dfb-20", "city": "Reutlingen", "tier": 8, "squad_size": 22, "fantasy_name": "Kreuzeiche-Kämpfer", "stadium_name": "Reutlingen Stadion", "stadium_capacity": 15228},
			{"id": "t-dfb-21", "city": "Villingen", "tier": 8, "squad_size": 22, "fantasy_name": "Brigach-Kicker Villingen", "stadium_name": "Villingen Arena", "stadium_capacity": 12000},
			{"id": "t-dfb-22", "city": "Lotte", "tier": 8, "squad_size": 22, "fantasy_name": "Autobahnkreuz-Kicker", "stadium_name": "Lotte Stadion", "stadium_capacity": 10059},
			{"id": "t-dfb-23", "city": "Bremerhaven", "tier": 8, "squad_size": 22, "fantasy_name": "Deich-Kicker Bremerhaven", "stadium_name": "Bremerhaven Stadion", "stadium_capacity": 10000},
			{"id": "t-dfb-24", "city": "Zwickau", "tier": 7, "squad_size": 22, "fantasy_name": "Trabant-Städter Zwickau", "stadium_name": "Zwickau Arena", "stadium_capacity": 10134},
			{"id": "t-dfb-25", "city": "Steinbach", "tier": 7, "squad_size": 22, "fantasy_name": "Stahlträger Steinbach", "stadium_name": "Steinbach Sportzentrum", "stadium_capacity": 4990},
			{"id": "t-dfb-26", "city": "Koblenz", "tier": 8, "squad_size": 22, "fantasy_name": "Deutsche Eck-Kicker", "stadium_name": "Koblenz Stadion", "stadium_capacity": 9500},
			{"id": "t-dfb-27", "city": "Unterhaching", "tier": 7, "squad_size": 22, "fantasy_name": "Vorstadt-Giganten", "stadium_name": "Unterhaching Sportpark", "stadium_capacity": 15053},
			{"id": "t-dfb-28", "city": "Greifswald", "tier": 8, "squad_size": 22, "fantasy_name": "Greifen-Kicker", "stadium_name": "Greifswald Stadion", "stadium_capacity": 8000},
			{"id": "t-dfb-29", "city": "Celle", "tier": 8, "squad_size": 22, "fantasy_name": "Herzogstadt-Kicker Celle", "stadium_name": "Celle Stadion", "stadium_capacity": 11000},
			{"id": "t-dfb-30", "city": "Siegen", "tier": 8, "squad_size": 22, "fantasy_name": "Rubens-Städter Siegen", "stadium_name": "Siegen Stadion", "stadium_capacity": 18500},
			{"id": "t-dfb-31", "city": "Kassel", "tier": 7, "squad_size": 22, "fantasy_name": "Herkules-Kicker Kassel", "stadium_name": "Kassel Auestadion", "stadium_capacity": 18476},
			{"id": "t-dfb-32", "city": "Heide", "tier": 8, "squad_size": 22, "fantasy_name": "Dithmarschen-Kicker", "stadium_name": "Heide Stadion", "stadium_capacity": 11000},
			{"id": "t-dfb-33", "city": "Norderstedt", "tier": 8, "squad_size": 22, "fantasy_name": "Garstedter Eintracht", "stadium_name": "Norderstedt Stadion", "stadium_capacity": 5068},
			{"id": "t-dfb-34", "city": "Memmingen", "tier": 8, "squad_size": 22, "fantasy_name": "Allgäu-Kicker Memmingen", "stadium_name": "Memmingen Arena", "stadium_capacity": 5100},
			{"id": "t-dfb-35", "city": "Stuttgart", "tier": 8, "squad_size": 22, "fantasy_name": "Blaue Bomber Stuttgart", "stadium_name": "Stuttgart Waldau-Stadion", "stadium_capacity": 11410},
			{"id": "t-dfb-36", "city": "Walldorf", "tier": 8, "squad_size": 22, "fantasy_name": "Spargel-Stürmer Walldorf", "stadium_name": "Walldorf Sportpark", "stadium_capacity": 5000},
			{"id": "t-dfb-37", "city": "Düren", "tier": 8, "squad_size": 22, "fantasy_name": "Rur-Kicker Düren", "stadium_name": "Düren Arena", "stadium_capacity": 6000},
			{"id": "t-dfb-38", "city": "Rödinghausen", "tier": 8, "squad_size": 22, "fantasy_name": "Wiehengebirge-Kicker", "stadium_name": "Rödinghausen Stadion", "stadium_capacity": 2489},
			{"id": "t-dfb-39", "city": "Berlin", "tier": 8, "squad_size": 22, "fantasy_name": "Tempelhofer Freiheit", "stadium_name": "Berlin Stadion", "stadium_capacity": 4300},
			{"id": "t-dfb-40", "city": "Leipzig", "tier": 7, "squad_size": 22, "fantasy_name": "Probstheida Legenden", "stadium_name": "Leipzig Stadion", "stadium_capacity": 10900},
		],
		"European Clubs": [
			# --- England ---
			{"id": "t-eur-eng-01", "city": "Manchester", "tier": 1, "squad_size": 22, "fantasy_name": "Manchester Rot", "stadium_name": "Manchester Arena", "stadium_capacity": 74310},
			{"id": "t-eur-eng-02", "city": "Liverpool", "tier": 1, "squad_size": 22, "fantasy_name": "Liverpool Rot", "stadium_name": "Liverpool Stadion", "stadium_capacity": 61276},
			{"id": "t-eur-eng-03", "city": "London", "tier": 1, "squad_size": 22, "fantasy_name": "London Rot", "stadium_name": "London Arena", "stadium_capacity": 60704},
			{"id": "t-eur-eng-04", "city": "Manchester", "tier": 1, "squad_size": 22, "fantasy_name": "Manchester Blau", "stadium_name": "Manchester Stadion", "stadium_capacity": 53400},
			{"id": "t-eur-eng-05", "city": "London", "tier": 2, "squad_size": 22, "fantasy_name": "London Blau", "stadium_name": "London Stadion", "stadium_capacity": 40343},
			{"id": "t-eur-eng-06", "city": "Newcastle", "tier": 2, "squad_size": 22, "fantasy_name": "Newcastle", "stadium_name": "Newcastle Arena", "stadium_capacity": 52305},
			{"id": "t-eur-eng-07", "city": "London", "tier": 2, "squad_size": 22, "fantasy_name": "London Weiß", "stadium_name": "London Stadion", "stadium_capacity": 62850},
			{"id": "t-eur-eng-08", "city": "Birmingham", "tier": 3, "squad_size": 22, "fantasy_name": "Birmingham", "stadium_name": "Birmingham Park", "stadium_capacity": 42657},
			{"id": "t-eur-eng-09", "city": "London", "tier": 3, "squad_size": 22, "fantasy_name": "London Weinrot", "stadium_name": "London Stadion", "stadium_capacity": 62500},
			{"id": "t-eur-eng-10", "city": "Brighton", "tier": 4, "squad_size": 22, "fantasy_name": "Brighton", "stadium_name": "Brighton Stadion", "stadium_capacity": 31800},
			{"id": "t-eur-eng-11", "city": "Leicester", "tier": 4, "squad_size": 22, "fantasy_name": "Leicester", "stadium_name": "Leicester Stadion", "stadium_capacity": 32261},
			{"id": "t-eur-eng-12", "city": "Leeds", "tier": 4, "squad_size": 22, "fantasy_name": "Leeds", "stadium_name": "Leeds Stadion", "stadium_capacity": 37890},
			{"id": "t-eur-eng-13", "city": "Liverpool", "tier": 4, "squad_size": 22, "fantasy_name": "Liverpool Blau", "stadium_name": "Liverpool Park", "stadium_capacity": 39572},
			{"id": "t-eur-eng-14", "city": "Wolverhampton", "tier": 4, "squad_size": 22, "fantasy_name": "Wolverhampton", "stadium_name": "Wolverhampton Stadion", "stadium_capacity": 32050},
			{"id": "t-eur-eng-15", "city": "Stoke", "tier": 5, "squad_size": 22, "fantasy_name": "Stoke", "stadium_name": "Stoke Arena", "stadium_capacity": 30089},
			# --- Spanien ---
			{"id": "t-eur-esp-01", "city": "Madrid", "tier": 1, "squad_size": 22, "fantasy_name": "Madrid Weiß", "stadium_name": "Madrid Stadion", "stadium_capacity": 85000},
			{"id": "t-eur-esp-02", "city": "Barcelona", "tier": 1, "squad_size": 22, "fantasy_name": "Barcelona", "stadium_name": "Barcelona Stadion", "stadium_capacity": 105000},
			{"id": "t-eur-esp-03", "city": "Madrid", "tier": 2, "squad_size": 22, "fantasy_name": "Madrid Rot-Weiß", "stadium_name": "Madrid Metropolitano", "stadium_capacity": 68456},
			{"id": "t-eur-esp-04", "city": "Sevilla", "tier": 3, "squad_size": 22, "fantasy_name": "Sevilla Rot", "stadium_name": "Sevilla Stadion", "stadium_capacity": 43883},
			{"id": "t-eur-esp-05", "city": "San Sebastián", "tier": 3, "squad_size": 22, "fantasy_name": "San Sebastián", "stadium_name": "San Sebastián Arena", "stadium_capacity": 39500},
			{"id": "t-eur-esp-06", "city": "Villarreal", "tier": 3, "squad_size": 22, "fantasy_name": "Villarreal", "stadium_name": "Villarreal Stadion", "stadium_capacity": 23500},
			{"id": "t-eur-esp-07", "city": "Bilbao", "tier": 3, "squad_size": 22, "fantasy_name": "Bilbao", "stadium_name": "Bilbao Arena", "stadium_capacity": 53289},
			{"id": "t-eur-esp-08", "city": "Sevilla", "tier": 4, "squad_size": 22, "fantasy_name": "Sevilla Grün-Weiß", "stadium_name": "Sevilla Stadion", "stadium_capacity": 60720},
			{"id": "t-eur-esp-09", "city": "Valencia", "tier": 4, "squad_size": 22, "fantasy_name": "Valencia", "stadium_name": "Valencia Stadion", "stadium_capacity": 49430},
			{"id": "t-eur-esp-10", "city": "Girona", "tier": 2, "squad_size": 22, "fantasy_name": "Girona", "stadium_name": "Girona Stadion", "stadium_capacity": 14624},
			{"id": "t-eur-esp-11", "city": "Vigo", "tier": 5, "squad_size": 22, "fantasy_name": "Vigo", "stadium_name": "Vigo Stadion", "stadium_capacity": 29000},
			{"id": "t-eur-esp-12", "city": "Pamplona", "tier": 5, "squad_size": 22, "fantasy_name": "Pamplona", "stadium_name": "Pamplona Stadion", "stadium_capacity": 23576},
			# --- Italien ---
			{"id": "t-eur-ita-01", "city": "Mailand", "tier": 1, "squad_size": 22, "fantasy_name": "Mailand Blau-Schwarz", "stadium_name": "Mailand Stadion", "stadium_capacity": 75817},
			{"id": "t-eur-ita-02", "city": "Turin", "tier": 2, "squad_size": 22, "fantasy_name": "Turin Weiß-Schwarz", "stadium_name": "Turin Alpenstadion", "stadium_capacity": 41507},
			{"id": "t-eur-ita-03", "city": "Mailand", "tier": 2, "squad_size": 22, "fantasy_name": "Mailand Rot-Schwarz", "stadium_name": "Mailand Stadion", "stadium_capacity": 75817},
			{"id": "t-eur-ita-04", "city": "Neapel", "tier": 2, "squad_size": 22, "fantasy_name": "Neapel", "stadium_name": "Neapel Stadion", "stadium_capacity": 54726},
			{"id": "t-eur-ita-05", "city": "Rom", "tier": 2, "squad_size": 22, "fantasy_name": "Rom Weinrot", "stadium_name": "Rom Stadion", "stadium_capacity": 72698},
			{"id": "t-eur-ita-06", "city": "Bergamo", "tier": 3, "squad_size": 22, "fantasy_name": "Bergamo", "stadium_name": "Bergamo Stadion", "stadium_capacity": 21300},
			{"id": "t-eur-ita-07", "city": "Rom", "tier": 3, "squad_size": 22, "fantasy_name": "Rom Himmelblau", "stadium_name": "Rom Stadion", "stadium_capacity": 72698},
			{"id": "t-eur-ita-08", "city": "Florenz", "tier": 4, "squad_size": 22, "fantasy_name": "Florenz", "stadium_name": "Florenz Arena", "stadium_capacity": 43147},
			{"id": "t-eur-ita-09", "city": "Bologna", "tier": 3, "squad_size": 22, "fantasy_name": "Bologna", "stadium_name": "Bologna Stadion", "stadium_capacity": 38279},
			{"id": "t-eur-ita-10", "city": "Turin", "tier": 5, "squad_size": 22, "fantasy_name": "Turin Weinrot", "stadium_name": "Turin Stadion", "stadium_capacity": 28177},
			{"id": "t-eur-ita-11", "city": "Genua", "tier": 5, "squad_size": 22, "fantasy_name": "Genua", "stadium_name": "Genua Stadion", "stadium_capacity": 36599},
			{"id": "t-eur-ita-12", "city": "Udine", "tier": 5, "squad_size": 22, "fantasy_name": "Udine", "stadium_name": "Udine Arena", "stadium_capacity": 25144},
			# --- Rest von Europa ---
			{"id": "t-eur-fra-01", "city": "Paris", "tier": 1, "squad_size": 22, "fantasy_name": "Paris", "stadium_name": "Paris Arena", "stadium_capacity": 47929},
			{"id": "t-eur-mar-01", "city": "Marseille", "tier": 3, "squad_size": 22, "fantasy_name": "Marseille", "stadium_name": "Marseille Stadion", "stadium_capacity": 67394},
			{"id": "t-eur-lyo-01", "city": "Lyon", "tier": 3, "squad_size": 22, "fantasy_name": "Lyon", "stadium_name": "Lyon Park", "stadium_capacity": 59186},
			{"id": "t-eur-mon-01", "city": "Monaco", "tier": 3, "squad_size": 22, "fantasy_name": "Monaco", "stadium_name": "Monaco Stadion", "stadium_capacity": 16360},
			{"id": "t-eur-lil-01", "city": "Lille", "tier": 4, "squad_size": 22, "fantasy_name": "Lille", "stadium_name": "Lille Stadion", "stadium_capacity": 50186},
			{"id": "t-eur-ren-01", "city": "Rennes", "tier": 4, "squad_size": 22, "fantasy_name": "Rennes", "stadium_name": "Rennes Park", "stadium_capacity": 29778},
			{"id": "t-eur-nic-01", "city": "Nizza", "tier": 4, "squad_size": 22, "fantasy_name": "Nizza", "stadium_name": "Nizza Stadion", "stadium_capacity": 36178},
			{"id": "t-eur-len-01", "city": "Lens", "tier": 4, "squad_size": 22, "fantasy_name": "Lens", "stadium_name": "Lens Stadion", "stadium_capacity": 38223},
			{"id": "t-eur-str-01", "city": "Straßburg", "tier": 5, "squad_size": 22, "fantasy_name": "Straßburg", "stadium_name": "Straßburg Stadion", "stadium_capacity": 26109},
			{"id": "t-eur-nan-01", "city": "Nantes", "tier": 5, "squad_size": 22, "fantasy_name": "Nantes", "stadium_name": "Nantes Stadion", "stadium_capacity": 35322},
			{"id": "t-eur-lis-01", "city": "Lissabon", "tier": 3, "squad_size": 22, "fantasy_name": "Lissabon Rot", "stadium_name": "Lissabon Stadion", "stadium_capacity": 64642},
			{"id": "t-eur-por-01", "city": "Porto", "tier": 3, "squad_size": 22, "fantasy_name": "Porto", "stadium_name": "Porto Drachen-Stadion", "stadium_capacity": 50033},
			{"id": "t-eur-lis-02", "city": "Lissabon", "tier": 3, "squad_size": 22, "fantasy_name": "Lissabon Grün", "stadium_name": "Lissabon Alvalade-Stadion", "stadium_capacity": 50095},
			{"id": "t-eur-bra-01", "city": "Braga", "tier": 4, "squad_size": 22, "fantasy_name": "Braga", "stadium_name": "Braga Stadion", "stadium_capacity": 30286},
			{"id": "t-eur-gui-01", "city": "Guimarães", "tier": 5, "squad_size": 22, "fantasy_name": "Guimarães", "stadium_name": "Guimarães Stadion", "stadium_capacity": 30000},
			{"id": "t-eur-ams-01", "city": "Amsterdam", "tier": 3, "squad_size": 22, "fantasy_name": "Amsterdam", "stadium_name": "Amsterdam Arena", "stadium_capacity": 55865},
			{"id": "t-eur-ein-01", "city": "Eindhoven", "tier": 3, "squad_size": 22, "fantasy_name": "Eindhoven", "stadium_name": "Eindhoven Arena", "stadium_capacity": 35000},
			{"id": "t-eur-rot-01", "city": "Rotterdam", "tier": 3, "squad_size": 22, "fantasy_name": "Rotterdam", "stadium_name": "Rotterdam Stadion", "stadium_capacity": 51117},
			{"id": "t-eur-ens-01", "city": "Enschede", "tier": 4, "squad_size": 22, "fantasy_name": "Enschede", "stadium_name": "Enschede Stadion", "stadium_capacity": 30205},
			{"id": "t-eur-alk-01", "city": "Alkmaar", "tier": 4, "squad_size": 22, "fantasy_name": "Alkmaar", "stadium_name": "Alkmaar Stadion", "stadium_capacity": 19478},
			{"id": "t-eur-utr-01", "city": "Utrecht", "tier": 5, "squad_size": 22, "fantasy_name": "Utrecht", "stadium_name": "Utrecht Stadion", "stadium_capacity": 23750},
			{"id": "t-eur-ist-01", "city": "Istanbul", "tier": 4, "squad_size": 22, "fantasy_name": "Istanbul Rot-Gelb", "stadium_name": "Istanbul Arena", "stadium_capacity": 52280},
			{"id": "t-eur-ist-02", "city": "Istanbul", "tier": 5, "squad_size": 22, "fantasy_name": "Istanbul Blau-Gelb", "stadium_name": "Istanbul Stadion", "stadium_capacity": 50530},
			{"id": "t-eur-ist-03", "city": "Istanbul", "tier": 5, "squad_size": 22, "fantasy_name": "Istanbul Schwarz-Weiß", "stadium_name": "Istanbul Park", "stadium_capacity": 42590},
			{"id": "t-eur-tra-01", "city": "Trabzon", "tier": 5, "squad_size": 22, "fantasy_name": "Trabzon", "stadium_name": "Trabzon Arena", "stadium_capacity": 40782},
			{"id": "t-eur-kon-01", "city": "Konya", "tier": 6, "squad_size": 22, "fantasy_name": "Konya", "stadium_name": "Konya Arena", "stadium_capacity": 42000},
			{"id": "t-eur-brg-01", "city": "Brügge", "tier": 4, "squad_size": 22, "fantasy_name": "Brügge", "stadium_name": "Brügge Stadion", "stadium_capacity": 29062},
			{"id": "t-eur-and-01", "city": "Anderlecht", "tier": 5, "squad_size": 22, "fantasy_name": "Anderlecht", "stadium_name": "Anderlecht Park", "stadium_capacity": 22500},
			{"id": "t-eur-ant-01", "city": "Antwerpen", "tier": 5, "squad_size": 22, "fantasy_name": "Antwerpen", "stadium_name": "Antwerpen Stadion", "stadium_capacity": 16144},
			{"id": "t-eur-gnk-01", "city": "Genk", "tier": 5, "squad_size": 22, "fantasy_name": "Genk", "stadium_name": "Genk Arena", "stadium_capacity": 23718},
			{"id": "t-eur-gnt-01", "city": "Gent", "tier": 5, "squad_size": 22, "fantasy_name": "Gent", "stadium_name": "Gent Arena", "stadium_capacity": 20000},
			{"id": "t-eur-brn-01", "city": "Bern", "tier": 5, "squad_size": 22, "fantasy_name": "Bern", "stadium_name": "Bern Wankdorf-Stadion", "stadium_capacity": 32000},
			{"id": "t-eur-bas-01", "city": "Basel", "tier": 5, "squad_size": 22, "fantasy_name": "Basel", "stadium_name": "Basel Park", "stadium_capacity": 37994},
			{"id": "t-eur-zur-01", "city": "Zürich", "tier": 6, "squad_size": 22, "fantasy_name": "Zürich", "stadium_name": "Zürich Stadion", "stadium_capacity": 26104},
			{"id": "t-eur-lug-01", "city": "Lugano", "tier": 6, "squad_size": 22, "fantasy_name": "Lugano", "stadium_name": "Lugano Stadion", "stadium_capacity": 6390},
			{"id": "t-eur-gla-01", "city": "Glasgow", "tier": 4, "squad_size": 22, "fantasy_name": "Glasgow Grün", "stadium_name": "Glasgow Park", "stadium_capacity": 60411},
			{"id": "t-eur-gla-02", "city": "Glasgow", "tier": 4, "squad_size": 22, "fantasy_name": "Glasgow Blau", "stadium_name": "Glasgow Arena", "stadium_capacity": 50817},
			{"id": "t-eur-edi-01", "city": "Edinburgh", "tier": 6, "squad_size": 22, "fantasy_name": "Edinburgh", "stadium_name": "Edinburgh Arena", "stadium_capacity": 20099},
			{"id": "t-eur-abe-01", "city": "Aberdeen", "tier": 6, "squad_size": 22, "fantasy_name": "Aberdeen", "stadium_name": "Aberdeen Stadion", "stadium_capacity": 20866},
			{"id": "t-eur-sal-01", "city": "Salzburg", "tier": 4, "squad_size": 22, "fantasy_name": "Salzburg", "stadium_name": "Salzburg Arena", "stadium_capacity": 30188},
			{"id": "t-eur-grz-01", "city": "Graz", "tier": 5, "squad_size": 22, "fantasy_name": "Graz", "stadium_name": "Graz Arena", "stadium_capacity": 16364},
			{"id": "t-eur-vie-01", "city": "Wien", "tier": 5, "squad_size": 22, "fantasy_name": "Wien", "stadium_name": "Wien Arena", "stadium_capacity": 28000},
			{"id": "t-eur-lin-01", "city": "Linz", "tier": 6, "squad_size": 22, "fantasy_name": "Linz", "stadium_name": "Linz Arena", "stadium_capacity": 19080},
			{"id": "t-eur-don-01", "city": "Donezk", "tier": 5, "squad_size": 22, "fantasy_name": "Donezk", "stadium_name": "Donezk Arena", "stadium_capacity": 34915},
			{"id": "t-eur-kie-01", "city": "Kiew", "tier": 5, "squad_size": 22, "fantasy_name": "Kiew", "stadium_name": "Kiew Stadion", "stadium_capacity": 70050},
			{"id": "t-eur-pol-01", "city": "Poltawa", "tier": 7, "squad_size": 22, "fantasy_name": "Poltawa", "stadium_name": "Poltawa Stadion", "stadium_capacity": 24795},
			{"id": "t-eur-bel-01", "city": "Belgrad", "tier": 6, "squad_size": 22, "fantasy_name": "Belgrad Rot-Weiß", "stadium_name": "Belgrad Stadion", "stadium_capacity": 53000},
			{"id": "t-eur-bel-02", "city": "Belgrad", "tier": 6, "squad_size": 22, "fantasy_name": "Belgrad Schwarz-Weiß", "stadium_name": "Belgrad Stadion", "stadium_capacity": 32710},
			{"id": "t-eur-bac-01", "city": "Bačka Topola", "tier": 7, "squad_size": 22, "fantasy_name": "Bačka Topola", "stadium_name": "Bačka Topola Arena", "stadium_capacity": 4500},
			{"id": "t-eur-cop-01", "city": "Kopenhagen", "tier": 5, "squad_size": 22, "fantasy_name": "Kopenhagen", "stadium_name": "Kopenhagen Park", "stadium_capacity": 38065},
			{"id": "t-eur-her-01", "city": "Herning", "tier": 6, "squad_size": 22, "fantasy_name": "Herning", "stadium_name": "Herning Arena", "stadium_capacity": 11432},
			{"id": "t-eur-bro-01", "city": "Brøndby", "tier": 6, "squad_size": 22, "fantasy_name": "Brøndby", "stadium_name": "Brøndby Stadion", "stadium_capacity": 28000},
			{"id": "t-eur-aar-01", "city": "Aarhus", "tier": 6, "squad_size": 22, "fantasy_name": "Aarhus", "stadium_name": "Aarhus Park", "stadium_capacity": 19433},
			{"id": "t-eur-mol-01", "city": "Molde", "tier": 6, "squad_size": 22, "fantasy_name": "Molde", "stadium_name": "Molde Stadion", "stadium_capacity": 11249},
			{"id": "t-eur-bod-01", "city": "Bodø", "tier": 6, "squad_size": 22, "fantasy_name": "Bodø", "stadium_name": "Bodø Stadion", "stadium_capacity": 8270},
			{"id": "t-eur-tro-01", "city": "Trondheim", "tier": 6, "squad_size": 22, "fantasy_name": "Trondheim", "stadium_name": "Trondheim Stadion", "stadium_capacity": 21421},
			{"id": "t-eur-brg-02", "city": "Bergen", "tier": 7, "squad_size": 22, "fantasy_name": "Bergen", "stadium_name": "Bergen Stadion", "stadium_capacity": 16750},
			{"id": "t-eur-pir-01", "city": "Piräus", "tier": 5, "squad_size": 22, "fantasy_name": "Piräus", "stadium_name": "Piräus Stadion", "stadium_capacity": 32115},
			{"id": "t-eur-the-01", "city": "Thessaloniki", "tier": 6, "squad_size": 22, "fantasy_name": "Thessaloniki", "stadium_name": "Thessaloniki Stadion", "stadium_capacity": 28703},
			{"id": "t-eur-ath-01", "city": "Athen", "tier": 6, "squad_size": 22, "fantasy_name": "Athen Gelb", "stadium_name": "Athen Stadion", "stadium_capacity": 32500},
			{"id": "t-eur-ath-02", "city": "Athen", "tier": 6, "squad_size": 22, "fantasy_name": "Athen Grün", "stadium_name": "Athen Olympiastadion", "stadium_capacity": 69618},
			{"id": "t-eur-zag-01", "city": "Zagreb", "tier": 5, "squad_size": 22, "fantasy_name": "Zagreb", "stadium_name": "Zagreb Stadion", "stadium_capacity": 35423},
			{"id": "t-eur-spl-01", "city": "Split", "tier": 6, "squad_size": 22, "fantasy_name": "Split", "stadium_name": "Split Poljud-Stadion", "stadium_capacity": 34198},
			{"id": "t-eur-rij-01", "city": "Rijeka", "tier": 6, "squad_size": 22, "fantasy_name": "Rijeka", "stadium_name": "Rijeka Stadion", "stadium_capacity": 8279},
			{"id": "t-eur-osi-01", "city": "Osijek", "tier": 6, "squad_size": 22, "fantasy_name": "Osijek", "stadium_name": "Osijek Opus Arena", "stadium_capacity": 13005},
			{"id": "t-eur-pra-01", "city": "Prag", "tier": 5, "squad_size": 22, "fantasy_name": "Prag Rot", "stadium_name": "Prag Arena", "stadium_capacity": 18944},
			{"id": "t-eur-pra-02", "city": "Prag", "tier": 6, "squad_size": 22, "fantasy_name": "Prag Rot-Weiß", "stadium_name": "Prag Fortuna Arena", "stadium_capacity": 20800},
			{"id": "t-eur-pil-01", "city": "Pilsen", "tier": 6, "squad_size": 22, "fantasy_name": "Pilsen", "stadium_name": "Pilsen Arena", "stadium_capacity": 11700},
			{"id": "t-eur-ost-01", "city": "Ostrava", "tier": 7, "squad_size": 22, "fantasy_name": "Ostrava", "stadium_name": "Ostrava Stadion", "stadium_capacity": 15123},
			{"id": "t-eur-war-01", "city": "Warschau", "tier": 6, "squad_size": 22, "fantasy_name": "Warschau", "stadium_name": "Warschau Stadion", "stadium_capacity": 31800},
			{"id": "t-eur-pos-01", "city": "Posen", "tier": 6, "squad_size": 22, "fantasy_name": "Posen", "stadium_name": "Posen Stadion", "stadium_capacity": 42837},
			{"id": "t-eur-cze-01", "city": "Częstochowa", "tier": 6, "squad_size": 22, "fantasy_name": "Częstochowa", "stadium_name": "Częstochowa Stadion", "stadium_capacity": 5500},
			{"id": "t-eur-szc-01", "city": "Stettin", "tier": 7, "squad_size": 22, "fantasy_name": "Stettin", "stadium_name": "Stettin Stadion", "stadium_capacity": 21163},
			{"id": "t-eur-mal-01", "city": "Malmö", "tier": 6, "squad_size": 22, "fantasy_name": "Malmö", "stadium_name": "Malmö Stadion", "stadium_capacity": 22500},
			{"id": "t-eur-sto-01", "city": "Stockholm", "tier": 7, "squad_size": 22, "fantasy_name": "Stockholm Blau-Gelb", "stadium_name": "Stockholm Arena", "stadium_capacity": 30001},
			{"id": "t-eur-got-01", "city": "Göteborg", "tier": 7, "squad_size": 22, "fantasy_name": "Göteborg", "stadium_name": "Göteborg Arena", "stadium_capacity": 6316},
			{"id": "t-eur-sto-02", "city": "Stockholm", "tier": 7, "squad_size": 22, "fantasy_name": "Stockholm Schwarz-Gelb", "stadium_name": "Stockholm Nationalarena", "stadium_capacity": 50000},
			{"id": "t-eur-clu-01", "city": "Cluj-Napoca", "tier": 6, "squad_size": 22, "fantasy_name": "Cluj-Napoca", "stadium_name": "Cluj-Napoca Stadion", "stadium_capacity": 23500},
			{"id": "t-eur-buc-01", "city": "Bukarest", "tier": 6, "squad_size": 22, "fantasy_name": "Bukarest", "stadium_name": "Bukarest Nationalarena", "stadium_capacity": 55634},
			{"id": "t-eur-cra-01", "city": "Craiova", "tier": 7, "squad_size": 22, "fantasy_name": "Craiova", "stadium_name": "Craiova Stadion", "stadium_capacity": 30983},
			{"id": "t-eur-con-01", "city": "Constanța", "tier": 7, "squad_size": 22, "fantasy_name": "Constanța", "stadium_name": "Constanța Stadion", "stadium_capacity": 4554},
			{"id": "t-eur-bud-01", "city": "Budapest", "tier": 6, "squad_size": 22, "fantasy_name": "Budapest", "stadium_name": "Budapest Arena", "stadium_capacity": 22043},
			{"id": "t-eur-sze-01", "city": "Székesfehérvár", "tier": 7, "squad_size": 22, "fantasy_name": "Székesfehérvár", "stadium_name": "Székesfehérvár Stadion", "stadium_capacity": 14201},
			{"id": "t-eur-deb-01", "city": "Debrecen", "tier": 7, "squad_size": 22, "fantasy_name": "Debrecen", "stadium_name": "Debrecen Stadion", "stadium_capacity": 20340},
			{"id": "t-eur-hai-01", "city": "Haifa", "tier": 6, "squad_size": 22, "fantasy_name": "Haifa", "stadium_name": "Haifa Stadion", "stadium_capacity": 30858},
			{"id": "t-eur-tel-01", "city": "Tel Aviv", "tier": 6, "squad_size": 22, "fantasy_name": "Tel Aviv", "stadium_name": "Tel Aviv Stadion", "stadium_capacity": 29400},
			{"id": "t-eur-bee-01", "city": "Be’er Scheva", "tier": 7, "squad_size": 22, "fantasy_name": "Be’er Scheva", "stadium_name": "Be’er Scheva Stadion", "stadium_capacity": 16126},
			{"id": "t-eur-lim-01", "city": "Limassol", "tier": 7, "squad_size": 22, "fantasy_name": "Limassol Grün", "stadium_name": "Limassol Stadion", "stadium_capacity": 10700},
			{"id": "t-eur-nic-02", "city": "Nikosia", "tier": 7, "squad_size": 22, "fantasy_name": "Nikosia", "stadium_name": "Nikosia Stadion", "stadium_capacity": 22859},
			{"id": "t-eur-lar-01", "city": "Larnaka", "tier": 7, "squad_size": 22, "fantasy_name": "Larnaka", "stadium_name": "Larnaka Arena", "stadium_capacity": 7400},
			{"id": "t-eur-lim-02", "city": "Limassol", "tier": 7, "squad_size": 22, "fantasy_name": "Limassol Blau", "stadium_name": "Limassol Stadion", "stadium_capacity": 13331},
			{"id": "t-eur-raz-01", "city": "Razgrad", "tier": 6, "squad_size": 22, "fantasy_name": "Razgrad", "stadium_name": "Razgrad Arena", "stadium_capacity": 10422},
			{"id": "t-eur-sof-01", "city": "Sofia", "tier": 7, "squad_size": 22, "fantasy_name": "Sofia Rot", "stadium_name": "Sofia Stadion", "stadium_capacity": 22995},
			{"id": "t-eur-sof-02", "city": "Sofia", "tier": 7, "squad_size": 22, "fantasy_name": "Sofia Blau", "stadium_name": "Sofia Arena", "stadium_capacity": 25000},
			{"id": "t-eur-bra-02", "city": "Bratislava", "tier": 6, "squad_size": 22, "fantasy_name": "Bratislava", "stadium_name": "Bratislava Stadion", "stadium_capacity": 22500},
			{"id": "t-eur-trv-01", "city": "Trnava", "tier": 7, "squad_size": 22, "fantasy_name": "Trnava", "stadium_name": "Trnava Stadion", "stadium_capacity": 19200},
			{"id": "t-eur-dun-01", "city": "Dunajská Streda", "tier": 7, "squad_size": 22, "fantasy_name": "Dunajská Streda", "stadium_name": "Dunajská Streda Arena", "stadium_capacity": 12700},
			{"id": "t-eur-agd-01", "city": "Ağdam", "tier": 7, "squad_size": 22, "fantasy_name": "Ağdam", "stadium_name": "Ağdam Arena", "stadium_capacity": 5800},
			{"id": "t-eur-bak-01", "city": "Baku", "tier": 7, "squad_size": 22, "fantasy_name": "Baku", "stadium_name": "Baku Arena", "stadium_capacity": 11000},
			{"id": "t-eur-ast-01", "city": "Astana", "tier": 7, "squad_size": 22, "fantasy_name": "Astana", "stadium_name": "Astana Arena", "stadium_capacity": 30244},
			{"id": "t-eur-aqt-01", "city": "Aqtöbe", "tier": 7, "squad_size": 22, "fantasy_name": "Aqtöbe", "stadium_name": "Aqtöbe Zentralstadion", "stadium_capacity": 12729},
			{"id": "t-eur-lju-01", "city": "Ljubljana", "tier": 7, "squad_size": 22, "fantasy_name": "Ljubljana", "stadium_name": "Ljubljana Stadion", "stadium_capacity": 16038},
			{"id": "t-eur-mar-02", "city": "Maribor", "tier": 7, "squad_size": 22, "fantasy_name": "Maribor", "stadium_name": "Maribor Ljudski-Garten", "stadium_capacity": 12702},
			{"id": "t-eur-cel-01", "city": "Celje", "tier": 7, "squad_size": 22, "fantasy_name": "Celje", "stadium_name": "Celje Stadion", "stadium_capacity": 13059},
			{"id": "t-eur-tir-01", "city": "Tiraspol", "tier": 7, "squad_size": 22, "fantasy_name": "Tiraspol", "stadium_name": "Tiraspol Stadion", "stadium_capacity": 12746},
			{"id": "t-eur-orh-01", "city": "Orhei", "tier": 8, "squad_size": 22, "fantasy_name": "Orhei", "stadium_name": "Orhei Stadion", "stadium_capacity": 3000},
			{"id": "t-eur-pri-01", "city": "Pristina", "tier": 7, "squad_size": 22, "fantasy_name": "Pristina", "stadium_name": "Pristina Stadion", "stadium_capacity": 13500},
			{"id": "t-eur-gji-01", "city": "Gjilan", "tier": 8, "squad_size": 22, "fantasy_name": "Gjilan", "stadium_name": "Gjilan Stadion", "stadium_capacity": 10000},
			{"id": "t-eur-dub-01", "city": "Dublin", "tier": 7, "squad_size": 22, "fantasy_name": "Dublin", "stadium_name": "Dublin Stadion", "stadium_capacity": 8000},
			{"id": "t-eur-dun-02", "city": "Dundalk", "tier": 8, "squad_size": 22, "fantasy_name": "Dundalk", "stadium_name": "Dundalk Park", "stadium_capacity": 4500},
			{"id": "t-eur-der-01", "city": "Derry", "tier": 8, "squad_size": 22, "fantasy_name": "Derry", "stadium_name": "Derry Stadion", "stadium_capacity": 3700},
			{"id": "t-eur-hel-01", "city": "Helsinki", "tier": 7, "squad_size": 22, "fantasy_name": "Helsinki", "stadium_name": "Helsinki Arena", "stadium_capacity": 10770},
			{"id": "t-eur-kuo-01", "city": "Kuopio", "tier": 7, "squad_size": 22, "fantasy_name": "Kuopio", "stadium_name": "Kuopio Arena", "stadium_capacity": 5000},
			{"id": "t-eur-tur-01", "city": "Turku", "tier": 8, "squad_size": 22, "fantasy_name": "Turku", "stadium_name": "Turku Stadion", "stadium_capacity": 8072},
			{"id": "t-eur-jer-01", "city": "Jerewan", "tier": 7, "squad_size": 22, "fantasy_name": "Jerewan", "stadium_name": "Jerewan Stadion", "stadium_capacity": 14403},
			{"id": "t-eur-mos-01", "city": "Mostar", "tier": 7, "squad_size": 22, "fantasy_name": "Mostar", "stadium_name": "Mostar Stadion", "stadium_capacity": 9000},
			{"id": "t-eur-vil-01", "city": "Vilnius", "tier": 7, "squad_size": 22, "fantasy_name": "Vilnius", "stadium_name": "Vilnius Stadion", "stadium_capacity": 5067},
			{"id": "t-eur-dud-01", "city": "Düdelingen", "tier": 8, "squad_size": 22, "fantasy_name": "Düdelingen", "stadium_name": "Düdelingen Stadion", "stadium_capacity": 2558},
			{"id": "t-eur-tbi-01", "city": "Tiflis", "tier": 7, "squad_size": 22, "fantasy_name": "Tiflis", "stadium_name": "Tiflis Arena", "stadium_capacity": 54549},
			{"id": "t-eur-kop-01", "city": "Kópavogur", "tier": 8, "squad_size": 22, "fantasy_name": "Kópavogur", "stadium_name": "Kópavogur Stadion", "stadium_capacity": 3009},
			{"id": "t-eur-osw-01", "city": "Oswestry", "tier": 8, "squad_size": 22, "fantasy_name": "Oswestry", "stadium_name": "Oswestry Park", "stadium_capacity": 2034},
			{"id": "t-eur-gib-01", "city": "Gibraltar", "tier": 8, "squad_size": 22, "fantasy_name": "Gibraltar", "stadium_name": "Gibraltar Victoria-Stadion", "stadium_capacity": 5000},
			{"id": "t-eur-rig-01", "city": "Riga", "tier": 7, "squad_size": 22, "fantasy_name": "Riga", "stadium_name": "Riga Skonto-Stadion", "stadium_capacity": 8087},
			{"id": "t-eur-tir-02", "city": "Tirana", "tier": 8, "squad_size": 22, "fantasy_name": "Tirana", "stadium_name": "Tirana Nationalarena", "stadium_capacity": 22500},
			{"id": "t-eur-str-02", "city": "Struga", "tier": 8, "squad_size": 22, "fantasy_name": "Struga", "stadium_name": "Struga Stadion", "stadium_capacity": 2500},
			{"id": "t-eur-pod-01", "city": "Podgorica", "tier": 8, "squad_size": 22, "fantasy_name": "Podgorica", "stadium_name": "Podgorica Stadion", "stadium_capacity": 15230},
			{"id": "t-eur-kla-01", "city": "Klaksvík", "tier": 8, "squad_size": 22, "fantasy_name": "Klaksvík", "stadium_name": "Klaksvík Stadion", "stadium_capacity": 2600},
			{"id": "t-eur-lar-02", "city": "Larne", "tier": 8, "squad_size": 22, "fantasy_name": "Larne", "stadium_name": "Larne Park", "stadium_capacity": 3000},
			{"id": "t-eur-ham-01", "city": "Ħamrun", "tier": 8, "squad_size": 22, "fantasy_name": "Ħamrun", "stadium_name": "Ħamrun Nationalstadion", "stadium_capacity": 17797},
		]
	}

	var teams_database: Dictionary = {}

	func generate_and_save():
		print("--- STARTE GENERIERUNG: Teams (Finale, sichere Version) ---")
		_load_eu_country_mapping()
		
		# KRITISCHER FIX: Zurücksetzen des global tracking (wie _used_names.clear() im Player Generator)
		_assigned_players.clear()
		
		var player_pool_by_tier = _load_json_from_path(MASTER_PLAYER_POOL_PATH)
		if not player_pool_by_tier:
			print("FEHLER: Spieler-Pool konnte nicht geladen werden.")
			return
		# Mische alle Spieler im Pool (gespeichert unter Schlüssel "1")
		if player_pool_by_tier.has("1"):
			player_pool_by_tier["1"].shuffle()

		teams_database.clear()
		var all_teams_to_process = []
		
		# Lade Ligamannschaften
		for league_name in ALL_LEAGUE_DATA:
			for team_info in ALL_LEAGUE_DATA[league_name]:
				var temp_team_info = team_info.duplicate()
				temp_team_info["league_name"] = league_name
				all_teams_to_process.append(temp_team_info)
		
		# Lade Pokalmannschaften
		for cup_pool_name in ALL_CUP_DATA:
			for team_info in ALL_CUP_DATA[cup_pool_name]:
				var temp_team_info = team_info.duplicate()
				temp_team_info["league_name"] = cup_pool_name
				if not temp_team_info.has("last_season_placement"):
					temp_team_info["last_season_placement"] = 1
				if not temp_team_info.has("default_tactic"):
					temp_team_info["default_tactic"] = "Kontrolliert Offensiv"
				if not temp_team_info.has("default_einsatz"):
					temp_team_info["default_einsatz"] = "Normal"
				all_teams_to_process.append(temp_team_info)

		all_teams_to_process.sort_custom(func(a, b): return a.tier < b.tier)

		for team_info in all_teams_to_process:
			var new_team = {
				"team_id": team_info.id, "team_name": team_info.fantasy_name, "city": team_info.city,
				"league_name": team_info.league_name, "tier": team_info.tier,
				"last_season_placement": team_info.last_season_placement, "player_roster": [],
				"stadium": _generate_stadium_details(team_info),
				"popularity": _calculate_initial_popularity(team_info),
				"morale": _calculate_initial_morale(team_info),
				"default_tactic": team_info.default_tactic, "default_einsatz": team_info.default_einsatz,
				"league_stats": {"punkte": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0, "tore_geschossen": 0, "tore_kassiert": 0},
				"pokal_runde": "1. Runde", "zuschauerschnitt": 0, "tabellenplatz_verlauf": []
			}
			# EU-TEAMS: Länderspezifische Spielerzuweisung
			var team_squad_players
			if team_info.id.begins_with("t-eur-"):
				team_squad_players = _assign_eu_players_to_squad(player_pool_by_tier, team_info)
			else:
				team_squad_players = _assign_players_to_squad(player_pool_by_tier, team_info.squad_size, team_info.tier)
			for player in team_squad_players:
				new_team.player_roster.append(player.player_id)
			teams_database[team_info.id] = new_team

		_save_database_to_file(teams_database, MASTER_TEAM_DB_PATH)
		print("--- FERTIG: Team-Datenbank wurde erstellt ---")

	func _assign_players_to_squad(player_pool: Dictionary, squad_size: int, team_tier: int) -> Array:
		var assigned_squad = []
		
		# KRITISCHER FIX: Reduziere Torwart-Anforderungen (nur 501 verfügbar für 256 Teams)
		# 256 * 3 = 768 benötigt vs. 501 verfügbar = unmöglich
		# 256 * 2 = 512 benötigt vs. 501 verfügbar = fast machbar
		var position_requirements = {
			"Torwart": {"min": 2, "max": 3, "target": 2},
			"Abwehr": {"min": 5, "max": 8, "target": 7},
			"Mittelfeld": {"min": 5, "max": 8, "target": 7},
			"Sturm": {"min": 3, "max": 6, "target": 5}
		}
		
		# Passe Ziele an Kader-Größe an
		var remaining_slots = squad_size - 22  # 22 = Neuer Mindestkader (3+5+5+3+6 Rest)
		if remaining_slots > 0:
			# Verteile zusätzliche Plätze proportional
			position_requirements["Abwehr"]["target"] += max(1, remaining_slots / 3)
			position_requirements["Mittelfeld"]["target"] += max(1, remaining_slots / 3)
			position_requirements["Sturm"]["target"] += max(1, remaining_slots / 3)
		
		# Realistische Spielstärke-Verteilung nach Team-Tier und Hierarchie im Kader
		# Stärkste Teams: Stammelf 6-7, Reserve 5-6, Jugend/Ausreißer 1-4
		# Abstufung nach unten bis schwächste Teams: Stammelf 3-4, Reserve 2-3, Rest 1-2
		var strength_data = _get_realistic_strength_plan(team_tier, squad_size)
		var current_plan = strength_data.get(team_tier, {1: 1.0})
		
		# Organisiere Spieler nach Position und Spielstärke
		var players_by_position_and_strength = _organize_players_by_position_and_strength(player_pool)
		
		# KRITISCHER FIX: Weise ZUERST Torhüter zu (sind am seltensten)
		# Dann erst andere Positionen - verhindert dass frühe Teams alle Torhüter "verbrauchen"
		for position in ["Torwart", "Abwehr", "Mittelfeld", "Sturm"]:
			var target_count = position_requirements[position]["target"]
			var assigned_count = 0
			
			print("[DEBUG] Versuche %d %s-Spieler zu finden" % [target_count, position])
			
			# Für jede Position: Versuche aus den passenden Spielstärken zu draften
			for strength_int in current_plan:
				if assigned_count >= target_count:
					break
					
				var strength_str = str(strength_int)
				var num_from_this_strength = max(1, roundi(target_count * current_plan[strength_int]))
				var available_players = players_by_position_and_strength.get(position, {}).get(strength_str, [])
				
				print("[DEBUG] Stärke %s: Brauche %d, habe %d verfügbare %s-Spieler" % [strength_str, num_from_this_strength, available_players.size(), position])
				
				# KRITISCHER FIX: Prüfe auf bereits zugewiesene Spieler
				var attempts = 0
				var max_attempts = min(available_players.size(), 10)  # Maximal 10 Versuche pro Stärke
				while assigned_count < target_count and attempts < max_attempts and not available_players.is_empty():
					var player = available_players.pop_back()
					attempts += 1
					
					var player_id = player.get("player_id", "")
					if not _assigned_players.has(player_id):
						_assigned_players[player_id] = true
						assigned_squad.append(player)
						assigned_count += 1
						print("[DEBUG] %s-Spieler hinzugefügt: %s %s (ID: %s, Stärke %s)" % [position, player.get("first_name", "?"), player.get("last_name", "?"), player_id, str(player.get("strength_overall_base", "?"))])
					else:
						print("[DEBUG] ÜBERSPRINGE bereits zugewiesenen Spieler: %s %s (ID: %s)" % [player.get("first_name", "?"), player.get("last_name", "?"), player_id])
				
				# Früher Ausstieg falls keine verfügbaren Spieler dieser Stärke
				if attempts >= max_attempts:
					print("[DEBUG] Alle %d Spieler der Stärke %s waren bereits zugewiesen" % [max_attempts, strength_str])
			
			# NOTFALL-FIX: Falls Position nicht vollständig gefüllt, durchsuche ALLE Stärken
			if assigned_count < target_count:
				print("[DEBUG] NOTFALL: Nur %d von %d %s-Spielern gefunden - durchsuche alle Stärken" % [assigned_count, target_count, position])
				for emergency_strength in range(1, 8):  # Stärke 1-7
					if assigned_count >= target_count:
						break
					var emerg_str = str(emergency_strength)
					var emerg_players = players_by_position_and_strength.get(position, {}).get(emerg_str, [])
					
					while not emerg_players.is_empty() and assigned_count < target_count:
						var player = emerg_players.pop_back()
						var player_id = player.get("player_id", "")
						if not _assigned_players.has(player_id):
							_assigned_players[player_id] = true
							assigned_squad.append(player)
							assigned_count += 1
							print("[DEBUG] NOTFALL-%s-Spieler hinzugefügt: %s %s (ID: %s, Stärke %s)" % [position, player.get("first_name", "?"), player.get("last_name", "?"), player_id, emerg_str])
							break
			
			print("[DEBUG] Position %s abgeschlossen: %d von %d Spielern zugewiesen" % [position, assigned_count, target_count])
		
		# Fülle auf, falls noch Plätze frei sind - AUCH HIER FIX ANWENDEN
		while assigned_squad.size() < squad_size:
			var found_player = false
			for position in ["Abwehr", "Mittelfeld", "Sturm", "Torwart"]:
				for strength_i in range(1, 9):  # Spielstärke 1-8 (8 für seltene "Jahrhundertereignisse")
					var strength_str = str(strength_i)
					var available_players = players_by_position_and_strength.get(position, {}).get(strength_str, [])
					
					# KRITISCHER FIX: Prüfe auch hier auf Duplikate
					while not available_players.is_empty():
						var player = available_players.pop_back()
						var player_id = player.get("player_id", "")
						if not _assigned_players.has(player_id):
							_assigned_players[player_id] = true
							assigned_squad.append(player)
							found_player = true
							print("[DEBUG] AUFFÜLL-Spieler hinzugefügt: %s %s (ID: %s)" % [player.get("first_name", "?"), player.get("last_name", "?"), player_id])
							break
						else:
							print("[DEBUG] ÜBERSPRINGE doppelten Auffüll-Spieler: %s %s (ID: %s)" % [player.get("first_name", "?"), player.get("last_name", "?"), player_id])
					
					if found_player:
						break
				if found_player:
					break
			if not found_player:
				print("[WARNUNG] Nicht genügend einzigartige Spieler für vollständigen Squad verfügbar!")
				break
		
		# Validiere die finale Aufstellung
		_validate_squad_composition(assigned_squad)
		
		return assigned_squad
	
	# Hilfsfunktion: Organisiert Spieler nach Position und Spielstärke
	func _organize_players_by_position_and_strength(player_pool: Dictionary) -> Dictionary:
		var organized = {}
		var debug_position_counts = {}
		
		# Spielerdaten sind unter dem Schlüssel "1" gespeichert
		var all_players = player_pool.get("1", [])
		print("[DEBUG] Gesamte Spieleranzahl: %d" % all_players.size())
		
		# Stärke-Statistik sammeln
		var strength_debug = {}
		
		# Organisiere alle Spieler nach Position und Spielstärke
		for player in all_players:
			var position = player.get("primary_position", "Mittelfeld")
			var player_strength = str(int(player.get("strength_overall_base", 1)))  # Convert zu int dann zu string
			
			# Debug-Stärke-Zählung
			if not strength_debug.has(player_strength):
				strength_debug[player_strength] = 0
			strength_debug[player_strength] += 1
			
			# Debug-Zählung
			if not debug_position_counts.has(position):
				debug_position_counts[position] = 0
			debug_position_counts[position] += 1
			
			# Initialisiere Struktur falls nötig
			if not organized.has(position):
				organized[position] = {}
			if not organized[position].has(player_strength):
				organized[position][player_strength] = []
			
			organized[position][player_strength].append(player)
		
		# Debug-Ausgabe für Spielstärken
		print("[DEBUG] Spieler pro Spielstärke:")
		for strength in strength_debug:
			print("  Stärke %s: %d Spieler" % [strength, strength_debug[strength]])
		
		# Debug-Ausgabe
		print("[DEBUG] Spieler nach Position organisiert:")
		for pos in debug_position_counts:
			print("  %s: %d Spieler" % [pos, debug_position_counts[pos]])
		
		# Mische die Spieler in jeder Position/Stärke-Gruppe
		for position in organized:
			for strength_str in organized[position]:
				organized[position][strength_str].shuffle()
		
		return organized
	
	# Hilfsfunktion: Erstellt realistische Spielstärke-Verteilung basierend auf Kaderhierarchie
	func _get_realistic_strength_plan(team_tier: int, squad_size: int) -> Dictionary:
		var plan = {}
		
		# Kaderhierarchie: Stammelf (11), Wichtige Reserve (6-8), Rest = Jugend/Ausreißer
		var stammelf_count = 11
		var wichtige_reserve_count = min(8, squad_size - stammelf_count)
		var rest_count = squad_size - stammelf_count - wichtige_reserve_count
		
		match team_tier:
			1: # Stärkste Teams (z.B. Bayern, Dortmund)
				plan = {
					7: max(1, stammelf_count * 0.2),      # 2-3 Weltklasse-Spieler in Stammelf
					6: max(1, stammelf_count * 0.6 + wichtige_reserve_count * 0.4), # Hauptteil Stammelf + Reserve
					5: max(1, stammelf_count * 0.2 + wichtige_reserve_count * 0.6), # Rest Stammelf + Reserve
					4: max(1, rest_count * 0.3),          # Jugend/Ausreißer
					3: max(1, rest_count * 0.3),
					2: max(1, rest_count * 0.2),
					1: max(1, rest_count * 0.2)
				}
			2: # Starke Teams (z.B. Leverkusen, Leipzig)
				plan = {
					6: max(1, stammelf_count * 0.3),      # Wenige Top-Spieler
					5: max(1, stammelf_count * 0.6 + wichtige_reserve_count * 0.5), # Hauptteil Stammelf + Reserve
					4: max(1, stammelf_count * 0.1 + wichtige_reserve_count * 0.5), # Rest Stammelf + Reserve
					3: max(1, rest_count * 0.4),          # Jugend/Ausreißer
					2: max(1, rest_count * 0.3),
					1: max(1, rest_count * 0.3)
				}
			3: # Mittlere Teams (z.B. Freiburg, Mainz)
				plan = {
					5: max(1, stammelf_count * 0.2),      # Wenige sehr gute Spieler
					4: max(1, stammelf_count * 0.6 + wichtige_reserve_count * 0.4), # Hauptteil
					3: max(1, stammelf_count * 0.2 + wichtige_reserve_count * 0.6), # Rest + Reserve
					2: max(1, rest_count * 0.5),          # Jugend/Ausreißer
					1: max(1, rest_count * 0.5)
				}
			4: # Schwächere 1. Liga / Starke 2. Liga Teams
				plan = {
					5: max(1, stammelf_count * 0.1),      # 1-2 gute Spieler
					4: max(1, stammelf_count * 0.4 + wichtige_reserve_count * 0.3), # Stammelf-Kern
					3: max(1, stammelf_count * 0.5 + wichtige_reserve_count * 0.7), # Hauptteil
					2: max(1, rest_count * 0.6),          # Jugend/Ausreißer
					1: max(1, rest_count * 0.4)
				}
			5: # Schwache 2. Liga / Starke 3. Liga Teams
				plan = {
					4: max(1, stammelf_count * 0.2),      # Wenige bessere Spieler
					3: max(1, stammelf_count * 0.6 + wichtige_reserve_count * 0.5), # Hauptteil
					2: max(1, stammelf_count * 0.2 + wichtige_reserve_count * 0.5), # Rest + Reserve
					1: max(1, rest_count * 1.0)           # Jugend/Ausreißer nur Stärke 1
				}
			6: # Schwache 3. Liga / Amateur-Teams
				plan = {
					3: max(1, stammelf_count * 0.1),      # 1 besserer Spieler
					2: max(1, stammelf_count * 0.5 + wichtige_reserve_count * 0.8), # Hauptteil
					1: max(1, stammelf_count * 0.4 + wichtige_reserve_count * 0.2 + rest_count * 1.0) # Rest
				}
			7: # Unterklassen-Amateur-Teams
				plan = {
					2: max(1, stammelf_count * 0.2),      # Wenige Stärke 2
					1: max(1, stammelf_count * 0.8 + wichtige_reserve_count * 1.0 + rest_count * 1.0) # Fast alle Stärke 1
				}
			8: # Schwächste Teams
				plan = {
					1: max(1, squad_size * 1.0)           # Nur Stärke 1
				}
		
		# Normalisiere die Werte zu Prozentsätzen
		var total = 0
		for strength in plan:
			total += plan[strength]
		
		var normalized_plan = {}
		for strength in plan:
			if total > 0:
				normalized_plan[strength] = plan[strength] / float(total)
			else:
				normalized_plan[strength] = 0.0
		
		return {team_tier: normalized_plan}
	
	# Hilfsfunktion: Validiert die Kaderzusammensetzung
	func _validate_squad_composition(squad: Array):
		var position_counts = {"Torwart": 0, "Abwehr": 0, "Mittelfeld": 0, "Sturm": 0}
		
		for player in squad:
			var position = player.get("primary_position", "Mittelfeld")  # Korrigiert: primary_position aus PlayerGenerator
			position_counts[position] += 1
		
		print("Kader-Zusammensetzung:")
		print("  Torwart: %d" % position_counts["Torwart"])
		print("  Abwehr: %d" % position_counts["Abwehr"])
		print("  Mittelfeld: %d" % position_counts["Mittelfeld"])
		print("  Sturm: %d" % position_counts["Sturm"])
		
		# ANGEPASST: Torwart-Minimum von 3 auf 2 reduziert
		var has_minimum_requirements = (
			position_counts["Torwart"] >= 1 and
			position_counts["Abwehr"] >= 6 and
			position_counts["Mittelfeld"] >= 6 and
			position_counts["Sturm"] >= 3
		)
		
		if not has_minimum_requirements:
			print("WARNUNG: Team erfüllt nicht die Mindestanforderungen!")
		else:
			print("✓ Team erfüllt alle Mindestanforderungen")
	
	# === EU-TEAM LÄNDERSPEZIFISCHE SPIELERZUWEISUNG ===
	
	func _load_eu_country_mapping():
		print("Lade EU-Team Länder-Mapping...")
		var mapping_file = FileAccess.open("res://generatoren/eu_team_complete_mapping.json", FileAccess.READ)
		if mapping_file == null:
			print("FEHLER: EU-Mapping-Datei nicht gefunden!")
			return
		
		var json_text = mapping_file.get_as_text()
		mapping_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result != OK:
			print("FEHLER: Konnte EU-Mapping nicht parsen!")
			return
		
		_eu_country_mapping = json.data.get("city_mappings", {})
		print("EU-Mapping geladen: %d Städte-Codes verfügbar" % _eu_country_mapping.size())
	
	func _assign_eu_players_to_squad(player_pool: Dictionary, team_info: Dictionary) -> Array:
		print("EU-Team: %s (%s)" % [team_info.get("fantasy_name", "Unknown"), team_info.id])
		
		# Extrahiere Stadt-Code aus Team-ID (t-eur-[code]-[number])
		var team_id_parts = team_info.id.split("-")
		var city_code = ""
		if team_id_parts.size() >= 3:
			city_code = team_id_parts[2]
		
		# Finde Nationalität basierend auf Stadt-Code
		var nationality_info = _eu_country_mapping.get(city_code, {})
		var nationality = nationality_info.get("nationality", "International")
		var country = nationality_info.get("country", "Unknown")
		var tier = team_info.get("tier", 5)
		
		print("  Stadt-Code: %s → %s (%s), Tier %d" % [city_code, country, nationality, tier])
		
		# Bestimme Mischungsregeln basierend auf Tier
		var national_percentage = 1.0  # 100% national als Standard
		if tier <= 3:
			national_percentage = 0.6  # 60% national, 40% international (wie Barcelona)
		elif tier <= 5:
			national_percentage = 0.8  # 80% national, 20% gemischt
		# else: tier 6-8 = 100% national (wie Athletic Bilbao)
		
		var squad_size = team_info.get("squad_size", 22)
		var national_count = int(squad_size * national_percentage)
		var international_count = squad_size - national_count
		
		print("  Squad-Mischung: %d × %s, %d × International" % [national_count, nationality, international_count])
		
		var assigned_squad = []
		
		# 1. Weise nationale Spieler zu
		var national_players = _assign_players_by_nationality(player_pool, nationality, national_count, team_info.tier)
		assigned_squad.append_array(national_players)
		
		# 2. Fülle mit internationalen Spielern auf
		if international_count > 0:
			var remaining_positions = _get_remaining_position_needs(assigned_squad, squad_size)
			var international_players = _assign_players_by_nationality(player_pool, "International", international_count, team_info.tier, remaining_positions)
			assigned_squad.append_array(international_players)
		
		# SICHERHEITS-CHECK: Squad-Auffüllung garantieren
		if assigned_squad.size() < squad_size:
			print("  WARNUNG: Nur %d/%d Spieler - fülle mit beliebigen Spielern auf" % [assigned_squad.size(), squad_size])
			var remaining_needed = squad_size - assigned_squad.size()
			var emergency_players = _get_emergency_players(player_pool, remaining_needed, team_info.tier)
			assigned_squad.append_array(emergency_players)
		
		print("  Finale Squad-Größe: %d Spieler" % assigned_squad.size())
		return assigned_squad
	
	func _assign_players_by_nationality(player_pool: Dictionary, nationality: String, count: int, team_tier: int, position_filter: Dictionary = {}) -> Array:
		var assigned_players = []
		var attempts = 0
		var max_attempts = count * 50
		
		# Position-Anforderungen für den Anteil
		var position_targets = {
			"Torwart": max(1, int(count * 0.1)),    # ~10% Torhüter
			"Abwehr": max(2, int(count * 0.35)),    # ~35% Abwehr  
			"Mittelfeld": max(2, int(count * 0.35)), # ~35% Mittelfeld
			"Sturm": max(1, int(count * 0.2))       # ~20% Sturm
		}
		
		# Falls position_filter übergeben wurde, verwende diese
		if not position_filter.is_empty():
			position_targets = position_filter
		
		# FALLBACK-MECHANISMUS: Erweitere Nationalitäten-Suche
		var fallback_nationalities = _get_fallback_nationalities(nationality)
		var available_players = []
		
		# Primär: Exakte Nationalität
		for tier_key in player_pool.keys():
			for player in player_pool[tier_key]:
				if player.get("nationality", "") == nationality and not _assigned_players.has(player.player_id):
					available_players.append(player)
		
		# Fallback 1: Ähnliche Nationalitäten
		if available_players.size() < count:
			for fallback_nat in fallback_nationalities:
				for tier_key in player_pool.keys():
					for player in player_pool[tier_key]:
						if player.get("nationality", "") == fallback_nat and not _assigned_players.has(player.player_id):
							available_players.append(player)
		
		# Fallback 2: Beliebige Spieler im passenden Tier (NOTFALL)
		if available_players.size() < count:
			print("    WARNUNG: Nur %d Spieler für %s gefunden, fülle mit beliebigen Spielern auf" % [available_players.size(), nationality])
			for tier_key in player_pool.keys():
				# Nur passende Tiers verwenden
				if int(tier_key) <= team_tier + 2:  # Max 2 Tiers höher
					for player in player_pool[tier_key]:
						if not _assigned_players.has(player.player_id) and available_players.size() < count * 2:
							available_players.append(player)
		
		print("    %s: %d verfügbare Spieler (inkl. Fallbacks)" % [nationality, available_players.size()])
		
		# Organisiere nach Positionen
		var players_by_position = {"Torwart": [], "Abwehr": [], "Mittelfeld": [], "Sturm": []}
		for player in available_players:
			var position = player.get("primary_position", "Mittelfeld")
			players_by_position[position].append(player)
		
		# Weise pro Position zu
		for position in ["Torwart", "Abwehr", "Mittelfeld", "Sturm"]:
			var target = position_targets.get(position, 0)
			var position_players = players_by_position[position]
			
			# Sortiere nach Stärke (beste zuerst)
			position_players.sort_custom(func(a, b): return a.get("strength_overall_base", 1) > b.get("strength_overall_base", 1))
			
			var assigned_in_position = 0
			for player in position_players:
				if assigned_in_position >= target or assigned_players.size() >= count:
					break
				
				if not _assigned_players.has(player.player_id):
					_assigned_players[player.player_id] = true
					assigned_players.append(player)
					assigned_in_position += 1
		
		print("    %s: %d/%d Spieler zugewiesen" % [nationality, assigned_players.size(), count])
		return assigned_players
	
	func _get_fallback_nationalities(nationality: String) -> Array:
		"""Gibt ähnliche/verwandte Nationalitäten für Fallback zurück"""
		var fallback_map = {
			# Britische Inseln
			"England": ["Schottland", "Wales", "Irland", "International"],
			"Schottland": ["England", "Wales", "Irland", "International"], 
			"Wales": ["England", "Schottland", "Irland", "International"],
			"Irland": ["England", "Schottland", "Wales", "International"],
			
			# Iberische Halbinsel
			"Spanien": ["Portugal", "International"],
			"Portugal": ["Spanien", "International"],
			
			# Südamerika
			"Brasilien": ["Argentinien", "Uruguay", "Kolumbien", "Chile", "International"],
			"Argentinien": ["Brasilien", "Uruguay", "Chile", "International"],
			"Uruguay": ["Argentinien", "Brasilien", "International"],
			"Kolumbien": ["Brasilien", "Argentinien", "International"],
			"Chile": ["Argentinien", "Uruguay", "International"],
			
			# Balkan
			"Kroatien": ["Serbien", "Bosnien", "Slowenien", "International"],
			"Serbien": ["Kroatien", "Bosnien", "Montenegro", "International"],
			"Bosnien": ["Kroatien", "Serbien", "Montenegro", "International"],
			"Montenegro": ["Serbien", "Kroatien", "International"],
			
			# Skandinavien
			"Schweden": ["Norwegen", "Dänemark", "Finnland", "International"],
			"Norwegen": ["Schweden", "Dänemark", "International"],
			"Dänemark": ["Schweden", "Norwegen", "International"],
			"Finnland": ["Schweden", "Estland", "International"],
			
			# Westeuropa
			"Frankreich": ["Belgien", "Schweiz", "International"],
			"Belgien": ["Frankreich", "Niederlande", "International"],
			"Niederlande": ["Belgien", "Deutschland", "International"],
			"Italien": ["Schweiz", "Österreich", "International"],
			
			# Afrika
			"Marokko": ["Tunesien", "Algerien", "International"],
			"Tunesien": ["Marokko", "Algerien", "International"],
			"Algerien": ["Marokko", "Tunesien", "International"],
			"Nigeria": ["Ghana", "Senegal", "Elfenbeinküste", "International"],
			"Ghana": ["Nigeria", "Elfenbeinküste", "International"],
			"Senegal": ["Nigeria", "Elfenbeinküste", "International"],
			"Elfenbeinküste": ["Ghana", "Senegal", "International"],
			
			# Osteuropa
			"Polen": ["Tschechien", "Slowakei", "Deutschland", "International"],
			"Tschechien": ["Slowakei", "Polen", "Ungarn", "International"],
			"Slowakei": ["Tschechien", "Polen", "Ungarn", "International"],
			"Ungarn": ["Österreich", "Tschechien", "International"],
			
			# Asien
			"Japan": ["Südkorea", "International"],
			"Südkorea": ["Japan", "International"],
			
			# Default Fallbacks
			"International": ["Brasilien", "Argentinien", "Spanien", "Italien"]
		}
		
		return fallback_map.get(nationality, ["International"])
	
	func _get_emergency_players(player_pool: Dictionary, needed: int, max_tier: int) -> Array:
		"""Notfall-Funktion: Holt beliebige verfügbare Spieler"""
		var emergency_players = []
		
		print("    NOTFALL: Suche %d beliebige Spieler (max Tier %d)" % [needed, max_tier])
		
		# Durchsuche alle Tiers bis max_tier
		for tier in range(1, max_tier + 3):  # +3 für mehr Flexibilität
			var tier_key = str(tier)
			if player_pool.has(tier_key):
				for player in player_pool[tier_key]:
					if not _assigned_players.has(player.player_id) and emergency_players.size() < needed:
						_assigned_players[player.player_id] = true
						emergency_players.append(player)
						
						if emergency_players.size() >= needed:
							break
			if emergency_players.size() >= needed:
				break
		
		print("    NOTFALL: %d Spieler gefunden" % emergency_players.size())
		return emergency_players
	
	func _get_remaining_position_needs(current_squad: Array, total_squad_size: int) -> Dictionary:
		# Berechne wie viele Spieler pro Position noch benötigt werden
		var current_counts = {"Torwart": 0, "Abwehr": 0, "Mittelfeld": 0, "Sturm": 0}
		for player in current_squad:
			var position = player.get("primary_position", "Mittelfeld")
			current_counts[position] += 1
		
		var remaining_slots = total_squad_size - current_squad.size()
		var target_counts = {
			"Torwart": max(2, int(total_squad_size * 0.1)),
			"Abwehr": max(6, int(total_squad_size * 0.35)),
			"Mittelfeld": max(6, int(total_squad_size * 0.35)),
			"Sturm": max(3, int(total_squad_size * 0.2))
		}
		
		var remaining_needs = {}
		for position in current_counts.keys():
			var needed = target_counts[position] - current_counts[position]
			if needed > 0:
				remaining_needs[position] = needed
		
		return remaining_needs

	func _generate_stadium_details(team_info: Dictionary) -> Dictionary:
		var tier = team_info.tier
		return {
			"stadium_name": team_info.stadium_name,
			"stadium_capacity": team_info.stadium_capacity,
			"has_pitch_heating": tier <= 6,
			"scoreboard_type": max(0, 4 - tier),
			"floodlight_strength": 1200 + (tier - 1) * -150
		}

	func _calculate_initial_popularity(team_info: Dictionary) -> Dictionary:
		var base_pop = 50.0
		var tier_mod = (4 - team_info.tier) * 5.0
		var city_size_mod = 0.0
		if team_info.stadium_capacity > 60000:
			city_size_mod = 10.0
		elif team_info.stadium_capacity < 15000:
			city_size_mod = -10.0
		var success_mod = 0.0
		if team_info.last_season_placement == 1 and team_info.league_name == "1. Bundesliga":
			success_mod = 25.0
		elif team_info.last_season_placement <= 4:
			success_mod = 10.0
		var fans = clampi(roundi(base_pop + tier_mod + city_size_mod + success_mod + randf_range(-5, 5)), 10, 100)
		var board = clampi(roundi(base_pop + tier_mod + success_mod * 1.5 + randf_range(-5, 5)), 15, 100)
		return {"fans": fans, "board": board}

	# Überarbeitete und verbesserte Funktion zur Berechnung der Teammoral
	func _calculate_initial_morale(team_info: Dictionary) -> int:
		var morale = 0
		var placement = team_info.last_season_placement
		
		# 1. Grundmoral basierend auf der Stärkeklasse (Tier)
		match team_info.tier:
			1, 2: morale = 6
			3, 4: morale = 5
			5: morale = 4
			_: morale = 3

		# 2. Bonus/Malus für Ligaplatzierung (nur für Ligamannschaften relevant)
		if team_info.league_name in ["1. Bundesliga", "2. Bundesliga", "3. Liga"]:
			if placement == 1:
				morale += 3 # Meister-Bonus
			elif placement >= 2 and placement <= 4:
				morale += 2 # Top-Platzierung
			elif placement >= 5 and placement <= 8:
				morale += 1 # Gute Saison
			elif placement >= 14 and placement <= 16:
				morale -= 1 # Schwache Saison
			elif placement >= 17:
				morale -= 3 # Abstieg

		# 3. Zusätzlicher Aufstiegs-Bonus
		# Annahme: Ein Team in Liga X mit Platz 1-3 aus der Vorsaison ist aufgestiegen
		var is_promoted = false
		if team_info.league_name == "1. Bundesliga" and (placement == 1 or placement == 2):
			is_promoted = true # Aufsteiger aus der 2. Bundesliga
		if team_info.league_name == "2. Bundesliga" and (placement >= 1 and placement <= 3):
			is_promoted = true # Aufsteiger aus der 3. Liga
		
		if is_promoted:
			morale += 2

		# 4. Zufallsfaktor und Begrenzung auf Skala 0-10
		morale += randi_range(-1, 1)
		return clampi(morale, 0, 10)

	func _load_json_from_path(path: String) -> Variant:
		if not FileAccess.file_exists(path):
			return null
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
