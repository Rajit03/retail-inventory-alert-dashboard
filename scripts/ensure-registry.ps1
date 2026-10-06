<#
.SYNOPSIS
    Ensures the local Docker distribution registry container (localhost:5000) is running and ready.
.DESCRIPTION
    Verifies Docker daemon connectivity, inspects/creates the 'registry' container backed by
    'registry-data' persistent volume, and polls http://localhost:5000/v2/ until ready.
    Idempotent and safe to run on every pipeline build.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host " Checking Local Docker Registry (Port 5000)"
Write-Host "=========================================="

# 1. Verify Docker Engine accessibility
Write-Host "[1/3] Verifying Docker Engine connectivity..."
$dockerVersionOut = cmd /c "docker version 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker engine is not reachable or not running. Please ensure Docker Desktop is started." -ForegroundColor Red
    Write-Host "Output: $dockerVersionOut" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Docker daemon is reachable."

# 2. Check container state for 'registry'
Write-Host "[2/3] Checking 'registry' container status..."
$inspectStatus = (cmd /c "docker inspect --format ""{{.State.Status}}"" registry 2>nul").Trim()

if ($inspectStatus -eq 'running') {
    Write-Host "  Registry container is already running."
} elseif ($inspectStatus -ne '') {
    Write-Host "  Registry container exists with status '$inspectStatus'. Starting container..."
    $startOut = cmd /c "docker start registry 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to start existing registry container: $startOut" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Registry container started."
} else {
    Write-Host "  Registry container does not exist. Creating and running 'registry:2'..."
    $runOut = cmd /c "docker run -d --name registry --restart unless-stopped -p 5000:5000 -v registry-data:/var/lib/registry registry:2 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to launch registry container: $runOut" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Registry container created and started."
}

# 3. Poll http://localhost:5000/v2/ until responsive (up to 30 seconds)
Write-Host "[3/3] Waiting for registry API (http://localhost:5000/v2/)..."
$registryUrl = "http://localhost:5000/v2/"
$maxWaitSec = 30
$intervalSec = 1
$elapsed = 0
$isReady = $false

while ($elapsed -lt $maxWaitSec) {
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec
    try {
        $resp = Invoke-WebRequest -Uri $registryUrl -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $isReady = $true
            Write-Host "  Registry API responded with HTTP 200 (took ${elapsed}s)."
            break
        }
    } catch {
        # Retry until timeout
    }
}

if (-not $isReady) {
    Write-Host "[ERROR] Local Docker registry failed to respond at $registryUrl within $maxWaitSec seconds." -ForegroundColor Red
    cmd /c "docker logs --tail 20 registry"
    exit 1
}

Write-Host "`nDocker Registry Status:"
cmd /c "docker ps --filter name=^/registry$ --format ""table {{.Names}}\t{{.Status}}\t{{.Ports}}"""
Write-Host "=========================================="
Write-Host " Local Docker Registry is READY at localhost:5000"
Write-Host "=========================================="
exit 0
