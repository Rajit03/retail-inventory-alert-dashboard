[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('teardown', 'provision', 'deploy', 'healthcheck', 'rollback')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseId,

    [Parameter(Mandatory = $false)]
    [string]$PackagePath,

    [Parameter(Mandatory = $false)]
    [string]$TargetRelease,

    [Parameter(Mandatory = $false)]
    [string]$LogFile
)

$Distro = "Ubuntu-Retail"
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))

# Resolve WSL paths dynamically
$WslRepoRoot = (& wsl.exe -d $Distro -- wslpath -a -u "$($RepoRoot.Replace('\', '/'))" 2>$null).Trim()
$WslAnsibleDir = "$WslRepoRoot/ansible"

# Query Ansible version
$AnsibleVersion = (& wsl.exe -d $Distro -- bash -lc "ansible --version | head -n 1" 2>$null).Trim()
$CurrentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$PlaybookCmd = ""

switch ($Action) {
    'teardown' {
        $PlaybookCmd = "ansible-playbook teardown.yml -e confirm_teardown=yes"
    }
    'provision' {
        $PlaybookCmd = "ansible-playbook site.yml"
    }
    'deploy' {
        if (-not $PackagePath) {
            Write-Host "Creating package with npm pack in $RepoRoot..."
            Push-Location $RepoRoot
            try {
                & npm.cmd pack
                if ($LASTEXITCODE -ne 0) {
                    npm pack
                }
            } finally {
                Pop-Location
            }
            $NewestTgz = Get-ChildItem -Path $RepoRoot -Filter "*.tgz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $NewestTgz) {
                Write-Error "No .tgz package found in $RepoRoot after npm pack."
                exit 1
            }
            $PackagePath = $NewestTgz.FullName
        } else {
            if (-not [System.IO.Path]::IsPathRooted($PackagePath)) {
                $PackagePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PackagePath))
            }
        }

        $WslPackagePath = (& wsl.exe -d $Distro -- wslpath -a -u "$($PackagePath.Replace('\', '/'))" 2>$null).Trim()

        if (-not $ReleaseId) {
            $ReleaseId = "rel-$(Get-Date -Format 'yyyyMMddHHmmss')"
        }

        $PlaybookCmd = "ansible-playbook deploy.yml -e release_id=$ReleaseId -e release_package='$WslPackagePath'"
    }
    'healthcheck' {
        $PlaybookCmd = "ansible-playbook healthcheck.yml"
    }
    'rollback' {
        if ($TargetRelease) {
            $PlaybookCmd = "ansible-playbook rollback.yml -e target_release=$TargetRelease"
        } else {
            $PlaybookCmd = "ansible-playbook rollback.yml"
        }
    }
}

$FullWslCommand = "cd '$WslAnsibleDir' && export ANSIBLE_CONFIG='$WslAnsibleDir/ansible.cfg' && $PlaybookCmd"
$HeaderLine = "$CurrentDate action=$Action command=$PlaybookCmd ansible=$AnsibleVersion"

if ($LogFile) {
    $ResolvedLogPath = $LogFile
    if (-not [System.IO.Path]::IsPathRooted($LogFile)) {
        $ResolvedLogPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $LogFile))
    }
    $LogDir = [System.IO.Path]::GetDirectoryName($ResolvedLogPath)
    if ($LogDir -and -not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ResolvedLogPath, "$HeaderLine`n`n", [System.Text.Encoding]::UTF8)
}

Write-Host $HeaderLine
Write-Host "Executing in WSL ($Distro): $FullWslCommand"

if ($LogFile) {
    & wsl.exe -d $Distro -- bash -lc "$FullWslCommand" 2>&1 | Tee-Object -FilePath $ResolvedLogPath -Append
    $ExitCode = $LASTEXITCODE
} else {
    & wsl.exe -d $Distro -- bash -lc "$FullWslCommand"
    $ExitCode = $LASTEXITCODE
}

if ($ExitCode -ne 0) {
    Write-Warning "Playbook execution completed with non-zero exit code: $ExitCode"
}
exit $ExitCode
