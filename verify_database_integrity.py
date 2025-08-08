#!/usr/bin/env python3
"""
Comprehensive Database Integrity Verification
Checks for duplicate names, player ID integrity, team-player cross-references, and data validation
"""

import json
import sys
from collections import defaultdict, Counter

def load_json_file(filepath):
    """Load and parse JSON file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR loading {filepath}: {e}")
        sys.exit(1)

def verify_duplicate_names(players_data):
    """Check for duplicate first_name + last_name combinations"""
    print("=" * 60)
    print("1. ZERO DUPLICATE NAMES VERIFICATION")
    print("=" * 60)
    
    name_combinations = []
    duplicate_names = defaultdict(list)
    total_players = 0
    
    # Extract all name combinations
    for tier_players in players_data.values():
        for player in tier_players:
            total_players += 1
            full_name = f"{player['first_name']} {player['last_name']}"
            name_combinations.append(full_name)
            duplicate_names[full_name].append(player['player_id'])
    
    # Find duplicates
    duplicates_found = []
    for name, player_ids in duplicate_names.items():
        if len(player_ids) > 1:
            duplicates_found.append((name, player_ids))
    
    print(f"Total players processed: {total_players}")
    print(f"Unique name combinations: {len(set(name_combinations))}")
    print(f"Expected unique names: {total_players}")
    
    if duplicates_found:
        print(f"\nERROR: DUPLICATES FOUND: {len(duplicates_found)}")
        for name, player_ids in duplicates_found:
            print(f"  - '{name}': {player_ids}")
        return False
    else:
        print("SUCCESS: NO DUPLICATES FOUND - All names are unique!")
        return True

def verify_player_ids(players_data):
    """Verify player ID integrity"""
    print("\n" + "=" * 60)
    print("2. PLAYER ID INTEGRITY VERIFICATION")
    print("=" * 60)
    
    all_player_ids = []
    total_players = 0
    
    # Collect all player IDs
    for tier_players in players_data.values():
        for player in tier_players:
            all_player_ids.append(player['player_id'])
            total_players += 1
    
    # Check for duplicates
    id_counts = Counter(all_player_ids)
    duplicate_ids = [pid for pid, count in id_counts.items() if count > 1]
    
    # Check for sequential IDs p0001-p8200
    expected_ids = [f"p{i:04d}" for i in range(1, 8201)]
    missing_ids = set(expected_ids) - set(all_player_ids)
    unexpected_ids = set(all_player_ids) - set(expected_ids)
    
    print(f"Total players: {total_players}")
    print(f"Unique player IDs: {len(set(all_player_ids))}")
    print(f"Expected range: p0001 to p8200 ({len(expected_ids)} IDs)")
    
    success = True
    
    if duplicate_ids:
        print(f"\nERROR: DUPLICATE IDs FOUND: {len(duplicate_ids)}")
        for pid in duplicate_ids[:10]:  # Show first 10
            print(f"  - {pid} (appears {id_counts[pid]} times)")
        success = False
    else:
        print("SUCCESS: No duplicate player IDs")
    
    if missing_ids:
        print(f"\nERROR: MISSING IDs: {len(missing_ids)}")
        for pid in sorted(list(missing_ids))[:10]:  # Show first 10
            print(f"  - {pid}")
        success = False
    else:
        print("SUCCESS: No missing player IDs")
        
    if unexpected_ids:
        print(f"\nERROR: UNEXPECTED IDs: {len(unexpected_ids)}")
        for pid in sorted(list(unexpected_ids))[:10]:  # Show first 10
            print(f"  - {pid}")
        success = False
    else:
        print("SUCCESS: No unexpected player IDs")
    
    return success

def verify_team_player_cross_reference(players_data, teams_data):
    """Verify team-player cross-references"""
    print("\n" + "=" * 60)
    print("3. TEAM-PLAYER CROSS-REFERENCE VERIFICATION")
    print("=" * 60)
    
    # Build player ID set
    all_player_ids = set()
    for tier_players in players_data.values():
        for player in tier_players:
            all_player_ids.add(player['player_id'])
    
    total_teams = len(teams_data)
    invalid_refs = []
    roster_issues = []
    duplicate_players_in_team = []
    
    print(f"Total teams to check: {total_teams}")
    print(f"Total players available: {len(all_player_ids)}")
    
    for team_id, team_data in teams_data.items():
        roster = team_data.get('player_roster', [])
        
        # Check roster size
        if len(roster) != 22:
            roster_issues.append((team_id, len(roster)))
        
        # Check for duplicates within team
        if len(roster) != len(set(roster)):
            duplicate_count = len(roster) - len(set(roster))
            duplicate_players_in_team.append((team_id, duplicate_count))
        
        # Check if all player IDs exist
        for player_id in roster:
            if player_id not in all_player_ids:
                invalid_refs.append((team_id, player_id))
    
    success = True
    
    if invalid_refs:
        print(f"\n🚨 INVALID PLAYER REFERENCES: {len(invalid_refs)}")
        for team_id, player_id in invalid_refs[:10]:  # Show first 10
            print(f"  - Team {team_id}: player {player_id} doesn't exist")
        success = False
    else:
        print("✅ All player references are valid")
    
    if roster_issues:
        print(f"\n🚨 ROSTER SIZE ISSUES: {len(roster_issues)}")
        for team_id, size in roster_issues[:10]:  # Show first 10
            print(f"  - Team {team_id}: {size} players (expected 22)")
        success = False
    else:
        print("✅ All teams have exactly 22 players")
    
    if duplicate_players_in_team:
        print(f"\n🚨 DUPLICATE PLAYERS IN TEAMS: {len(duplicate_players_in_team)}")
        for team_id, dup_count in duplicate_players_in_team[:10]:  # Show first 10
            print(f"  - Team {team_id}: {dup_count} duplicate players")
        success = False
    else:
        print("✅ No duplicate players within teams")
    
    return success

def verify_position_distribution(players_data, teams_data):
    """Verify position distribution"""
    print("\n" + "=" * 60)
    print("4. POSITION DISTRIBUTION VERIFICATION")
    print("=" * 60)
    
    # Build player position map
    player_positions = {}
    position_counts = Counter()
    
    for tier_players in players_data.values():
        for player in tier_players:
            player_id = player['player_id']
            position = player['primary_position']
            player_positions[player_id] = position
            position_counts[position] += 1
    
    # Check overall distribution
    total_players = sum(position_counts.values())
    print(f"Overall position distribution:")
    for position, count in position_counts.items():
        percentage = (count / total_players) * 100
        print(f"  {position}: {count} players ({percentage:.1f}%)")
    
    # Check goalkeeper distribution per team
    gk_issues = []
    for team_id, team_data in teams_data.items():
        roster = team_data.get('player_roster', [])
        gk_count = sum(1 for pid in roster if player_positions.get(pid) == 'Torwart')
        
        if gk_count < 3 or gk_count > 4:
            gk_issues.append((team_id, gk_count))
    
    success = True
    
    if gk_issues:
        print(f"\n🚨 GOALKEEPER DISTRIBUTION ISSUES: {len(gk_issues)}")
        for team_id, gk_count in gk_issues[:10]:  # Show first 10
            print(f"  - Team {team_id}: {gk_count} goalkeepers (expected 3-4)")
        success = False
    else:
        print("✅ All teams have 3-4 goalkeepers")
    
    # Check if TW target of ~6% is met
    tw_percentage = (position_counts.get('Torwart', 0) / total_players) * 100
    print(f"\nGoalkeeper percentage: {tw_percentage:.1f}% (target: ~6%)")
    
    if abs(tw_percentage - 6.0) > 1.0:  # Allow 1% deviation
        print("⚠️  Goalkeeper percentage deviates from 6% target")
        success = False
    else:
        print("✅ Goalkeeper percentage within target range")
    
    return success

def verify_data_structure(players_data, teams_data):
    """Verify JSON data structure integrity"""
    print("\n" + "=" * 60)
    print("5. DATA STRUCTURE VALIDATION")
    print("=" * 60)
    
    required_player_fields = [
        'player_id', 'first_name', 'last_name', 'age', 'primary_position',
        'strength_overall_base', 'current_form', 'kondition_basis'
    ]
    
    required_team_fields = [
        'player_roster', 'city', 'default_einsatz', 'default_tactic', 'morale'
    ]
    
    player_issues = []
    team_issues = []
    
    # Check players
    for tier, tier_players in players_data.items():
        for i, player in enumerate(tier_players):
            for field in required_player_fields:
                if field not in player:
                    player_issues.append((tier, i, field))
                elif player[field] is None or player[field] == '':
                    if field not in ['verletzungsart']:  # verletzungsart can be empty
                        player_issues.append((tier, i, f"{field} is empty/null"))
    
    # Check teams
    for team_id, team_data in teams_data.items():
        for field in required_team_fields:
            if field not in team_data:
                team_issues.append((team_id, field))
            elif team_data[field] is None or team_data[field] == '':
                team_issues.append((team_id, f"{field} is empty/null"))
    
    success = True
    
    if player_issues:
        print(f"\n🚨 PLAYER DATA ISSUES: {len(player_issues)}")
        for tier, idx, issue in player_issues[:10]:  # Show first 10
            print(f"  - Tier {tier}, Player {idx}: {issue}")
        success = False
    else:
        print("✅ All player data structures are valid")
    
    if team_issues:
        print(f"\n🚨 TEAM DATA ISSUES: {len(team_issues)}")
        for team_id, issue in team_issues[:10]:  # Show first 10
            print(f"  - Team {team_id}: {issue}")
        success = False
    else:
        print("✅ All team data structures are valid")
    
    return success

def check_game_breaking_issues(players_data, teams_data):
    """Check for conditions that would cause assert() failures"""
    print("\n" + "=" * 60)
    print("6. GAME-BREAKING ISSUES CHECK")
    print("=" * 60)
    
    issues = []
    
    # Check for negative or zero strength values
    for tier_players in players_data.values():
        for player in tier_players:
            if player.get('strength_overall_base', 0) <= 0:
                issues.append(f"Player {player['player_id']} has invalid strength: {player.get('strength_overall_base')}")
            
            if player.get('current_form', 10) < 0 or player.get('current_form', 10) > 20:
                issues.append(f"Player {player['player_id']} has invalid form: {player.get('current_form')}")
            
            if player.get('kondition_basis', 100) < 0 or player.get('kondition_basis', 100) > 100:
                issues.append(f"Player {player['player_id']} has invalid kondition: {player.get('kondition_basis')}")
    
    # Check team morale ranges
    for team_id, team_data in teams_data.items():
        morale = team_data.get('morale', 3)
        if morale < 0 or morale > 8:
            issues.append(f"Team {team_id} has invalid morale: {morale}")
    
    if issues:
        print(f"\n🚨 GAME-BREAKING ISSUES FOUND: {len(issues)}")
        for issue in issues[:20]:  # Show first 20
            print(f"  - {issue}")
        return False
    else:
        print("✅ No game-breaking issues found")
        return True

def main():
    """Main verification function"""
    print("COMPREHENSIVE DATABASE INTEGRITY VERIFICATION")
    print("=" * 60)
    
    # Load data files
    players_data = load_json_file('C:\\Users\\Shadow\\Documents\\Anpfiff1\\data\\master_players_pool.json')
    teams_data = load_json_file('C:\\Users\\Shadow\\Documents\\Anpfiff1\\data\\master_teams.json')
    
    # Run all verifications
    results = []
    
    results.append(verify_duplicate_names(players_data))
    results.append(verify_player_ids(players_data))
    results.append(verify_team_player_cross_reference(players_data, teams_data))
    results.append(verify_position_distribution(players_data, teams_data))
    results.append(verify_data_structure(players_data, teams_data))
    results.append(check_game_breaking_issues(players_data, teams_data))
    
    # Final summary
    print("\n" + "=" * 60)
    print("FINAL VERIFICATION SUMMARY")
    print("=" * 60)
    
    passed = sum(results)
    total = len(results)
    
    if all(results):
        print("🎉 ALL CHECKS PASSED! Database is fully verified and ready for use.")
        print(f"✅ {passed}/{total} verification checks successful")
    else:
        print(f"🚨 {total - passed}/{total} verification checks failed")
        print("⚠️  Database has issues that need to be resolved")
    
    return all(results)

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)