#!/bin/bash
# sound_panel.sh — panel sterowania dźwiękami Claude Code (StarCraft / Warcraft)
#
# Edytuje sounds.json: mapuje hooki Claude Code na pliki WAV z katalogu sounds/.
# Zmiany zapisywane są natychmiast. Skrypt działa w Git Bash na Windows
# (używa PowerShell do manipulacji JSON i odtwarzania testowego).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/sounds.json"
SOUNDS_DIR="$SCRIPT_DIR/sounds"
PLAY="$SCRIPT_DIR/play_sound.sh"

C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_CYAN=$'\e[36m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'

to_win() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        echo "$1"
    fi
}

banner() {
    clear
    echo "${C_CYAN}${C_BOLD}+==============================================================+${C_RESET}"
    echo "${C_CYAN}${C_BOLD}|   SOUND CODE - panel sterowania dzwiekami Claude Code        |${C_RESET}"
    echo "${C_CYAN}${C_BOLD}|   Hook -> StarCraft / Warcraft                               |${C_RESET}"
    echo "${C_CYAN}${C_BOLD}+==============================================================+${C_RESET}"
    echo
}

ps_eval() {
    # Uruchamia fragment PS z wczytanym $c (config). Dla zapisu przekaż writeBack=1.
    local writeBack="${2:-0}"
    local win
    win=$(to_win "$CONFIG")
    if [[ "$writeBack" == "1" ]]; then
        powershell.exe -NoProfile -Command "
            \$c = Get-Content -Raw -Path '$win' | ConvertFrom-Json
            $1
            \$c | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path '$win'
        " 2>/dev/null
    else
        powershell.exe -NoProfile -Command "
            \$c = Get-Content -Raw -Path '$win' | ConvertFrom-Json
            $1
        " 2>/dev/null | tr -d '\r'
    fi
}

get_hooks() {
    ps_eval "foreach (\$p in \$c.mappings.PSObject.Properties) { Write-Output \$p.Name }"
}

