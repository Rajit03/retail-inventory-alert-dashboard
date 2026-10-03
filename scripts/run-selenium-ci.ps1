[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port = 3100
)

$ErrorActionPreference = 'Continue'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Ensure Node, npm, Maven and Git are on PATH (especially when running under Jenkins service)
$toolPaths = @(
    'C:\nvm4w\nodejs',
    'C:\Program Files\nodejs',
    'C:\DevTools\apache-maven-3.9.16\bin',
    'C:\Program Files\Git\bin',
    'C:\Program Files\Git\cmd'
)
foreach ($p in $toolPaths) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
        $env:PATH = "$p;$env:PATH"
    }
}

Write-Host "=========================================="
Write-Host " Running Selenium Test Suite in CI"
Write-Host " Port           : $Port"
Write-Host " Workspace Root : $workspaceRoot"
Write-Host "=========================================="

# 1. Stop any process already listening on target port
$conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $pids = $conn.OwningProcess | Select-Object -Unique
    foreach ($p in $pids) {
        if ($p -and $p -ne 0) {
            Write-Host "Stopping existing process on port $Port (PID: $p)..."
            cmd /c "taskkill /F /PID $p /T 2>nul" | Out-Null
        }
    }
    Start-Sleep -Seconds 1
}

# 2. Configure environment and seed database
$dataDir = Join-Path $workspaceRoot 'data'
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$testDb = Join-Path $dataDir 'selenium-ci.db'
if (Test-Path $testDb) {
    Remove-Item -Force $testDb -ErrorAction SilentlyContinue
}

$env:PORT = "$Port"
$env:NODE_ENV = 'test'
$env:DB_PATH = "$testDb"

Write-Host "Seeding test database at $testDb..."
Push-Location $workspaceRoot
try {
    cmd /c "npm run seed"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Database seed failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

# 3. Create target directory and prepare logs
$targetDir = Join-Path $workspaceRoot 'tests\selenium\target'
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$stdoutLog = Join-Path $targetDir 'ci-app.log'
$stderrLog = Join-Path $targetDir 'ci-app-err.log'
if (Test-Path $stdoutLog) { Remove-Item -Force $stdoutLog -ErrorAction SilentlyContinue }
if (Test-Path $stderrLog) { Remove-Item -Force $stderrLog -ErrorAction SilentlyContinue }

# 4. Start the app in the background
$serverScript = Join-Path $workspaceRoot 'src\server.js'
Write-Host "Starting application server on port $Port..."
$appProc = Start-Process -FilePath "node" `
    -ArgumentList "`"$serverScript`"" `
    -WorkingDirectory $workspaceRoot `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru `
    -WindowStyle Hidden

Write-Host "Application started (PID: $($appProc.Id))"

# 5. Poll health endpoint
Write-Host "Verifying application health at http://localhost:$Port/health..."
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
            Write-Host "Application is healthy (UP) on port $Port after ${elapsed}s."
            break
        }
    } catch {
        # continue polling
    }
}

if (-not $isHealthy) {
    Write-Host "[ERROR] Application health check failed after ${maxWaitSec}s!" -ForegroundColor Red
    if (Test-Path $stderrLog) {
        Write-Host "`n--- Last 20 lines of ci-app-err.log ---" -ForegroundColor Red
        Get-Content -Path $stderrLog -Tail 20
    }
    if ($appProc -and -not $appProc.HasExited) {
        cmd /c "taskkill /PID $($appProc.Id) /T /F 2>nul" | Out-Null
    }
    if (Test-Path $testDb) {
        Remove-Item -Force $testDb -ErrorAction SilentlyContinue
    }
    exit 1
}

# 6. Ensure Java 17+ environment for Maven if available
if (-not $env:JAVA_HOME -or $env:JAVA_HOME -like "*jdk-11*") {
    $jdkCandidates = @(
        'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot',
        'C:\Program Files\Java\jdk-21',
        'C:\Program Files\Java\jdk-17'
    )
    foreach ($cand in $jdkCandidates) {
        if (Test-Path $cand) {
            $env:JAVA_HOME = $cand
            break
        }
    }
}

# 7. Run tests inside try/finally and build report
$testExitCode = 0
try {
    Write-Host "Running Maven Selenium tests..."
    Push-Location $workspaceRoot
    try {
        cmd /c "mvn -B -f tests/selenium/pom.xml test `"-Dbase.url=http://localhost:$Port`" -Dheadless=true"
        $testExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    Write-Host "Building Surefire HTML report..."
    Push-Location $workspaceRoot
    try {
        cmd /c "mvn -B -f tests/selenium/pom.xml surefire-report:report-only"
    } catch {
        Write-Host "Surefire report generation failed: $_"
    } finally {
        Pop-Location
    }
} finally {
    Write-Host "Stopping application process tree (PID: $($appProc.Id))..."
    if ($appProc -and -not $appProc.HasExited) {
        cmd /c "taskkill /PID $($appProc.Id) /T /F 2>nul" | Out-Null
    } else {
        cmd /c "taskkill /PID $($appProc.Id) /T /F 2>nul" | Out-Null
    }

    if (Test-Path $testDb) {
        Write-Host "Deleting test database: $testDb"
        Remove-Item -Force $testDb -ErrorAction SilentlyContinue
    }
}

Write-Host "Selenium CI run finished with exit code: $testExitCode"
exit $testExitCode
