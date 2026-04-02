#!/bin/bash
# Sync sound configuration from Notion database
#
# Reads a Notion database with columns:
#   - Event (title):    "stop" or "start"
#   - Melody (select):  melody name (e.g. "nhl_goal_horn", "ode_to_joy")
#   - Active (checkbox): whether this mapping is active
#
# Saves active mappings to local cache file for play_sound.sh to read.
#
# Usage:
#   notion_sync.sh                    - sync using saved credentials
#   notion_sync.sh --setup KEY DB_ID  - save credentials and sync
#
# Credentials are stored in ~/.claude_sound_notion

CRED_FILE="$HOME/.claude_sound_notion"
CONFIG_FILE="${TEMP:-/tmp}/claude_sound_config"

# ---- Setup mode ----
if [[ "$1" == "--setup" ]]; then
    if [[ -z "$2" || -z "$3" ]]; then
        echo "Usage: notion_sync.sh --setup <NOTION_API_KEY> <DATABASE_ID>"
        echo ""
        echo "To get these:"
        echo "  1. Go to https://www.notion.so/my-integrations"
        echo "  2. Create a new integration, copy the API key"
        echo "  3. Create a database with columns: Event (title), Melody (select), Active (checkbox)"
        echo "  4. Share the database with your integration"
        echo "  5. Copy the database ID from the URL"
        exit 1
    fi
    echo "NOTION_API_KEY=$2" > "$CRED_FILE"
    echo "NOTION_DB_ID=$3" >> "$CRED_FILE"
    chmod 600 "$CRED_FILE"
    echo "Credentials saved to $CRED_FILE"
    echo "Syncing..."
fi

# ---- Load credentials ----
if [[ ! -f "$CRED_FILE" ]]; then
    echo "Error: No credentials found. Run: notion_sync.sh --setup <API_KEY> <DB_ID>"
    exit 1
fi

source "$CRED_FILE"

if [[ -z "$NOTION_API_KEY" || -z "$NOTION_DB_ID" ]]; then
    echo "Error: Invalid credentials file. Re-run --setup."
    exit 1
fi

# ---- Query Notion database ----
RESPONSE=$(curl -s -X POST \
    "https://api.notion.com/v1/databases/${NOTION_DB_ID}/query" \
    -H "Authorization: Bearer ${NOTION_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: 2022-06-28" \
    -d '{
        "filter": {
            "property": "Active",
            "checkbox": {
                "equals": true
            }
        }
    }')

# ---- Check for errors ----
if echo "$RESPONSE" | grep -q '"status":4'; then
    echo "Error: Notion API returned an error:"
    echo "$RESPONSE" | head -5
    exit 1
fi

# ---- Parse response and write config ----
# We need lightweight JSON parsing - use grep/sed for simplicity
# Format: event=melody (one per line)

# Clear config
> "$CONFIG_FILE"

# Parse each result entry
# Extract Event (title) and Melody (select) from each page
echo "$RESPONSE" | python3 -c "
import json, sys

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    print('Error: Failed to parse Notion response', file=sys.stderr)
    sys.exit(1)

if 'results' not in data:
    print('Error: No results in response', file=sys.stderr)
    if 'message' in data:
        print(f'Notion says: {data[\"message\"]}', file=sys.stderr)
    sys.exit(1)

for page in data['results']:
    props = page.get('properties', {})

    # Get Event (title property)
    event_prop = props.get('Event', {})
    event_title = event_prop.get('title', [])
    if event_title:
        event = event_title[0].get('plain_text', '').strip().lower()
    else:
        continue

    # Get Melody (select property)
    melody_prop = props.get('Melody', {})
    melody_select = melody_prop.get('select', {})
    if melody_select:
        melody = melody_select.get('name', '').strip().lower()
    else:
        continue

    if event and melody:
        print(f'{event}={melody}')
" > "$CONFIG_FILE"

if [[ $? -eq 0 ]]; then
    echo "Config synced to $CONFIG_FILE:"
    cat "$CONFIG_FILE"
else
    echo "Error parsing Notion response."
    exit 1
fi
