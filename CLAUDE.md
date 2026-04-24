# Sound Code

System alertów dźwiękowych dla Claude Code w terminalu VS Code (Git Bash / Windows).
Hooki (`SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, ...) są powiązane
z samplami z gier StarCraft / Warcraft przez plik `sounds.json`, zarządzany z
interaktywnego panelu `sound_panel.sh`.

## Stack

- Bash (Git Bash na Windows)
- PowerShell:
  - `[Media.SoundPlayer]::PlaySync()` — odtwarzanie WAV
  - `[Console]::Beep()` — fallback (beep / melodia)
  - `ConvertFrom-Json` / `ConvertTo-Json` — zapis panelu
- Claude Code hooks (`SessionStart`, `UserPromptSubmit`, `Notification`, `Stop`,
  `SubagentStop`, `PreCompact`, `SessionEnd`)

## Architektura

```
play_sound.sh        # wykonawca - dispatcher per hook
sound_panel.sh       # panel sterowania (TUI) - edytuje sounds.json
sounds.json          # stan panelu: mapowanie hook -> plik + flagi
sounds/              # pliki .wav ze StarCrafta / Warcrafta
  README.md          # oczekiwane nazwy plikow i jak zdobyc sample
```

## Jak to działa

1. Claude Code wywołuje hook → uruchamia `bash play_sound.sh <HookName>`.
2. `play_sound.sh` czyta `sounds.json`, znajduje wpis dla danego hooka, odtwarza
   `sounds/<plik>.wav` przez PowerShell.
3. Gdy plik nie istnieje / hook wyłączony / config wyłączony:
   - dla `Stop`: fallback = melodia Beethovena skalowana czasem pracy (legacy),
   - dla pozostałych: krótki beep (gdy `fallback_beep=true`).

`UserPromptSubmit` dodatkowo zapisuje timestamp do `$TEMP/claude_sound_start` — używany
przez fallback `Stop` do obliczenia liczby nut (1 nuta / 15 s pracy).

## Panel sterowania

```bash
bash sound_panel.sh
```

Funkcje:
1. Zmień plik dźwięku dla hooka
2. Włącz/wyłącz dźwięk dla konkretnego hooka
3. Globalne wł/wył wszystkich dźwięków
4. Przełącz fallback beep
5. Testuj — odtwórz dźwięk wybranego hooka
6. Pokaż pliki obecne w `sounds/`
7. Wygeneruj snippet do wklejenia w `~/.claude/settings.json`

Panel zapisuje zmiany w `sounds.json` natychmiast.

## Instalacja hooków

W panelu opcja 7 — skopiuj wygenerowany snippet do sekcji `"hooks"` w
`~/.claude/settings.json`. Alternatywnie ręcznie:

```json
"hooks": {
  "Stop": [{"hooks":[{"type":"command","command":"bash /c/.../play_sound.sh Stop"}]}],
  "UserPromptSubmit": [{"hooks":[{"type":"command","command":"bash /c/.../play_sound.sh UserPromptSubmit"}]}]
}
```

## Pliki dźwiękowe

Katalog `sounds/` nie zawiera próbek — są chronione prawem autorskim.
Użytkownik sam wrzuca pliki `.wav` (patrz `sounds/README.md` dla oczekiwanych nazw
i konwersji z MP3 przez `ffmpeg`).

## Parametry do strojenia

- **Mapowania hook → plik** — panel lub bezpośrednio `sounds.json`.
- **Fallback beep** — flaga `fallback_beep` w `sounds.json`.
- **Melodia fallback** — tablica częstotliwości w bloku PowerShell w `play_sound.sh`
  (zmienna `melody`), 15 nut, 1 nuta/15 s pracy.
- **Czas trwania nut** — 180 ms zwykłe, 300 ms ostatnia (funkcja `Play-Melody`).
