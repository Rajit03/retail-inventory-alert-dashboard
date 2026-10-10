[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [Parameter(Mandatory = $false)]
    [string]$DeployRoot = 'C:\deploy\retail-inventory',

    [Parameter(Mandatory = $true)]
    [string]$PackagePath,

    [Parameter(Mandatory = $true)]
    [string]$BuildNumber
)

$ErrorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host " Deploying Retail Inventory Alert Dashboard"
Write-Host " Environment  : $Environment"
Write-Host " Port         : $Port"
Write-Host " Deploy Root  : $DeployRoot"
Write-Host " Package Path : $PackagePath"
Write-Host " Build Number : $BuildNumber"
Write-Host "=========================================="

# 1. Validate inputs and package file
if (-not (Test-Path -Path $PackagePath -PathType Leaf)) {
    Write-Error "Package file does not exist at path: $PackagePath"
    exit 1
}

$resolvedPackagePath = (Resolve-Path -Path $PackagePath).Path
$resolvedDeployRoot = [System.IO.Path]::GetFullPath($DeployRoot)

# Define directories
$envDir = Join-Path $resolvedDeployRoot $Environment
$releasesDir = Join-Path $envDir 'releases'
$releaseDir = Join-Path $releasesDir $BuildNumber
$currentDir = Join-Path $envDir 'current'
$sharedDir = Join-Path $envDir 'shared'
$sharedDataDir = Join-Path $sharedDir 'data'
$logsDir = Join-Path $envDir 'logs'
$pidFile = Join-Path $envDir 'app.pid'
$dbFile = Join-Path $sharedDataDir 'inventory.db'
$stdoutLog = Join-Path $logsDir 'app.log'
$stderrLog = Join-Path $logsDir 'err.log'

