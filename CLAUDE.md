# Sound Code

System alertów dźwiękowych informujących o oczekiwaniu na użytkownika w trakcie sesji Claude Code w terminalu VS Code.

## Stack

- Bash (Git Bash na Windows)
- PowerShell `[Console]::Beep()` do odtwarzania dźwięku
- Claude Code hooks (`UserPromptSubmit`, `Stop`)

## Jak to działa

Dwa hooki w `~/.claude/settings.json` współpracują ze skryptem `play_sound.sh`:

1. **UserPromptSubmit** — użytkownik wysyła prompt → skrypt zapisuje timestamp startu do pliku tymczasowego (`$TEMP/claude_sound_start`)
2. **Stop** — Claude kończy pracę → skrypt odczytuje timestamp, oblicza czas pracy, gra odpowiednią liczbę nut z melodii

## Melodie

8 melodii rotowanych kolejno (co zadanie inna):

1. **Ode to Joy** — Beethoven
2. **Fur Elise** — Beethoven
3. **Turkish March** — Mozart
4. **Canon in D** — Pachelbel
5. **Eine kleine Nachtmusik** — Mozart
6. **Spring (Four Seasons)** — Vivaldi
7. **Symphony No. 5** — Beethoven
8. **Twinkle Twinkle** — wariant Mozarta

Licznik rotacji w `$TEMP/claude_sound_counter`. Po ostatniej melodii wraca do pierwszej.

Liczba odtwarzanych nut = `czas_pracy / 15s + 1`:

| Czas pracy | Nuty | Efekt |
|---|---|---|
| < 15s | 1 | Pojedynczy sygnał |
| ~1 min | 4 | Pierwszy takt (rozpoznawalny) |
| ~2 min | 8 | Dwa takty |
| ~3.5 min+ | 15-16 | Pełna fraza |

Ostatnia nuta jest zawsze dłuższa (300ms vs 180ms) dla poczucia zakończenia.

## Pliki

- `play_sound.sh` — jedyny skrypt, dwa tryby:
  - `play_sound.sh start` — zapisuje timestamp
  - `play_sound.sh` (bez argumentów) — oblicza czas i gra melodię
- `~/.claude/settings.json` — konfiguracja hooków (globalna, działa we wszystkich projektach)

## Parametry do strojenia

- **Interwał** — obecnie 15s na nutę (linia 22: `ELAPSED / 15 + 1`)
- **Czas trwania nut** — 180ms zwykłe, 300ms ostatnia (linie 39-41)
- **Przerwa między nutami** — 50ms (linia 43)
- **Melodie** — tablica `MELODIES` (łatwo dodać nowe lub podmienić istniejące)

