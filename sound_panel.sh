#!/bin/bash
# sound_panel.sh — panel sterowania dźwiękami Claude Code (StarCraft, profile)
#
# Edytuje sounds.json: włączenie per hook × profile, wybór default_profile.
# Integracja z Notion w podmenu (status / bootstrap / push / pull / dashboard).
# Profil jest wybierany per terminal przez $SOUND_PROFILE.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/sounds.json"
SOUNDS_DIR="$SCRIPT_DIR/sounds"
PLAY="$SCRIPT_DIR/play_sound.sh"
NOTION="$SCRIPT_DIR/notion_sync.sh"

C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_CYAN=$'\e[36m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'
C_MAGENTA=$'\e[35m'

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
    echo "${C_CYAN}${C_BOLD}|   StarCraft profiles: terran / protoss / zerg / beep         |${C_RESET}"
    echo "${C_CYAN}${C_BOLD}+==============================================================+${C_RESET}"
    echo
}

ps_eval() {
    # $1 = PS expression; $2 = writeBack (0/1)
    local writeBack="${2:-0}"
    local win
    win=$(to_win "$CONFIG")
    if [[ "$writeBack" == "1" ]]; then
        powershell.exe -NoProfile -Command "
            \$c = Get-Content -Raw -Path '$win' | ConvertFrom-Json
            $1
            \$c | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -Path '$win'
        " 2>/dev/null
    else
        powershell.exe -NoProfile -Command "
            \$c = Get-Content -Raw -Path '$win' | ConvertFrom-Json
            $1
        " 2>/dev/null | tr -d '\r'
    fi
}

get_hooks() {
    ps_eval "foreach (\$h in \$c.hooks) { Write-Output \$h }"
}

get_profiles() {
    ps_eval "foreach (\$p in \$c.profiles.PSObject.Properties) { Write-Output \$p.Name }"
}

list_state() {
    banner
    local default global fallback
    default=$(ps_eval "Write-Output \$c.default_profile")
    global=$(ps_eval "Write-Output \$c.enabled")
    fallback=$(ps_eval "Write-Output \$c.fallback_beep")

    echo "${C_BOLD}Stan panelu:${C_RESET}"
    if [[ "$global" == "True" ]]; then
        echo "  Globalnie       : ${C_GREEN}WLACZONE${C_RESET}"
    else
        echo "  Globalnie       : ${C_RED}WYLACZONE${C_RESET}"
    fi
    echo "  Default profile : ${C_BOLD}$default${C_RESET}"
    echo "  Fallback beep   : $fallback"
    echo "  SOUND_PROFILE (tego terminala): ${C_MAGENTA}${SOUND_PROFILE:-<niestawione, uzyje default>}${C_RESET}"
    echo "  Katalog sounds  : $SOUNDS_DIR"
    echo

    # Macierz: rows = hooks, cols = profiles
    local hooks=() profiles=()
    while IFS= read -r h; do [[ -n "$h" ]] && hooks+=("$h"); done < <(get_hooks)
    while IFS= read -r p; do [[ -n "$p" ]] && profiles+=("$p"); done < <(get_profiles)

    echo "${C_BOLD}Macierz hook x profile:${C_RESET}"
    printf "  %-20s" "HOOK"
    for p in "${profiles[@]}"; do
        printf " %-14s" "$p"
    done
    echo
    echo "  ----------------------------------------------------------------------------"
    for h in "${hooks[@]}"; do
        printf "  %-20s" "$h"
        for p in "${profiles[@]}"; do
            local enabled subdir file_exists cell
            enabled=$(ps_eval "Write-Output ([bool]\$c.profiles.'$p'.hooks.'$h')")
            subdir=$(ps_eval "if (\$c.profiles.'$p'.subdir) { Write-Output \$c.profiles.'$p'.subdir } else { Write-Output '' }")
            if [[ -n "$subdir" && -f "$SOUNDS_DIR/$subdir/$h.wav" ]]; then
                file_exists=1
            else
                file_exists=0
            fi
            local mark
            [[ "$enabled" == "True" ]] && mark="on" || mark="off"
            if [[ "$p" == "beep" ]]; then
                cell="[${mark}] mel"
            elif (( file_exists == 1 )); then
                cell="[${mark}] ${C_GREEN}OK${C_RESET}"
            else
                cell="[${mark}] ${C_RED}NO${C_RESET}"
            fi
            # kompensacja bajtow ANSI (9 na OK, 9 na NO, 0 na mel)
            printf " %s" "$cell"
            local visible_len=$(( 7 ))
            if [[ "$cell" == *"OK"* || "$cell" == *"NO"* ]]; then
                printf "      "  # padding do 14
            else
                printf "       "
            fi
        done
        echo
    done
    echo
}