# 2. Create required directory structure
Write-Host "[1/7] Creating directory structure..."
$dirsToCreate = @($releasesDir, $sharedDataDir, $logsDir)
foreach ($dir in $dirsToCreate) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir"
    }
}
if (Test-Path -Path $releaseDir) {
    Remove-Item -Path $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
Write-Host "  Created: $releaseDir"

# 3. Extract package archive
Write-Host "[2/7] Extracting package into $releaseDir..."
tar -xzf "$resolvedPackagePath" -C "$releaseDir"
$pkgSubdir = Join-Path $releaseDir 'package'
if (Test-Path -Path $pkgSubdir) {
    Get-ChildItem -Path $pkgSubdir -Force | ForEach-Object {
        $dest = Join-Path $releaseDir $_.Name
        if (Test-Path -Path $dest) {
            Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
        Move-Item -Path $_.FullName -Destination $releaseDir -Force
    }
    Remove-Item -Path $pkgSubdir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  Extracted files to release folder."

# 4. Install production dependencies
Write-Host "[3/7] Installing production dependencies in release folder..."
$targetLock = Join-Path $releaseDir 'package-lock.json'
if (-not (Test-Path -Path $targetLock)) {
    $candidates = @(
        (Join-Path (Split-Path -Parent $resolvedPackagePath) 'package-lock.json'),
        (Join-Path $PSScriptRoot '..\package-lock.json'),
        (Join-Path (Get-Location) 'package-lock.json')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -Path $c)) {
            Copy-Item -Path $c -Destination $targetLock -Force
            Write-Host "  Found and copied package-lock.json to release directory."
            break
        }
    }
}
Push-Location $releaseDir
try {
    cmd /c "npm ci --omit=dev --ignore-scripts"
    if ($LASTEXITCODE -ne 0) {
        throw "npm ci --omit=dev failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}
Write-Host "  Production dependencies installed successfully."

# 5. Stop previous Node process if running
Write-Host "[4/7] Stopping previous application process if active..."
if (Test-Path -Path $pidFile) {
    try {
        $oldPidContent = (Get-Content -Path $pidFile -Raw).Trim()
        if ($oldPidContent -match '^\d+$') {
            $oldPid = [int]$oldPidContent
            Write-Host "  Stopping previous process tree (PID: $oldPid)..."
            cmd /c "taskkill /F /PID $oldPid /T 2>nul" | Out-Null
            Start-Sleep -Seconds 1
            Write-Host "  Previous process stopped."
        }
    } catch {
        Write-Host "  Note: Could not stop existing process: $_"
    }
    Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  No active pid file found."
}

# 6. Update 'current' junction
Write-Host "[5/7] Updating 'current' junction to release $BuildNumber..."
if (Test-Path -Path $currentDir) {
    cmd /c "rmdir `"$currentDir`"" 2>&1 | Out-Null
    if (Test-Path -Path $currentDir) {
        Remove-Item -Path $currentDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}
New-Item -ItemType Junction -Path $currentDir -Target $releaseDir | Out-Null
Write-Host "  Junction created: $currentDir -> $releaseDir"

# Seed database if it does not exist yet
if (-not (Test-Path -Path $dbFile)) {
    Write-Host "  Database not found at $dbFile. Seeding database..."
    Push-Location $currentDir
    try {
        $env:PORT = "$Port"
        $env:NODE_ENV = "production"
        $env:DB_PATH = "$dbFile"
        cmd /c "npm run seed"
        if ($LASTEXITCODE -ne 0) {
            throw "Database seed failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
    Write-Host "  Database seeded successfully."
} else {
    Write-Host "  Existing database found at $dbFile."
}

# 7. Start the Node.js application process
Write-Host "[6/7] Starting Node.js server on port $Port..."
$env:PORT = "$Port"
$env:NODE_ENV = "production"
$env:DB_PATH = "$dbFile"

# Launch detached process with file redirection
$cmdArgs = "/c node src\server.js 1>> `"$stdoutLog`" 2>> `"$stderrLog`""
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = $cmdArgs
$psi.WorkingDirectory = $currentDir
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.EnvironmentVariables["PORT"] = "$Port"
$psi.EnvironmentVariables["NODE_ENV"] = "production"
$psi.EnvironmentVariables["DB_PATH"] = "$dbFile"

$proc = [System.Diagnostics.Process]::Start($psi)
Set-Content -Path $pidFile -Value $proc.Id
Write-Host "  Application started with PID: $($proc.Id)"
Write-Host "  Logs: $stdoutLog | $stderrLog"

# 8. Health check polling
Write-Host "[7/7] Verifying health at http://localhost:$Port/health..."
$healthUrl = "http://localhost:$Port/health"
$maxWaitSec = 30
$intervalSec = 2
$elapsed = 0
$isHealthy = $false

while ($elapsed -lt $maxWaitSec) {
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec
    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 2 -ErrorAction Stop
        if ($resp.status -eq "UP" -or ($resp -is [string] -and $resp -match '"status"\s*:\s*"UP"')) {
            $isHealthy = $true
            Write-Host "  Health check SUCCESS after ${elapsed}s: status = UP"
            break
        }
    } catch {
        Write-Host "  Health check retry (${elapsed}s/${maxWaitSec}s)..."
    }
}

if (-not $isHealthy) {
    Write-Host "  [ERROR] Health check failed after $maxWaitSec seconds!" -ForegroundColor Red
    if (Test-Path -Path $stderrLog) {
        Write-Host "`n--- Last 20 lines of err.log ---" -ForegroundColor Red
        Get-Content -Path $stderrLog -Tail 20
    }
    exit 1
}

# Clean up old releases: keep 3 newest, delete older ones
Write-Host "Cleaning up old releases (keeping latest 3)..."
$allReleases = Get-ChildItem -Path $releasesDir -Directory | Sort-Object {
    $num = 0
    if ([int]::TryParse($_.Name, [ref]$num)) { $num } else { $_.CreationTime.Ticks }
} -Descending

if ($allReleases.Count -gt 3) {
    $releasesToDelete = $allReleases | Select-Object -Skip 3
    foreach ($rel in $releasesToDelete) {
        Write-Host "  Removing old release: $($rel.FullName)"
        Remove-Item -Path $rel.FullName -Recurse -Force
    }
} else {
    Write-Host "  Total releases: $($allReleases.Count). No old releases to prune."
}

Write-Host "`nDeployment completed successfully for $Environment on port $Port (Build: $BuildNumber)"
exit 0
