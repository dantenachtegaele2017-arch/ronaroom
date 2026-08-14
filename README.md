# CousinGame

Simpel mobiel spelletje, gebouwd met [Godot 4](https://godotengine.org/) (GDScript, 2D, portrait).

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

## Volgende stappen

- [ ] Bepaal het genre/concept (bv. endless runner, puzzel, klassieke arcade-clone)
- [ ] Basisspeler + besturing (touch input)
- [ ] Eén werkend level/scherm
- [ ] Score/game-over flow
- [ ] Testen op een echt Android-toestel (Godot → Export → Android)