list_mappings() {
    banner
    echo "${C_BOLD}Stan panelu:${C_RESET}"
    local global
    global=$(ps_eval "Write-Output \$c.enabled")
    if [[ "$global" == "True" ]]; then
        echo "  Globalnie      : ${C_GREEN}WLACZONE${C_RESET}"
    else
        echo "  Globalnie      : ${C_RED}WYLACZONE${C_RESET}"
    fi
    echo "  Fallback beep  : $(ps_eval "Write-Output \$c.fallback_beep")"
    echo "  Katalog sounds : $SOUNDS_DIR"
    echo
    echo "${C_BOLD}Mapowania hook -> dzwiek:${C_RESET}"
    printf "  %-20s %-6s %-38s %s\n" "HOOK" "STAN" "PLIK" "PLIK OBECNY?"
    echo "  ----------------------------------------------------------------------------------"
    local win_sounds
    win_sounds=$(to_win "$SOUNDS_DIR")
    ps_eval "
        foreach (\$p in \$c.mappings.PSObject.Properties) {
            \$m = \$p.Value
            \$state = if (\$m.enabled) { 'on' } else { 'off' }
            \$path = Join-Path '$win_sounds' \$m.file
            \$exists = if (Test-Path \$path) { 'YES' } else { 'NO' }
            Write-Output (\"{0}|{1}|{2}|{3}\" -f \$p.Name, \$state, \$m.file, \$exists)
        }
    " | while IFS='|' read -r name state file exists; do
        [[ -z "$name" ]] && continue
        local exists_col
        if [[ "$exists" == "YES" ]]; then
            exists_col="${C_GREEN}OK${C_RESET}"
        else
            exists_col="${C_RED}BRAK${C_RESET}"
        fi
        printf "  %-20s [%-3s] %-38s %s\n" "$name" "$state" "$file" "$exists_col"
    done
    echo
}

pick_hook() {
    local hooks=() h
    while IFS= read -r h; do
        [[ -n "$h" ]] && hooks+=("$h")
    done < <(get_hooks)
    echo "${C_BOLD}Wybierz hook:${C_RESET}" >&2
    local i
    for i in "${!hooks[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${hooks[$i]}" >&2
    done
    printf "  0) powrot\n> " >&2
    local sel
    read -r sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#hooks[@]} )); then
        echo "${hooks[$((sel-1))]}"
    fi
}

change_file_for_hook() {
    banner
    local hook
    hook=$(pick_hook)
    [[ -z "$hook" ]] && return
    echo
    echo "${C_BOLD}Pliki dostepne w sounds/:${C_RESET}"
    if [[ -d "$SOUNDS_DIR" ]]; then
        ls -1 "$SOUNDS_DIR" 2>/dev/null | grep -iE '\.(wav|mp3)$' | nl -w3 -s') ' || echo "  (brak plikow audio)"
    else
        echo "  ${C_YELLOW}Katalog sounds/ nie istnieje.${C_RESET}"
    fi
    echo
    printf "Podaj nazwe pliku dla ${C_BOLD}%s${C_RESET} (np. sc_under_attack.wav): " "$hook"
    local file
    read -r file
    [[ -z "$file" ]] && return
    # escape pojedynczych apostrofow dla PS
    local file_esc=${file//\'/\'\'}
    ps_eval "\$c.mappings.'$hook'.file = '$file_esc'" 1
    echo "${C_GREEN}Zapisano: $hook -> $file${C_RESET}"
    sleep 1
}

toggle_hook() {
    banner
    local hook
    hook=$(pick_hook)
    [[ -z "$hook" ]] && return
    ps_eval "\$c.mappings.'$hook'.enabled = -not \$c.mappings.'$hook'.enabled" 1
    echo "${C_GREEN}Przelaczono stan dla $hook.${C_RESET}"
    sleep 1
}

toggle_global() {
    ps_eval "\$c.enabled = -not \$c.enabled" 1
    echo "${C_GREEN}Przelaczono globalny wlacznik.${C_RESET}"
    sleep 1
}

toggle_fallback() {
    ps_eval "\$c.fallback_beep = -not \$c.fallback_beep" 1
    echo "${C_GREEN}Przelaczono fallback beep.${C_RESET}"
    sleep 1
}

test_hook() {
    banner
    local hook
    hook=$(pick_hook)
    [[ -z "$hook" ]] && return
    echo
    echo "Odtwarzam: ${C_BOLD}$hook${C_RESET} ..."
    bash "$PLAY" "$hook"
    echo "Gotowe."
    sleep 1
}

show_files() {
    banner
    echo "${C_BOLD}Pliki w katalogu sounds/:${C_RESET}"
    echo
    if [[ -d "$SOUNDS_DIR" ]]; then
        local any=0
        while IFS= read -r f; do
            any=1
            local size
            size=$(stat -c%s "$SOUNDS_DIR/$f" 2>/dev/null || echo '?')
            printf "  %-40s %10s bytes\n" "$f" "$size"
        done < <(ls -1 "$SOUNDS_DIR" 2>/dev/null | grep -iE '\.(wav|mp3)$')
        (( any == 0 )) && echo "  (brak plikow audio - wrzuc pliki .wav do $SOUNDS_DIR)"
    else
        echo "  ${C_YELLOW}Katalog nie istnieje: $SOUNDS_DIR${C_RESET}"
        echo "  Utworz go i wrzuc tam pliki .wav ze StarCrafta/Warcrafta."
    fi
    echo
    read -rp "ENTER, aby wrocic..." _
}

print_hook_snippet() {
    banner
    echo "${C_BOLD}Snippet do ~/.claude/settings.json (sekcja \"hooks\"):${C_RESET}"
    echo
    local script_win
    script_win=$(to_win "$SCRIPT_DIR/play_sound.sh")
    # znormalizuj backslashe do forward slash dla bezpieczenstwa JSON
    local script_json=${script_win//\\/\/}
    cat <<JSON
  "hooks": {
    "SessionStart":     [{"hooks":[{"type":"command","command":"bash '$script_json' SessionStart"}]}],
    "UserPromptSubmit": [{"hooks":[{"type":"command","command":"bash '$script_json' UserPromptSubmit"}]}],
    "Notification":     [{"hooks":[{"type":"command","command":"bash '$script_json' Notification"}]}],
    "Stop":             [{"hooks":[{"type":"command","command":"bash '$script_json' Stop"}]}],
    "SubagentStop":     [{"hooks":[{"type":"command","command":"bash '$script_json' SubagentStop"}]}],
    "PreCompact":       [{"hooks":[{"type":"command","command":"bash '$script_json' PreCompact"}]}],
    "SessionEnd":       [{"hooks":[{"type":"command","command":"bash '$script_json' SessionEnd"}]}]
  }
JSON
    echo
    read -rp "ENTER, aby wrocic..." _
}

main_menu() {
    while true; do
        list_mappings
        echo "${C_BOLD}Menu:${C_RESET}"
        echo "  1) Zmien plik dzwieku dla hooka"
        echo "  2) Wlacz/wylacz dzwiek dla hooka"
        echo "  3) Globalnie wlacz/wylacz dzwieki"
        echo "  4) Przelacz fallback beep (melodia Ody do Radosci)"
        echo "  5) Testuj - odtworz dzwiek hooka"
        echo "  6) Pokaz pliki w sounds/"
        echo "  7) Wygeneruj snippet do ~/.claude/settings.json"
        echo "  0) Wyjscie"
        printf "> "
        local choice
        read -r choice
        case "$choice" in
            1) change_file_for_hook ;;
            2) toggle_hook ;;
            3) toggle_global ;;
            4) toggle_fallback ;;
            5) test_hook ;;
            6) show_files ;;
            7) print_hook_snippet ;;
            0|q|Q) echo "Bye."; exit 0 ;;
            *) ;;
        esac
    done
}

if [[ ! -f "$CONFIG" ]]; then
    echo "Brak pliku konfiguracyjnego: $CONFIG" >&2
    exit 1
fi

main_menu
