#!/bin/bash
# notion_sync.sh — integracja Sound Code z Notion
#
# Komendy:
#   bootstrap <parent_page_id>
#       Tworzy w Notion:
#         A) bazę konfiguracji   (Hook | Profile | Enabled | Label)
#         B) bazę logu zdarzeń   (Timestamp | Hook | Profile | Played | File)
#         C) stronę dashboard    (stan profili, wizualizacja)
#       Zapisuje ID do sounds.json (notion.config_db_id / log_db_id / dashboard_page_id)
#       i ustawia notion.enabled = true.
#
#   push                 - wypchnij lokalny sounds.json → baza A (per hook x profile)
#   pull                 - zaciągnij bazę A → sounds.json (aktualizuje flagi enabled)
#   log <hook> <profile> <played:true|false> <file>
#                        - dopisz wiersz do bazy B (fire-and-forget z play_sound.sh)
#   dashboard            - przegeneruj stronę C
#   status               - pokaż status integracji
#
# Wymaga: $NOTION_TOKEN (secret integracji Notion) w środowisku.
# Integracja musi być udostępniona rodzicowi (Share → Connections → twoja integracja).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/sounds.json"

to_win() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        echo "$1"
    fi
}

require_token() {
    if [[ -z "${NOTION_TOKEN:-}" ]]; then
        echo "NOTION_TOKEN nie jest ustawiony. Export tokena integracji Notion:" >&2
        echo "  export NOTION_TOKEN='secret_xxx...'" >&2
        return 1
    fi
    return 0
}

ps_exec() {
    # Wykonuje podany fragment PS. Dostępne zmienne w kontekście:
    #   $configPath, $token
    local token_win
    token_win="${NOTION_TOKEN:-}"
    local config_win
    config_win=$(to_win "$CONFIG")
    local header=$(cat <<PSHEAD
\$ErrorActionPreference='Stop'
\$token='$token_win'
\$configPath='$config_win'
\$baseHeaders = @{
    'Authorization' = 'Bearer ' + \$token
    'Notion-Version' = '2022-06-28'
    'Content-Type' = 'application/json; charset=utf-8'
}
function Save-Config(\$cfg) {
    \$cfg | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -Path \$configPath
}
function Load-Config {
    Get-Content -Raw -Path \$configPath | ConvertFrom-Json
}
PSHEAD
)
    powershell.exe -NoProfile -Command "$header
$1"
}

cmd_status() {
    local win
    win=$(to_win "$CONFIG")
    powershell.exe -NoProfile -Command "
        \$c = Get-Content -Raw -Path '$win' | ConvertFrom-Json
        Write-Output ('enabled         : ' + \$c.notion.enabled)
        Write-Output ('log_events      : ' + \$c.notion.log_events)
        Write-Output ('config_db_id    : ' + \$c.notion.config_db_id)
        Write-Output ('log_db_id       : ' + \$c.notion.log_db_id)
        Write-Output ('dashboard_page  : ' + \$c.notion.dashboard_page_id)
        Write-Output ('NOTION_TOKEN    : ' + \$(if (\$env:NOTION_TOKEN) { '[ustawiony]' } else { '[BRAK]' }))
    " 2>/dev/null | tr -d '\r'
}

