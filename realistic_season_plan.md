# Realistische Fußball-Saison 2025/26 (nach UEFA/DFB Terminen)

## Saison-Timeline: August 2025 - Mai 2026 (ECHTE TERMINE!)

### **AUGUST 2025 (Wochen 1-4)**
- **Woche 1**: **DFB-Pokal 1. Runde** (15-18 Aug)
- **Woche 2**: 1. Bundesliga-Spieltag (22 Aug Start)
- **Woche 3**: 2. Bundesliga-Spieltag
- **Woche 4**: 3. Bundesliga-Spieltag

### **SEPTEMBER 2025 (Wochen 5-8)**
- **Woche 5**: 4. Bundesliga-Spieltag + **Champions League MD1** (16-18 Sep)
- **Woche 6**: 5. Bundesliga-Spieltag
- **Woche 7**: 6. Bundesliga-Spieltag + **Champions League MD2** (30 Sep-1 Oct)
- **Woche 8**: 7. Bundesliga-Spieltag

### **OKTOBER 2025 (Wochen 9-12)**
- **Woche 9**: 8. Bundesliga-Spieltag + **Champions League MD3** (21-22 Oct)
- **Woche 10**: 9. Bundesliga-Spieltag
- **Woche 11**: 10. Bundesliga-Spieltag
- **Woche 12**: 11. Bundesliga-Spieltag + **Champions League MD4** (4-5 Nov)

### **NOVEMBER 2025 (Wochen 13-16)**
- **Woche 13**: 12. Bundesliga-Spieltag + **Champions League MD5** (25-26 Nov)
- **Woche 14**: 13. Bundesliga-Spieltag
- **Woche 15**: 14. Bundesliga-Spieltag
- **Woche 16**: 15. Bundesliga-Spieltag

### **DEZEMBER 2025 (Wochen 17-20)**
- **Woche 17**: **DFB-Pokal 2. Runde** (2-3 Dez) + 16. Bundesliga-Spieltag
- **Woche 18**: 17. Bundesliga-Spieltag + **Champions League MD6** (9-10 Dez)
- **Woche 19**: **WINTERPAUSE** (nach 19-21 Dez)
- **Woche 20**: **WINTERPAUSE**

### **JANUAR 2026 (Wochen 21-24)**
- **Woche 21**: **WINTERPAUSE**
- **Woche 22**: 18. Bundesliga-Spieltag (9-11 Jan) + **Champions League MD7** (20-21 Jan)
- **Woche 23**: 19. Bundesliga-Spieltag + **Champions League MD8** (28 Jan - FINALE LIGA-PHASE)
- **Woche 24**: 20. Bundesliga-Spieltag

### **FEBRUAR 2026 (Wochen 25-28)**
- **Woche 25**: 21. Bundesliga-Spieltag + **DFB-Pokal Achtelfinale** (3-11 Feb)
- **Woche 26**: 22. Bundesliga-Spieltag + **CL Playoffs Hinspiel** (17-18 Feb)
- **Woche 27**: 23. Bundesliga-Spieltag + **CL Playoffs Rückspiel** (24-25 Feb)
- **Woche 28**: 24. Bundesliga-Spieltag

### **MÄRZ 2026 (Wochen 29-32)**
- **Woche 29**: 25. Bundesliga-Spieltag + **CL Achtelfinale Hinspiel** (10-11 März)
- **Woche 30**: 26. Bundesliga-Spieltag + **CL Achtelfinale Rückspiel** (17-18 März)
- **Woche 31**: 27. Bundesliga-Spieltag
- **Woche 32**: 28. Bundesliga-Spieltag

### **APRIL 2026 (Wochen 33-36)**
- **Woche 33**: 29. Bundesliga-Spieltag + **CL Viertelfinale Hinspiel** (7-8 Apr)
- **Woche 34**: 30. Bundesliga-Spieltag + **CL Viertelfinale Rückspiel** (14-15 Apr)
- **Woche 35**: 31. Bundesliga-Spieltag + **DFB-Pokal Halbfinale** (21-22 Apr)
- **Woche 36**: 32. Bundesliga-Spieltag + **CL Halbfinale Hinspiel** (28-29 Apr)

### **MAI 2026 (Wochen 37-40)**
- **Woche 37**: 33. Bundesliga-Spieltag + **CL Halbfinale Rückspiel** (5-6 Mai)
- **Woche 38**: 34. Bundesliga-Spieltag (16 Mai - SAISONENDE)
- **Woche 39**: **DFB-Pokal FINALE** (23 Mai Berlin) + Relegation Play-offs (21-22 & 25-26 Mai)
- **Woche 40**: **CHAMPIONS LEAGUE FINALE** (30 Mai Budapest)

### **JUNI-AUGUST 2026 (Wochen 41-52)**
- **Sommerpause + Transfers + Neue Saison Vorbereitung**

---

## Implementierung-Plan für Anstoss 1:

### **Neue Wochenstruktur:**
```gdscript
{
  "week": 5,
  "league_matchday": 4,           // 4. Bundesliga-Spieltag
  "cup_matches": {
    "champions_league": {         // Dienstag/Mittwoch
      "matchday": 1,
      "matches": [...]
    }
  },
  "description": "4. Spieltag + CL Matchday 1"
}
```

### **Key Features:**
- ✅ **34 Bundesliga-Spieltage** (22 Aug - 16 Mai)
- ✅ **Champions League Liga-Phase**: 8 Spieltage (Sep-Jan)
- ✅ **Champions League K.O.-Phase**: 5 Runden (Feb-Mai) 
- ✅ **DFB-Pokal**: 6 Runden über ganze Saison
- ✅ **Winterpause**: 3 Wochen (Dez-Jan)
- ✅ **Alles endet im Mai 2026** - Finale am 30. Mai!

### **Implementation:**
1. ScheduleGenerator: Liga + Pokal pro Woche
2. MatchdayEngine: 2 Matches pro Woche (Liga + Pokal)
3. CupManager: Echte Terminierung nach UEFA-Kalender