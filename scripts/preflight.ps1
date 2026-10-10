<#
.SYNOPSIS
    Preflight verification script for the demo and CI environment.
.DESCRIPTION
    Checks Docker engine, registry, Jenkins, WSL Ubuntu-Retail node, Nginx, Node app,
    container port mapping, process ownership on port 3001, and port listening states.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$hasFailures = $false
$results = [System.Collections.Generic.List[PSObject]]::new()

function Add-CheckResult {
    param(
        [string]$Component,
        [string]$Status, # PASS, WARN, FAIL, INFO
        [string]$Details
    )
    if ($Status -eq "FAIL") {
        $script:hasFailures = $true
    }
    $script:results.Add([PSCustomObject]@{
        Component = $Component
        Status    = $Status
        Details   = $Details
    })
}

# 1. Docker Engine
try {
    $dockerVer = & docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $dockerVer) {
        Add-CheckResult -Component "Docker Engine" -Status "PASS" -Details "Engine running (v$($dockerVer.Trim()))"
    } else {
        Add-CheckResult -Component "Docker Engine" -Status "FAIL" -Details "Docker engine is unreachable"
    }
} catch {
    Add-CheckResult -Component "Docker Engine" -Status "FAIL" -Details "Docker check exception: $($_.Exception.Message)"
}

# 2. Local Docker Registry (localhost:5000)
try {
    $regContainer = & docker ps --filter "name=^/registry$" --format '{{.Names}} ({{.Status}})' 2>$null
    $regHttp = & curl.exe -s -o /dev/null -w "%{http_code}" http://localhost:5000/v2/ 2>$null
    if ($regHttp -eq "200" -or $regHttp -eq "401") {
        Add-CheckResult -Component "Docker Registry" -Status "PASS" -Details "Registry answering on :5000 (HTTP $regHttp, $regContainer)"
    } else {
        Add-CheckResult -Component "Docker Registry" -Status "FAIL" -Details "Registry unavailable on http://localhost:5000/v2/ (HTTP '$regHttp')"
    }
} catch {
    Add-CheckResult -Component "Docker Registry" -Status "FAIL" -Details "Registry check exception: $($_.Exception.Message)"
}

# 3. Jenkins Service (localhost:8080)
try {
    $jenkinsHttp = & curl.exe -s -o /dev/null -w "%{http_code}" http://localhost:8080/login 2>$null
    if ($jenkinsHttp -and $jenkinsHttp -ne "000") {
        Add-CheckResult -Component "Jenkins CI" -Status "PASS" -Details "Jenkins responsive at http://localhost:8080/login (HTTP $jenkinsHttp)"
    } else {
        Add-CheckResult -Component "Jenkins CI" -Status "FAIL" -Details "Jenkins unreachable at http://localhost:8080/login"
    }
} catch {
    Add-CheckResult -Component "Jenkins CI" -Status "FAIL" -Details "Jenkins check exception: $($_.Exception.Message)"
}

# 4. WSL Ubuntu-Retail Distribution
try {
    $wslEcho = & wsl.exe -d Ubuntu-Retail -- echo ok 2>$null
    if ($LASTEXITCODE -eq 0 -and $wslEcho.Trim() -eq "ok") {
        Add-CheckResult -Component "WSL Distribution" -Status "PASS" -Details "Ubuntu-Retail reachable and functional"
    } else {
        Add-CheckResult -Component "WSL Distribution" -Status "FAIL" -Details "Ubuntu-Retail WSL distribution did not respond with 'ok'"
    }
} catch {
    Add-CheckResult -Component "WSL Distribution" -Status "FAIL" -Details "WSL check exception: $($_.Exception.Message)"
}

# 5. Ubuntu-Retail Services (nginx & retail-inventory)
try {
    $svcNginx = (& wsl.exe -d Ubuntu-Retail -- systemctl is-active nginx 2>$null).Trim()
    $svcApp = (& wsl.exe -d Ubuntu-Retail -- systemctl is-active retail-inventory 2>$null).Trim()
    if ($svcNginx -eq "active" -and $svcApp -eq "active") {
        Add-CheckResult -Component "WSL Services" -Status "PASS" -Details "nginx ($svcNginx), retail-inventory ($svcApp)"
    } else {
        Add-CheckResult -Component "WSL Services" -Status "FAIL" -Details "Services not active: nginx ($svcNginx), retail-inventory ($svcApp)"
    }
} catch {
    Add-CheckResult -Component "WSL Services" -Status "FAIL" -Details "WSL services check exception: $($_.Exception.Message)"
}

