#!/bin/bash
# Claude Code sound hooks — odtwarza dźwięk z profilu StarCraft przypisany do hooka.
#
# Użycie:
#   play_sound.sh <HookName>      - odtwarza dźwięk dla hooka (SessionStart, Stop, ...)
#   play_sound.sh start           - legacy: tylko zapis timestampa
#
# Wybór profilu (w kolejności):
#   1. $SOUND_PROFILE (env var)           ← rekomendowane per terminal
#   2. plik $SOUND_PROFILE_FILE (env var) ← dla VS Code extension (override per PID)
#   3. $TEMP/sound_profile.$PPID          ← fallback dla extension
#   4. sounds.json → default_profile
#
# Pliki dźwięków:
#   sounds/<profile_subdir>/<HookName>.wav
#   np. sounds/terran/SessionStart.wav, sounds/zerg/Stop.wav
#
# Fallback (gdy plik brak / profil "beep" / config wyłączony):
#   - Stop: melodia "Ode to Joy" skalowana czasem pracy (1 nuta / 15s)
#   - inne hooki: krótki beep

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

# UserPromptSubmit zapisuje też timestamp (dla fallback-melodii Stop)
if [[ "$HOOK" == "UserPromptSubmit" ]]; then
    date +%s > "$TEMP_FILE"
fi

if [[ -f "$TEMP_FILE" ]]; then
    ELAPSED=$(( $(date +%s) - $(cat "$TEMP_FILE") ))
else
    ELAPSED=1
fi
(( ELAPSED < 1 )) && ELAPSED=1

# Rozstrzygnięcie profilu
PROFILE=""
if [[ -n "${SOUND_PROFILE:-}" ]]; then
    PROFILE="$SOUND_PROFILE"
elif [[ -n "${SOUND_PROFILE_FILE:-}" && -f "$SOUND_PROFILE_FILE" ]]; then
    PROFILE=$(tr -d '[:space:]' < "$SOUND_PROFILE_FILE")
elif [[ -f "${TEMP:-/tmp}/sound_profile.$PPID" ]]; then
    PROFILE=$(tr -d '[:space:]' < "${TEMP:-/tmp}/sound_profile.$PPID")
fi

WIN_CONFIG=$(to_win "$CONFIG")
WIN_SOUNDS=$(to_win "$SOUNDS_DIR")
NOTION_SYNC="$SCRIPT_DIR/notion_sync.sh"

PS_CMD=$(cat <<PSEOF
\$ErrorActionPreference='SilentlyContinue'
\$hook='$HOOK'
\$elapsed=$ELAPSED
\$profileOverride='$PROFILE'
\$configPath='$WIN_CONFIG'
\$soundsRoot='$WIN_SOUNDS'

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

\$profile = \$null
\$profileName = ''
if (\$cfg -and \$cfg.enabled) {
    if (\$profileOverride -and \$cfg.profiles.\$profileOverride) {
        \$profileName = \$profileOverride
    } elseif (\$cfg.default_profile -and \$cfg.profiles.(\$cfg.default_profile)) {
        \$profileName = \$cfg.default_profile
    }
    if (\$profileName) { \$profile = \$cfg.profiles.\$profileName }
}

\$played = \$false
\$playedFile = ''
if (\$profile -and \$profile.subdir -and \$profile.hooks.\$hook) {
    \$path = Join-Path (Join-Path \$soundsRoot \$profile.subdir) (\$hook + '.wav')
    if (Test-Path \$path) {
        try {
            \$sp = New-Object Media.SoundPlayer \$path
            \$sp.PlaySync()
            \$played = \$true
            \$playedFile = \$path
        } catch {}
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

# Metadane dla logu Notion (stdout pojedyncza linia, parsowana przez bash)
Write-Output (\"PROFILE={0};PLAYED={1};FILE={2}\" -f \$profileName, (\$played.ToString().ToLower()), \$playedFile)
PSEOF
)

META=$(powershell.exe -NoProfile -Command "$PS_CMD" 2>/dev/null | tr -d '\r' | tail -n1)

# Opcjonalny log do Notion (fire-and-forget, nie blokuje hooka)
if [[ -x "$NOTION_SYNC" && -n "$META" ]]; then
    (
        PROFILE_USED=$(echo "$META" | sed -n 's/.*PROFILE=\([^;]*\);.*/\1/p')
        PLAYED=$(echo "$META" | sed -n 's/.*PLAYED=\([^;]*\);.*/\1/p')
        FILE_USED=$(echo "$META" | sed -n 's/.*FILE=\(.*\)$/\1/p')
        bash "$NOTION_SYNC" log "$HOOK" "${PROFILE_USED:-<none>}" "${PLAYED:-false}" "${FILE_USED:-<fallback>}" >/dev/null 2>&1 &
    ) >/dev/null 2>&1
fi

exit 0
