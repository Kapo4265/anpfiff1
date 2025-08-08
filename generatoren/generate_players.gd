# res://scripts/generators/generate_players.gd
# FINALE VERSION: Mit realistischer, Tier-basierter Nationalitäten-Verteilung.
@tool
extends EditorScript

func _run():
	var generator = PlayerGenerator.new()
	generator.generate_and_save()

class PlayerGenerator:
	const OUTPUT_PATH = "res://data/master_players_pool.json"

	const TIERS = {
		1: {"count": 300, "avg_str": 6.0, "str_dev": 0.5, "min_pot": 85, "max_pot": 99},
		2: {"count": 300, "avg_str": 5.2, "str_dev": 0.6, "min_pot": 75, "max_pot": 92},
		3: {"count": 600, "avg_str": 4.5, "str_dev": 0.7, "min_pot": 65, "max_pot": 88},
		4: {"count": 800, "avg_str": 3.5, "str_dev": 0.8, "min_pot": 60, "max_pot": 82},
		5: {"count": 1200, "avg_str": 2.8, "str_dev": 0.9, "min_pot": 50, "max_pot": 78},
		6: {"count": 1400, "avg_str": 2.0, "str_dev": 1.0, "min_pot": 40, "max_pot": 75},
		7: {"count": 1400, "avg_str": 1.5, "str_dev": 0.7, "min_pot": 30, "max_pot": 68},
		8: {"count": 1000, "avg_str": 1.2, "str_dev": 0.5, "min_pot": 20, "max_pot": 60}
	}

	# Realistische Nationalitäten-Verteilung basierend auf Transfermarkt.de 2024
	# 1. Bundesliga: 48% Deutsche, 52% Ausländer
	# 2. Bundesliga: 66.2% Deutsche, 33.8% Ausländer  
	# 3. Liga: 79.2% Deutsche, 20.8% Ausländer
	# NEUE REALISTISCHE VERTEILUNG: Mehr internationale Spieler in höheren Tiers für EU-Teams
	const NATIONALITY_DIST_BY_TIER = {
		# Tier 1: Elite-Spieler (Champions League Niveau)
		1: {"Deutschland": 0.25, "Spanien": 0.08, "England": 0.07, "Frankreich": 0.07, "Italien": 0.06,
			"Brasilien": 0.08, "Argentinien": 0.06, "Portugal": 0.04, "Niederlande": 0.03, "Belgien": 0.02,
			"Kroatien": 0.02, "Uruguay": 0.01, "Kolumbien": 0.01, "Senegal": 0.01, "Nigeria": 0.01,
			"Marokko": 0.01, "Algerien": 0.01, "Elfenbeinküste": 0.01, "Ghana": 0.01, "Japan": 0.01,
			"Südkorea": 0.01, "Mexiko": 0.01, "USA": 0.01, "Kanada": 0.005, "Chile": 0.005,
			"Serbien": 0.005, "Polen": 0.005, "Türkei": 0.02, "International": 0.07},
		
		# Tier 2: Sehr gute Spieler (Europa League Niveau)
		2: {"Deutschland": 0.28, "Spanien": 0.06, "England": 0.06, "Frankreich": 0.06, "Italien": 0.05,
			"Brasilien": 0.06, "Argentinien": 0.04, "Portugal": 0.03, "Niederlande": 0.03, "Belgien": 0.02,
			"Türkei": 0.03, "Polen": 0.02, "Österreich": 0.02, "Schweiz": 0.01, "Dänemark": 0.01,
			"Schweden": 0.01, "Kroatien": 0.01, "Tschechien": 0.01, "Ungarn": 0.01, "Griechenland": 0.01,
			"Serbien": 0.01, "Ukraine": 0.01, "Russland": 0.01, "Tunesien": 0.005, "Japan": 0.005,
			"USA": 0.005, "Mexiko": 0.005, "Kolumbien": 0.005, "Uruguay": 0.005, "International": 0.10},
		# Tier 3: Gute Spieler (Conference League / 2. Liga Niveau)
		3: {"Deutschland": 0.35, "Spanien": 0.04, "England": 0.04, "Frankreich": 0.04, "Italien": 0.03,
			"Portugal": 0.02, "Niederlande": 0.02, "Belgien": 0.02, "Türkei": 0.04, "Polen": 0.03,
			"Österreich": 0.03, "Schweiz": 0.02, "Dänemark": 0.02, "Schweden": 0.02, "Norwegen": 0.01,
			"Tschechien": 0.01, "Ungarn": 0.01, "Kroatien": 0.01, "Serbien": 0.01, "Griechenland": 0.01,
			"Schottland": 0.01, "Brasilien": 0.02, "Argentinien": 0.01, "Japan": 0.01, "USA": 0.01,
			"Bosnien": 0.005, "Albanien": 0.005, "Kosovo": 0.005, "International": 0.15},
		
		# Tier 4: Durchschnittliche Spieler (3. Liga Niveau)
		4: {"Deutschland": 0.40, "Türkei": 0.05, "Polen": 0.04, "Österreich": 0.03, "Schweiz": 0.02,
			"Frankreich": 0.03, "Spanien": 0.02, "Italien": 0.02, "England": 0.02, "Niederlande": 0.02,
			"Belgien": 0.01, "Dänemark": 0.01, "Schweden": 0.01, "Norwegen": 0.01, "Finnland": 0.01,
			"Tschechien": 0.01, "Ungarn": 0.01, "Kroatien": 0.01, "Serbien": 0.01, "Bosnien": 0.01,
			"Kosovo": 0.01, "Albanien": 0.01, "Bulgarien": 0.01, "Rumänien": 0.01, "Griechenland": 0.01,
			"Slowakei": 0.005, "Slowenien": 0.005, "International": 0.18},
		# Tier 5-6: Unterdurchschnittliche Spieler (Regional/Amateur)
		5: {"Deutschland": 0.50, "Türkei": 0.05, "Österreich": 0.04, "Polen": 0.03, "Kosovo": 0.02,
			"Schweiz": 0.02, "Frankreich": 0.02, "Italien": 0.01, "Spanien": 0.01, "Kroatien": 0.02,
			"Serbien": 0.02, "Bosnien": 0.01, "Albanien": 0.01, "Tschechien": 0.01, "Ungarn": 0.01,
			"Dänemark": 0.01, "Schweden": 0.01, "Norwegen": 0.01, "Finnland": 0.01, "Bulgarien": 0.01,
			"Rumänien": 0.01, "Slowakei": 0.01, "Slowenien": 0.01, "Griechenland": 0.01, "Montenegro": 0.005,
			"Georgien": 0.005, "Lettland": 0.005, "Estland": 0.005, "Litauen": 0.005, "International": 0.135},
		
		6: {"Deutschland": 0.55, "Türkei": 0.05, "Österreich": 0.03, "Polen": 0.03, "Kosovo": 0.02,
			"Schweiz": 0.02, "Kroatien": 0.02, "Serbien": 0.02, "Bosnien": 0.01, "Albanien": 0.01,
			"Tschechien": 0.01, "Ungarn": 0.01, "Frankreich": 0.01, "Italien": 0.01, "Spanien": 0.01,
			"Dänemark": 0.01, "Schweden": 0.01, "Norwegen": 0.01, "Finnland": 0.01, "Bulgarien": 0.01,
			"Rumänien": 0.01, "Slowakei": 0.01, "Slowenien": 0.01, "Griechenland": 0.01, "Montenegro": 0.005,
			"Georgien": 0.005, "Lettland": 0.005, "Estland": 0.005, "Litauen": 0.005, "International": 0.115},
		# Tier 7-8: Schwache Spieler (Kreisliga/Amateur)  
		7: {"Deutschland": 0.65, "Türkei": 0.04, "Österreich": 0.02, "Polen": 0.02, "Kosovo": 0.02,
			"Kroatien": 0.015, "Serbien": 0.015, "Bosnien": 0.01, "Albanien": 0.01, "Schweiz": 0.01,
			"Tschechien": 0.01, "Ungarn": 0.01, "Bulgarien": 0.01, "Rumänien": 0.01, "Slowakei": 0.01,
			"Slowenien": 0.01, "Griechenland": 0.005, "Montenegro": 0.005, "Georgien": 0.005, "Finnland": 0.005,
			"Norwegen": 0.005, "Dänemark": 0.005, "Schweden": 0.005, "Lettland": 0.005, "Estland": 0.005,
			"Litauen": 0.005, "Island": 0.003, "Malta": 0.003, "Zypern": 0.003, "International": 0.089},
		
		8: {"Deutschland": 0.70, "Türkei": 0.04, "Österreich": 0.02, "Polen": 0.015, "Kosovo": 0.015,
			"Kroatien": 0.01, "Serbien": 0.01, "Bosnien": 0.01, "Albanien": 0.01, "Schweiz": 0.01,
			"Tschechien": 0.01, "Ungarn": 0.01, "Bulgarien": 0.01, "Rumänien": 0.01, "Slowakei": 0.005,
			"Slowenien": 0.005, "Griechenland": 0.005, "Montenegro": 0.005, "Georgien": 0.005, "Finnland": 0.005,
			"Norwegen": 0.005, "Dänemark": 0.005, "Schweden": 0.005, "Lettland": 0.005, "Estland": 0.005,
			"Litauen": 0.005, "Aserbaidschan": 0.003, "Island": 0.003, "Malta": 0.003, "Zypern": 0.003,
			"Israel": 0.003, "Mazedonien": 0.003, "International": 0.081}
	}

	const NAME_DATA = {
		"Deutschland": {"first_names": ["Alexander", "Andreas", "Anton", "Axel", "Benedikt", "Benjamin", "Bernd", "Christian", "Christoph", "Daniel", "David", "Dominik", "Elias", "Emil", "Fabian", "Felix", "Finn", "Florian", "Frank", "Georg", "Hans", "Heiko", "Henri", "Jakob", "Jan", "Jannik", "Jens", "Joachim", "Johannes", "Jonas", "Jonathan", "Julian", "Kai", "Karl", "Kevin", "Leo", "Leon", "Liam", "Linus", "Louis", "Luca", "Lucas", "Luis", "Lukas", "Marcel", "Marcus", "Marius", "Martin", "Mats", "Max", "Michael", "Moritz", "Nico", "Niklas", "Noah", "Ole", "Oskar", "Pascal", "Paul", "Peter", "Philipp", "Raphael", "René", "Sebastian", "Simon", "Stefan", "Theo", "Thomas", "Till", "Tim", "Tobias", "Tom", "Torsten", "Uwe", "Viktor", "Vincent", "Walter", "Werner", "Yannik", "Adrian", "Arne", "Björn", "Dennis", "Erik", "Frederik", "Gerrit", "Holger", "Ingo", "Jörg", "Kurt", "Lars", "Marco", "Niels", "Olaf", "Ralf", "Robin", "Sven", "Timo", "Volker", "Wolfgang", "Ahmed", "Ali", "Amin", "Omar", "Yusuf", "Mohammed", "Mehmet", "Emre", "Can", "Deniz", "Ibrahim", "Musa", "Ismail", "Cem", "Erhan", "Mustafa", "Serkan", "Hakan", "Koray", "Kerem", "Mert", "Okan", "Erdem", "Furkan", "Baran", "Devin", "Jamal", "Nabil", "Rayan", "Samir", "Aron", "Ivan", "Sergej", "Nikolai", "Artur", "Alexei", "Dmitri", "Viktor", "Stanislav", "Grigori", "Mateo", "Thiago", "Diego", "Mateusz", "Filip", "Janek", "Adam", "Kacper", "Maksymilian", "Olek", "Santiago", "Joaquim", "Miguel", "Ricardo", "Gabriel", "Bruno", "Cristiano", "Fabio", "Leonardo", "Giovanni", "Antonio", "Vincenzo", "Giuseppe", "Marco", "Angelo", "Luca", "Matteo", "Domenico", "Francesco", "Salvatore", "Kwame", "Kofi", "Abdul", "Chinedu", "Dapo", "Tariq", "Zayd", "Malik", "Rohan", "Sanjay", "Aydin", "Ugur", "Fritz", "Otto", "Knut", "Heino", "Rudi", "Kalle", "Gustav", "Poldi", "Hasso", "Willi", "Siegfried", "Franz", "Kasimir", "Adalbert", "Bartholomäus", "Egon", "Waldemar", "Günther", "Horst", "Manfred", "Zottel", "Wackel", "Gurken", "Schlumpf", "Schnitzel", "Popo", "Lulatsch", "Meister", "Held"], "last_names": ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Schäfer", "Koch", "Richter", "Bauer", "Klein", "Wolf", "Hoffmann", "Schulz", "Braun", "Hofmann", "Meier", "Becker", "Schwarz", "Reese", "Thiel", "Kaiser", "Frank", "Weller", "Herrmann", "Voigt", "Barth", "Scholz", "Schmitt", "Huber", "Maier", "Schuster", "Baumann", "Dietrich", "Fleischer", "Gärtner", "Lehmann", "Krause", "Vogel", "Friedrich", "Berger", "Arnold", "Merkel", "Götz", "Hahn", "Abt", "Ackermann", "Adam", "Albrecht", "Appel", "Arndt", "Bachmann", "Behrens", "Benz", "Binder", "Blank", "Böhm", "Böhme", "Born", "Brandt", "Bremer", "Busch", "Diehl", "Dittrich", "Ebert", "Eckert", "Endres", "Engel", "Ernst", "Fuchs", "Geiger", "Graf", "Groß", "Haase", "Heck", "Hein", "Heinrich", "Hellwig", "Henke", "Heyer", "Hilpert", "Hinz", "Hirsch", "Jäger", "Kern", "Köhler", "Kolb", "Kramer", "Krebs", "Kuhn", "Lang", "Lauer", "Lenz", "Lieb", "Lindner", "List", "Lorenz", "Marx", "Meister", "Moser", "Nagel", "Naumann", "Neubert", "Neumann", "Niemeyer", "Oehler", "Orth", "Paulus", "Peters", "Pfeiffer", "Probst", "Rau", "Reich", "Reuter", "Riehl", "Ries", "Römer", "Roth", "Sander", "Schmitt", "Schnell", "Seidl", "Seifert", "Sommer", "Späth", "Stein", "Steiner", "Strobel", "Trautmann", "Ullrich", "Vogt", "Walther", "Wenzel", "Wetzel", "Wiegand", "Wild", "Winter", "Ziegler", "Demir", "Yilmaz", "Can", "Kaya", "Öztürk", "Aslan", "Polat", "Türk", "Kilic", "Demirci", "Schmidt", "Nowak", "Kowalski", "Lewandowski", "Wojcik", "Kaczmarek", "Majewski", "Jankowski", "Wozniak", "Kaminski", "Popov", "Ivanov", "Smirnov", "Volkov", "Kuznetsov", "Sokolov", "Lebedev", "Frolov", "Nikitin", "Morozov", "Diaz", "Gomez", "Sanchez", "Perez", "Garcia", "Martinez", "Rodriguez", "Lopez", "Hernandez", "Gonzalez", "Silva", "Santos", "Oliveira", "Souza", "Lima", "Fernandes", "Costa", "Rodrigues", "Alves", "Pereira", "Rossi", "Ferrari", "Russo", "Bianchi", "Romano", "Ricci", "Bruno", "Conte", "Esposito", "Gallo", "Mohammed", "Ali", "Khan", "Hussain", "Ahmed", "Syed", "Shah", "Sheikh", "Malik", "Butt", "Nzou", "Camara", "Diop", "Keita", "Kone", "Traore", "Diallo", "Sow", "Ndour", "Cissé", "Kaplan", "Möhrchen", "Zapfenberger", "Kloppholz", "Zottel", "Wackel", "Schildkröt", "Bärentatz", "Hasenfuß", "Gurkenkopf", "Wurstbrot", "Schneemann", "Goldfuß", "Sturmfels", "Blitzschlag", "Donnerkeil", "Sonnenschein", "Regenbogen", "Wolkenbruch", "Feuerschein", "Eichhorn", "Dreckschaufel", "Hackbrett", "Zuckerguss", "Fussballgott", "Supermann", "Knallkopf", "Witzbold", "Sockenpuppe", "Regalbrett", "Gänseblümchen"]},
		"England": {"first_names": ["Harry", "Jack", "George", "Oliver", "James", "William", "Thomas", "Charlie", "Oscar", "Henry", "Alexander", "Leo", "Alfie", "Mason", "Jacob", "Michael", "Daniel", "Samuel", "Luke", "Joseph", "Benjamin", "Ethan", "Noah", "Lewis", "Max", "Edward", "Finley", "Arthur", "Sebastian", "Logan", "Ryan", "Isaac", "Callum", "Nathan", "Adam", "Jake", "Harrison", "Matthew", "Owen", "Freddie", "Theo", "Robert", "David", "Connor", "Joshua", "Liam", "Tyler", "Toby", "Zachary", "Cameron"], "last_names": ["Smith", "Jones", "Taylor", "Brown", "Williams", "Wilson", "Johnson", "Davies", "Robinson", "Wright", "Thompson", "Evans", "Walker", "White", "Roberts", "Green", "Hall", "Wood", "Jackson", "Clarke", "Harris", "Lewis", "Martin", "Cooper", "Turner", "Hill", "Ward", "Morgan", "Baker", "Harrison", "Edwards", "Collins", "Clark", "Young", "King", "Scott", "Adams", "Campbell", "Anderson", "Moore", "Parker", "Phillips", "Mitchell", "Stewart", "Carter", "Morris", "Cook", "Rogers", "Reed", "Murphy"]},
		"Spanien": {"first_names": ["Hugo", "Martin", "Lucas", "Mateo", "Pablo", "Alejandro", "Daniel", "Adrian", "David", "Alvaro", "Diego", "Leo", "Nicolas", "Manuel", "Jorge", "Mario", "Carlos", "Antonio", "Angel", "Bruno", "Sergio", "Gonzalo", "Rafael", "Fernando", "Victor", "Luis", "Francisco", "Raul", "Pedro", "Miguel", "Javier", "Jose", "Juan", "Eduardo", "Alberto", "Andres", "Ruben", "Ivan", "Oscar", "Rodrigo", "Hector", "Gabriel", "Marcos", "Aaron", "Izan", "Alex", "Samuel", "Jaime", "Thiago", "Iker"], "last_names": ["Garcia", "Rodriguez", "Gonzalez", "Fernandez", "Lopez", "Martinez", "Sanchez", "Perez", "Gomez", "Martin", "Jimenez", "Ruiz", "Hernandez", "Diaz", "Moreno", "Munoz", "Alvarez", "Romero", "Alonso", "Gutierrez", "Navarro", "Torres", "Dominguez", "Vazquez", "Ramos", "Gil", "Ramirez", "Serrano", "Blanco", "Molina", "Morales", "Ortega", "Delgado", "Castro", "Ortiz", "Rubio", "Marin", "Sanz", "Iglesias", "Nuñez", "Medina", "Garrido", "Santos", "Castillo", "Cortes", "Lozano", "Guerrero", "Cano", "Prieto", "Mendez"]},
		"Italien": {"first_names": ["Leonardo", "Francesco", "Alessandro", "Lorenzo", "Mattia", "Andrea", "Gabriele", "Riccardo", "Tommaso", "Edoardo", "Matteo", "Giuseppe", "Antonio", "Federico", "Giovanni", "Marco", "Luca", "Simone", "Davide", "Nicolo", "Samuele", "Pietro", "Filippo", "Emanuele", "Cristian", "Michele", "Alberto", "Stefano", "Manuel", "Diego", "Gioele", "Samuel", "Giulio", "Daniele", "Gabriel", "Christian", "Paolo", "Jacopo", "Nathan", "Thomas", "Vincenzo", "Angelo", "Elia", "Enea", "Noah", "Alessio", "Giorgio", "Nicolas", "Salvatore", "Domenico"], "last_names": ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti", "De Luca", "Mancini", "Costa", "Giordano", "Rizzo", "Lombardi", "Moretti", "Barbieri", "Fontana", "Santoro", "Mariani", "Rinaldi", "Caruso", "Ferrara", "Galli", "Martini", "Leone", "Longo", "Gentile", "Martinelli", "Vitale", "Lombardo", "Serra", "Coppola", "De Santis", "D'Angelo", "Marchetti", "Parisi", "Villa", "Conte", "Ferretti", "Palumbo", "Pellegrini", "Piras", "Fabbri", "Farina", "Battaglia"]},
		"Frankreich": {"first_names": ["Léo", "Gabriel", "Raphaël", "Arthur", "Louis", "Lucas", "Adam", "Jules", "Hugo", "Maël", "Liam", "Noah", "Ethan", "Mathis", "Nathan", "Théo", "Sacha", "Noa", "Tom", "Samuel", "Yanis", "Gabin", "Aaron", "Mohamed", "Timéo", "Valentin", "Maxime", "Antoine", "Paul", "Alexandre", "Diego", "Enzo", "Victor", "Martin", "Axel", "Kylian", "Léon", "Rayan", "Benjamin", "Marius", "Baptiste", "Pierre", "Jean", "Thomas", "Clément", "Loïc", "Vincent", "Nicolas", "Olivier", "Julien"], "last_names": ["Martin", "Bernard", "Thomas", "Petit", "Robert", "Richard", "Durand", "Dubois", "Moreau", "Laurent", "Simon", "Michel", "Lefebvre", "Leroy", "Roux", "David", "Bertrand", "Morel", "Fournier", "Girard", "Bonnet", "Dupont", "Lambert", "Fontaine", "Rousseau", "Vincent", "Muller", "Lefevre", "Faure", "Andre", "Mercier", "Blanc", "Guerin", "Boyer", "Garnier", "Chevalier", "Francois", "Legrand", "Gauthier", "Garcia", "Perrin", "Robin", "Clement", "Morin", "Nicolas", "Henry", "Roussel", "Mathieu", "Gautier", "Masson"]},
		"Brasilien": {"first_names": ["Miguel", "Arthur", "Heitor", "Bernardo", "Gabriel", "Davi", "Lorenzo", "Théo", "Pedro", "Enzo", "Matheus", "Lucas", "Benjamin", "Nicolas", "Guilherme", "Rafael", "Joaquim", "Samuel", "João Miguel", "Henrique", "Gustavo", "Murilo", "Pedro Henrique", "Pietro", "Lucca", "Felipe", "João Pedro", "Cauã", "Isaac", "Caio", "Vinicius", "Leonardo", "Levi", "Bryan", "João", "Luan", "Enzo Gabriel", "Ian", "Ravi", "Fernando", "Marcelo", "Antônio", "João Vitor", "Calebe", "Daniel", "Otávio", "Augusto", "Emanuel", "Benício", "Davi Lucca"], "last_names": ["da Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes", "Ribeiro", "Carvalho", "Almeida", "Lopes", "Soares", "Fernandes", "Vieira", "Barbosa", "Rocha", "Dias", "Monteiro", "Mendes", "Freitas", "Martins", "Costa", "Pinto", "Araújo", "Cardoso", "Nascimento", "Reis", "Castro", "Andrade", "Moreira", "Ramos", "Cunha", "Teixeira", "Correia", "Nunes", "Melo", "Campos", "Moura", "Azevedo", "Silveira", "Farias", "Cavalcanti", "Macedo", "Xavier", "Vasconcelos", "Batista", "Nogueira"]},
		"Argentinien": {"first_names": ["Mateo", "Bautista", "Juan", "Felipe", "Thiago", "Santiago", "Benjamín", "Lautaro", "Nicolás", "Tomás", "Joaquín", "Valentino", "Facundo", "Agustín", "Máximo", "Emiliano", "Bruno", "Alonso", "Santino", "Ignacio", "Matías", "Lucas", "Gael", "Francisco", "Rodrigo", "Dante", "Renato", "Tobías", "Ian", "León", "Luciano", "Lorenzo", "Esteban", "Gabriel", "Fernando", "Manuel", "Martín", "Sebastián", "Diego", "Pablo", "Alejandro", "Adrián", "Cristian", "Damián", "Eduardo", "Gonzalo", "Gastón", "Hernán", "Iván", "Javier"], "last_names": ["Gonzalez", "Rodriguez", "Gomez", "Fernandez", "Lopez", "Martinez", "Perez", "Garcia", "Sanchez", "Romero", "Sosa", "Pereyra", "Acosta", "Medina", "Herrera", "Aguilar", "Gutierrez", "Jimenez", "Ruiz", "Hernandez", "Diaz", "Morales", "Muñoz", "Alvarez", "Castillo", "Torres", "Vargas", "Ramos", "Castro", "Ortega", "Dominguez", "Guerrero", "Mendez", "Silva", "Rojas", "Moreno", "Vazquez", "Contreras", "Luna", "Ortiz", "Espinoza", "Molina", "Flores", "Rivera", "Gomez", "Cabrera", "Jimenez", "Navarro", "Cáceres", "Miranda"]},
		"Portugal": {"first_names": ["João", "Francisco", "Afonso", "Duarte", "Tomás", "Gabriel", "Gonçalo", "Miguel", "Martim", "Santiago", "Dinis", "Salvador", "Rodrigo", "Diego", "Rafael", "Pedro", "António", "Vicente", "Gustavo", "Lucas", "Simão", "Mateus", "David", "José", "Leonardo", "Henrique", "Daniel", "Alexandre", "Enzo", "Lourenço", "Samuel", "Tiago", "Eduardo", "Isaac", "Noah", "Benjamim", "Manuel", "Nuno", "André", "Carlos", "Rúben", "Paulo", "Ricardo", "Bruno", "Hugo", "Diogo", "Luís", "Marco", "Sérgio", "Filipe"], "last_names": ["Silva", "Santos", "Ferreira", "Pereira", "Oliveira", "Costa", "Rodrigues", "Martins", "Jesus", "Sousa", "Fernandes", "Gonçalves", "Gomes", "Lopes", "Marques", "Alves", "Almeida", "Ribeiro", "Pinto", "Carvalho", "Teixeira", "Moreira", "Correia", "Mendes", "Nunes", "Soares", "Vieira", "Monteiro", "Cardoso", "Rocha", "Neves", "Coelho", "Cruz", "Cunha", "Pires", "Ramos", "Reis", "Simões", "Antunes", "Matos", "Fonseca", "Morais", "Barbosa", "Machado", "Guerreiro", "Lourenço", "Marques", "Campos", "Freitas", "Castro"]},
		"Niederlande": {"first_names": ["Daan", "Bram", "Sem", "Lucas", "Liam", "Milan", "Levi", "Noah", "Finn", "Luuk", "Noud", "Thijs", "Lars", "Mees", "James", "Samuel", "Floris", "Teun", "Adam", "Benjamin", "Jesse", "Mason", "Gijs", "Stijn", "Olivier", "Sven", "Julian", "Koen", "Tim", "Thomas", "Morris", "Dean", "Hugo", "Joep", "Tobias", "Max", "Alexander", "Ryan", "David", "Nathan", "Jayden", "Cas", "Ruben", "Jens", "Mats", "Oscar", "Leon", "Niels", "Job", "Aiden"], "last_names": ["de Jong", "Jansen", "de Vries", "van den Berg", "van Dijk", "Bakker", "Janssen", "Visser", "Smit", "Meijer", "de Boer", "Mulder", "de Groot", "Bos", "Vos", "Peters", "Hendriks", "van Leeuwen", "Dekker", "Brouwer", "de Wit", "Dijkstra", "Smits", "de Graaf", "van der Meer", "van der Laan", "Koning", "Vermeulen", "van Dijk", "Kok", "Jacobs", "de Haan", "van den Heuvel", "van der Heijden", "van der Berg", "Schouten", "van Nieuwenhuizen", "Hoekstra", "van Leeuwen", "Willems", "van der Veen", "Scholten", "van der Wal", "Post", "Witlox", "Prins", "Blom", "Huisman", "van der Pol", "de Lange"]},
		"Belgien": {"first_names": ["Arthur", "Noah", "Louis", "Lucas", "Liam", "Adam", "Jules", "Gabriel", "Victor", "Raphaël", "Léon", "Hugo", "Mohamed", "Aaron", "Maël", "Finn", "Oscar", "Mathis", "Nathan", "Samuel", "Lewis", "Rayan", "Théo", "Yanis", "Axel", "Ibrahim", "Mattéo", "Maxime", "Sacha", "Diego", "Noa", "Benjamin", "Alexander", "Ethan", "Milan", "Tiago", "Leon", "Antoine", "Kylian", "Alexandre", "Thomas", "Martin", "Pierre", "Jean", "Paul", "Vincent", "Nicolas", "Olivier", "Julien", "Philippe"], "last_names": ["Peeters", "Janssens", "Maes", "Jacobs", "Mertens", "Willems", "Claes", "Goossens", "Wouters", "De Smet", "Dubois", "Lambert", "Dupont", "Moreau", "Laurent", "Simon", "Martin", "Durand", "Leroy", "Roux", "Petit", "Morel", "Fournier", "Girard", "Bonnet", "Robert", "Richard", "Duval", "Lemaire", "Dufour", "Leclerc", "Mercier", "Fabre", "Blanc", "Guerin", "Muller", "Henry", "Rousseau", "Nicolas", "Perrin", "Morin", "Mathieu", "Clement", "Gauthier", "Dumont", "Lopez", "Fontaine", "Chevalier", "Robin", "Masson"]},
		"Türkei": {"first_names": ["Yusuf", "Eymen", "Ömer", "Mustafa", "Mehmet", "Ahmet", "Emir", "Berat", "Kaan", "Efe", "Aslan", "Miraç", "Ali", "Hamza", "Alparslan", "Kerem", "Çınar", "Mert", "Arda", "Emirhan", "Alperen", "Berkay", "Burak", "Oğuz", "Emre", "Batuhan", "Furkan", "Deniz", "Barış", "Kemal", "Hasan", "İbrahim", "Özgür", "Serkan", "Koray", "Tolga", "Erdem", "Onur", "Tuncay", "Volkan", "Gökhan", "Selim", "Yasin", "Hakan", "Uğur", "Orhan", "Tarık", "Sinan", "Cihan", "Engin"], "last_names": ["Yılmaz", "Kaya", "Demir", "Çelik", "Şahin", "Yıldız", "Yıldırım", "Öztürk", "Aydin", "Özkan", "Kaplan", "Çetin", "Kara", "Koç", "Kurt", "Özdemir", "Arslan", "Doğan", "Kilic", "Aslan", "Çakır", "Eren", "Güneş", "Pek", "Karagöz", "Polat", "Taş", "Soylu", "Karaca", "Uzun", "Korkmaz", "Keskin", "Yaman", "Şen", "Bozkurt", "Özer", "Akın", "Türk", "Güler", "Tekin", "Bulut", "Ceylan", "Işık", "Önal", "Kaynak", "Konak", "Erdoğan", "Turan", "Bora", "Çolak"]},
		"Polen": {"first_names": ["Antoni", "Jan", "Jakub", "Aleksander", "Franciszek", "Mikołaj", "Wojciech", "Filip", "Kacper", "Michał", "Stanisław", "Marcel", "Wiktor", "Piotr", "Igor", "Leon", "Adam", "Maksymilian", "Natan", "Nikodem", "Oliwier", "Tymoteusz", "Bartosz", "Krzysztof", "Mateusz", "Patryk", "Szymon", "Tomasz", "Dawid", "Daniel", "Oskar", "Gabriel", "Hubert", "Dominik", "Marcin", "Paweł", "Sebastian", "Kamil", "Grzegorz", "Artur", "Robert", "Maciej", "Łukasz", "Jarosław", "Andrzej", "Rafał", "Marek", "Dariusz", "Mariusz", "Jacek"], "last_names": ["Nowak", "Kowalski", "Wiśniewski", "Wójcik", "Kowalczyk", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski", "Kozłowski", "Jankowski", "Mazur", "Wojciechowski", "Kwiatkowski", "Krawczyk", "Kaczmarek", "Piotrowski", "Grabowski", "Zając", "Pawłowski", "Michalski", "Król", "Wieczorek", "Jabłoński", "Wróbel", "Nowakowski", "Majewski", "Olszewski", "Jaworski", "Malinowski", "Stępień", "Górski", "Rutkowski", "Witkowski", "Walczak", "Sikora", "Baran", "Duda", "Szewczyk", "Tomaszewski", "Pietrzak", "Marciniak", "Wróblewski", "Zalewski", "Jakubowski", "Jasinski", "Zawadzki", "Sawicki"]},
		"Kroatien": {"first_names": ["Luka", "David", "Jakov", "Petar", "Ivan", "Marko", "Ante", "Josip", "Matej", "Filip", "Dario", "Mario", "Zvonimir", "Nikola", "Tomislav"], "last_names": ["Horvat", "Kovačević", "Babić", "Marić", "Novak", "Perić", "Jurić", "Matić", "Popović", "Šimić", "Božić", "Radić", "Knežević", "Pavić", "Lovrić"]},
		"Dänemark": {"first_names": ["William", "Noah", "Oscar", "Alfred", "Lucas", "Emil", "Victor", "Oliver", "Magnus", "Malthe", "August", "Aksel", "Sebastian", "Storm", "Carl"], "last_names": ["Nielsen", "Jensen", "Hansen", "Pedersen", "Andersen", "Christensen", "Larsen", "Sørensen", "Rasmussen", "Jørgensen", "Petersen", "Madsen", "Kristensen", "Olsen", "Thomsen"]},
		"Österreich": {"first_names": ["Paul", "Jakob", "Maximilian", "David", "Lukas", "Tobias", "Jonas", "Felix", "Leon", "Alexander", "Elias", "Noah", "Luca", "Ben", "Samuel", "Thomas", "Michael", "Stefan", "Christian", "Andreas", "Florian", "Sebastian"], "last_names": ["Gruber", "Huber", "Wagner", "Pichler", "Steiner", "Moser", "Mayer", "Hofer", "Leitner", "Berger", "Fuchs", "Eder", "Fischer", "Bauer", "Wolf", "Reiter", "Wallner", "Wimmer", "Koller", "Schwarz", "Mayr", "Schuster"]},
		"Schweiz": {"first_names": ["Noah", "Liam", "Luca", "Leon", "Gabriel", "David", "Luis", "Elia", "Ben", "Samuel", "Matteo", "Tim", "Levin", "Julian", "Aaron"], "last_names": ["Müller", "Meier", "Schmid", "Keller", "Weber", "Huber", "Schneider", "Meyer", "Steiner", "Fischer", "Gerber", "Brunner", "Baumann", "Frei", "Zimmermann"]},
		"Griechenland": {"first_names": ["Georgios", "Dimitrios", "Konstantinos", "Ioannis", "Andreas", "Nikos", "Panagiotis", "Christos", "Alexandros", "Michail", "Vasilis", "Apostolos", "Evangelos", "Thanasis", "Spyros"], "last_names": ["Papadopoulos", "Pappas", "Nikolaou", "Vasileiou", "Karagiannis", "Manolas", "Fortounis", "Bakasetas", "Pavlidis", "Tzavellas", "Kourbelis", "Samaris", "Pelkas", "Limnios", "Fountas"]},
		"Bosnien": {"first_names": ["Amar", "Vedad", "Edin", "Miralem", "Asmir", "Haris", "Sead", "Elvir", "Samir", "Adnan", "Kenan", "Senad", "Muhamed", "Armin", "Dino"], "last_names": ["Hodžić", "Džeko", "Pjanić", "Ibišević", "Begović", "Medunjanin", "Kolašinac", "Višća", "Gojak", "Hajrović", "Kodro", "Dupovac", "Prevljak", "Rahmanović", "Zakarić"]},
		"Serbien": {"first_names": ["Luka", "Stefan", "Lazar", "Nemanja", "Miloš", "Marko", "Nikola", "Aleksandar", "Dušan", "Filip", "Vladmir", "Ognjen", "Andrija", "Petar", "Milovan"], "last_names": ["Jovanović", "Petrović", "Nikolić", "Marković", "Stojanović", "Milošević", "Đorđević", "Stankovic", "Mitrović", "Lazić", "Savić", "Popović", "Radić", "Kostić", "Tadić"]},
		"USA": {"first_names": ["Christian", "Weston", "Tyler", "Gio", "Michael", "Alex", "John", "David", "Matt", "Josh", "Kyle", "Brian", "Ryan", "Sean", "Joe"], "last_names": ["Pulisic", "McKennie", "Adams", "Reyna", "Turner", "Musah", "Weah", "Dest", "Scally", "Tillman", "Morris", "Zimmerman", "Pepi", "Folarin", "Luca"]},
		"Japan": {"first_names": ["Takumi", "Daichi", "Takefusa", "Kaoru", "Hiroki", "Yuki", "Wataru", "Reo", "Junya", "Ayase", "Yuya", "Takuma", "Ritsu", "Hidemasa", "Ko"], "last_names": ["Minamino", "Kamada", "Kubo", "Mitoma", "Sakai", "Nagatomo", "Endo", "Hatate", "Ito", "Ueda", "Osako", "Asano", "Doan", "Morita", "Itakura"]},
		"Tschechien": {"first_names": ["Tomáš", "Patrik", "Vladimír", "Antonín", "Jan", "Petr", "Pavel", "Jakub", "Martin", "Ondřej", "Lukáš", "David", "Michal", "Adam", "Filip"], "last_names": ["Souček", "Schick", "Coufal", "Barák", "Novák", "Svoboda", "Novotný", "Dvořák", "Černý", "Procházka", "Krejčí", "Hájek", "Kratochvíl", "Machala", "Šimek"]},
		"Ungarn": {"first_names": ["Dominik", "Péter", "Willi", "Ádám", "Zsolt", "László", "Gábor", "Zoltán", "István", "Attila", "Bence", "Dániel", "Máté", "Roland", "Balázs"], "last_names": ["Szoboszlai", "Gulácsi", "Orbán", "Szalai", "Nagy", "Kovács", "Tóth", "Varga", "Horváth", "Kiss", "Molnár", "Németh", "Farkas", "Balogh", "Papp"]},
		"Schweden": {"first_names": ["Alexander", "Emil", "Victor", "Martin", "Gustaf", "Erik", "Oscar", "Ludwig", "Zlatan", "Robin", "Sebastian", "Marcus", "Dejan", "Kristoffer", "Pontus"], "last_names": ["Isak", "Forsberg", "Lindelöf", "Andersson", "Johansson", "Hansen", "Larsson", "Svensson", "Ibrahimović", "Olsen", "Ekdal", "Berg", "Kulusevski", "Olsson", "Jansson"]},
		"Kosovo": {"first_names": ["Arber", "Milot", "Florent", "Valon", "Ermal", "Granit", "Besar", "Lirim", "Alban", "Blendi", "Drilon", "Flamur", "Gentian", "Kushtrim", "Lindrit"], "last_names": ["Zeneli", "Rashica", "Hadergjonaj", "Berisha", "Krasniqi", "Xhaka", "Halimi", "Kastrati", "Shala", "Gashi", "Kelmendi", "Hoti", "Muriqi", "Ibrahimi", "Rexhepi"]},
		"Skandinavien": {"first_names": ["Alexander", "Emil", "Victor", "Erling", "Martin", "Gylfi", "Teemu", "Magnus", "Lars", "Andreas", "Kristoffer", "Johan", "Mikael", "Rasmus", "Henrik"], "last_names": ["Isak", "Forsberg", "Lindelöf", "Haaland", "Ødegaard", "Sigurðsson", "Pukki", "Andersson", "Johansson", "Hansen", "Larsson", "Svensson", "Berg", "Lindberg", "Eriksson"]},
		"International": {"first_names": ["Alex", "Chris", "Sam", "Leo", "Max", "Marco", "Ivan", "Diego", "Adrian", "Daniel", "Michael", "Stefan", "Nicolas", "Viktor", "Anton", "Dmitri", "Sergei", "Pavel", "Milan", "Bogdan", "Radu", "Andrei", "Aleksandar", "Marko", "Nikola", "Petar"], "last_names": ["Global", "United", "International", "World", "Footballer", "Santos", "Silva", "Kim", "Petrov", "Popov", "Volkov", "Smirnov", "Kuznetsov", "Sokolov", "Fedorov", "Morozov", "Vasiliev", "Mikhailov", "Stepanov", "Semenov", "Pavlov", "Alexeev", "Lebedev", "Titov", "Orlov", "Zakharov"]},
		
		# === FEHLENDE EU-LÄNDER NAMEN-POOLS ===
		"Bulgarien": {"first_names": ["Dimitar", "Georgi", "Ivan", "Nikolai", "Petar", "Stoyan", "Todor", "Vasil", "Vladimir", "Yordan", "Stefan", "Kiril", "Plamen", "Rosen", "Angel"], "last_names": ["Petrov", "Ivanov", "Georgiev", "Dimitrov", "Nikolov", "Stoyanov", "Todorov", "Vasilev", "Vladimirov", "Yordanov", "Stefanov", "Kirilov", "Plamenovv", "Rosenov", "Angelov"]},
		"Rumänien": {"first_names": ["Alexandru", "Andrei", "Cristian", "Daniel", "Florin", "Gabriel", "Ion", "Marian", "Mihai", "Nicolae", "Radu", "Sergiu", "Stefan", "Valentin", "Victor"], "last_names": ["Popescu", "Ionescu", "Radu", "Stan", "Stoica", "Marin", "Gheorghe", "Ciobanu", "Dumitrescu", "Moldovan", "Barbu", "Cristea", "Dobre", "Florescu", "Mihai"]},
		"Slowakei": {"first_names": ["Martin", "Peter", "Michal", "Tomáš", "Ján", "Pavol", "Juraj", "Marián", "Miroslav", "Jozef", "Ladislav", "Stanislav", "Štefan", "Rudolf", "Erik"], "last_names": ["Novák", "Kováč", "Horváth", "Varga", "Tóth", "Nagy", "Baláž", "Molnár", "Krupka", "Slovák", "Polák", "Urban", "Jurčík", "Masaryk", "Sládek"]},
		"Slowenien": {"first_names": ["Luka", "Jan", "Matic", "Nejc", "Žan", "Tim", "Mark", "Anže", "Gašper", "David", "Miha", "Marko", "Gregor", "Andrej", "Jaka"], "last_names": ["Novak", "Horvat", "Krajnc", "Žagar", "Kos", "Golob", "Božič", "Kovačič", "Jenko", "Petek", "Vidmar", "Zupan", "Rus", "Hribar", "Pavlin"]},
		"Lettland": {"first_names": ["Jānis", "Māris", "Andris", "Pēteris", "Aigars", "Juris", "Guntis", "Valdis", "Arturs", "Edgars", "Sandris", "Roberts", "Normunds", "Uldis", "Raimonds"], "last_names": ["Bērziņš", "Kalniņš", "Ozoliņš", "Liepiņš", "Krūmiņš", "Zariņš", "Jansons", "Pētersons", "Karpovs", "Leitis", "Vītols", "Balodis", "Grīnbergs", "Vanags", "Priede"]},
		"Estland": {"first_names": ["Mart", "Andres", "Toomas", "Peeter", "Tarmo", "Rein", "Aivar", "Ants", "Heiki", "Jaak", "Kalev", "Lembit", "Märt", "Olev", "Priit"], "last_names": ["Tamm", "Saar", "Kask", "Mägi", "Sepp", "Org", "Koppel", "Lill", "Pärn", "Rebane", "Saks", "Teder", "Vares", "Käär", "Kiik"]},
		"Litauen": {"first_names": ["Jonas", "Antanas", "Vytautas", "Petras", "Algirdas", "Mindaugas", "Romualdas", "Raimondas", "Saulius", "Gediminas", "Arūnas", "Darius", "Gintautas", "Kęstutis", "Valdas"], "last_names": ["Kazlauskas", "Petrauskas", "Jankauskas", "Paulauskas", "Juškevičius", "Butkus", "Urbonas", "Stankevičius", "Vasiliauskas", "Žukauskas", "Norkus", "Mickevičius", "Kavaliauskás", "Rimkus", "Baranauskas"]},
		"Finnland": {"first_names": ["Mikael", "Aleksi", "Eino", "Väinö", "Aarne", "Paavo", "Tapio", "Matti", "Juhani", "Olavi", "Pentti", "Heikki", "Seppo", "Risto", "Kyösti"], "last_names": ["Virtanen", "Korhonen", "Mäkinen", "Nieminen", "Mäkelä", "Hämäläinen", "Laine", "Heikkinen", "Koskinen", "Järvinen", "Lehtonen", "Lehtinen", "Saarinen", "Salminen", "Heinonen"]},
		"Norwegen": {"first_names": ["Magnus", "Mathias", "Kristian", "Lars", "Morten", "Ola", "Andreas", "Thomas", "Martin", "Jonas", "Even", "Sindre", "Espen", "Håkon", "Trond"], "last_names": ["Hansen", "Johansen", "Olsen", "Larsen", "Andersen", "Pedersen", "Nilsen", "Kristiansen", "Jensen", "Karlsen", "Johnsen", "Pettersen", "Eriksen", "Berg", "Haugen"]},
		"Albanien": {"first_names": ["Alban", "Arben", "Agron", "Besart", "Blerim", "Driton", "Ermal", "Fatmir", "Gentian", "Ilir", "Luan", "Mentor", "Petrit", "Sokol", "Xhevdet"], "last_names": ["Hoxha", "Berisha", "Krasniqi", "Rama", "Gashi", "Murati", "Kastrati", "Shala", "Meta", "Zeqiri", "Hajdari", "Morina", "Sahiti", "Bajrami", "Veliu"]},
		"Georgien": {"first_names": ["Giorgi", "Levan", "Davit", "Irakli", "Mamuka", "Zurab", "Avtandil", "Givi", "Nika", "Tornike", "Sandro", "Luka", "Archil", "Revaz", "Vakhtang"], "last_names": ["Beridze", "Gelashvili", "Kvaratskhelia", "Mamardashvili", "Tsitaishvili", "Gvilia", "Lobzhanidze", "Papunashvili", "Zivzivadze", "Mikautadze", "Chakvetadze", "Davitashvili", "Lochoshvili", "Tabidze", "Sigua"]},
		"Montenegro": {"first_names": ["Nikola", "Marko", "Stefan", "Miloš", "Aleksandar", "Nemanja", "Petar", "Filip", "Luka", "Dušan", "Jovan", "Bojan", "Dejan", "Vukašin", "Radovan"], "last_names": ["Petrović", "Nikolić", "Jovanović", "Marković", "Stojanović", "Milošević", "Đorđević", "Mitrović", "Lazić", "Savić", "Popović", "Radić", "Kostić", "Tadić", "Stanković"]},
		"Aserbaidschan": {"first_names": ["Elvin", "Ramil", "Mahir", "Namiq", "Rashad", "Samir", "Tural", "Vuqar", "Xəqani", "Yusif", "Ziya", "Anar", "Baxtiyar", "Ceyhun", "Elman"], "last_names": ["Məmmədov", "Əliyev", "Həsənov", "Quliyev", "Rəhimov", "Səfərov", "Təhməzov", "Vəliyev", "Xəlilov", "Yusifov", "Zülfüqarov", "Abbasov", "Babayev", "Camalov", "Əhmədov"]},
		"Zypern": {"first_names": ["Andreas", "Georgios", "Christos", "Nikos", "Panayiotis", "Stelios", "Marios", "Constantinos", "Dimitris", "Michalis", "Stavros", "Antonis", "Costas", "Petros", "Yiannis"], "last_names": ["Charalambous", "Georgiou", "Christodoulou", "Nicolaou", "Panayiotou", "Stylianou", "Mariou", "Constantinou", "Dimitriou", "Michaelidou", "Stavrou", "Antoniou", "Costa", "Petrou", "Yiannou"]},
		"Israel": {"first_names": ["David", "Daniel", "Yosef", "Michael", "Moshe", "Avraham", "Shimon", "Yitzhak", "Reuven", "Yaakov", "Eliezer", "Meir", "Chaim", "Shlomo", "Aron"], "last_names": ["Cohen", "Levi", "Miller", "Goldstein", "Rosen", "Katz", "Schwartz", "Klein", "Green", "Weiss", "Shapiro", "Wolf", "Stern", "Abramovich", "Friedman"]},
		"Russland": {"first_names": ["Aleksandr", "Sergei", "Dmitri", "Andrei", "Vladimir", "Mikhail", "Nikolai", "Pavel", "Ivan", "Viktor", "Anton", "Maxim", "Artem", "Denis", "Roman"], "last_names": ["Petrov", "Ivanov", "Smirnov", "Volkov", "Kuznetsov", "Sokolov", "Fedorov", "Morozov", "Vasiliev", "Mikhailov", "Stepanov", "Semenov", "Pavlov", "Alexeev", "Lebedev"]},
		"Ukraine": {"first_names": ["Oleksandr", "Andriy", "Sergiy", "Vitaliy", "Yuriy", "Igor", "Viktor", "Dmytro", "Mykola", "Ruslan", "Roman", "Vasyl", "Volodymyr", "Maksym", "Taras"], "last_names": ["Kovalenko", "Shevchenko", "Yarmolenko", "Zinchenko", "Malinovsky", "Sydorchuk", "Stepanenko", "Tsygankov", "Mudryk", "Dovbyk", "Shaparenko", "Mykolenko", "Karavaev", "Buyalsky", "Zubkov"]},
		
		# === WEITERE EU-INSELN ===
		"Island": {"first_names": ["Jón", "Sigurður", "Guðmundur", "Gunnar", "Ólafur", "Einar", "Kristján", "Magnús", "Þórður", "Ragnar", "Björn", "Stefán", "Árni", "Þorvaldur", "Halldór"], "last_names": ["Jónsson", "Sigurðsson", "Guðmundsson", "Ólafsson", "Magnússon", "Einarsson", "Kristjánsson", "Þórsson", "Ragnarsson", "Björnsson", "Stefánsson", "Árnason", "Þorvaldsson", "Halldórsson", "Gunnarsson"]},
		"Malta": {"first_names": ["Joseph", "John", "Paul", "Anthony", "Michael", "David", "Mario", "Robert", "Mark", "Stephen", "Charles", "Daniel", "Matthew", "Andrew", "Christopher"], "last_names": ["Borg", "Farrugia", "Vella", "Mifsud", "Camilleri", "Grech", "Muscat", "Gauci", "Attard", "Cassar", "Saliba", "Bonello", "Agius", "Fenech", "Zammit"]},
		
		# === WEITERE BALKAN-LÄNDER ===
		"Mazedonien": {"first_names": ["Aleksandar", "Stefan", "Marko", "Nikola", "Dimitar", "Bojan", "Dejan", "Goran", "Eljif", "Arijan", "Tihomir", "Darko", "Milan", "Kristijan", "Ezgjan"], "last_names": ["Trajkovski", "Bardhi", "Alioski", "Nestorovski", "Pandev", "Musliu", "Velkovski", "Ristovski", "Ademi", "Churlinov", "Zajkov", "Spirovski", "Kostadinov", "Milevski", "Ashkovski"]},
		
		# === NEU: TOP AUßEREUROPÄISCHE NATIONALITÄTEN (Transfermarkt.de 2024/25) ===
		"Kanada": {"first_names": ["Alphonso", "Jonathan", "Cyle", "Stephen", "Milan", "Samuel", "Atiba", "Scott", "Junior", "Richie", "Tajon", "Alistair", "Kamal", "Derek", "Ismael"], "last_names": ["Davies", "David", "Larin", "Eustaquio", "Borjan", "Piette", "Hutchinson", "Arfield", "Hoilett", "Laryea", "Buchanan", "Johnston", "Miller", "Cornelius", "Kone"]},
		"Mexiko": {"first_names": ["Hirving", "Raul", "Jesus", "Edson", "Cesar", "Hector", "Andres", "Carlos", "Diego", "Jorge", "Luis", "Roberto", "Santiago", "Alexis", "Johan"], "last_names": ["Lozano", "Jimenez", "Corona", "Alvarez", "Montes", "Herrera", "Guardado", "Rodriguez", "Lainez", "Sanchez", "Romo", "Alvarado", "Gimenez", "Vega", "Vasquez"]},
		"Uruguay": {"first_names": ["Federico", "Darwin", "Luis", "Rodrigo", "Ronald", "Jose", "Giorgian", "Matias", "Manuel", "Nicolas", "Diego", "Martin", "Facundo", "Nahitan", "Brian"], "last_names": ["Valverde", "Nunez", "Suarez", "Bentancur", "Araujo", "Gimenez", "De Arrascaeta", "Vecino", "Ugarte", "De La Cruz", "Godin", "Caceres", "Pellistri", "Nandez", "Rodriguez"]},
		"Chile": {"first_names": ["Alexis", "Arturo", "Charles", "Eduardo", "Erick", "Gary", "Guillermo", "Jean", "Ben", "Claudio", "Paulo", "Diego", "Francisco", "Mauricio", "Victor"], "last_names": ["Sanchez", "Vidal", "Aranguiz", "Vargas", "Pulgar", "Medel", "Maripan", "Beausejour", "Brereton", "Bravo", "Diaz", "Valdes", "Sierralta", "Isla", "Davila"]},
		"Kolumbien": {"first_names": ["Luis", "Rafael", "Juan", "Duvan", "Jhon", "Davinson", "Yerry", "Wilmar", "James", "Mateus", "Daniel", "Steven", "Kevin", "Jorge", "Cristian"], "last_names": ["Diaz", "Borre", "Cuadrado", "Zapata", "Cordoba", "Sanchez", "Mina", "Barrios", "Rodriguez", "Uribe", "Munoz", "Alzate", "Castano", "Carrascal", "Borja"]},
		"Südkorea": {"first_names": ["Heung-Min", "Min-Jae", "Woo-Young", "In-Beom", "Kang-In", "Jae-Sung", "Ui-Jo", "Young-Woo", "Chang-Hoon", "Jin-Su", "Seung-Ho", "Sang-Ho", "Tae-Hwan", "Hyun-Jun", "Gue-Sung"], "last_names": ["Son", "Kim", "Jung", "Hwang", "Lee", "Park", "Kwon", "Seol", "Na", "Hong", "Paik", "Jeong", "Yang", "Cho", "Oh"]},
		"Iran": {"first_names": ["Sardar", "Mehdi", "Alireza", "Saman", "Saeid", "Milad", "Ehsan", "Morteza", "Hossein", "Majid", "Shoja", "Omid", "Ramin", "Karim", "Ahmad"], "last_names": ["Azmoun", "Taremi", "Jahanbakhsh", "Ghoddos", "Ezatolahi", "Mohammadi", "Hajsafi", "Pouraliganji", "Kanaani", "Hosseini", "Khalilzadeh", "Noorafkan", "Rezaeian", "Ansarifard", "Nourollahi"]},
		"Marokko": {"first_names": ["Achraf", "Hakim", "Youssef", "Sofyan", "Noussair", "Romain", "Azzedine", "Selim", "Sofiane", "Zakaria", "Abdelhamid", "Yahya", "Munir", "Abde", "Walid"], "last_names": ["Hakimi", "Ziyech", "En-Nesyri", "Amrabat", "Mazraoui", "Saiss", "Ounahi", "Amallah", "Boufal", "Aboukhlal", "Sabiri", "Attiat-Allah", "El Haddadi", "Ezzalzouli", "Cheddira"]},
		"Tunesien": {"first_names": ["Wahbi", "Ellyes", "Youssef", "Aissa", "Dylan", "Mohamed", "Montassar", "Ali", "Hannibal", "Nader", "Yan", "Ferjani", "Seifeddine", "Taha", "Naim"], "last_names": ["Khazri", "Skhiri", "Msakni", "Laidouni", "Bronn", "Drager", "Talbi", "Abdi", "Mejbri", "Ghandri", "Valery", "Sassi", "Jaziri", "Khenissi", "Sliti"]},
		"Algerien": {"first_names": ["Riyad", "Islam", "Sofiane", "Youcef", "Ismael", "Ramy", "Adam", "Houssem", "Nabil", "Baghdad", "Aissa", "Ramiz", "Hicham", "Mohamed", "Farès"], "last_names": ["Mahrez", "Slimani", "Feghouli", "Atal", "Bennacer", "Bensebaini", "Ounas", "Aouar", "Bentaleb", "Bounedjah", "Mandi", "Zerrouki", "Boudaoui", "Amoura", "Chaibi"]},
		"Senegal": {"first_names": ["Sadio", "Kalidou", "Edouard", "Idrissa", "Ismaila", "Boulaye", "Nampalys", "Cheikhou", "Pape", "Krepin", "Habib", "Nicolas", "Abdou", "Iliman", "Famara"], "last_names": ["Mane", "Koulibaly", "Mendy", "Gueye", "Sarr", "Dia", "Mendy", "Kouyate", "Gueye", "Diatta", "Diallo", "Jackson", "Diallo", "Ndiaye", "Diedhiou"]},
		"Nigeria": {"first_names": ["Victor", "Wilfred", "Alex", "Moses", "Kelechi", "Samuel", "Joe", "Ademola", "Calvin", "Taiwo", "Nathan", "Paul", "Terem", "Bright", "Frank"], "last_names": ["Osimhen", "Ndidi", "Iwobi", "Simon", "Iheanacho", "Chukwueze", "Aribo", "Lookman", "Bassey", "Awoniyi", "Collins", "Onuachu", "Moffi", "Osayi-Samuel", "Onyeka"]},
		"Elfenbeinküste": {"first_names": ["Franck", "Wilfried", "Nicolas", "Sebastien", "Jean", "Eric", "Maxwel", "Odilon", "Jeremie", "Seko", "Ibrahim", "Christian", "Willy", "Simon", "Ghislain"], "last_names": ["Kessie", "Zaha", "Pepe", "Haller", "Seri", "Bailly", "Cornet", "Kossounou", "Boga", "Fofana", "Sangare", "Kouame", "Boly", "Adingra", "Konan"]},
		"Ghana": {"first_names": ["Thomas", "Mohammed", "Andre", "Jordan", "Daniel", "Kamaldeen", "Alexander", "Joseph", "Felix", "Iddrisu", "Antoine", "Tariq", "Denis", "Elisha", "Gideon"], "last_names": ["Partey", "Kudus", "Ayew", "Ayew", "Amartey", "Sulemana", "Djiku", "Paintsil", "Afena-Gyan", "Baba", "Semenyo", "Lamptey", "Odoi", "Owusu", "Mensah"]}
	}

	var player_pool: Array = []  # Änderung: Flache Liste statt Dictionary
	var _current_player_id: int = 0
	var _used_names: Dictionary = {}  # Track verwendete Namen zur Duplikat-Vermeidung
	
	func generate_and_save():
		print("--- STARTE GENERIERUNG: Globaler Spieler-Pool mit realistischer Nationalitäten-Verteilung ---")
		_current_player_id = 0
		player_pool.clear()
		_used_names.clear()
		for tier_key in TIERS:
			var tier_info = TIERS[tier_key]
			print("Generiere %d Spieler für Tier %d" % [tier_info["count"], tier_key])
			for _i in range(tier_info["count"]):
				player_pool.append(_create_player(tier_key))
		_save_database_to_file({"1": player_pool}, OUTPUT_PATH)  # Speichere als {"1": [alle_spieler]}
		print("--- FERTIG: Globaler Spieler-Pool mit %d Spielern wurde erstellt ---" % player_pool.size())

	func _create_player(tier: int) -> Dictionary:
		_current_player_id += 1
		var nationality = _assign_nationality(tier)
		
		# Generiere eindeutigen Namen (max 50 Versuche pro Spieler)
		var first_name = ""
		var last_name = ""
		var full_name = ""
		var attempts = 0
		
		while attempts < 50:
			if NAME_DATA.has(nationality):
				first_name = NAME_DATA[nationality]["first_names"].pick_random()
				last_name = NAME_DATA[nationality]["last_names"].pick_random()
			else:
				first_name = NAME_DATA["International"]["first_names"].pick_random()
				last_name = NAME_DATA["International"]["last_names"].pick_random()
			
			full_name = first_name + " " + last_name
			
			# Prüfe ob Name bereits verwendet
			if not _used_names.has(full_name):
				_used_names[full_name] = true
				break
			
			attempts += 1
		
		# Falls nach 50 Versuchen immer noch Duplikat: Nummeriere
		if attempts >= 50:
			var counter = 2
			while _used_names.has(full_name + " " + str(counter)):
				counter += 1
			full_name = full_name + " " + str(counter)
			_used_names[full_name] = true
			# Namen für Rückgabe splitten
			var parts = full_name.split(" ")
			if parts.size() >= 3:  # "Max Müller 2"
				last_name = parts[-2] + " " + parts[-1]  # "Müller 2"
			
		var assigned_pos = _assign_random_position()
		var age = _generate_realistic_age()
		var strength = _calculate_strength(tier, age)
		var potential = _calculate_potential(strength, tier)
		var peak_age = randi_range(27, 32)
		if assigned_pos == "Torwart": peak_age += 2
		var market_val = _calculate_market_value(strength, potential, age)
		
		var base = strength * 2
		var skill_freistoss = clampi(randi_range(base - 4, base + 4), 1, 20)
		var skill_elfmeter = clampi(randi_range(base - 2, base + 6), 1, 20)
		var skill_zweikampf = clampi(randi_range(base - 5, base + 5), 1, 20)
		var skill_technik = clampi(randi_range(base - 5, base + 5), 1, 20)
		var skill_stellungsspiel = clampi(randi_range(base - 6, base + 4), 1, 20)
		var kondition_basis = randi_range(70, 99)
		var verletzungsanfaelligkeit = randi_range(1, 10)
		
		var stats = {"tore": 0, "vorlagen": 0, "einsaetze": 0, "gelbe_karten": 0, "rote_karten": 0, "spieler_des_tages": 0, "notenschnitt": 0.0}
		var status = {"zustand": "fit", "verletzungsart": "", "erholung_wochen_verbleibend": 0, "ist_gesperrt": false, "frische": 100, "moral": 7}
		
		return {
			"player_id": "p%04d" % _current_player_id,
			"first_name": first_name, "last_name": last_name,
			"age": age, "peak_age": peak_age,
			"nationality": nationality,
			"primary_position": assigned_pos,
			"strength_overall_base": strength, "potential": potential, "current_form": 10,
			"contract_years_remaining": randi_range(1, 4),
			"monthly_salary_eur": _calculate_monthly_salary(market_val),
			"market_value_eur": market_val,
			"skill_freistoss": skill_freistoss, "skill_elfmeter": skill_elfmeter,
			"skill_zweikampf": skill_zweikampf, "skill_technik": skill_technik,
			"skill_stellungsspiel": skill_stellungsspiel,
			"kondition_basis": kondition_basis, "verletzungsanfaelligkeit": verletzungsanfaelligkeit,
			"stats": stats,
			"status": status
		}

	# (Rest der Funktionen _assign_nationality, _assign_random_position, etc. bleibt unverändert)

	func _assign_nationality(tier: int) -> String:
		var distribution = NATIONALITY_DIST_BY_TIER[tier]
		var roll = randf()
		var cumulative = 0.0
		for nation in distribution:
			cumulative += distribution[nation]
			if roll < cumulative:
				return nation
		return "International" # Fallback, sollte nicht oft passieren

	func _assign_random_position() -> String:
		var roll = randf()
		# ANGEPASST: Erhöht auf 7% (256 Teams × 2 TW = 512 benötigt, 7% = ~574 verfügbar)
		if roll < 0.07: return "Torwart"    # 7% (~574 TW für alle Teams + Reserve)
		elif roll < 0.41: return "Abwehr"    # 35% 
		elif roll < 0.76: return "Mittelfeld" # 35%
		else: return "Sturm"                # 24%

	func _generate_realistic_age() -> int:
		var r1 = randf_range(16, 39); var r2 = randf_range(16, 39)
		return int(round((r1 + r2) / 2.0))
		
	func _calculate_potential(strength: int, tier: int) -> int:
		var tier_data = TIERS[tier]
		return randi_range(max(tier_data.min_pot, strength * 10), tier_data.max_pot)
		
	func _calculate_strength(tier: int, age: int) -> int:
		var tier_data = TIERS[tier]
		var base_strength = normal_dist_rand(tier_data.avg_str, tier_data.str_dev)
		if age < 19 or age > 34: base_strength -= randf_range(0.3, 0.8)
		var final_strength = clampi(roundi(base_strength), 1, 7)  # Begrenzt auf 1-7
		# Stärke 8 nur durch Spieler-Aufwertung im Spiel möglich
		return final_strength
		
	func _calculate_monthly_salary(market_value: int) -> int:
		return _round_to_nearest(market_value * randf_range(0.08, 0.15) / 12.0, 1000)

	func _calculate_market_value(strength: int, potential: int, age: int) -> int:
		var base_value: float
		match strength:
			1: base_value = randf_range(10_000, 75_000)
			2: base_value = randf_range(75_000, 400_000)
			3: base_value = randf_range(400_000, 1_500_000)
			4: base_value = randf_range(1_500_000, 5_000_000)
			5: base_value = randf_range(5_000_000, 12_000_000)
			6: base_value = randf_range(12_000_000, 30_000_000)
			7: base_value = randf_range(30_000_000, 60_000_000)
			8: base_value = randf_range(60_000_000, 90_000_000)
			9: base_value = randf_range(90_000_000, 130_000_000)
			10: base_value = randf_range(130_000_000, 180_000_000)
			_: base_value = 5_000
		var potential_factor = 1.0 + (float(potential - 60) / 40.0) * 0.5
		var age_factor = 1.0
		if age < 23: age_factor = 1.6 - (age - 16) * 0.08
		elif age > 29: age_factor = 1.0 - (age - 29) * 0.1
		return _round_to_nearest(base_value * potential_factor * age_factor, 25000)

	func _round_to_nearest(val: float, nearest: int) -> int:
		if nearest == 0: return int(round(val))
		return int(round(val / float(nearest))) * nearest

	func normal_dist_rand(mean: float, std_dev: float) -> float:
		var u1 = randf(); var u2 = randf()
		if u1 == 0: u1 = 0.0001
		return mean + std_dev * (sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2))
		
	func _save_database_to_file(data: Variant, path: String):
		var dir_path = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t")); file.close()
		print("Master-Datei gespeichert: %s" % path)
