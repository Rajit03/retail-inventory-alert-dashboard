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
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path

# Resolve WSL paths
$WslRepoRoot = (wsl -d $Distro -- wslpath -a -u "$($RepoRoot.Replace('\', '/'))").Trim()
$WslAnsibleDir = "$WslRepoRoot/ansible"

# Query Ansible version
$AnsibleVersion = (wsl -d $Distro -- bash -lc "ansible --version | head -n 1").Trim()
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
            Write-Host "Creating package with npm pack..."
            Push-Location $RepoRoot
            try {
                npm pack
            } finally {
                Pop-Location
            }
            $NewestTgz = Get-ChildItem -Path $RepoRoot -Filter "*.tgz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $NewestTgz) {
                Write-Error "No .tgz package found in $RepoRoot after npm pack."
                exit 1
            }
            $PackagePath = $NewestTgz.FullName
        }

        $WslPackagePath = (wsl -d $Distro -- wslpath -a -u "$($PackagePath.Replace('\', '/'))").Trim()

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

$FullWslCommand = "cd $WslAnsibleDir && export ANSIBLE_CONFIG=$WslAnsibleDir/ansible.cfg && $PlaybookCmd"
$HeaderLine = "$CurrentDate action=$Action command=$PlaybookCmd ansible=$AnsibleVersion"

if ($LogFile) {
    $ResolvedLogPath = $LogFile
    if (-not [System.IO.Path]::IsPathRooted($LogFile)) {
        $ResolvedLogPath = Join-Path $RepoRoot $LogFile
    }
    $LogDir = [System.IO.Path]::GetDirectoryName($ResolvedLogPath)
    if ($LogDir -and -not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ResolvedLogPath, "$HeaderLine`n`n", [System.Text.Encoding]::UTF8)
}

Write-Host $HeaderLine
Write-Host "Executing in WSL ($Distro): $FullWslCommand"

$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = "wsl.exe"
$ProcessInfo.Arguments = "-d $Distro -- bash -lc `"$FullWslCommand`""
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.RedirectStandardError = $true
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.CreateNoWindow = $true

$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo

$Process.add_OutputDataReceived({
    param($sender, $e)
    if ($null -ne $e.Data) {
        [Console]::Out.WriteLine($e.Data)
        if ($LogFile) {
            [System.IO.File]::AppendAllText($ResolvedLogPath, $e.Data + "`n", [System.Text.Encoding]::UTF8)
        }
    }
})

$Process.add_ErrorDataReceived({
    param($sender, $e)
    if ($null -ne $e.Data) {
        [Console]::Error.WriteLine($e.Data)
        if ($LogFile) {
            [System.IO.File]::AppendAllText($ResolvedLogPath, $e.Data + "`n", [System.Text.Encoding]::UTF8)
        }
    }
})

$Process.Start() | Out-Null
$Process.BeginOutputReadLine()
$Process.BeginErrorReadLine()
$Process.WaitForExit()

$ExitCode = $Process.ExitCode
if ($ExitCode -ne 0) {
    Write-Warning "Playbook execution failed with exit code $ExitCode"
}
exit $ExitCode
