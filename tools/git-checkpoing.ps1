[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Message,

    [switch] $NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $GitArgs
    )

    & git @GitArgs

    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE."
    }
}

$repoRoot = & git rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Run this script from inside a Git repository.'
}

Push-Location -LiteralPath $repoRoot.Trim()

try {
    Write-Host 'Repository status before staging:'
    Invoke-Git -GitArgs @('status', '--short', '--branch')

    Invoke-Git -GitArgs @('add', '-A')
    Invoke-Git -GitArgs @('diff', '--cached', '--check')

    & git diff --cached --quiet
    $diffExitCode = $LASTEXITCODE

    if ($diffExitCode -eq 0) {
        Write-Host 'No staged changes; nothing to commit.'
        return
    }

    if ($diffExitCode -ne 1) {
        throw "git diff --cached --quiet failed with exit code $diffExitCode."
    }

    Write-Host 'Staged change summary:'
    Invoke-Git -GitArgs @('diff', '--cached', '--stat')

    Invoke-Git -GitArgs @('commit', '-m', $Message)

    if (-not $NoPush) {
        $branch = (& git branch --show-current).Trim()

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
            throw 'Cannot push because the repository is in detached-HEAD state.'
        }

        & git rev-parse `
            --abbrev-ref `
            --symbolic-full-name `
            '@{u}' 2>$null | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Invoke-Git -GitArgs @('push')
        }
        else {
            Invoke-Git -GitArgs @('push', '-u', 'origin', $branch)
        }
    }

    Write-Host 'Repository status after checkpoint:'
    Invoke-Git -GitArgs @('status', '--short', '--branch')

    $commitSha = (& git rev-parse HEAD).Trim()
    Write-Host "Checkpoint commit: $commitSha"
}
finally {
    Pop-Location
}