cmd_bootstrap() {
    local parent="${1:-}"
    if [[ -z "$parent" ]]; then
        echo "Użycie: $0 bootstrap <parent_page_id>" >&2
        echo "  parent_page_id to ID strony Notion (z URL), na której utworzymy bazy." >&2
        return 1
    fi
    require_token || return 1

    ps_exec "
\$parent = '$parent'
\$cfg = Load-Config

# --- A: baza konfiguracji ---
\$configDbBody = @{
    parent = @{ type='page_id'; page_id=\$parent }
    title  = @(@{ type='text'; text=@{ content='Sound Code — Config' } })
    properties = @{
        'Key'     = @{ title = @{} }
        'Hook'    = @{ rich_text = @{} }
        'Profile' = @{ select = @{ options = @(
            @{ name='terran';  color='red' },
            @{ name='protoss'; color='yellow' },
            @{ name='zerg';    color='purple' },
            @{ name='beep';    color='gray' }
        ) } }
        'Enabled' = @{ checkbox = @{} }
        'Label'   = @{ rich_text = @{} }
    }
} | ConvertTo-Json -Depth 20
\$configDb = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/databases' -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$configDbBody))

# --- B: baza logu ---
\$logDbBody = @{
    parent = @{ type='page_id'; page_id=\$parent }
    title  = @(@{ type='text'; text=@{ content='Sound Code — Event Log' } })
    properties = @{
        'Event'     = @{ title = @{} }
        'Timestamp' = @{ date = @{} }
        'Hook'      = @{ select = @{ options = @(
            @{ name='SessionStart' }, @{ name='UserPromptSubmit' },
            @{ name='Notification' }, @{ name='Stop' },
            @{ name='SubagentStop' }, @{ name='PreCompact' },
            @{ name='SessionEnd' }
        ) } }
        'Profile'   = @{ select = @{ options = @(
            @{ name='terran' }, @{ name='protoss' }, @{ name='zerg' }, @{ name='beep' }, @{ name='<none>' }
        ) } }
        'Played'    = @{ checkbox = @{} }
        'File'      = @{ rich_text = @{} }
    }
} | ConvertTo-Json -Depth 20
\$logDb = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/databases' -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$logDbBody))

# --- C: dashboard page ---
\$dashBody = @{
    parent = @{ type='page_id'; page_id=\$parent }
    properties = @{
        title = @(@{ type='text'; text=@{ content='Sound Code — Dashboard' } })
    }
    children = @(
        @{ object='block'; type='heading_2'; heading_2=@{ rich_text=@(@{ type='text'; text=@{ content='Sound Code — Dashboard' } }) } },
        @{ object='block'; type='paragraph'; paragraph=@{ rich_text=@(@{ type='text'; text=@{ content='Uruchom: bash notion_sync.sh dashboard — żeby odświeżyć stan.' } }) } }
    )
} | ConvertTo-Json -Depth 20
\$dash = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/pages' -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$dashBody))

\$cfg.notion.enabled          = \$true
\$cfg.notion.config_db_id     = \$configDb.id
\$cfg.notion.log_db_id        = \$logDb.id
\$cfg.notion.dashboard_page_id = \$dash.id
Save-Config \$cfg

Write-Output ('OK. config_db_id    = ' + \$configDb.id)
Write-Output ('OK. log_db_id       = ' + \$logDb.id)
Write-Output ('OK. dashboard_page  = ' + \$dash.id)
" 2>&1 | tr -d '\r'
}

