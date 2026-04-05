# Dane Srodowiska Claude - Kompletna Mapa

> Lokalizacja bazowa: `C:\Users\Slawek\.claude\`
>
> Data: 2026-04-05 | Windows 11

---

## Spis tresci

1. [Claude Code (CLI/Terminal)](#1-claude-code-cliterminal)
2. [Claude.ai (Web App)](#2-claudeai-web-app)
3. [Zrodla konfiguracji, pamieci i kontekstu](#3-zrodla-konfiguracji-pamieci-i-kontekstu)
4. [Hierarchia priorytetow](#4-hierarchia-priorytetow)
5. [Komendy inspekcji](#5-komendy-inspekcji)

---

## 1. Claude Code (CLI/Terminal)

### 1.1 Katalog glowny `~/.claude/`

| Plik / Katalog | Sciezka Windows | Opis | Dane |
|---|---|---|---|
| **settings.json** | `C:\Users\Slawek\.claude\settings.json` | Globalne ustawienia uzytkownika | `permissions` (allow/deny narzedzi), `hooks` (eventy + komendy), `env` (zmienne srodowiskowe), `model` (domyslny model), `autoMemoryEnabled` (bool), `theme`, `sandbox` |
| **settings.local.json** | `C:\Users\Slawek\.claude\settings.local.json` | Lokalne nadpisania (nie commitowane) | Identyczna struktura jak settings.json, wyzszy priorytet |
| **.credentials.json** | `C:\Users\Slawek\.claude\.credentials.json` | Tokeny uwierzytelniania (0600) | `oauth.access_token`, `oauth.refresh_token`, `oauth.expires_at`, `api_key.key`, `api_key.provider` (claude/bedrock/vertex/foundry), `console_credentials.token`, `console_credentials.org_id` |
| **CLAUDE.md** | `C:\Users\Slawek\.claude\CLAUDE.md` | Osobiste instrukcje (wszystkie projekty) | Markdown - ladowany na starcie kazdej sesji |
| **.mcp.json** | `C:\Users\Slawek\.claude\.mcp.json` | Konfiguracja serwerow MCP uzytkownika | `mcpServers.{nazwa}.type` (stdio/http), `.command`, `.args[]`, `.env{}`, `.auth{}` |
| **rules/** | `C:\Users\Slawek\.claude\rules\` | Reguly uzytkownika (all projects) | Pliki `.md` - z opcjonalnym frontmatter `paths:` do filtrowania sciezek |
| **skills/** | `C:\Users\Slawek\.claude\skills\` | Zainstalowane skille | Pliki `SKILL.md` z frontmatter: `title`, `description`, `trigger`, `permissions[]`, `tools[]`, `model` |

### 1.2 Pamiec automatyczna (Auto Memory)

| Element | Sciezka Windows | Dane |
|---|---|---|
| **MEMORY.md** | `C:\Users\Slawek\.claude\projects\<hash-projektu>\memory\MEMORY.md` | Indeks pamieci - pierwsze 200 linii lub 25KB ladowane na starcie sesji |
| **Pliki tematyczne** | `C:\Users\Slawek\.claude\projects\<hash-projektu>\memory\*.md` | Pliki tworzone przez Claude (np. `debugging.md`, `api-conventions.md`) - ladowane on-demand |
| **Pamiec subagentow** | `C:\Users\Slawek\.claude\projects\<hash-projektu>\agents\<nazwa>\memory\` | Osobna pamiec per subagent |

**Co jest zapisywane w pamieci:**
- Komendy build/test projektu
- Korekty zachowania Claude przez uzytkownika
- Wzorce API/architektury
- Spostrzenia z debugowania
- Preferencje i workflow uzytkownika

**Wlasciwosci:**
- Lokalna maszyna (nie synchronizowana)
- Przezywa `/compact` (reinjectowana)
- Edytowalna przez uzytkownika (plain markdown)
- Hash projektu oparty o sciezke git repo (wszystkie worktree wspoldziela pamiec)

### 1.3 Pliki CLAUDE.md (wiele zakresow)

| Zakres | Sciezka | Wspoldzielony? | Kiedy ladowany |
|---|---|---|---|
| **Managed (org)** | `C:\Program Files\ClaudeCode\CLAUDE.md` | Tak (admin) | Start sesji (nie mozna wykluczyc) |
| **User** | `C:\Users\Slawek\.claude\CLAUDE.md` | Nie | Start sesji |
| **Project** | `.\CLAUDE.md` lub `.\.claude\CLAUDE.md` | Tak (git) | Start sesji |
| **Project local** | `.\CLAUDE.local.md` | Nie (.gitignore) | Start sesji |
| **Podkatalogi** | `.\src\CLAUDE.md`, `.\tests\CLAUDE.md` itd. | Tak (git) | On-demand (gdy Claude czyta pliki z tego katalogu) |

**Skladnia importow:** `@sciezka/do/pliku` - importuje inny plik (maks. 5 poziomow rekursji)

### 1.4 Konfiguracja na poziomie projektu

| Plik | Sciezka | Dane |
|---|---|---|
| **settings.json** | `.\.claude\settings.json` | Permissions, hooks, env - wspoldzielone z zespolem |
| **settings.local.json** | `.\.claude\settings.local.json` | Lokalne nadpisania - nie commitowane |
| **rules/** | `.\.claude\rules\*.md` | Reguly per-sciezka (frontmatter `paths:`) |
| **agents/** | `.\.claude\agents\*.md` | Definicje subagentow: `name`, `description`, `scope`, `model`, `permissions`, `autoMemoryEnabled` |
| **.mcp.json** | `.\.mcp.json` (root projektu) | Serwery MCP per-projekt |
| **CLAUDE.md** | `.\CLAUDE.md` | Instrukcje projektowe |

### 1.5 Hooki - dostepne eventy

| Event | Kiedy | Mozliwosci |
|---|---|---|
| `SessionStart` | Start/wznowienie sesji | Inicjalizacja srodowiska |
| `InstructionsLoaded` | Zaladowanie CLAUDE.md | Modyfikacja kontekstu |
| `UserPromptSubmit` | Wyslanie promptu | Logowanie, walidacja |
| `PreToolUse` | Przed wywolaniem narzedzia | **Moze zablokowac** (exit code != 0) |
| `PostToolUse` | Po uzyciu narzedzia (sukces) | Logowanie, reakcja |
| `PostToolUseFailure` | Po uzyciu narzedzia (blad) | Diagnostyka |
| `PermissionRequest` | Dialog uprawnien | Automatyczne decyzje |
| `PermissionDenied` | Narzedzie zablokowane | Logowanie |
| `Notification` | Wyslanie notyfikacji | Przekierowanie (dzwiek, Slack) |
| `Stop` | Claude skonczyl odpowiedz | Walidacja, dzwiek, cleanup |
| `ConfigChange` | Zmiana ustawien | Reakcja na zmiany |
| `CwdChanged` | Zmiana katalogu roboczego | Przeladowanie kontekstu |
| `FileChanged` | Zmiana obserwowanego pliku | Hot-reload |
| `PreCompact` / `PostCompact` | Kompakcja kontekstu | Zapis/odczyt stanu |
| `SessionEnd` | Koniec sesji | Cleanup |
| `SubagentStart` / `SubagentStop` | Cykl zycia subagenta | Monitorowanie |
| `TaskCreated` / `TaskCompleted` | Cykl zycia zadania | Tracking |
| `WorktreeCreate` / `WorktreeRemove` | Git worktree | Zarzadzanie izolacja |

**Format hooka w settings.json:**
```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "sciezka/do/skryptu.sh"
      }]
    }]
  }
}
```

### 1.6 Uwierzytelnianie - kolejnosc rozwiazywania

| Priorytet | Zrodlo | Opis |
|---|---|---|
| 1 (najwyzszy) | Zmienne srodowiskowe cloud | `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_FOUNDRY` |
| 2 | `ANTHROPIC_AUTH_TOKEN` | Bearer token (np. gateway/proxy) |
| 3 | `ANTHROPIC_API_KEY` | Bezposredni klucz API |
| 4 | `apiKeyHelper` | Skrypt zwracajacy klucz |
| 5 (najnizszy) | `.credentials.json` | OAuth z pliku lokalnego |

### 1.7 Stan globalny

| Plik | Sciezka Windows | Dane |
|---|---|---|
| **.claude.json** | `C:\Users\Slawek\.claude.json` | `theme`, `userId`, `lastLogin`, `mcpServers`, `keybindings` |

### 1.8 Zmienne srodowiskowe

| Zmienna | Opis |
|---|---|
| `CLAUDE_CONFIG_DIR` | Nadpisanie katalogu konfiguracji (domyslnie `~/.claude`) |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | Wylacz auto-pamiec (`1`) |
| `CLAUDE_CODE_GIT_BASH_PATH` | Sciezka do Git Bash na Windows |
| `CLAUDE_PROJECT_DIR` | Katalog projektu (dostepne w hookach) |
| `CLAUDE_ENV_FILE` | Plik env dla komend Bash |
| `CLAUDE_CODE_REMOTE` | Flaga sesji zdalnej |
| `ANTHROPIC_API_KEY` | Klucz API |
| `ANTHROPIC_AUTH_TOKEN` | Token Bearer |

### 1.9 Pliki tymczasowe i cache

| Typ | Lokalizacja Windows | Dane |
|---|---|---|
| Cache npm | `C:\Users\Slawek\.npm\_cacache\` | Pobrane paczki (sha512) |
| Logi npm | `C:\Users\Slawek\.npm\_logs\` | Debug logi z datami |
| Pliki tymczasowe | `%TEMP%\` | Pliki sesyjne (np. `claude_sound_start` z play_sound.sh) |
| Indeksy wyszukiwania | W pamieci | Cache ripgrep, LSP |

### 1.10 Managed Settings (Enterprise)

| Zrodlo | Sciezka | Opis |
|---|---|---|
| Plik | `C:\Program Files\ClaudeCode\managed-settings.json` | Polityki organizacji |
| CLAUDE.md | `C:\Program Files\ClaudeCode\CLAUDE.md` | Instrukcje org (nie mozna wykluczyc) |
| MDM | Windows Group Policy | Polityki domenowe |
| Serwer | API push | Zdalne zarzadzanie |

**Unikalne ustawienia managed:**
- `forceLoginMethod` - wymuszenie SSO
- `forceLoginOrgUUID` - blokada do organizacji
- `deniedMcpServers` / `allowedMcpServers` - blacklist/whitelist MCP

---

## 2. Claude.ai (Web App)

### 2.1 Dane przechowywane w przegladarce

| Typ | Technologia | Dane |
|---|---|---|
| **Sesja** | Cookies | Token sesji, preferencje jezyka |
| **Ustawienia UI** | localStorage | Motyw, rozmiar czcionki, stan paneli |
| **Cache** | IndexedDB | Cachowane odpowiedzi, drafty |
| **Credentials** | Zaszyfrowane w sesji | Token OAuth (nie bezposrednio dostepny) |

### 2.2 Dane przechowywane server-side (cloud)

| Typ | Dane | Mozliwosc eksportu |
|---|---|---|
| **Projekty** | `nazwa`, `data_utworzenia`, `data_modyfikacji`, `opis`, `instrukcje_projektowe` | Tak (UI) |
| **Watki (Conversations)** | `tytul`, `data_utworzenia`, `data_ostatniej_wiadomosci`, `model_uzywany`, `lista_wiadomosci[]` | Tak (eksport) |
| **Wiadomosci** | `tresc`, `rola` (user/assistant), `timestamp`, `tokeny_uzyte`, `artifacts[]`, `zalaczniki[]` | Tak (eksport) |
| **Artifacts** | `typ` (kod/dokument/svg/html), `tytul`, `tresc`, `jezyk`, `wersja` | Tak (kopiowanie) |
| **Pamiec (Memory)** | `fakt`, `data_dodania`, `zrodlo_watku` | Tak (Settings > Memory) |
| **Styles** | `nazwa_stylu`, `opis_preferencji`, `data_utworzenia` | Tak (UI) |
| **Konto** | `email`, `plan` (Free/Pro/Team/Enterprise), `org_id`, `limity_uzycia` | Czesciowe |
| **Uzycie** | `tokeny_wejsciowe`, `tokeny_wyjsciowe`, `model`, `data`, `koszt` | Czesciowe (dashboard) |

### 2.3 Zrodla kontekstu w Claude.ai

| Zrodlo | Zakres | Trwalosc |
|---|---|---|
| **System prompt** | Per watek | Sesyjna |
| **Instrukcje projektowe** | Per projekt (wszystkie watki) | Trwale |
| **Memory** | Globalne (wszystkie watki) | Trwale (do usuniecia) |
| **Styles** | Wybierany per watek | Trwale |
| **Zalaczniki** | Per wiadomosc | Sesyjna |
| **Kontekst MCP** | Per integracja | Sesyjna |
| **Connected apps** | Google Drive, GitHub itd. | Trwale (do odlaczenia) |

---

## 3. Zrodla konfiguracji, pamieci i kontekstu

### 3.1 Pelna mapa zrodel (Claude Code)

```
KONTEKST SESJI CLAUDE CODE
==========================

