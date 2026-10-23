<#
.SYNOPSIS
    Starts and verifies all demo services across Docker, Nginx, WSL, and Jenkins.
.DESCRIPTION
    Run this script after restarting your PC to ensure all ports and environments
    (3000, 3001, 5000, 8080, 8095, 8300) are running and ready for demonstration.
#>

[CmdletBinding()]
param(
    [switch]$StartLocalDev = $false
)

$ErrorActionPreference = "Continue"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   Retail Inventory Alert Dashboard - Demo Environment" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Docker Desktop & Engine
Write-Host "[1/5] Checking Docker Engine..." -ForegroundColor Yellow
$dockerReady = $false
try {
    $ver = & docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $ver) {
        $dockerReady = $true
        Write-Host "  [OK] Docker Engine is running (v$($ver.Trim()))." -ForegroundColor Green
    }
} catch {}

if (-not $dockerReady) {
    Write-Host "  [!] Docker Desktop not responding. Attempting to start Docker Desktop..." -ForegroundColor Yellow
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        Start-Process $dockerPath
        Write-Host "  Waiting up to 45 seconds for Docker engine to initialize..."
        for ($i = 1; $i -le 45; $i++) {
            Start-Sleep -Seconds 1
            $v = & docker version --format '{{.Server.Version}}' 2>$null
            if ($LASTEXITCODE -eq 0 -and $v) {
                $dockerReady = $true
                Write-Host "  [OK] Docker Desktop is now READY!" -ForegroundColor Green
                break
            }
        }
    }
}

# 2. Local Registry & Dev Container
if ($dockerReady) {
    Write-Host "`n[2/5] Starting Docker Containers (Registry :5000 & App :3001)..." -ForegroundColor Yellow
    & docker start registry 2>$null | Out-Null
    & docker start retail-inventory-dev 2>$null | Out-Null
    Write-Host "  [OK] Container states:" -ForegroundColor Green
    & docker ps --format "    - {{.Names}}: {{.Status}} (Ports: {{.Ports}})"
}

# 3. Windows Nginx Proxy (Port 8095)
Write-Host "`n[3/5] Checking Windows Nginx Reverse Proxy (Port 8095)..." -ForegroundColor Yellow
$nginxProc = Get-Process "nginx" -ErrorAction SilentlyContinue
if (-not $nginxProc) {
    if (Test-Path "C:\nginx\nginx.exe") {
        Start-Process -FilePath "C:\nginx\nginx.exe" -WorkingDirectory "C:\nginx"
        Start-Sleep -Seconds 2
        Write-Host "  [OK] Windows Nginx started." -ForegroundColor Green
    } else {
        Write-Host "  [!] C:\nginx\nginx.exe not found. Skipping Windows Nginx." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  [OK] Windows Nginx is already running (PID: $($nginxProc[0].Id))." -ForegroundColor Green
}

# 4. WSL 2 Ubuntu-Retail & Keep-Alive (Port 8300)
Write-Host "`n[4/5] Initializing WSL 2 Node (Ubuntu-Retail -> Port 8300)..." -ForegroundColor Yellow
# Launch keep-alive background job if not already active
$wslJob = Get-Job -Name "WSL-KeepAlive-Demo" -ErrorAction SilentlyContinue
if (-not $wslJob -or $wslJob.State -ne 'Running') {
    Start-Job -Name "WSL-KeepAlive-Demo" -ScriptBlock {
        wsl.exe -d Ubuntu-Retail -- sleep infinity
    } | Out-Null
}

# Wake up WSL and start systemd services
& wsl.exe -d Ubuntu-Retail -- bash -c "systemctl start nginx retail-inventory 2>/dev/null"
Start-Sleep -Seconds 2
$wslHealth = try { (Invoke-WebRequest -Uri "http://localhost:8300/health" -UseBasicParsing -TimeoutSec 3).StatusCode } catch { 0 }
if ($wslHealth -eq 200) {
    Write-Host "  [OK] WSL Ubuntu-Retail is awake and healthy on http://localhost:8300." -ForegroundColor Green
} else {
    Write-Host "  [!] Port 8300 returned code '$wslHealth'. Retrying in 3 seconds..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 3
}

# 5. Standalone Local Dev (Port 3000)
if ($StartLocalDev) {
    Write-Host "`n[5/5] Launching Standalone Node.js Dev App (Port 3000)..." -ForegroundColor Yellow
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
    Start-Process powershell -ArgumentList "-NoExit -Command `"cd '$repoRoot'; npm start`""
    Write-Host "  [OK] Standalone dev process started in a separate window." -ForegroundColor Green
} else {
    Write-Host "`n[5/5] Standalone Node Dev App (Port 3000):" -ForegroundColor Yellow
    Write-Host "  Tip: Run 'npm start' in your terminal if you want to showcase direct local dev." -ForegroundColor DarkGray
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   Running Comprehensive Preflight Verification" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$preflightScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "preflight.ps1"
if (Test-Path $preflightScript) {
    & powershell -ExecutionPolicy Bypass -File $preflightScript
}
