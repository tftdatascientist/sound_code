# sounds/ — pliki dźwiękowe (StarCraft)

Dźwięki są **posegregowane po profilach rasowych**. Każdy profil to podkatalog:

```
sounds/
  terran/    - profil 1
  protoss/   - profil 2
  zerg/      - profil 3
             (profil "beep" = melodia Ody do Radości, bez plików)
```

## Konwencja nazw — **plik = nazwa hooka + `.wav`**

Wrzuć WAV-y z takimi nazwami:

| Hook Claude Code    | Oczekiwany plik             | Kiedy zagra                                     |
|---------------------|------------------------------|-------------------------------------------------|
| `SessionStart`      | `SessionStart.wav`           | start sesji Claude Code                         |
| `UserPromptSubmit`  | `UserPromptSubmit.wav`       | wysłałeś prompt                                  |
| `Notification`      | `Notification.wav`           | Claude czeka na akcję / permission prompt       |
| `Stop`              | `Stop.wav`                   | Claude skończył turę                            |
| `SubagentStop`      | `SubagentStop.wav`           | subagent skończył                                |
| `PreCompact`        | `PreCompact.wav`             | kompaktowanie kontekstu                          |
| `SessionEnd`        | `SessionEnd.wav`             | koniec sesji                                     |

Identyczne nazwy w każdym z `terran/`, `protoss/`, `zerg/` — brzmienie dobierasz sam.

### Sugestie sampli (luźne, swoboda wyboru)

| Hook              | Terran                          | Protoss                          | Zerg                          |
|-------------------|---------------------------------|----------------------------------|-------------------------------|
| `SessionStart`    | "Greetings, Commander"          | "Adun toridas"                   | Overmind greeting / intro     |
| `UserPromptSubmit`| Marine: "Yessir!"               | Probe: "Warp field secured"      | Drone: "For the Swarm"        |
| `Notification`    | "Your forces are under attack"  | "We require more pylons"         | Zergling: alert                |
| `Stop`            | SCV: "Job's finished" / "Reporting" | "Mission accomplished"       | "We have completed our task"   |
| `SubagentStop`    | "Objective complete"            | "Task complete"                  | "Victory is ours"              |
| `PreCompact`      | "Not enough minerals"           | "Not enough vespene"             | "Spawn more Overlords"         |
| `SessionEnd`      | "See you later"                 | "My life for Aiur"               | "We obey"                      |

To tylko sugestie — panel nie sprawdza *jaki* sampel to jest, tylko *czy plik istnieje* pod właściwą nazwą.

## Format

- **WAV (PCM 16‑bit)** — działa out-of-the-box przez `[Media.SoundPlayer]::PlaySync()`.
- **MP3 nieobsługiwane natywnie** — skonwertuj:
  ```bash
  ffmpeg -i sampel.mp3 SessionStart.wav
  ```

## Workflow — jak przenieść swoje WAV-y

Masz WAV-y o losowych nazwach posortowane jednostkami. Przykład (Terran SCV):

```bash
cd sounds/terran
cp ~/my_sc_wavs/scv_ready.wav         SessionStart.wav
cp ~/my_sc_wavs/scv_reporting.wav     UserPromptSubmit.wav
cp ~/my_sc_wavs/siege_tank_yes.wav    Notification.wav
cp ~/my_sc_wavs/scv_jobs_done.wav     Stop.wav
cp ~/my_sc_wavs/scv_complete.wav      SubagentStop.wav
cp ~/my_sc_wavs/not_enough_minerals.wav PreCompact.wav
cp ~/my_sc_wavs/scv_more_work.wav     SessionEnd.wav
```

Weryfikacja w panelu: `bash sound_panel.sh` → macierz pokazuje `OK` / `NO` dla każdej komórki.

## Test

```bash
# Odtwórz pojedynczy hook w wybranym profilu
SOUND_PROFILE=terran  bash play_sound.sh Stop
SOUND_PROFILE=protoss bash play_sound.sh Notification
SOUND_PROFILE=zerg    bash play_sound.sh SessionStart

# Interaktywnie (opcja 5 w menu)
bash sound_panel.sh
```

## Profil `beep`

Nie ma podkatalogu i nie ma plików — gdy wybrany, każdy hook leci fallback:
- `Stop` → melodia "Ode to Joy" (1 nuta / 15 s pracy),
- pozostałe → krótki beep 440 Hz.

## Sample

Repozytorium **nie zawiera** plików WAV — są chronione prawem autorskim.
Użyj własnych (wyekstrahowanych legalnie z plików gry).
