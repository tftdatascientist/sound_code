#!/bin/bash
# Create Sound Code database in Notion via API
#
# Creates a database with:
#   - Event (title): stop / start
#   - Melody (select): all available melodies as options
#   - Active (checkbox)
#   - Pre-populated rows with default config
#
# Usage:
#   create_notion_db.sh <NOTION_API_KEY> <PARENT_PAGE_ID>
#
# The parent page ID is the Notion page where the database will be created.
# Get it from the page URL: https://notion.so/Your-Page-<PAGE_ID>

set -e

NOTION_API_KEY="${1:-}"
PARENT_PAGE_ID="${2:-}"

if [[ -z "$NOTION_API_KEY" || -z "$PARENT_PAGE_ID" ]]; then
    echo "Usage: create_notion_db.sh <NOTION_API_KEY> <PARENT_PAGE_ID>"
    echo ""
    echo "Arguments:"
    echo "  NOTION_API_KEY   - Your Notion integration secret (ntn_...)"
    echo "  PARENT_PAGE_ID   - ID of the page where DB will be created"
    echo ""
    echo "How to get PARENT_PAGE_ID:"
    echo "  1. Open any Notion page where you want the database"
    echo "  2. Copy the page URL"
    echo "  3. The ID is the 32-char hex string at the end of the URL"
    echo "     e.g. https://notion.so/My-Page-abc123def456..."
    exit 1
fi

# Clean up page ID (remove dashes, spaces)
PARENT_PAGE_ID=$(echo "$PARENT_PAGE_ID" | tr -d ' -')

echo "Creating Sound Code database in Notion..."

# ---- Step 1: Create database with schema ----
CREATE_RESPONSE=$(curl -s -X POST \
    "https://api.notion.com/v1/databases" \
    -H "Authorization: Bearer ${NOTION_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: 2022-06-28" \
    -d '{
        "parent": {
            "type": "page_id",
            "page_id": "'"${PARENT_PAGE_ID}"'"
        },
        "icon": {
            "type": "emoji",
            "emoji": "🏒"
        },
        "title": [
            {
                "type": "text",
                "text": { "content": "Sound Code Config" }
            }
        ],
        "properties": {
            "Event": {
                "title": {}
            },
            "Melody": {
                "select": {
                    "options": [
                        { "name": "ode_to_joy", "color": "blue" },
                        { "name": "nhl_goal_horn", "color": "red" },
                        { "name": "nhl_charge", "color": "orange" },
                        { "name": "nhl_hat_trick", "color": "yellow" },
                        { "name": "nhl_power_play", "color": "green" },
                        { "name": "nhl_overtime", "color": "purple" },
                        { "name": "nhl_organ_lets_go", "color": "pink" }
                    ]
                }
            },
            "Active": {
                "checkbox": {}
            },
            "Description": {
                "rich_text": {}
            }
        }
    }')

# Extract database ID
DB_ID=$(echo "$CREATE_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'id' in data:
    print(data['id'].replace('-', ''))
elif 'message' in data:
    print('ERROR: ' + data['message'], file=sys.stderr)
    sys.exit(1)
else:
    print('ERROR: Unexpected response', file=sys.stderr)
    sys.exit(1)
")

if [[ $? -ne 0 || -z "$DB_ID" ]]; then
    echo "Failed to create database."
    echo "Response: $CREATE_RESPONSE"
    exit 1
fi

echo "Database created! ID: $DB_ID"

# ---- Step 2: Add default rows ----
add_row() {
    local event="$1"
    local melody="$2"
    local active="$3"
    local description="$4"

    curl -s -X POST \
        "https://api.notion.com/v1/pages" \
        -H "Authorization: Bearer ${NOTION_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Notion-Version: 2022-06-28" \
        -d '{
            "parent": { "database_id": "'"${DB_ID}"'" },
            "properties": {
                "Event": {
                    "title": [{ "text": { "content": "'"${event}"'" } }]
                },
                "Melody": {
                    "select": { "name": "'"${melody}"'" }
                },
                "Active": {
                    "checkbox": '"${active}"'
                },
                "Description": {
                    "rich_text": [{ "text": { "content": "'"${description}"'" } }]
                }
            }
        }' > /dev/null
}

echo "Adding default entries..."

add_row "stop" "nhl_goal_horn" "true"  "Melody when Claude finishes work"
add_row "stop" "ode_to_joy"    "false" "Classic Beethoven - scales with work time"
add_row "stop" "nhl_charge"    "false" "Organ Charge! riff"
add_row "stop" "nhl_hat_trick" "false" "3x horn + victory fanfare"
add_row "stop" "nhl_power_play" "false" "Fast energetic ascending riff"
add_row "stop" "nhl_overtime"  "false" "Dramatic build-up to climax"
add_row "stop" "nhl_organ_lets_go" "false" "Arena Let's Go! chant"

echo "Added 7 melody entries (nhl_goal_horn active by default)."

# ---- Step 3: Save credentials ----
CRED_FILE="$HOME/.claude_sound_notion"
echo "NOTION_API_KEY=$NOTION_API_KEY" > "$CRED_FILE"
echo "NOTION_DB_ID=$DB_ID" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"

echo ""
echo "=== Done! ==="
echo ""
echo "Credentials saved to: $CRED_FILE"
echo "Database ID: $DB_ID"
echo ""
echo "How to use:"
echo "  1. Open the database in Notion"
echo "  2. Toggle 'Active' checkbox to choose which melody plays"
echo "  3. Only ONE entry per event should be active"
echo "  4. Run: bash notion_sync.sh   (or it auto-syncs every 5 min)"
echo ""
echo "Change melody anytime from Notion - just toggle the checkbox!"
