#!/bin/bash
# Setup helper for Sound Code + Notion integration
#
# This script:
# 1. Saves your Notion credentials
# 2. Tests the connection
# 3. Shows available melodies
# 4. Explains the Notion database structure
#
# Usage: setup_notion.sh

cat << 'BANNER'
╔══════════════════════════════════════════╗
║     Sound Code - Notion Setup            ║
╚══════════════════════════════════════════╝
BANNER

echo ""
echo "=== Step 1: Create Notion Integration ==="
echo ""
echo "1. Go to: https://www.notion.so/my-integrations"
echo "2. Click '+ New integration'"
echo "3. Name it 'Sound Code' (or whatever you like)"
echo "4. Copy the 'Internal Integration Secret'"
echo ""

read -p "Paste your Notion API key: " API_KEY

if [[ -z "$API_KEY" ]]; then
    echo "Error: API key cannot be empty."
    exit 1
fi

echo ""
echo "=== Step 2: Create Notion Database ==="
echo ""
echo "Create a new database in Notion with these columns:"
echo ""
echo "  ┌────────────┬──────────┬─────────────────────────────┐"
echo "  │ Event      │ Melody   │ Active                      │"
echo "  │ (title)    │ (select) │ (checkbox)                  │"
echo "  ├────────────┼──────────┼─────────────────────────────┤"
echo "  │ stop       │ nhl_goal │ ☑                           │"
echo "  │ start      │ (none)   │ ☐                           │"
echo "  └────────────┴──────────┴─────────────────────────────┘"
echo ""
echo "Available melodies for the 'Melody' select column:"
echo ""
echo "  Classic:"
echo "    ode_to_joy        - Beethoven, scales with work time"
echo ""
echo "  NHL Hockey:"
echo "    nhl_goal_horn     - Goal horn + fanfare"
echo "    nhl_charge        - Classic organ 'Charge!' riff"
echo "    nhl_hat_trick     - 3x horn + victory fanfare"
echo "    nhl_power_play    - Energetic ascending riff"
echo "    nhl_overtime      - Dramatic build to climax"
echo "    nhl_organ_lets_go - Arena 'Let's Go!' chant"
echo ""
echo "Then share the database with your 'Sound Code' integration"
echo "(click '...' > 'Connections' > add your integration)"
echo ""

read -p "Paste your Database ID (from URL): " DB_ID

if [[ -z "$DB_ID" ]]; then
    echo "Error: Database ID cannot be empty."
    exit 1
fi

# Clean up DB_ID (remove dashes if pasted from URL)
DB_ID=$(echo "$DB_ID" | tr -d ' -')

echo ""
echo "=== Step 3: Testing connection... ==="
echo ""

# Save credentials
CRED_FILE="$HOME/.claude_sound_notion"
echo "NOTION_API_KEY=$API_KEY" > "$CRED_FILE"
echo "NOTION_DB_ID=$DB_ID" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"

# Test connection
RESPONSE=$(curl -s \
    "https://api.notion.com/v1/databases/${DB_ID}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Notion-Version: 2022-06-28")

if echo "$RESPONSE" | grep -q '"title"'; then
    DB_TITLE=$(echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
titles = data.get('title', [])
print(titles[0]['plain_text'] if titles else 'Untitled')
" 2>/dev/null)
    echo "✓ Connected to database: $DB_TITLE"
else
    echo "✗ Connection failed. Check your API key and database ID."
    echo "  Make sure you shared the database with your integration."
    echo ""
    echo "  Response: $(echo "$RESPONSE" | head -3)"
    exit 1
fi

echo ""
echo "=== Step 4: Initial sync ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/notion_sync.sh"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Credentials saved to: $CRED_FILE"
echo ""
echo "To change melodies:"
echo "  1. Edit the Notion database (toggle Active, change Melody)"
echo "  2. Run: bash notion_sync.sh"
echo ""
echo "The sync will update the local config that play_sound.sh reads."
echo "You can also add 'bash $(pwd)/notion_sync.sh' to a cron job"
echo "or Claude Code hook for automatic syncing."
