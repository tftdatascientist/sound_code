# Sound Code

System alertów dźwiękowych informujących o oczekiwaniu na użytkownika w trakcie sesji Claude Code w terminalu VS Code.

## Stack

- Bash (Git Bash na Windows)
- PowerShell `[Console]::Beep()` do odtwarzania dźwięku
- Claude Code hooks (`UserPromptSubmit`, `Stop`)
- Notion API do zdalnego sterowania melodiami
- Python 3 (do parsowania JSON z Notion)

## Jak to działa

Dwa hooki w `~/.claude/settings.json` współpracują ze skryptem `play_sound.sh`:

1. **UserPromptSubmit** — użytkownik wysyła prompt → skrypt zapisuje timestamp startu do pliku tymczasowego (`$TEMP/claude_sound_start`)
2. **Stop** — Claude kończy pracę → skrypt odczytuje timestamp, czyta konfigurację melodii z cache'a (zsynchronizowanego z Notion), gra odpowiednią melodię

## Sterowanie z Notion

Baza danych w Notion pozwala zdalnie konfigurować jaką melodię odtwarza każde zdarzenie:

| Kolumna | Typ | Opis |
|---|---|---|
| Event | title | Zdarzenie: `stop` lub `start` |
| Melody | select | Nazwa melodii (np. `nhl_goal_horn`) |
| Active | checkbox | Czy mapowanie jest aktywne |

### Setup

```bash
bash setup_notion.sh    # interaktywny kreator - tworzy bazę automatycznie
# lub ręcznie:
bash create_notion_db.sh <API_KEY> <PARENT_PAGE_ID>  # tworzy bazę
bash notion_sync.sh --setup <API_KEY> <DATABASE_ID>  # tylko zapisuje credentials
```

### Synchronizacja

Auto-sync wbudowany w `play_sound.sh` — odpytuje Notion co 5 minut (TTL cache).
Ręczny sync:

```bash
bash notion_sync.sh     # pobiera config z Notion do lokalnego cache'a
```

### Zmiana melodii

1. Otwórz bazę w Notion
2. Odznacz aktualnie aktywną melodię (Active = off)
3. Zaznacz nową (Active = on)
4. Zmiana zadziała automatycznie w ciągu 5 minut (lub po `bash notion_sync.sh`)

Cache zapisywany jest w `$TEMP/claude_sound_config` (format `event=melody`).

## Dostępne melodie

### Klasyczne
| Nazwa | Opis | Skalowanie |
|---|---|---|
| `ode_to_joy` | Beethoven - Oda do radości (15 nut) | Tak - nuty rosną z czasem pracy |

### NHL Hockey
| Nazwa | Opis | Nut |
|---|---|---|
| `nhl_goal_horn` | Syrena po golu + fanfara | 7 |
| `nhl_charge` | Klasyczne organowe "Charge!" | 6 |
| `nhl_hat_trick` | 3x klakson + fanfara zwycięstwa | 9 |
| `nhl_power_play` | Energetyczny, szybki motyw | 9 |
| `nhl_overtime` | Dramatyczny build-up do kulminacji | 8 |
| `nhl_organ_lets_go` | Organowe "Let's Go!" z trybun | 10 |

NHL melodies grają zawsze pełną frazę (nie skalują się z czasem pracy).

## Pliki

- `play_sound.sh` — główny skrypt, trzy tryby:
  - `play_sound.sh start` — zapisuje timestamp
  - `play_sound.sh` (bez argumentów) — czyta config z cache'a, gra melodię
  - `play_sound.sh <melody_name>` — gra konkretną melodię
- `notion_sync.sh` — synchronizuje konfigurację z Notion do lokalnego cache'a
- `create_notion_db.sh` — tworzy bazę danych w Notion przez API (z gotowymi opcjami)
- `setup_notion.sh` — interaktywny kreator (prowadzi krok po kroku, wywołuje create_notion_db.sh)
- `~/.claude/settings.json` — konfiguracja hooków (globalna)
- `~/.claude_sound_notion` — dane dostępowe do Notion (chmod 600)
- `$TEMP/claude_sound_config` — lokalny cache konfiguracji

## Parametry do strojenia

- **Interwał (ode_to_joy)** — 15s na nutę
- **Melodie NHL** — zawsze grają pełną frazę, niezależnie od czasu pracy
- **Częstotliwości/czasy** — definiowane w `case` w `play_sound.sh` (tablice FREQS, DURS, GAPS)
- **Auto-sync TTL** — 300s (5 min), konfigurowalne w `play_sound.sh` (zmienna `SYNC_INTERVAL`)
