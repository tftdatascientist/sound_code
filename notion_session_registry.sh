#!/bin/bash
# Notion Session Registry — Claude Code Status Line
# Reads JSON from stdin, outputs status text, registers sessions >100k tokens in Notion
#
# Configured in ~/.claude/settings.json as "statusLine"
# Requires: jq, curl
# API key: ~/.claude/.notion_api_key (Notion Internal Integration Token)

# --- Phase 1: Read stdin immediately (don't block Claude Code) ---
INPUT=$(cat)

# --- Phase 2: Parse JSON fields ---
TOTAL_IN=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
TOTAL_OUT=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
SESSION_NAME=$(echo "$INPUT" | jq -r '.session_name // ""' 2>/dev/null)
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null)
USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
CW_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)

# Handle non-numeric values
[[ "$TOTAL_IN" =~ ^[0-9]+$ ]] || TOTAL_IN=0
[[ "$TOTAL_OUT" =~ ^[0-9]+$ ]] || TOTAL_OUT=0
TOTAL_TOKENS=$((TOTAL_IN + TOTAL_OUT))

# --- Phase 3: Output status line (primary purpose, ALWAYS runs) ---
TOKENS_K=$((TOTAL_TOKENS / 1000))
# Format cost with awk (bc may not be available)
COST_FMT=$(echo "$COST" | awk '{printf "%.2f", $1}' 2>/dev/null || echo "$COST")
echo "${TOKENS_K}k tok | \$${COST_FMT} | ctx ${USED_PCT}%"

# --- Phase 4: Notion registration (background, non-blocking) ---
THRESHOLD=100000
FLAG_DIR="/tmp/claude_notion_registry"
FLAG_FILE="${FLAG_DIR}/${SESSION_ID}.registered"

if [[ "$TOTAL_TOKENS" -ge "$THRESHOLD" ]] && [[ ! -f "$FLAG_FILE" ]]; then
    mkdir -p "$FLAG_DIR"
    touch "$FLAG_FILE"

    # Load API key
    NOTION_API_KEY="${NOTION_API_KEY:-}"
    if [[ -z "$NOTION_API_KEY" ]] && [[ -f "$HOME/.claude/.notion_api_key" ]]; then
        NOTION_API_KEY=$(cat "$HOME/.claude/.notion_api_key" 2>/dev/null)
    fi

    if [[ -n "$NOTION_API_KEY" ]]; then
        # Background Notion API call
        (
            DATABASE_ID="2091eecaa19c45ed815b16a7dec3d173"
            DURATION_S=$(echo "$DURATION_MS" | awk '{printf "%.1f", $1/1000}' 2>/dev/null || echo "0")
            DISPLAY_NAME="${SESSION_NAME:-$SESSION_ID}"
            NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -Iseconds)
            CWD=$(pwd 2>/dev/null || echo "unknown")

            DETAILS="session_id: ${SESSION_ID}
cwd: ${CWD}
tokens: ${TOTAL_IN} in + ${TOTAL_OUT} out = ${TOTAL_TOKENS}
context_window: ${CW_SIZE}
used: ${USED_PCT}%"

            curl -s -X POST "https://api.notion.com/v1/pages" \
                -H "Authorization: Bearer ${NOTION_API_KEY}" \
                -H "Content-Type: application/json" \
                -H "Notion-Version: 2022-06-28" \
                -d "$(jq -n \
                    --arg db_id "$DATABASE_ID" \
                    --arg name "$DISPLAY_NAME" \
                    --arg details "$DETAILS" \
                    --arg date "$NOW" \
                    --argjson tokens "$TOTAL_TOKENS" \
                    --argjson cost "${COST_FMT:-0}" \
                    --argjson duration "${DURATION_S:-0}" \
                    '{
                        parent: { database_id: $db_id },
                        properties: {
                            "Nazwa": { title: [{ text: { content: $name } }] },
                            "Agent": { select: { name: "System" } },
                            "Akcja": { select: { name: "Session 100k+" } },
                            "Status": { select: { name: "OK" } },
                            "Szczegóły": { rich_text: [{ text: { content: $details } }] },
                            "Data": { date: { start: $date } },
                            "Tokeny": { number: $tokens },
                            "Czas (s)": { number: $duration },
                            "Przetworzone": { number: $cost }
                        }
                    }'
                )" > /dev/null 2>&1
        ) &
    fi
fi