# 6. WSL Ansible Target Health (port 8300)
try {
    $wslHealth = (& wsl.exe -d Ubuntu-Retail -- curl -s http://127.0.0.1:8300/health 2>$null).Trim()
    if ($wslHealth -match '"status"\s*:\s*"UP"') {
        Add-CheckResult -Component "WSL App Health" -Status "PASS" -Details "http://localhost:8300/health returns UP"
    } else {
        Add-CheckResult -Component "WSL App Health" -Status "FAIL" -Details "WSL health check failed (response: '$wslHealth')"
    }
} catch {
    Add-CheckResult -Component "WSL App Health" -Status "FAIL" -Details "WSL app health exception: $($_.Exception.Message)"
}

# 7. Container retail-inventory-dev Status & Port Mapping
try {
    $devStatus = (& docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' retail-inventory-dev 2>$null)
    $devPort = (& docker port retail-inventory-dev 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($devStatus)) {
        Add-CheckResult -Component "Dev Container" -Status "FAIL" -Details "Container 'retail-inventory-dev' is missing or not found"
    } else {
        $parts = $devStatus.Trim().Split('|')
        $state = $parts[0]
        $health = $parts[1]
        
        $hasPort3001 = $false
        if ($devPort -and $devPort -match '3001') {
            $hasPort3001 = $true
        }

        if ($state -eq "running" -and ($health -eq "healthy" -or $health -eq "none")) {
            if ($hasPort3001) {
                Add-CheckResult -Component "Dev Container" -Status "PASS" -Details "Running ($state, health=$health), port: $devPort"
            } else {
                Add-CheckResult -Component "Dev Container" -Status "WARN" -Details "Running ($state) but no published host port 3001 (hint: run the pipeline to recreate the container with its port mapping)"
            }
        } else {
            Add-CheckResult -Component "Dev Container" -Status "FAIL" -Details "Container not healthy: state=$state, health=$health"
        }
    }
} catch {
    Add-CheckResult -Component "Dev Container" -Status "FAIL" -Details "Dev container exception: $($_.Exception.Message)"
}

# 8. Process listening on host port 3001
try {
    $conn3001 = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn3001) {
        $pid3001 = $conn3001.OwningProcess
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pid3001" -ErrorAction SilentlyContinue
        $pName = if ($proc) { $proc.Name } else { "PID $pid3001" }
        $cmdLine = if ($proc -and $proc.CommandLine) { $proc.CommandLine } else { "N/A" }
        
        $isDocker = $pName -match 'com\.docker\.backend|wslrelay|vpnkit|docker-proxy'
        if ($isDocker) {
            Add-CheckResult -Component "Port 3001 Process" -Status "PASS" -Details "Docker backend process ($pName, PID $pid3001)"
        } else {
            Add-CheckResult -Component "Port 3001 Process" -Status "WARN" -Details "Non-Docker process holding port 3001: $pName (PID $pid3001), Cmd: $cmdLine"
        }
    } else {
        Add-CheckResult -Component "Port 3001 Process" -Status "WARN" -Details "No process currently listening on host port 3001"
    }
} catch {
    Add-CheckResult -Component "Port 3001 Process" -Status "WARN" -Details "Could not inspect port 3001 process: $($_.Exception.Message)"
}

# 9. Windows Nginx Dev Proxy (http://localhost:8095/health)
try {
    $nginxDev = & curl.exe -s -o /dev/null -w "%{http_code}" http://localhost:8095/health 2>$null
    if ($nginxDev -eq "200") {
        Add-CheckResult -Component "Windows Nginx (Dev)" -Status "PASS" -Details "http://localhost:8095/health returns HTTP 200"
    } else {
        Add-CheckResult -Component "Windows Nginx (Dev)" -Status "WARN" -Details "http://localhost:8095/health unreachable (HTTP '$nginxDev')"
    }
} catch {
    Add-CheckResult -Component "Windows Nginx (Dev)" -Status "WARN" -Details "Windows Nginx Dev exception: $($_.Exception.Message)"
}

# 10. Staging Environment (Optional: 3002 / 8096)
try {
    $conn3002 = Get-NetTCPConnection -LocalPort 3002 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    $nginxStaging = & curl.exe -s -o /dev/null -w "%{http_code}" http://localhost:8096/health 2>$null
    if ($conn3002 -or $nginxStaging -eq "200") {
        Add-CheckResult -Component "Staging (Optional)" -Status "PASS" -Details "Staging active (Port 3002 listening, Nginx 8096: $nginxStaging)"
    } else {
        Add-CheckResult -Component "Staging (Optional)" -Status "INFO" -Details "Staging environment is not currently deployed (expected/optional)"
    }
} catch {
    Add-CheckResult -Component "Staging (Optional)" -Status "INFO" -Details "Staging check info: $($_.Exception.Message)"
}

# 11. Informational Host Port Listening Statuses
$monitoredPorts = @(3001, 5000, 8080, 8300)
$portSummary = @()
foreach ($p in $monitoredPorts) {
    $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) {
        $portSummary += "$p (LISTEN/PID $($c.OwningProcess))"
    } else {
        # Check if WSL is listening on 8300
        if ($p -eq 8300) {
            $wslListen = (& wsl.exe -d Ubuntu-Retail -- ss -ltn 'sport = :8300' 2>$null) -match '8300'
            if ($wslListen) {
                $portSummary += "8300 (LISTEN in WSL)"
                continue
            }
        }
        $portSummary += "$p (FREE)"
    }
}
Add-CheckResult -Component "Monitored Ports" -Status "INFO" -Details ($portSummary -join ", ")

# Render Output Table
Write-Host ""
Write-Host "================================ PREFLIGHT ENVIRONMENT CHECK ================================" -ForegroundColor Cyan
Write-Host ("{0,-24} | {1,-6} | {2}" -f "COMPONENT", "STATUS", "DETAILS")
Write-Host ("-" * 92)

foreach ($r in $results) {
    $color = switch ($r.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        Default { "Cyan" }
    }
    Write-Host ("{0,-24} | " -f $r.Component) -NoNewline
    Write-Host ("{0,-6}" -f $r.Status) -ForegroundColor $color -NoNewline
    Write-Host (" | {0}" -f $r.Details)
}
Write-Host ("=" * 92)

if ($hasFailures) {
    Write-Host "`nPreflight check failed. Please resolve the FAIL items above.`n" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nPreflight check succeeded (all mandatory services and prerequisites ready).`n" -ForegroundColor Green
    exit 0
}
