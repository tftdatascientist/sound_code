# Sound Code

System alertów dźwiękowych i rejestr sesji Claude Code w Notion.

## Stack

- Bash (Git Bash na Windows)
- PowerShell `[Console]::Beep()` do odtwarzania dźwięku
- Claude Code hooks (`UserPromptSubmit`, `Stop`)

## Jak to działa

Dwa hooki w `~/.claude/settings.json` współpracują ze skryptem `play_sound.sh`:

1. **UserPromptSubmit** — użytkownik wysyła prompt → skrypt zapisuje timestamp startu do pliku tymczasowego (`$TEMP/claude_sound_start`)
2. **Stop** — Claude kończy pracę → skrypt odczytuje timestamp, oblicza czas pracy, gra odpowiednią liczbę nut z melodii

## Melodia

"Ode to Joy" Beethovena (pierwsza fraza, 15 nut). Liczba odtwarzanych nut = `czas_pracy / 15s + 1`:

| Czas pracy | Nuty | Efekt |
|---|---|---|
| < 15s | 1 | Pojedynczy sygnał |
| ~1 min | 4 | Pierwszy takt (rozpoznawalny) |
| ~2 min | 8 | Dwa takty |
| ~3.5 min+ | 15 | Pełna fraza |

Ostatnia nuta jest zawsze dłuższa (300ms vs 180ms) dla poczucia zakończenia.

## Pliki

- `play_sound.sh` — dźwięki, dwa tryby:
  - `play_sound.sh start` — zapisuje timestamp
  - `play_sound.sh` (bez argumentów) — oblicza czas i gra melodię
- `notion_session_registry.sh` — status line + rejestr sesji w Notion
- `~/.claude/settings.json` — konfiguracja hooków i status line (globalna)

## Notion Session Registry

Automatyczny rejestr sesji >100k tokenów w bazie [Rejestr CC](https://www.notion.so/2091eecaa19c45ed815b16a7dec3d173).

**Mechanizm:** Status line Claude Code (jedyne miejsce z danymi o tokenach) uruchamia `notion_session_registry.sh` po każdej odpowiedzi asystenta:
1. Parsuje JSON (tokeny, koszt, session_id)
2. Wyświetla status: `125k tok | $0.45 | ctx 62%`
3. Przy >= 100k tokenów → rejestruje sesję w Notion (curl w tle, jednokrotnie)

**Deduplikacja:** Flag file `/tmp/claude_notion_registry/<session_id>.registered`

**Wymagania:**
- Notion Internal Integration Token w `~/.claude/.notion_api_key`
- Baza udostępniona integracji (Connections → dodaj)
- `jq`, `curl` w PATH

**Konfiguracja w `~/.claude/settings.json`:**
```json
"statusLine": { "type": "command", "command": "~/.claude/notion_session_registry.sh" }
```

## Parametry do strojenia

- **Interwał** — obecnie 15s na nutę (linia 22: `ELAPSED / 15 + 1`)
- **Czas trwania nut** — 180ms zwykłe, 300ms ostatnia (linie 39-41)
- **Przerwa między nutami** — 50ms (linia 43)
- **Melodia** — tablica częstotliwości Hz w linii 29 (łatwo podmienić na inną)