pick_from() {
    # $1 = label, args 2.. = items
    local label="$1"; shift
    local items=("$@")
    echo "${C_BOLD}$label${C_RESET}" >&2
    local i
    for i in "${!items[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${items[$i]}" >&2
    done
    printf "  0) powrot\n> " >&2
    local sel
    read -r sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#items[@]} )); then
        echo "${items[$((sel-1))]}"
    fi
}

pick_profile() {
    local profiles=()
    while IFS= read -r p; do [[ -n "$p" ]] && profiles+=("$p"); done < <(get_profiles)
    pick_from "Wybierz profil:" "${profiles[@]}"
}

pick_hook() {
    local hooks=()
    while IFS= read -r h; do [[ -n "$h" ]] && hooks+=("$h"); done < <(get_hooks)
    pick_from "Wybierz hook:" "${hooks[@]}"
}

set_default_profile() {
    banner
    local p
    p=$(pick_profile)
    [[ -z "$p" ]] && return
    ps_eval "\$c.default_profile = '$p'" 1
    echo "${C_GREEN}Default profile = $p${C_RESET}"
    sleep 1
}

toggle_hook_in_profile() {
    banner
    local p h
    p=$(pick_profile); [[ -z "$p" ]] && return
    h=$(pick_hook);    [[ -z "$h" ]] && return
    ps_eval "\$c.profiles.'$p'.hooks.'$h' = -not \$c.profiles.'$p'.hooks.'$h'" 1
    echo "${C_GREEN}Przelaczono: $p / $h${C_RESET}"
    sleep 1
}

toggle_global() {
    ps_eval "\$c.enabled = -not \$c.enabled" 1
    echo "${C_GREEN}Globalnie przelaczone.${C_RESET}"
    sleep 1
}

toggle_fallback() {
    ps_eval "\$c.fallback_beep = -not \$c.fallback_beep" 1
    echo "${C_GREEN}Fallback beep przelaczony.${C_RESET}"
    sleep 1
}

test_hook() {
    banner
    local p h
    p=$(pick_profile); [[ -z "$p" ]] && return
    h=$(pick_hook);    [[ -z "$h" ]] && return
    echo
    echo "Odtwarzam: profil=${C_BOLD}$p${C_RESET}  hook=${C_BOLD}$h${C_RESET} ..."
    SOUND_PROFILE="$p" bash "$PLAY" "$h"
    echo "Gotowe."
    sleep 1
}

show_files() {
    banner
    echo "${C_BOLD}Zawartosc katalogu sounds/ (.wav):${C_RESET}"
    echo
    if [[ -d "$SOUNDS_DIR" ]]; then
        local any=0
        while IFS= read -r f; do
            any=1
            local size
            size=$(stat -c%s "$f" 2>/dev/null || echo '?')
            printf "  %-60s %10s bytes\n" "${f#$SOUNDS_DIR/}" "$size"
        done < <(find "$SOUNDS_DIR" -type f -iname '*.wav' 2>/dev/null | sort)
        (( any == 0 )) && echo "  (brak plikow audio)"
    else
        echo "  ${C_YELLOW}Katalog $SOUNDS_DIR nie istnieje.${C_RESET}"
    fi
    echo
    read -rp "ENTER, aby wrocic..." _
}

