#!/bin/bash
# Interactive setup for Sound Code + Notion integration
#
# This script:
# 1. Collects Notion API key
# 2. Creates the database automatically via API
# 3. Pre-populates with all melody options
# 4. Runs first sync
#
# Usage: setup_notion.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat << 'BANNER'
╔══════════════════════════════════════════╗
║   🏒  Sound Code - Notion Setup  🏒     ║
╚══════════════════════════════════════════╝
BANNER

echo ""
echo "=== Step 1: Create Notion Integration ==="
echo ""
echo "1. Go to: https://www.notion.so/my-integrations"
echo "2. Click '+ New integration'"
echo "3. Name it 'Sound Code'"
echo "4. Capabilities: Read/Update/Insert content"
echo "5. Copy the 'Internal Integration Secret'"
echo ""

read -p "Paste your Notion API key: " API_KEY

if [[ -z "$API_KEY" ]]; then
    echo "Error: API key cannot be empty."
    exit 1
fi

echo ""
echo "=== Step 2: Choose parent page ==="
echo ""
echo "The database will be created inside a Notion page."
echo ""
echo "1. Open (or create) a Notion page for Sound Code config"
echo "2. Click '...' > 'Connections' > add your 'Sound Code' integration"
echo "3. Copy the page URL"
echo ""
echo "The page ID is the 32-char hex at the end of the URL:"
echo "  https://www.notion.so/My-Page-abc123def456..."
echo "                                 ^^^^^^^^^^^^^^^^"
echo ""

read -p "Paste the parent page ID (or full URL): " PAGE_INPUT

if [[ -z "$PAGE_INPUT" ]]; then
    echo "Error: Page ID cannot be empty."
    exit 1
fi

# Extract page ID from URL or raw input
# Remove everything before the last dash-separated hex block, or just clean up
PAGE_ID=$(echo "$PAGE_INPUT" | sed 's/.*-//' | sed 's/[?#].*//' | tr -d ' -')

# If it's a full URL, the ID is the last 32 hex chars
if [[ ${#PAGE_ID} -gt 32 ]]; then
    PAGE_ID="${PAGE_ID: -32}"
fi

echo ""
echo "=== Step 3: Creating database... ==="
echo ""

bash "$SCRIPT_DIR/create_notion_db.sh" "$API_KEY" "$PAGE_ID"

if [[ $? -ne 0 ]]; then
    echo ""
    echo "Setup failed. Check your API key and page ID."
    echo "Make sure the page is shared with your integration."
    exit 1
fi

echo ""
echo "=== Step 4: Initial sync ==="
echo ""

bash "$SCRIPT_DIR/notion_sync.sh"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Setup complete!                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Available melodies:"
echo "  ode_to_joy        Beethoven (scales with work time)"
echo "  nhl_goal_horn     Goal horn + fanfare"
echo "  nhl_charge        Organ 'Charge!' riff"
echo "  nhl_hat_trick     3x horn + victory fanfare"
echo "  nhl_power_play    Energetic ascending riff"
echo "  nhl_overtime      Dramatic build to climax"
echo "  nhl_organ_lets_go Arena 'Let's Go!' chant"
echo ""
echo "To change melody:"
echo "  1. Open the database in Notion"
echo "  2. Uncheck current active melody"
echo "  3. Check the one you want"
echo "  4. Auto-syncs within 5 minutes (or run: bash notion_sync.sh)"
echo ""
echo "Test a melody now:  bash play_sound.sh nhl_goal_horn"
