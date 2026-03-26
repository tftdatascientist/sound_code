#!/bin/bash
# Sound notification for Claude Code
# Plays rotating melodies - one note per 15 seconds of work
#
# Usage:
#   play_sound.sh start   - save timestamp (called on UserPromptSubmit)
#   play_sound.sh          - play melody (called on Stop)

TEMP_DIR="${TEMP:-/tmp}"
TEMP_FILE="$TEMP_DIR/claude_sound_start"
COUNTER_FILE="$TEMP_DIR/claude_sound_counter"

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

# --- Melody library ---
# Each melody: "Name|freq1 freq2 freq3 ..."

MELODIES=(
    # Ode to Joy - Beethoven
    # E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4 D4 D4
    "330 330 349 392 392 349 330 294 262 262 294 330 330 294 294"

    # Fur Elise - Beethoven (opening motif)
    # E5 D#5 E5 D#5 E5 B4 D5 C5 | A4 ...
    "659 622 659 622 659 494 587 523 440 262 330 440 494 330 415 494"

    # Turkish March - Mozart (main theme)
    # B4 A4 G#4 A4 | C5 ... D5 C5 B4 C5 | E5 ...
    "494 440 415 440 523 494 440 415 440 587 523 494 440 415 440"

    # Canon in D - Pachelbel (melody)
    # F#5 E5 D5 C#5 | B4 A4 B4 C#5
    "740 659 587 554 494 440 494 554 587 494 554 440 494 554 587 659"

    # Eine kleine Nachtmusik - Mozart
    # G4 . D4 . G4 D4 G4 B4 D5 | C5 . A4 . C5 A4
    "392 294 392 294 392 494 587 523 440 523 440 523 587 659 587 494"

    # Spring (Four Seasons) - Vivaldi
    # E5 E5 E5 D#5 E5 | E5 E5 E5 D#5 E5 | G5 ...
    "659 659 659 622 659 659 659 659 622 659 784 659 587 523 494 440"

    # Symphony No. 5 - Beethoven (opening)
    # G4 G4 G4 Eb4 | F4 F4 F4 D4
    "392 392 392 311 349 349 349 294 392 392 392 311 349 349 349 294"

    # Twinkle Twinkle Little Star - Mozart variation
    # C4 C4 G4 G4 | A4 A4 G4 | F4 F4 E4 E4 | D4 D4 C4
    "262 262 392 392 440 440 392 349 349 330 330 294 294 262 262 392"
)

MELODY_COUNT=${#MELODIES[@]}

# Read and increment counter
if [[ -f "$COUNTER_FILE" ]]; then
    INDEX=$(cat "$COUNTER_FILE")
    (( INDEX >= MELODY_COUNT )) && INDEX=0
else
    INDEX=0
fi
NEXT=$(( (INDEX + 1) % MELODY_COUNT ))
echo "$NEXT" > "$COUNTER_FILE"

# Parse selected melody into array
read -ra MELODY <<< "${MELODIES[$INDEX]}"
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
