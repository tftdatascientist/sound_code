# sounds/ — katalog plików dźwiękowych

Wrzuć tu własne pliki `.wav` (zalecane — `[Media.SoundPlayer]` obsługuje WAV natywnie i synchronicznie).

## Domyślne mapowania (z `sounds.json`)

| Hook Claude Code    | Oczekiwany plik                    | Sugerowany sampel                                  |
|---------------------|------------------------------------|----------------------------------------------------|
| `SessionStart`      | `sc_terran_greetings.wav`          | SC — "Greetings, Commander"                        |
| `UserPromptSubmit`  | `wc_peon_zug_zug.wav`              | WC — Peon: "Zug zug"                               |
| `Notification`      | `sc_nuclear_launch.wav`            | SC — "Nuclear launch detected"                     |
| `Stop`              | `wc_peon_work_complete.wav`        | WC — Peon: "Work complete" / "Job's done"          |
| `SubagentStop`      | `sc_mission_accomplished.wav`      | SC — "Mission accomplished"                        |
| `PreCompact`        | `sc_not_enough_minerals.wav`       | SC — "Not enough minerals"                         |
| `SessionEnd`        | `wc_peasant_goodbye.wav`           | WC — Peasant: "Goodbye"                            |

Nazwy możesz dowolnie zmienić w panelu (`bash sound_panel.sh`, opcja 1) lub bezpośrednio w `sounds.json`.

## Format

- **WAV (PCM)** — działa out-of-the-box przez `[Media.SoundPlayer]::PlaySync()`.
- **MP3** — `[Media.SoundPlayer]` ich nie umie. Jeśli chcesz mp3, trzeba albo skonwertować
  do WAV (np. `ffmpeg -i in.mp3 out.wav`), albo rozszerzyć `play_sound.sh` o Windows Media API.

## Gdzie zdobyć dźwięki

Sample z StarCrafta i Warcrafta są chronione prawem autorskim — ten repozytorium ich nie zawiera.
Zdobądź je legalnie (np. z własnej instalacji gry, plików MPQ) i wrzuć tutaj pod
nazwami z tabeli wyżej albo zmapuj w panelu własne.

## Test

```bash
# Test pojedynczego dźwięku
bash play_sound.sh Stop
bash play_sound.sh UserPromptSubmit

# Panel sterowania (opcja 5 — testuj)
bash sound_panel.sh
```

Gdy pliku brak, a `fallback_beep=true`, skrypt zagra dotychczasową melodię "Ody do Radości"
(Stop) lub krótki beep (pozostałe hooki).
