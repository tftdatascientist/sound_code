##############################################
# Setup: Claude Environment Manager
# Uruchom w PowerShell: .\setup_env_manager.ps1
##############################################

$ErrorActionPreference = "Stop"
$ProjectDir = "$env:USERPROFILE\claude-env-manager"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`n=== Claude Environment Manager - Setup ===" -ForegroundColor Cyan

# 1. Katalog projektu
if (Test-Path $ProjectDir) {
    Write-Host "Katalog $ProjectDir juz istnieje - czyszcze..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $ProjectDir
}
Write-Host "Tworze katalog: $ProjectDir" -ForegroundColor Green
New-Item -ItemType Directory -Path $ProjectDir | Out-Null

# 2. Kopiuj CLAUDE.md
$BriefSource = Join-Path $ScriptDir "CLAUDE_ENV_MANAGER_BRIEF.md"
if (-not (Test-Path $BriefSource)) {
    Write-Host "BLAD: Nie znaleziono $BriefSource" -ForegroundColor Red
    exit 1
}
Copy-Item $BriefSource (Join-Path $ProjectDir "CLAUDE.md")
Write-Host "Skopiowano CLAUDE.md" -ForegroundColor Green

# 3. requirements.txt
@"
PySide6>=6.7
QScintilla>=2.14
watchdog>=4.0
pytest>=8.0
"@ | Out-File -Encoding utf8NoBOM (Join-Path $ProjectDir "requirements.txt")
Write-Host "Utworzono requirements.txt" -ForegroundColor Green

# 4. .gitignore
@"
__pycache__/
*.pyc
.venv/
*.egg-info/
dist/
build/
*.spec
*.bak
.env
"@ | Out-File -Encoding utf8NoBOM (Join-Path $ProjectDir ".gitignore")
Write-Host "Utworzono .gitignore" -ForegroundColor Green

# 5. Git init + pierwszy commit
Push-Location $ProjectDir
git init
git add CLAUDE.md requirements.txt .gitignore
git commit -m "Initial project setup with CLAUDE.md brief"
Pop-Location
Write-Host "Git zainicjalizowany z pierwszym commitem" -ForegroundColor Green

# 6. Python venv + instalacja
Write-Host "Tworze venv i instaluje zaleznosci..." -ForegroundColor Green
Push-Location $ProjectDir
python -m venv .venv
& .\.venv\Scripts\pip.exe install -r requirements.txt
Pop-Location
Write-Host "Zaleznosci zainstalowane" -ForegroundColor Green

# 7. Otworz VS Code
Write-Host "`n=== Otwieram VS Code w $ProjectDir ===" -ForegroundColor Cyan
code $ProjectDir

Write-Host "`n=== GOTOWE ===" -ForegroundColor Cyan
Write-Host "W terminalu VS Code uruchom: claude" -ForegroundColor White
Write-Host "Potem napisz: Przeczytaj CLAUDE.md i zaimplementuj Faze 1 MVP" -ForegroundColor White
Write-Host ""