print_snippet() {
    banner
    echo "${C_BOLD}Snippet do ~/.claude/settings.json (sekcja \"hooks\"):${C_RESET}"
    echo
    local script_win script_json
    script_win=$(to_win "$SCRIPT_DIR/play_sound.sh")
    script_json=${script_win//\\/\/}
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
    echo "${C_BOLD}Wybor profilu per terminal:${C_RESET}"
    echo "  export SOUND_PROFILE=terran   # terminal #1"
    echo "  export SOUND_PROFILE=protoss  # terminal #2"
    echo "  export SOUND_PROFILE=zerg     # terminal #3"
    echo "  export SOUND_PROFILE=beep     # terminal #4 (melodia)"
    echo
    echo "${C_BOLD}Dla rozszerzenia VS Code:${C_RESET}"
    echo "  vscode.window.createTerminal({ name:'Claude (terran)', env:{ SOUND_PROFILE:'terran' } })"
    echo
    read -rp "ENTER, aby wrocic..." _
}

notion_menu() {
    while true; do
        banner
        echo "${C_BOLD}Notion — integracja (A konfiguracja + B log + C dashboard)${C_RESET}"
        echo
        bash "$NOTION" status 2>/dev/null | sed 's/^/  /'
        echo
        echo "Menu:"
        echo "  1) Bootstrap - utworz bazy A,B i strone C pod podana strona rodzica"
        echo "  2) Push      - wypchnij lokalny stan do bazy A"
        echo "  3) Pull      - zaciagnij stan z bazy A do sounds.json"
        echo "  4) Dashboard - przegeneruj strone C"
        echo "  5) Wlacz/wylacz logowanie zdarzen (B)"
        echo "  6) Wlacz/wylacz integracje Notion globalnie"
        echo "  0) Powrot"
        printf "> "
        local ch
        read -r ch
        case "$ch" in
            1)
                printf "Podaj parent_page_id (z URL strony Notion): "
                local pid
                read -r pid
                [[ -z "$pid" ]] && continue
                bash "$NOTION" bootstrap "$pid"
                read -rp "ENTER..." _
                ;;
            2) bash "$NOTION" push;      read -rp "ENTER..." _ ;;
            3) bash "$NOTION" pull;      read -rp "ENTER..." _ ;;
            4) bash "$NOTION" dashboard; read -rp "ENTER..." _ ;;
            5) ps_eval "\$c.notion.log_events = -not \$c.notion.log_events" 1
               echo "${C_GREEN}Przelaczono log_events.${C_RESET}"; sleep 1 ;;
            6) ps_eval "\$c.notion.enabled = -not \$c.notion.enabled" 1
               echo "${C_GREEN}Przelaczono notion.enabled.${C_RESET}"; sleep 1 ;;
            0|q|Q) return ;;
        esac
    done
}

main_menu() {
    while true; do
        list_state
        echo "${C_BOLD}Menu:${C_RESET}"
        echo "  1) Ustaw default profile"
        echo "  2) Wlacz/wylacz hook w profilu"
        echo "  3) Globalnie wlacz/wylacz dzwieki"
        echo "  4) Przelacz fallback beep"
        echo "  5) Testuj - odtworz hook w wybranym profilu"
        echo "  6) Pokaz pliki w sounds/"
        echo "  7) Snippet: hooki settings.json + SOUND_PROFILE per terminal"
        echo "  8) Notion (status / bootstrap / push / pull / dashboard)"
        echo "  0) Wyjscie"
        printf "> "
        local choice
        read -r choice
        case "$choice" in
            1) set_default_profile ;;
            2) toggle_hook_in_profile ;;
            3) toggle_global ;;
            4) toggle_fallback ;;
            5) test_hook ;;
            6) show_files ;;
            7) print_snippet ;;
            8) notion_menu ;;
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
