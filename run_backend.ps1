# ============================================================
# Secure launcher for the Food Ordering backend
#
# - uses the project's Python virtual environment (..\venv)
# - asks for the MySQL password WITHOUT displaying it and WITHOUT
#   saving it to any file (it lives only in this process)
# - starts the Flask development server at http://127.0.0.1:5000
# ============================================================
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$python = Join-Path $PSScriptRoot "..\venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "No Python virtual environment found at ..\venv" -ForegroundColor Yellow
    Write-Host "Create it first, then re-run this script:" -ForegroundColor Yellow
    Write-Host "    python -m venv ..\venv" -ForegroundColor Cyan
    Write-Host "    ..\venv\Scripts\pip install -r requirements.txt" -ForegroundColor Cyan
    exit 1
}

# Prompt for the database password (hidden input, never stored).
$secure = Read-Host "MySQL password for the database user" -AsSecureString
$env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

Write-Host "Starting Food Ordering backend on http://127.0.0.1:5000 ..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor Green
& $python app.py
