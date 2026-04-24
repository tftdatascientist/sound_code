#!/bin/bash
# Claude Code sound hooks — odtwarza dźwięk gry przypisany do danego hooka.
#
# Użycie:
#   play_sound.sh <HookName>   - odtwarza dźwięk zmapowany w sounds.json
#                                (np. Stop, UserPromptSubmit, Notification, ...)
#   play_sound.sh start        - legacy: tylko zapis timestampa (kompatybilność)
#
# Konfiguracja: sounds.json (obok tego skryptu) — zarządzana przez sound_panel.sh
# Pliki dźwięków: katalog sounds/ (WAV zalecany dla [Media.SoundPlayer])

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/sounds.json"
SOUNDS_DIR="$SCRIPT_DIR/sounds"
TEMP_FILE="${TEMP:-/tmp}/claude_sound_start"

to_win() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        echo "$1"
    fi
}

HOOK="${1:-Stop}"

# Legacy: sam zapis czasu startu
if [[ "$HOOK" == "start" ]]; then
    date +%s > "$TEMP_FILE"
    exit 0
fi

# Dla UserPromptSubmit zapisujemy też timestamp — Stop użyje go do melodii-fallbacku
if [[ "$HOOK" == "UserPromptSubmit" ]]; then
    date +%s > "$TEMP_FILE"
fi

if [[ -f "$TEMP_FILE" ]]; then
    ELAPSED=$(( $(date +%s) - $(cat "$TEMP_FILE") ))
else
    ELAPSED=1
fi
(( ELAPSED < 1 )) && ELAPSED=1

WIN_CONFIG=$(to_win "$CONFIG")
WIN_SOUNDS=$(to_win "$SOUNDS_DIR")

PS_CMD=$(cat <<PSEOF
\$ErrorActionPreference='SilentlyContinue'
\$hook='$HOOK'
\$elapsed=$ELAPSED
\$configPath='$WIN_CONFIG'
\$soundsDir='$WIN_SOUNDS'
\$melody=@(330,330,349,392,392,349,330,294,262,262,294,330,330,294,294)
function Play-Melody(\$count) {
    if (\$count -lt 1) { \$count=1 }
    if (\$count -gt \$melody.Count) { \$count=\$melody.Count }
    for (\$i=0; \$i -lt \$count; \$i++) {
        \$dur = if (\$i -eq \$count-1) { 300 } else { 180 }
        [Console]::Beep(\$melody[\$i], \$dur)
        if (\$i -lt \$count-1) { Start-Sleep -Milliseconds 50 }
    }
}
try { \$cfg = Get-Content -Raw -Path \$configPath | ConvertFrom-Json } catch { \$cfg = \$null }
\$played = \$false
if (\$cfg -and \$cfg.enabled) {
    \$m = \$cfg.mappings.\$hook
    if (\$m -and \$m.enabled -and \$m.file) {
        \$path = Join-Path \$soundsDir \$m.file
        if (Test-Path \$path) {
            try {
                \$sp = New-Object Media.SoundPlayer \$path
                \$sp.PlaySync()
                \$played = \$true
            } catch {}
        }
    }
}
if (-not \$played -and (-not \$cfg -or \$cfg.fallback_beep)) {
    if (\$hook -eq 'Stop') {
        \$tones = [int]([math]::Floor((\$elapsed - 1) / 15) + 1)
        Play-Melody \$tones
    } else {
        [Console]::Beep(440, 120)
    }
}
PSEOF
)

powershell.exe -NoProfile -Command "$PS_CMD" 2>/dev/null
exit 0
