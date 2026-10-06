<#
.SYNOPSIS
    Deploys a fresh Docker container from a registry image for a target environment.
.DESCRIPTION
    1. Pulls the specified image from the Docker registry.
    2. Records previous container image (for rollback tracking), then stops and removes old container.
    3. Stops any legacy Task 8 host process and cleans up app.pid.
    4. Runs fresh container with persistent named volume, port mapping, and labels.
    5. Waits up to 60s for both Docker Healthcheck ('healthy') and HTTP /health ('UP').
    6. Automatically seeds database if /api/items is empty.
    7. Retains 5 newest local images for the repository and prunes older ones.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [int]$HostPort,

    [Parameter(Mandatory = $true)]
    [string]$ImageRef,

    [Parameter(Mandatory = $true)]
    [string]$BuildNumber,

    [Parameter(Mandatory = $false)]
    [string]$DeployRoot = 'C:\deploy\retail-inventory'
)

$ErrorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host " Deploying Container: retail-inventory-$Environment"
Write-Host " Environment  : $Environment"
Write-Host " Host Port    : $HostPort"
Write-Host " Image Ref    : $ImageRef"
Write-Host " Build Number : $BuildNumber"
Write-Host " Deploy Root  : $DeployRoot"
Write-Host "=========================================="

$containerName = "retail-inventory-$Environment"
$volumeName = "retail-inventory-$Environment-data"

# (a) Pull image from registry
Write-Host "`n[1/7] Pulling image from registry: $ImageRef..."
$pullOut = cmd /c "docker pull $ImageRef 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to pull image $ImageRef from registry." -ForegroundColor Red
    Write-Host "$pullOut" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Image pull successful."

# (b) Inspect and remove existing container
Write-Host "`n[2/7] Checking for existing container '$containerName'..."
$existingImage = (cmd /c "docker inspect --format ""{{.Config.Image}}"" $containerName 2>nul").Trim()
if ($existingImage) {
    Write-Host "  Previous image: $existingImage"
    Write-Host "  Stopping and removing container '$containerName'..."
    cmd /c "docker stop $containerName 2>nul" | Out-Null
    cmd /c "docker rm $containerName 2>nul" | Out-Null
    Write-Host "  Old container removed."
} else {
    Write-Host "  No previous container named '$containerName' found."
}

# (c) Stop legacy Task 8 host process if app.pid exists
Write-Host "`n[3/7] Checking for legacy host process pid file..."
$legacyPidFile = Join-Path $DeployRoot "$Environment\app.pid"
if (Test-Path -Path $legacyPidFile) {
    try {
        $legacyPidRaw = (Get-Content -Path $legacyPidFile -Raw).Trim()
        if ($legacyPidRaw -match '^\d+$') {
            $legacyPid = [int]$legacyPidRaw
            Write-Host "  Found legacy host process PID: $legacyPid. Stopping process..."
            Stop-Process -Id $legacyPid -Force -ErrorAction SilentlyContinue
            cmd /c "taskkill /F /PID $legacyPid /T 2>nul" | Out-Null
            Write-Host "  Legacy host process stopped."
        }
    } catch {
        Write-Host "  Note: Error while stopping legacy process: $_"
    }
    Remove-Item -Path $legacyPidFile -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed legacy pid file: $legacyPidFile"
} else {
    Write-Host "  No legacy pid file at: $legacyPidFile"
}

# (d) Run fresh container
Write-Host "`n[4/7] Launching fresh container '$containerName' on host port $HostPort..."
$dockerRunCmd = "docker run -d --name $containerName --restart unless-stopped -p ${HostPort}:3000 -v ${volumeName}:/app/data -e NODE_ENV=production --label deploy.environment=$Environment --label deploy.build=$BuildNumber $ImageRef"
$containerId = (cmd /c "$dockerRunCmd 2>&1").Trim()

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start container $containerName: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "  Container started successfully. ID: $containerId"