[1] MANAGED (najwyzszy priorytet, read-only)
    |-- C:\Program Files\ClaudeCode\managed-settings.json
    |-- C:\Program Files\ClaudeCode\CLAUDE.md
    |-- managed-mcp.json (server-pushed)
    |
[2] USER (globalne, osobiste)
    |-- C:\Users\Slawek\.claude\settings.json          -> permissions, hooks, env, model
    |-- C:\Users\Slawek\.claude\CLAUDE.md               -> instrukcje osobiste
    |-- C:\Users\Slawek\.claude\rules\*.md              -> reguly osobiste
    |-- C:\Users\Slawek\.claude\.mcp.json               -> serwery MCP
    |-- C:\Users\Slawek\.claude\.credentials.json       -> tokeny auth
    |-- C:\Users\Slawek\.claude.json                    -> stan globalny (theme, userId)
    |
[3] PROJECT (wspoldzielone z zespolem via git)
    |-- .\CLAUDE.md  lub  .\.claude\CLAUDE.md           -> instrukcje projektowe
    |-- .\.claude\settings.json                         -> ustawienia projektu
    |-- .\.claude\rules\*.md                            -> reguly projektu
    |-- .\.claude\agents\*.md                           -> subagenty
    |-- .\.claude\skills\*\SKILL.md                     -> skille projektu
    |-- .\.mcp.json                                     -> serwery MCP projektu
    |
