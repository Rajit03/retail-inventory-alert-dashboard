<#
.SYNOPSIS
    End-to-end verification script for Docker container, WSL Ansible node, and Nginx reverse proxy.
.DESCRIPTION
    Validates Docker container health and port publishing, Ansible node direct health and items API,
    and Windows Nginx reverse proxy endpoint. Emits an evidence report table to OutputFile.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [int]$HostPort,

    [Parameter(Mandatory = $true)]
    [int]$NginxPort,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseId,

    [Parameter(Mandatory = $false)]
    [string]$ImageTag,

    [Parameter(Mandatory = $false)]
    [string]$GitCommit,

    [Parameter(Mandatory = $false)]
    [string]$BuildNumber,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = 'e2e-verification.txt'
)

$ErrorActionPreference = 'Continue'

if (-not $GitCommit) {
    $GitCommit = try { (& git rev-parse --short HEAD 2>$null).Trim() } catch { 'unknown' }
}
if (-not $BuildNumber) {
    $BuildNumber = '0'
}
if (-not $ReleaseId) {
    $ReleaseId = "b$BuildNumber"
}
if (-not $ImageTag) {
    $ImageTag = 'latest'
}

$containerName = "retail-inventory-$Environment"

Write-Host "=================================================="
Write-Host " Executing End-to-End Verification"
Write-Host " Environment  : $Environment"
Write-Host " Container    : $containerName"
Write-Host " Host Port    : $HostPort"
Write-Host " Nginx Port   : $NginxPort"
Write-Host " Release ID   : $ReleaseId"
Write-Host " Image Tag    : $ImageTag"
Write-Host " Git Commit   : $GitCommit"
Write-Host " Build Number : $BuildNumber"
Write-Host " Output File  : $OutputFile"
Write-Host "=================================================="

$failed = $false
$rows = @()

# 1. Docker Container Health & Published Port
$dockerHealth = (& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $containerName 2>$null | Out-String).Trim()
$cPort = (& docker port $containerName 2>$null | Out-String).Trim()
$cUrl = "http://localhost:$HostPort/health"
$cHttp = try { (Invoke-WebRequest -Uri $cUrl -UseBasicParsing -TimeoutSec 3).Content.Trim() } catch { 'DOWN' }
$cPass = ($dockerHealth -match 'healthy|none' -and $cHttp -match '"status"\s*:\s*"UP"' -and $cPort -match "$HostPort")
if (-not $cPass) {
    $failed = $true
}
$rows += [PSCustomObject]@{
    Component = "Docker Container ($containerName)"
    Target    = "$cUrl (Port $cPort)"
    Result    = if ($cPass) { 'PASS' } else { 'FAIL' }
}

# 2. Ansible Node Direct Health (:8300/health) inside WSL
$wslHealthUrl = 'http://localhost:8300/health'
$wslHealth = (& wsl.exe -d Ubuntu-Retail -- curl -s http://127.0.0.1:8300/health 2>$null).Trim()
$wslHealthPass = ($wslHealth -match '"status"\s*:\s*"UP"')
if (-not $wslHealthPass) {
    $failed = $true
}
$rows += [PSCustomObject]@{
    Component = 'Ansible WSL Node Health'
    Target    = $wslHealthUrl
    Result    = if ($wslHealthPass) { 'PASS' } else { 'FAIL' }
}

# 3. Ansible Node Items API (:8300/api/items) inside WSL
$wslItemsUrl = 'http://localhost:8300/api/items'
$wslItems = (& wsl.exe -d Ubuntu-Retail -- curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8300/api/items 2>$null).Trim()
$wslItemsPass = ($wslItems -eq '200')
if (-not $wslItemsPass) {
    $failed = $true
}
$rows += [PSCustomObject]@{
    Component = 'Ansible WSL Items API'
    Target    = $wslItemsUrl
    Result    = if ($wslItemsPass) { 'PASS' } else { 'FAIL' }
}

# 4. Windows Nginx Reverse Proxy (:8095 or :8096) - WARN only
$winNginxUrl = "http://localhost:$NginxPort/health"
$winNginx = try { (Invoke-WebRequest -Uri $winNginxUrl -UseBasicParsing -TimeoutSec 3).StatusCode } catch { 'UNREACHABLE' }
$winNginxPass = ($winNginx -eq 200)
$rows += [PSCustomObject]@{
    Component = "Windows Nginx Proxy ($NginxPort)"
    Target    = $winNginxUrl
    Result    = if ($winNginxPass) { 'PASS' } else { 'WARN (Unreachable)' }
}

# Format Output Table and evidence file
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
$lines = @(
    '========================================================================================',
    '                       END-TO-END SYSTEM VERIFICATION REPORT',
    '========================================================================================',
    "Build Number : #$BuildNumber",
    "Git Commit   : $GitCommit",
    "Release ID   : $ReleaseId",
    "Docker Image : $ImageTag",
    "Verified At  : $timestamp",
    '----------------------------------------------------------------------------------------',
    ('{0,-32} | {1,-36} | {2}' -f 'COMPONENT', 'TARGET URL / ENDPOINT', 'RESULT'),
    '----------------------------------------------------------------------------------------'
)

foreach ($r in $rows) {
    $lines += ('{0,-32} | {1,-36} | {2}' -f $r.Component, $r.Target, $r.Result)
}
$lines += '========================================================================================'

$resolvedOutputPath = $OutputFile
if (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputFile))
}
$outputDir = [System.IO.Path]::GetDirectoryName($resolvedOutputPath)
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$lines | Out-File -FilePath $resolvedOutputPath -Encoding utf8
Get-Content $resolvedOutputPath

if ($failed) {
    Write-Error "End-to-End verification failed! Docker container or Ansible node is unhealthy."
    exit 1
} else {
    Write-Host "`nEnd-to-End verification SUCCEEDED.`n" -ForegroundColor Green
    exit 0
}
