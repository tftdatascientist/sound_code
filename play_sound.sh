#!/bin/bash
# Sound notification for Claude Code
# Plays configurable melodies - controlled via Notion database
#
# Usage:
#   play_sound.sh start       - save timestamp (called on UserPromptSubmit)
#   play_sound.sh [melody]    - play melody (called on Stop)
#
# If no melody argument given, reads config from local cache (synced from Notion).
# Fallback: ode_to_joy

TEMP_DIR="${TEMP:-/tmp}"
TEMP_FILE="$TEMP_DIR/claude_sound_start"
CONFIG_FILE="$TEMP_DIR/claude_sound_config"

# --- Save start timestamp ---
if [[ "$1" == "start" ]]; then
    date +%s > "$TEMP_FILE"
    exit 0
fi

# --- Determine melody to play ---
# Priority: 1) CLI argument  2) Notion config cache  3) default
MELODY_NAME="${1:-}"

if [[ -z "$MELODY_NAME" && -f "$CONFIG_FILE" ]]; then
    # Read melody for "stop" event from config cache
    MELODY_NAME=$(grep '^stop=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)
fi

MELODY_NAME="${MELODY_NAME:-ode_to_joy}"

# --- Calculate number of tones (1 per 15s, minimum 1) ---
if [[ -f "$TEMP_FILE" ]]; then
    START=$(cat "$TEMP_FILE")
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))
    (( ELAPSED < 1 )) && ELAPSED=1
    TONES=$(( (ELAPSED - 1) / 15 + 1 ))
else
    TONES=1
fi

# ============================================================
#  MELODY DEFINITIONS
#  Each melody: FREQS array, DURS array, GAPS array
#  - FREQS: frequency in Hz (0 = silence/pause)
#  - DURS:  duration in ms for each note
#  - GAPS:  pause after each note in ms
# ============================================================

case "$MELODY_NAME" in

    ode_to_joy)
        # Beethoven - Ode to Joy (first phrase, 15 notes)
        # E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4 D4 D4
        FREQS=(330 330 349 392 392 349 330 294 262 262 294 330 330 294 294)
        DURS=(180 180 180 180 180 180 180 180 180 180 180 180 180 180 180)
        GAPS=(50  50  50  50  50  50  50  50  50  50  50  50  50  50  50)
        LAST_DUR=300
        ;;

    nhl_goal_horn)
        # NHL Goal Horn - low foghorn blasts with rising celebration
        # 3 long low blasts + short triumphant fanfare
        FREQS=(150 150 150 392 494 587 784)
        DURS=(400 400 400 150 150 150 350)
        GAPS=(100 100 200 30  30  30  0)
        LAST_DUR=500
        MAX_OVERRIDE=7
        ;;

    nhl_charge)
        # Classic arena organ "Charge!" riff
        # G4  C5  E5  G5 .... E5  G5!
        FREQS=(392 523 659 784 659 784)
        DURS=(150 150 150 400 150 500)
        GAPS=(30  30  30  150 30  0)
        LAST_DUR=600
        MAX_OVERRIDE=6
        ;;

    nhl_hat_trick)
        # Hat Trick celebration - 3x short horn + victory fanfare
        # Horn x3, then C5 E5 G5 C6 G5 C6
        FREQS=(175 175 175 523 659 784 1047 784 1047)
        DURS=(250 250 250 120 120 120 200 120 400)
        GAPS=(80  80  200 30  30  30  30  30  0)
        LAST_DUR=500
        MAX_OVERRIDE=9
        ;;

    nhl_power_play)
        # Power Play - energetic, aggressive ascending riff
        # Fast ascending: E4 G4 B4 E5, repeated pattern
        FREQS=(330 392 494 659 330 392 494 659 784)
        DURS=(100 100 100 200 100 100 100 200 350)
        GAPS=(20  20  20  80  20  20  20  80  0)
        LAST_DUR=450
        MAX_OVERRIDE=9
        ;;

    nhl_overtime)
        # Overtime Winner - dramatic build to climax
        # Slow build: C4.. D4.. E4.. G4.. then burst C5 E5 G5 C6
        FREQS=(262 294 330 392 523 659 784 1047)
        DURS=(250 250 250 300 150 150 150 500)
        GAPS=(50  50  50  100 30  30  30  0)
        LAST_DUR=600
        MAX_OVERRIDE=8
        ;;

    nhl_organ_lets_go)
        # Arena organ "Let's Go [Team]!" chant melody
        # Da da da-da-da! (repeated twice)
        FREQS=(523 523 523 659 784 523 523 523 659 784)
        DURS=(150 150 100 100 300 150 150 100 100 300)
        GAPS=(30  30  20  20  150 30  30  20  20  0)
        LAST_DUR=400
        MAX_OVERRIDE=10
        ;;

    *)
        # Unknown melody - fallback to single beep
        FREQS=(440)
        DURS=(300)
        GAPS=(0)
        LAST_DUR=300
        ;;
esac

# --- Apply tone limit ---
MAX_TONES=${MAX_OVERRIDE:-${#FREQS[@]}}
(( MAX_TONES > ${#FREQS[@]} )) && MAX_TONES=${#FREQS[@]}
(( TONES > MAX_TONES )) && TONES=$MAX_TONES

# For NHL melodies with MAX_OVERRIDE, always play full melody
# (they are designed as complete phrases, not scalable like Ode to Joy)
if [[ -n "${MAX_OVERRIDE:-}" ]]; then
    TONES=$MAX_TONES
fi

# --- Build PowerShell command ---
PS_CMD=""
for (( i=0; i<TONES; i++ )); do
    FREQ=${FREQS[$i]}
    DUR=${DURS[$i]}
    GAP=${GAPS[$i]}

    # Last note uses LAST_DUR for closure
    if (( i == TONES - 1 )); then
        DUR=$LAST_DUR
    fi

    # Add note
    if (( FREQ > 0 )); then
        PS_CMD+=";[Console]::Beep($FREQ,$DUR)"
    else
        PS_CMD+=";Start-Sleep -m $DUR"
    fi

    # Add gap (except after last note)
    if (( i < TONES - 1 && GAP > 0 )); then
        PS_CMD+=";Start-Sleep -m $GAP"
    fi
done

PS_CMD="${PS_CMD#;}"
powershell.exe -NoProfile -Command "$PS_CMD" 2>/dev/null
