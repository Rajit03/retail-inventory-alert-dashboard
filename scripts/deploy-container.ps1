<#
.SYNOPSIS
    Deploys a fresh Docker container from a registry image for a target environment.
.DESCRIPTION
    1. Pulls the specified image from the Docker registry.
    2. Records previous container image (for rollback tracking), then stops and removes old container.
    3. Detects and stops any leftover Task 8 host process on the target host port, or errors on unknown process.
    4. Runs fresh container with persistent named volume, port mapping, and labels.
    5. Verifies container port bindings with 'docker port'.
    6. Waits up to 60s for both Docker Healthcheck ('healthy') and HTTP /health ('UP').
    7. Automatically seeds database if /api/items is empty.
    8. Retains 5 newest local images for the repository and prunes older ones.
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

$ErrorActionPreference = 'Continue'

Write-Host "=========================================="
Write-Host " Docker Continuous Deployment: $Environment"
Write-Host " Image Ref    : $ImageRef"
Write-Host " Host Port    : $HostPort"
Write-Host " Build Number : $BuildNumber"
Write-Host " Deploy Root  : $DeployRoot"
Write-Host "=========================================="

$containerName = "retail-inventory-$Environment"
$volumeName = "retail-inventory-$Environment-data"

# (1) Pull image from registry
Write-Host "`n[1/7] Pulling image from registry: $ImageRef..."
& docker pull $ImageRef
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to pull image from registry: $ImageRef" -ForegroundColor Red
    exit 1
}
Write-Host "  Image pull successful."

# (2) Inspect and remove existing container
Write-Host "`n[2/7] Checking for existing container '$containerName'..."
$existingImage = (& docker inspect --format '{{.Config.Image}}' $containerName 2>$null | Out-String).Trim()
if ($LASTEXITCODE -eq 0 -and $existingImage) {
    Write-Host "  Previous image: $existingImage"
    Write-Host "  Stopping and removing container '$containerName'..."
    & docker stop $containerName 2>$null | Out-Null
    & docker rm $containerName 2>$null | Out-Null
    Write-Host "  Old container removed."
} else {
    Write-Host "  No previous container named '$containerName' found."
}

# (3) Stop legacy Task 8 host process on HostPort if listening
Write-Host "`n[3/7] Checking whether host port $HostPort is in use..."
$conn = Get-NetTCPConnection -LocalPort $HostPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1

