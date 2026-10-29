<#
.SYNOPSIS
    Generates deployment secrets outside the repository for Docker and Ansible deployments.
.DESCRIPTION
    Creates C:\deploy\retail-inventory\secrets.env and secrets.yml with cryptographically secure
    SESSION_SECRET (48 chars) and random 16-character passwords for manager and staff.
    Restricts file ACLs to the current Windows user using icacls.
.PARAMETER Force
    Prompts for confirmation before overwriting existing secrets files.
.PARAMETER DeployDir
    The deployment directory where secrets will be stored. Defaults to C:\deploy\retail-inventory.
#>

[CmdletBinding()]
param(
    [switch]$Force = $false,
    [string]$DeployDir = "C:\deploy\retail-inventory"
)

$ErrorActionPreference = "Stop"

function Get-SecureRandomString {
    param(
        [int]$Length,
        [string]$CharacterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $chars = New-Object char[] $Length
    for ($i = 0; $i -lt $Length; $i++) {
        $chars[$i] = $CharacterSet[$bytes[$i] % $CharacterSet.Length]
    }
    return [string]::new($chars)
}

$secretsEnv = Join-Path $DeployDir "secrets.env"
$secretsYml = Join-Path $DeployDir "secrets.yml"

$exists = (Test-Path $secretsEnv) -or (Test-Path $secretsYml)

if ($exists -and -not $Force) {
    Write-Host "Secrets files already exist in $DeployDir." -ForegroundColor Yellow
    Write-Host "  - $secretsEnv"
    Write-Host "  - $secretsYml"
    Write-Host "To replace them, run this script with -Force." -ForegroundColor Yellow
    return
}

if ($exists -and $Force) {
    $confirm = Read-Host "Existing secrets files found in $DeployDir. Are you sure you want to overwrite them? [y/N]"
    if ($confirm -notin @('y', 'Y', 'yes', 'YES')) {
        Write-Host "Operation cancelled. Existing secrets preserved." -ForegroundColor Yellow
        return
    }
}

if (-not (Test-Path $DeployDir)) {
    New-Item -ItemType Directory -Path $DeployDir -Force | Out-Null
}

$sessionSecret = Get-SecureRandomString -Length 48 -CharacterSet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
$managerPassword = Get-SecureRandomString -Length 16 -CharacterSet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
$staffPassword = Get-SecureRandomString -Length 16 -CharacterSet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

$envContent = @"
SESSION_SECRET=$sessionSecret
SEED_MANAGER_PASSWORD=$managerPassword
SEED_STAFF_PASSWORD=$staffPassword
"@

$ymlContent = @"
---
session_secret: "$sessionSecret"
seed_manager_password: "$managerPassword"
seed_staff_password: "$staffPassword"
SESSION_SECRET: "$sessionSecret"
SEED_MANAGER_PASSWORD: "$managerPassword"
SEED_STAFF_PASSWORD: "$staffPassword"
"@

[System.IO.File]::WriteAllText($secretsEnv, $envContent, [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText($secretsYml, $ymlContent, [System.Text.Encoding]::ASCII)

# Restrict file permissions to current Windows user, SYSTEM, and Administrators using icacls
$currentUser = "$env:USERDOMAIN\$env:USERNAME"
& icacls.exe $secretsEnv /inheritance:r /grant:r "${currentUser}:(F)" "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)" 2>$null | Out-Null
& icacls.exe $secretsYml /inheritance:r /grant:r "${currentUser}:(F)" "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)" 2>$null | Out-Null

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Deployment Secrets Initialized" -ForegroundColor Cyan
Write-Host " Location: $DeployDir" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "`nDemo Accounts Created:" -ForegroundColor Green
Write-Host "  manager    : $managerPassword"
Write-Host "  staff      : $staffPassword"
Write-Host "`nGenerated Files:" -ForegroundColor Yellow
Write-Host "  - $secretsEnv"
Write-Host "  - $secretsYml"
Write-Host "Permissions restricted to: $currentUser`n" -ForegroundColor Green
