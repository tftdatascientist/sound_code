# Sound Code

System alertów dźwiękowych dla Claude Code w terminalu VS Code (Git Bash / Windows).
Hooki (`SessionStart`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStop`,
`PreCompact`, `SessionEnd`) są powiązane z samplami ze **StarCrafta**, pogrupowanymi
w profile rasowe (`terran` / `protoss` / `zerg` / `beep`). Profil wybiera się per
terminal zmienną środowiskową `SOUND_PROFILE`. Stan trzyma `sounds.json`, zarządzany
interaktywnym panelem `sound_panel.sh`. Integracja z Notion (konfiguracja + log
zdarzeń + dashboard) w `notion_sync.sh`.

## Stack

- Bash (Git Bash na Windows)
- PowerShell:
  - `[Media.SoundPlayer]::PlaySync()` — odtwarzanie WAV
  - `[Console]::Beep()` — fallback (beep / melodia)
  - `ConvertFrom-Json` / `ConvertTo-Json` — stan w JSON
  - `Invoke-RestMethod` — Notion API (HTTP + JSON)
- Claude Code hooks (`SessionStart`, `UserPromptSubmit`, `Notification`, `Stop`,
  `SubagentStop`, `PreCompact`, `SessionEnd`)

## Architektura

```
play_sound.sh        # wykonawca - dispatcher per hook, uwzglednia SOUND_PROFILE
sound_panel.sh       # panel TUI - profile x hook, test, snippet, podmenu Notion
notion_sync.sh       # Notion: bootstrap / push / pull / log / dashboard
sounds.json          # stan: profiles + hooks + flagi + ID Notion
sounds/
  terran/            # profil 1: SessionStart.wav, UserPromptSubmit.wav, ...
  protoss/           # profil 2
  zerg/              # profil 3
  README.md          # konwencja nazw + sugestie sampli
```

Profil `beep` nie ma podkatalogu — odpala zawsze fallback-melodię "Ode to Joy".

## Jak to działa

1. Claude Code wywołuje hook → `bash play_sound.sh <HookName>`.
2. `play_sound.sh` ustala profil (kolejność: `$SOUND_PROFILE` → `$SOUND_PROFILE_FILE`
   → `$TEMP/sound_profile.$PPID` → `sounds.json .default_profile`).
3. Szuka `sounds/<profile.subdir>/<HookName>.wav`. Jeśli jest — odtwarza synchronicznie
   przez PowerShell.
4. Gdy brak pliku / profil wyłączony / config wyłączony:
   - `Stop` → melodia Beethovena skalowana czasem pracy (1 nuta/15 s),
   - pozostałe → krótki beep 440 Hz (gdy `fallback_beep=true`).
5. (Opcjonalnie) loguje zdarzenie do Notion (`notion.log_events=true`) — fire-and-forget
   w tle, nie blokuje hooka.

`UserPromptSubmit` zapisuje timestamp do `$TEMP/claude_sound_start` — używany przez
fallback `Stop` do obliczenia liczby nut.

## Profile per terminal (VS Code)

Każdy terminal VS Code to własna shell-sesja z własnymi env varami — wystarczy:

```bash
# terminal 1
export SOUND_PROFILE=terran
# terminal 2
export SOUND_PROFILE=protoss
# terminal 3
export SOUND_PROFILE=zerg
# terminal 4
export SOUND_PROFILE=beep
```

### Kontrakt dla własnego rozszerzenia VS Code

Rozszerzenie może tworzyć terminale z wstrzykniętym profilem:

```ts
vscode.window.createTerminal({
  name: 'Claude (terran)',
  env:  { SOUND_PROFILE: 'terran' }
});
```

Dynamiczna zmiana profilu bez restartu terminala — dwie ścieżki override:

- **`$SOUND_PROFILE_FILE`** — ścieżka do pliku z nazwą profilu; extension aktualizuje
  plik, `play_sound.sh` czyta przy każdym odpaleniu hooka.
- **`$TEMP/sound_profile.$PPID`** — fallback bez konfigurowania env vara; PPID
  hooka = PID shell'a terminala, więc rozszerzenie może nasłuchiwać PID-ów swoich
  terminali i zapisywać per-PID.

Rozstrzygnięcie w `play_sound.sh`: env > plik wskazany env-em > plik po PID > domyślny.

## Panel sterowania

```bash
bash sound_panel.sh
```

1. Ustaw default profile
2. Włącz/wyłącz hook w konkretnym profilu
3. Globalnie wł/wył wszystkich dźwięków
4. Przełącz fallback beep
5. Testuj — odtwórz hook w wybranym profilu (`SOUND_PROFILE=X bash play_sound.sh H`)
6. Pokaż pliki obecne w `sounds/<profile>/`
7. Snippet do `~/.claude/settings.json` + wzór `export SOUND_PROFILE=...`
8. Podmenu Notion (status / bootstrap / push / pull / dashboard / toggle log)

Widok główny pokazuje macierz hook × profile z oznaczeniem `OK`/`NO` (czy WAV jest na dysku).

## Integracja Notion (`notion_sync.sh`)

Wymaga `NOTION_TOKEN` w środowisku (secret z Twojej integracji Notion).
Integracja musi być zaproszona do strony‑rodzica (Share → Connections).

```bash
export NOTION_TOKEN='secret_xxx...'
bash notion_sync.sh bootstrap <parent_page_id>    # tworzy bazy A,B i stronę C
bash notion_sync.sh push                          # lokalny config → Notion A
bash notion_sync.sh pull                          # Notion A → lokalny config
bash notion_sync.sh dashboard                     # odśwież stronę C
bash notion_sync.sh status
```

Zawartość:

- **A. Config DB** (`Sound Code — Config`) — kolumny: `Key` (title), `Hook`, `Profile`,
  `Enabled`, `Label`. Jeden wiersz per (hook × profile). Źródło prawdy dla `enabled`.
- **B. Log DB** (`Sound Code — Event Log`) — `Event`, `Timestamp`, `Hook`, `Profile`,
  `Played`, `File`. Wpis generowany przez `play_sound.sh` w tle (fire-and-forget)
  gdy `notion.log_events=true`.
- **C. Dashboard** (`Sound Code — Dashboard`) — strona ze status-widokiem wszystkich
  profili, regenerowana komendą `dashboard`.

ID baz trzymane są w `sounds.json → notion.{config_db_id, log_db_id, dashboard_page_id}`.

## Instalacja hooków

Z panelu, opcja 7 — wklej wygenerowany snippet do `"hooks"` w `~/.claude/settings.json`.
Ręcznie (skrócone):

```json
"hooks": {
  "Stop":             [{"hooks":[{"type":"command","command":"bash /c/.../play_sound.sh Stop"}]}],
  "UserPromptSubmit": [{"hooks":[{"type":"command","command":"bash /c/.../play_sound.sh UserPromptSubmit"}]}]
}
```

Hooki są globalne (`~/.claude/settings.json`), ale profil rozstrzyga się per terminal
w momencie odpalenia hooka.

## Pliki dźwiękowe

Katalog `sounds/` nie zawiera próbek — prawa autorskie. Patrz `sounds/README.md` dla
konwencji nazw (plik = nazwa hooka + `.wav`) i sugerowanych sampli na profil.
Konwersja MP3 → WAV: `ffmpeg -i in.mp3 out.wav`.

## Parametry do strojenia

- **Profile i hooki** — panel / `sounds.json`.
- **Fallback beep** — flaga `fallback_beep` (panel opcja 4).
- **Melodia fallback** — tablica `$melody` w bloku PowerShell w `play_sound.sh`
  (15 nut, 1 nuta/15 s pracy, ostatnia 300 ms).
- **Logowanie do Notion** — `notion.log_events` (panel Notion → opcja 5).