[4] LOCAL (osobiste, per-projekt, nie commitowane)
    |-- .\CLAUDE.local.md                               -> lokalne instrukcje
    |-- .\.claude\settings.local.json                   -> lokalne nadpisania
    |
[5] AUTO-MEMORY (generowane przez Claude)
    |-- C:\Users\Slawek\.claude\projects\<hash>\memory\MEMORY.md
    |-- C:\Users\Slawek\.claude\projects\<hash>\memory\*.md
    |-- C:\Users\Slawek\.claude\projects\<hash>\agents\<name>\memory\
    |
[6] RUNTIME (sesyjne, nie persystowane)
    |-- Historia konwersacji (w pamieci)
    |-- Wyniki narzedzi (w pamieci)
    |-- Zmienne srodowiskowe ($CLAUDE_ENV_FILE)
    |-- Pliki tymczasowe (%TEMP%)
```

### 3.2 Porownanie Claude Code vs Claude.ai

| Cecha | Claude Code (CLI) | Claude.ai (Web) |
|---|---|---|
| **Lokalizacja konfiguracji** | `C:\Users\Slawek\.claude\` | Przegladarka (localStorage/IndexedDB) + cloud |
| **Synchronizacja** | Brak (tylko lokalna maszyna) | Automatyczna (cloud) |
| **CLAUDE.md** | Z dysku (wiele zakresow) | Brak (zastepuje: instrukcje projektowe) |
| **Auto Memory** | `~/.claude/projects/` (lokalne pliki .md) | Server-side (nie do pobrania bezposrednio) |
| **Credentials** | `.credentials.json` (plik lokalny) | Cookie sesji + cloud |
| **Sesje** | W pamieci per terminal | Persystowane server-side |
| **Hooki** | Pelne wsparcie (20+ eventow) | Brak |
| **MCP** | Pelne wsparcie (stdio/http) | Ograniczone (connected apps) |
| **Subagenty** | Pelne wsparcie (definiowalne) | Brak |
| **Skille** | Pelne wsparcie | Brak |
| **Eksport danych** | Pliki na dysku (pelna kontrola) | Eksport z UI (ograniczony) |
| **Przenoszenie** | Kopiowanie `~/.claude/` | Automatyczne (konto) |

### 3.3 Inne zrodla informacji o srodowisku

| Zrodlo | Typ danych | Jak uzyskac |
|---|---|---|
| **Git config** | `user.name`, `user.email`, `signingkey` | `C:\Users\Slawek\.gitconfig` |
| **VS Code settings** | Rozszerzenia Claude, keybindings | `%APPDATA%\Code\User\settings.json` |
| **Zmienne srodowiskowe systemu** | PATH, TEMP, klucze API | `set` / System Properties |
| **npm cache** | Pobrane paczki, logi | `C:\Users\Slawek\.npm\` |
| **SSH keys** | Klucze do podpisywania commitow | `C:\Users\Slawek\.ssh\` |
| **Rejestr Windows** | Polityki Group Policy | `regedit` (HKLM\Software\Policies) |

---

## 4. Hierarchia priorytetow

### Ustawienia (settings.json)

```
1. Managed policy          (najwyzszy - nie mozna nadpisac)
2. Local project           (.claude/settings.local.json)
3. Project                 (.claude/settings.json)
4. User                    (~/.claude/settings.json)
```

### CLAUDE.md

```
1. Managed CLAUDE.md       (nie mozna wykluczyc)
2. Project CLAUDE.md       (root + przodkowie katalogu)
3. User CLAUDE.md          (~/.claude/CLAUDE.md)
4. Local CLAUDE.md         (CLAUDE.local.md)
   + Podkatalogi           (ladowane on-demand)
