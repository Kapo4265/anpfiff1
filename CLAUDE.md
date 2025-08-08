# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projekt-Roadmap

**Anstoss 1 Remake** - Authentisches Remake basierend auf originalem Anstoss 1 Handbuch (Anstoss_Handbuch.pdf)
- Godot 4.4.1, Mobile-First (1920x1080 HD Landscape)
- Modular-Plugin-basierte Architektur mit 6 erweiterbaren Kernen

**Entwicklungsfortschritt:**
- ✅ KERN 1: BASIS-GAME-LOOP (vollständig implementiert)
- ✅ KERN 2: MATCH-EVENTS (vollständig implementiert)
- ✅ KERN 3: EU-TEAM SYSTEM (vollständig implementiert)
- ✅ KERN 4: POKALE & REALISTISCHE SAISON (vollständig implementiert)
- 🔄 KERN 5: VOLLSTÄNDIGER SPIELTAG-ABLAUF (Integration in Arbeit)
- ⏳ KERN 6: UI-INTEGRATION  
- ⏳ KERN 7: SAISON-LOOP & KARRIERE
- ⏳ KERN 8: ERWEITERTE MODULE

## Wichtige Referenz-Dateien

**Bei unklaren Fragen IMMER nachschlagen:**
- `docs/Anstoss_Handbuch.pdf` - Original Anstoss 1 Handbuch (42 Seiten)
- `Anstoss_1_Remake_Gesamtplan.txt` - Vollständiger Entwicklungsplan mit allen Mechaniken

Diese Dateien enthalten alle authentischen Spielmechaniken und Implementierungsdetails.

## Verwendete Funktionen und Variablen

**GameManager.gd (Singleton):**
- `teams: Dictionary`, `players: Dictionary`
- `current_season: int`, `current_matchday: int`, `current_team_id: String`
- `load_teams()`, `load_players()`, `get_team(team_id)`, `get_player(player_id)`

**PlayerData.gd:**
- `player_id, first_name, last_name, strength_overall_base, current_form`
- `primary_position, age, moral, zustand, ist_gesperrt, verletzungsart`
- `frische, kondition_basis`
- `get_effective_strength()`, `update_form_after_match(won, scored_goal, own_goal)`

**TeamData.gd:**
- `team_id, team_name, city, tier, player_roster[22], starting_eleven[11]`
- `morale, default_einsatz, default_tactic, stadium, league_stats`
- `calculate_team_strength(is_home, spielweise, einsatz)`
- `generate_default_lineup()`, `get_players_by_position()`
- `get_spielweise_modifier()`, `get_einsatz_modifier()`

**MatchEngine.gd:**
- `simulate_match(home_team_id, away_team_id)`
- Win-Chance = home_strength / (home_strength + away_strength)
- `get_match_result_text()`

## Authentische Spielmechaniken (Handbuch-basiert)

**Form-System:** 0-20 Skala, startet bei 10
- Sieg: +1, Niederlage: -1, Tor: +0.5, Eigentor: -1

**Team-Moral:** 0-8 Range (Handbuch Seite 17)
- Siegesserie: +1, Niederlagenserie: -1

**Einsatz-System:** 5 Stufen
- "Lieb & Nett" (0.9×), "Fair" (0.95×), "Normal" (1.0×), "Hart" (1.05×), "Brutal" (1.1×)

**Training:** 9 Bereiche mit 0-10 Punkteverteilung
- Freistöße, Elfmeter, Alleingänge, Tacklings, Spielzüge, Abseitsfalle, Kondition, Regeneration, Gymnastik

**KERN 2 Event-System (geplant):**
- Minuten-basierte Event-Generierung (1-90 Min)
- Event-Chance = 5% + (team_strength × 0.1%)
- Training beeinflusst Event-Erfolgsraten, nicht Häufigkeiten