cmd_push() {
    require_token || return 1
    ps_exec "
\$cfg = Load-Config
if (-not \$cfg.notion.enabled -or -not \$cfg.notion.config_db_id) {
    throw 'Notion wyłączony lub brak config_db_id. Najpierw: bootstrap <parent_page_id>.'
}
\$dbId = \$cfg.notion.config_db_id

# Pobierz istniejące wiersze (po 'Key' = Hook|Profile)
\$existing = @{}
\$hasMore = \$true
\$cursor  = \$null
while (\$hasMore) {
    \$q = @{ page_size = 100 }
    if (\$cursor) { \$q.start_cursor = \$cursor }
    \$body = (\$q | ConvertTo-Json -Depth 5)
    \$resp = Invoke-RestMethod -Method Post -Uri (\"https://api.notion.com/v1/databases/\" + \$dbId + \"/query\") -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body))
    foreach (\$r in \$resp.results) {
        \$keyProp = \$r.properties.Key.title
        if (\$keyProp -and \$keyProp.Count -gt 0) {
            \$existing[\$keyProp[0].plain_text] = \$r.id
        }
    }
    \$hasMore = \$resp.has_more
    \$cursor  = \$resp.next_cursor
}

foreach (\$pName in \$cfg.profiles.PSObject.Properties.Name) {
    \$prof = \$cfg.profiles.\$pName
    foreach (\$hook in \$cfg.hooks) {
        \$enabled = [bool]\$prof.hooks.\$hook
        \$key     = \"\$hook|\$pName\"
        \$props = @{
            'Key'     = @{ title     = @(@{ type='text'; text=@{ content=\$key } }) }
            'Hook'    = @{ rich_text = @(@{ type='text'; text=@{ content=\$hook } }) }
            'Profile' = @{ select    = @{ name=\$pName } }
            'Enabled' = @{ checkbox  = \$enabled }
            'Label'   = @{ rich_text = @(@{ type='text'; text=@{ content=\$prof.label } }) }
        }
        if (\$existing.ContainsKey(\$key)) {
            \$body = @{ properties = \$props } | ConvertTo-Json -Depth 20
            Invoke-RestMethod -Method Patch -Uri (\"https://api.notion.com/v1/pages/\" + \$existing[\$key]) -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body)) | Out-Null
        } else {
            \$body = @{ parent=@{ database_id=\$dbId }; properties=\$props } | ConvertTo-Json -Depth 20
            Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/pages' -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body)) | Out-Null
        }
    }
}
Write-Output 'push OK'
" 2>&1 | tr -d '\r'
}

cmd_pull() {
    require_token || return 1
    ps_exec "
\$cfg = Load-Config
if (-not \$cfg.notion.enabled -or -not \$cfg.notion.config_db_id) {
    throw 'Notion wyłączony lub brak config_db_id.'
}
\$dbId = \$cfg.notion.config_db_id

\$hasMore = \$true; \$cursor = \$null
\$updated = 0
while (\$hasMore) {
    \$q = @{ page_size = 100 }
    if (\$cursor) { \$q.start_cursor = \$cursor }
    \$body = (\$q | ConvertTo-Json -Depth 5)
    \$resp = Invoke-RestMethod -Method Post -Uri (\"https://api.notion.com/v1/databases/\" + \$dbId + \"/query\") -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body))
    foreach (\$r in \$resp.results) {
        \$hook    = if (\$r.properties.Hook.rich_text.Count -gt 0) { \$r.properties.Hook.rich_text[0].plain_text } else { \$null }
        \$profile = if (\$r.properties.Profile.select)           { \$r.properties.Profile.select.name }  else { \$null }
        \$enabled = [bool]\$r.properties.Enabled.checkbox
        if (\$hook -and \$profile -and \$cfg.profiles.\$profile -and \$cfg.profiles.\$profile.hooks.PSObject.Properties.Name -contains \$hook) {
            \$cfg.profiles.\$profile.hooks.\$hook = \$enabled
            \$updated++
        }
    }
    \$hasMore = \$resp.has_more; \$cursor = \$resp.next_cursor
}
Save-Config \$cfg
Write-Output (\"pull OK (zaktualizowano wpisow: \" + \$updated + \")\")
" 2>&1 | tr -d '\r'
}

cmd_log() {
    local hook="${1:-}"
    local profile="${2:-<none>}"
    local played="${3:-false}"
    local file="${4:-}"
    [[ -z "$hook" ]] && { echo "Uzycie: $0 log <hook> <profile> <played> <file>" >&2; return 1; }
    require_token >/dev/null 2>&1 || return 0  # cisza, to ma byc fire-and-forget

    # Escape apostrofow dla PS
    local hook_e=${hook//\'/\'\'}
    local profile_e=${profile//\'/\'\'}
    local played_e=${played//\'/\'\'}
    local file_e=${file//\'/\'\'}

    ps_exec "
\$cfg = Load-Config
if (-not \$cfg.notion.enabled -or -not \$cfg.notion.log_db_id -or -not \$cfg.notion.log_events) { exit 0 }
\$dbId = \$cfg.notion.log_db_id
\$hook='$hook_e'; \$profile='$profile_e'; \$played=('$played_e' -eq 'true'); \$file='$file_e'
\$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
\$title = \"\$ts  \$hook  (\$profile)\"
\$props = @{
    'Event'     = @{ title     = @(@{ type='text'; text=@{ content=\$title } }) }
    'Timestamp' = @{ date      = @{ start=\$ts } }
    'Hook'      = @{ select    = @{ name=\$hook } }
    'Profile'   = @{ select    = @{ name=\$profile } }
    'Played'    = @{ checkbox  = \$played }
    'File'      = @{ rich_text = @(@{ type='text'; text=@{ content=\$file } }) }
}
\$body = @{ parent=@{ database_id=\$dbId }; properties=\$props } | ConvertTo-Json -Depth 20
try { Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/pages' -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body)) | Out-Null } catch {}
" >/dev/null 2>&1
}

cmd_dashboard() {
    require_token || return 1
    ps_exec "
\$cfg = Load-Config
if (-not \$cfg.notion.enabled -or -not \$cfg.notion.dashboard_page_id) {
    throw 'Brak dashboard_page_id. Najpierw: bootstrap.'
}
\$pageId = \$cfg.notion.dashboard_page_id

# Pobierz obecne dzieci i usuń
\$children = Invoke-RestMethod -Method Get -Uri (\"https://api.notion.com/v1/blocks/\" + \$pageId + \"/children?page_size=100\") -Headers \$baseHeaders
foreach (\$c in \$children.results) {
    try { Invoke-RestMethod -Method Delete -Uri (\"https://api.notion.com/v1/blocks/\" + \$c.id) -Headers \$baseHeaders | Out-Null } catch {}
}

# Zbuduj nowe bloki
function Text(\$s) { return @(@{ type='text'; text=@{ content=[string]\$s } }) }
\$blocks = @()
\$blocks += @{ object='block'; type='heading_1'; heading_1=@{ rich_text=(Text 'Sound Code — Dashboard') } }
\$blocks += @{ object='block'; type='paragraph'; paragraph=@{ rich_text=(Text ('Default profile: ' + \$cfg.default_profile + '   |   enabled: ' + \$cfg.enabled + '   |   fallback_beep: ' + \$cfg.fallback_beep)) } }

foreach (\$pName in \$cfg.profiles.PSObject.Properties.Name) {
    \$prof = \$cfg.profiles.\$pName
    \$blocks += @{ object='block'; type='heading_2'; heading_2=@{ rich_text=(Text (\$pName + ' — ' + \$prof.label)) } }
    \$rows = @()
    \$rows += @{ object='block'; type='table_row'; table_row=@{ cells=@(
        (Text 'Hook'), (Text 'Enabled'), (Text 'File (konwencja)')
    ) } }
    foreach (\$h in \$cfg.hooks) {
        \$enabled = [bool]\$prof.hooks.\$h
        \$sub = if (\$prof.subdir) { \$prof.subdir } else { '-' }
        \$fname = if (\$prof.subdir) { \$sub + '/' + \$h + '.wav' } else { '<melodia Ody do Radości>' }
        \$rows += @{ object='block'; type='table_row'; table_row=@{ cells=@(
            (Text \$h), (Text (\$enabled.ToString().ToLower())), (Text \$fname)
        ) } }
    }
    \$blocks += @{ object='block'; type='table'; table=@{ table_width=3; has_column_header=\$true; has_row_header=\$false; children=\$rows } }
}

\$body = @{ children = \$blocks } | ConvertTo-Json -Depth 50
Invoke-RestMethod -Method Patch -Uri (\"https://api.notion.com/v1/blocks/\" + \$pageId + \"/children\") -Headers \$baseHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes(\$body)) | Out-Null
Write-Output 'dashboard OK'
" 2>&1 | tr -d '\r'
}

main() {
    local cmd="${1:-status}"
    shift || true
    case "$cmd" in
        status)     cmd_status ;;
        bootstrap)  cmd_bootstrap "$@" ;;
        push)       cmd_push ;;
        pull)       cmd_pull ;;
        log)        cmd_log "$@" ;;
        dashboard)  cmd_dashboard ;;
        help|-h|--help)
            sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
            ;;
        *)
            echo "Nieznana komenda: $cmd" >&2
            echo "Użycie: $0 {status|bootstrap <parent_page_id>|push|pull|log ...|dashboard|help}" >&2
            return 1
            ;;
    esac
}

main "$@"