```

### MCP Servers

```
1. Local scope             (.mcp.json w projekcie)
2. Project scope           (merged z local)
3. User scope              (~/.claude/.mcp.json)
```

---

## 5. Komendy inspekcji

| Komenda | Co pokazuje |
|---|---|
| `claude /config` | Aktywna konfiguracja |
| `claude /memory` | Zaladowana pamiec |
| `claude /hooks` | Skonfigurowane hooki |
| `claude /status` | Status sesji, model, priorytet ustawien |
| `claude /doctor` | Diagnostyka (problemy z konfiguracja) |
| `claude /mcp` | Zainstalowane serwery MCP |
| `claude /cost` | Zuzycie tokenow i koszty |
| `claude /compact` | Kompakcja kontekstu (zachowuje CLAUDE.md + memory) |
| `claude /checkpoint` | Punkt zapisu sesji |

---

## Szybkie linki do Twojej lokalizacji

| Co | Sciezka |
|---|---|
| Katalog glowny Claude | `C:\Users\Slawek\.claude\` |
| Ustawienia globalne | `C:\Users\Slawek\.claude\settings.json` |
| Credentials | `C:\Users\Slawek\.claude\.credentials.json` |
| Instrukcje osobiste | `C:\Users\Slawek\.claude\CLAUDE.md` |
| Pamiec projektow | `C:\Users\Slawek\.claude\projects\` |
| Reguly osobiste | `C:\Users\Slawek\.claude\rules\` |
| Skille | `C:\Users\Slawek\.claude\skills\` |
| MCP uzytkownika | `C:\Users\Slawek\.claude\.mcp.json` |
| Stan globalny | `C:\Users\Slawek\.claude.json` |
| Git config | `C:\Users\Slawek\.gitconfig` |