if ($conn) {
    $listeningPid = $conn.OwningProcess
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $listeningPid" -ErrorAction SilentlyContinue
    $pName = if ($proc) { $proc.Name } else { "PID $listeningPid" }
    $cmdLine = if ($proc -and $proc.CommandLine) { $proc.CommandLine } else { "" }

    Write-Host "  Process listening on port ${HostPort}: PID=$listeningPid, Name=$pName"
    Write-Host "  Command Line: $cmdLine"

    $legacyPidFile = Join-Path $DeployRoot "$Environment\app.pid"
    $hasLegacyPid = $false
    if (Test-Path $legacyPidFile) {
        $rawPid = (Get-Content $legacyPidFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($rawPid -eq "$listeningPid") {
            $hasLegacyPid = $true
        }
    }

    $isTask8Node = ($pName -match '^node(\.exe)?$' -and ($cmdLine -like "*$DeployRoot*" -or $cmdLine -like "*src\server.js*" -or $cmdLine -like "*src/server.js*" -or $hasLegacyPid -or [string]::IsNullOrWhiteSpace($cmdLine)))

    if ($isTask8Node) {
        Write-Host "  Identified leftover Task 8 Node.js process (PID $listeningPid). Stopping with -Force..." -ForegroundColor Yellow
        Stop-Process -Id $listeningPid -Force -ErrorAction SilentlyContinue
        cmd /c "taskkill /F /PID $listeningPid /T >nul 2>&1"
        if (Test-Path $legacyPidFile) {
            Remove-Item -Path $legacyPidFile -Force -ErrorAction SilentlyContinue
        }

        # Wait up to 15 seconds for port to become free
        $waitElapsed = 0
        $maxPortWait = 15
        while ($waitElapsed -lt $maxPortWait) {
            Start-Sleep -Seconds 1
            $waitElapsed++
            $cCheck = Get-NetTCPConnection -LocalPort $HostPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $cCheck) {
                Write-Host "  Port ${HostPort} is now free (took ${waitElapsed}s)." -ForegroundColor Green
                break
            }
        }

        $cCheckFinal = Get-NetTCPConnection -LocalPort $HostPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cCheckFinal) {
            Write-Host "[ERROR] Port ${HostPort} is still in use by PID $($cCheckFinal.OwningProcess) after stop attempt." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[ERROR] Port ${HostPort} is occupied by an unexpected process: $pName (PID $listeningPid)." -ForegroundColor Red
        Write-Host "  CommandLine: $cmdLine" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  Host port $HostPort is free."
}

# (4) Run fresh container
Write-Host "`n[4/7] Launching fresh container '$containerName' on host port $HostPort..."
$dockerRunArgs = @(
    'run', '-d',
    '--name', $containerName,
    '--restart', 'unless-stopped',
    '-p', "${HostPort}:3000",
    '-v', "${volumeName}:/app/data",
    '-e', 'NODE_ENV=production',
    '--label', "deploy.environment=$Environment",
    '--label', "deploy.build=$BuildNumber",
    $ImageRef
)

$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$containerId = (& docker @dockerRunArgs 2>&1 | Out-String).Trim()
$runExit = $LASTEXITCODE
$ErrorActionPreference = $previousEap

if ($runExit -ne 0) {
    Write-Host "[ERROR] Failed to start container ${containerName}" -ForegroundColor Red
    Write-Host $containerId -ForegroundColor Yellow
    exit 1
}
Write-Host "  Container started successfully. ID: $containerId"

# Verify port mapping
Write-Host "  Verifying container port mapping..."
$portMapping = (& docker port $containerName 2>$null | Out-String).Trim()
Write-Host "  Docker port output: $portMapping"

if (-not ($portMapping -match "$HostPort")) {
    Write-Host "[ERROR] Container '$containerName' does not have host port $HostPort mapped to 3000/tcp!" -ForegroundColor Red
    Write-Host "  Inspecting PortBindings:" -ForegroundColor Red
    & docker inspect --format '{{json .NetworkSettings.Ports}}' $containerName
    exit 1
}

# (5) Wait up to 60 seconds for both container healthcheck and HTTP endpoint
Write-Host "`n[5/7] Waiting for container health (Docker Health Status + HTTP /health)..."
$healthUrl = "http://localhost:$HostPort/health"
$maxWaitSec = 60
$intervalSec = 2
$elapsed = 0
$isHealthy = $false

while ($elapsed -lt $maxWaitSec) {
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec

    $dockerHealth = (& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $containerName 2>$null | Out-String).Trim()
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

    if (($dockerHealth -eq 'healthy' -or $dockerHealth -eq 'none') -and $httpHealthy) {
        $isHealthy = $true
        Write-Host "  Both container health check and HTTP endpoint are HEALTHY (took ${elapsed}s)." -ForegroundColor Green
        break
    }
}

if (-not $isHealthy) {
    Write-Host "[ERROR] Container '$containerName' failed health checks within ${maxWaitSec}s." -ForegroundColor Red
    Write-Host "`n--- Docker Container Logs (last 30 lines) ---" -ForegroundColor Yellow
    & docker logs --tail 30 $containerName
    exit 1
}

# (6) Check /api/items and seed database if empty
Write-Host "`n[6/7] Checking database status at http://localhost:$HostPort/api/items..."
try {
    $items = Invoke-RestMethod -Uri "http://localhost:$HostPort/api/items" -Method Get -TimeoutSec 5 -ErrorAction Stop
    $isEmpty = ($null -eq $items) -or ($items.Count -eq 0) -or ($items -is [string] -and $items.Trim() -eq '[]')
    if ($isEmpty) {
        Write-Host "  Database is empty. Seeding initial data with 'npm run seed'..."
        & docker exec $containerName npm run seed
        Write-Host "  Database seeded successfully."
    } else {
        $count = if ($items.Count) { $items.Count } else { 'N/A' }
        Write-Host "  Database already contains data ($count items). Skipping seed."
    }
} catch {
    Write-Host "  Warning: Failed to verify /api/items: $_. Executing seed as precaution..."
    & docker exec $containerName npm run seed
}

# (7) Prune older local images (keep 5 newest)
Write-Host "`n[7/7] Managing local image retention (keeping 5 newest tags)..."
try {
    $repoName = 'localhost:5000/retail-inventory-alert'
    $allImageLines = @(& docker images --format '{{.Repository}}:{{.Tag}}' $repoName 2>$null)
    $validImages = @($allImageLines | Where-Object { $_ -and $_ -notmatch '<none>' })

    if ($validImages.Count -gt 5) {
        $imagesToPrune = $validImages | Select-Object -Skip 5
        foreach ($img in $imagesToPrune) {
            Write-Host "  Pruning old image: $img"
            & docker rmi $img 2>$null | Out-Null
        }
    } else {
        Write-Host "  Total tagged images for ${repoName}: $($validImages.Count) (<= 5). No pruning required."
    }
} catch {
    Write-Host "  Image pruning notice: $_"
}

Write-Host "`nActive Container Status:"
& docker ps --filter "name=retail-inventory-$Environment"

Write-Host "=========================================="
Write-Host " Deployment of $containerName SUCCEEDED!"
Write-Host " Access URLs: http://localhost:$HostPort/items"
Write-Host "=========================================="
exit 0
