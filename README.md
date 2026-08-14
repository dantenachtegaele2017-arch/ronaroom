# CousinGame

**Concept:** Je lanceert je eigen taalmodel. Gebruikers stellen het vragen en leveren daarmee rekenkracht op; met rekenkracht train je het model (sneller/slimmer → meer groei) en bouw je datacenters/energie uit. Energie is de bottleneck. Doel: wereldwijde verspreiding voltooien. Idle/strategy-spel, een beetje Universal Paperclips × Plague Inc., met een AI-thema.

Gebouwd met [Godot 4](https://godotengine.org/) (GDScript, portrait, UI-based).

## Setup (eenmalig, voor beide van jullie)

1. **Godot installeren**
   - Download Godot 4 (stable, .NET-versie niet nodig) van https://godotengine.org/download/windows/
   - Kies de "Standard" versie (64-bit .zip), uitpakken, `Godot_v4.x-stable_win64.exe` starten. Geen installatie nodig.

2. **Repo clonen**
   ```bash
   git clone <GITHUB-REPO-URL>
   ```

3. **Project openen**
   - Godot starten → "Import" → wijs naar `project.godot` in deze map.

## Samenwerken via Git

- Werk niet allebei tegelijk in dezelfde scene (`.tscn`) — die bestanden zijn tekstueel maar merge-conflicten zijn lastig op te lossen. Spreek af wie aan welke scene/script werkt, of werk in aparte branches per feature.
- Commit vaak, kleine stapjes:
  ```bash
  git add .
  git commit -m "korte beschrijving"
  git push
  ```
- Haal wijzigingen van de ander op voor je begint:
  ```bash
  git pull
  ```
- `.godot/` en importbestanden staan in `.gitignore` — die hoeven niet gedeeld te worden, Godot genereert ze lokaal opnieuw.

## Projectstructuur

```
scenes/     # .tscn scene-bestanden (levels, UI, personages)
scripts/    # .gd scripts
assets/
  sprites/  # afbeeldingen
  audio/    # geluid/muziek
```

## Huidige status (v2)

- [x] Concept bepaald
- [x] Kernloop: naam kiezen → users genereren rekenkracht → upgrades → energie als bottleneck
- [x] Verspreiding per regio (8 regio's die na elkaar "vollopen", i.p.v. één kale balk)
- [x] Verhaalmomenten die vrijkomen bij gebruikersaantallen (bedrijven, media, overheden, robots, wereldovername)
- [x] Automatisch opslaan (elke 5s naar `user://savegame.json`) + "Nieuw spel beginnen"-knop
- [ ] Echte geografische wereldkaart i.p.v. regio-balken
- [ ] Balans tunen (groeisnelheid, kosten, energieverbruik) — huidige cijfers zijn een eerste gok
- [ ] Geluid/muziek + visuele polish (iconen, kleuren per regio)
- [ ] Testen op een echt Android-toestel (Godot → Export → Android)

Savegame-locatie op Windows: `%APPDATA%\Godot\app_userdata\CousinGame\savegame.json`. Verwijder dat bestand (of gebruik de "Nieuw spel beginnen"-knop in het spel) om opnieuw te beginnen.

## Spellogica

Alles zit in `scripts/Main.gd` (UI wordt in code opgebouwd, geen losse `.tscn`-knooppunten om merge-conflicten te vermijden). Belangrijkste variabelen bovenaan het script: groeisnelheid, kosten van upgrades, energieverbruik. Pas die aan om de balans te testen.
