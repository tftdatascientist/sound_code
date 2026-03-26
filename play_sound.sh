#!/bin/bash
# Sound notification for Claude Code
# Plays "Ode to Joy" melody - one note per 15 seconds of work
#
# Usage:
#   play_sound.sh start   - save timestamp (called on UserPromptSubmit)
#   play_sound.sh          - play melody (called on Stop)

TEMP_FILE="${TEMP:-/tmp}/claude_sound_start"

# Save start timestamp
if [[ "$1" == "start" ]]; then
    date +%s > "$TEMP_FILE"
    exit 0
fi

# Calculate number of tones (1 per 15s, minimum 1)
if [[ -f "$TEMP_FILE" ]]; then
    START=$(cat "$TEMP_FILE")
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))
    (( ELAPSED < 1 )) && ELAPSED=1
    TONES=$(( (ELAPSED - 1) / 15 + 1 ))
else
    TONES=1
fi

# Ode to Joy - Beethoven (first phrase)
# E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4 D4 D4
MELODY=(330 330 349 392 392 349 330 294 262 262 294 330 330 294 294)
MAX_TONES=${#MELODY[@]}
(( TONES > MAX_TONES )) && TONES=$MAX_TONES

# Build PowerShell command
PS_CMD=""
for (( i=0; i<TONES; i++ )); do
    FREQ=${MELODY[$i]}
    # Last note is longer for a sense of closure
    if (( i == TONES - 1 )); then
        DUR=300
    else
        DUR=180
    fi
    (( i > 0 )) && PS_CMD+=";Start-Sleep -m 50"
    PS_CMD+=";[Console]::Beep($FREQ,$DUR)"
done

PS_CMD="${PS_CMD#;}"
powershell.exe -NoProfile -Command "$PS_CMD" 2>/dev/null