# (e) Wait up to 60 seconds for both container healthcheck and HTTP endpoint
Write-Host "`n[5/7] Waiting for container health (Docker Health Status + HTTP /health)..."
$healthUrl = "http://localhost:$HostPort/health"
$maxWaitSec = 60
$intervalSec = 2
$elapsed = 0
$isHealthy = $false

while ($elapsed -lt $maxWaitSec) {
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec

    $dockerHealth = (cmd /c "docker inspect --format ""{{.State.Health.Status}}"" $containerName 2>nul").Trim()
    $httpHealthy = $false

    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 2 -ErrorAction Stop
        if ($resp.status -eq 'UP' -or ($resp -is [string] -and $resp -match '"status"\s*:\s*"UP"')) {
            $httpHealthy = $true
        }
    } catch {
        # HTTP endpoint not ready yet
    }

    Write-Host "  [T+${elapsed}s] Docker Health: '$dockerHealth' | HTTP /health UP: $httpHealthy"

    if ($dockerHealth -eq 'healthy' -and $httpHealthy) {
        $isHealthy = $true
        Write-Host "  Both container health check and HTTP endpoint are HEALTHY (took ${elapsed}s)."
        break
    }
}

if (-not $isHealthy) {
    Write-Host "[ERROR] Container $containerName failed health checks within $maxWaitSec seconds." -ForegroundColor Red
    Write-Host "`n--- Docker Container Logs (last 30 lines) ---" -ForegroundColor Red
    cmd /c "docker logs --tail 30 $containerName"
    exit 1
}

# (f) Check /api/items and seed database if empty
Write-Host "`n[6/7] Checking database status at http://localhost:$HostPort/api/items..."
try {
    $items = Invoke-RestMethod -Uri "http://localhost:$HostPort/api/items" -Method Get -TimeoutSec 5 -ErrorAction Stop
    $isEmpty = ($null -eq $items) -or ($items.Count -eq 0) -or ($items -is [string] -and $items.Trim() -eq '[]')
    if ($isEmpty) {
        Write-Host "  Database is empty. Seeding initial data with 'npm run seed'..."
        $seedOut = cmd /c "docker exec $containerName npm run seed 2>&1"
        Write-Host "$seedOut"
        Write-Host "  Database seeded successfully."
    } else {
        $count = if ($items.Count) { $items.Count } else { "N/A" }
        Write-Host "  Database already contains data ($count items). Skipping seed."
    }
} catch {
    Write-Host "  Warning: Failed to verify /api/items: $_. Executing seed as precaution..."
    cmd /c "docker exec $containerName npm run seed 2>&1" | Out-Null
}

# (g) Prune older local images (keep 5 newest)
Write-Host "`n[7/7] Managing local image retention (keeping 5 newest tags)..."
try {
    $repoName = ($ImageRef -split ':')[0]
    $allImageLines = cmd /c "docker images --format ""{{.Repository}}:{{.Tag}}"" $repoName 2>nul"
    $validImages = @($allImageLines | Where-Object { $_ -and $_ -notmatch '<none>' -and $_ -notmatch ':latest' })

    if ($validImages.Count -gt 5) {
        $imagesToPrune = $validImages | Select-Object -Skip 5
        foreach ($img in $imagesToPrune) {
            Write-Host "  Pruning old image: $img"
            cmd /c "docker rmi $img 2>nul" | Out-Null
        }
    } else {
        Write-Host "  Total tagged images for $repoName is $($validImages.Count) (<= 5). No pruning required."
    }
} catch {
    Write-Host "  Image pruning notice: $_"
}

Write-Host "`nActive Container Status:"
cmd /c "docker ps --filter name=^/$containerName$ --format ""table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"""

Write-Host "=========================================="
Write-Host " Deployment of $containerName SUCCEEDED!"
Write-Host " Access URLs: http://localhost:$HostPort/items"
Write-Host "=========================================="
exit 0
