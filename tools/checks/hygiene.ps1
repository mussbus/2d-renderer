[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$roots = @('src', 'tests', 'assets', 'build', 'tools')
$sourceFiles = @(
    foreach ($root in $roots) {
        Get-ChildItem -File -Recurse -LiteralPath (Join-Path $repositoryRoot $root) -ErrorAction Stop |
            Where-Object { $_.Extension -in @('.zig', '.hlsl', '.ps1', '.json') }
    }
)
$sourceFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'build.zig')
$sourceFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'build.zig.zon')

$forbiddenPatterns = @(
    ('SDL_' + 'Renderer'),
    ('SDL_' + 'RenderTexture'),
    ('SDL_' + 'RenderGeometry'),
    ('Open' + 'GL'),
    ('ray' + 'lib'),
    ('S' + 'FML')
)
$unfinishedPatterns = @(
    ('TO' + 'DO'),
    ('FIX' + 'ME'),
    ('st' + 'ub'),
    ('place' + 'holder'),
    ('Skip' + 'ZigTest'),
    ('testing.' + 'skip')
)

$failed = $false
foreach ($pattern in $forbiddenPatterns) {
    foreach ($match in @(Select-String -LiteralPath $sourceFiles.FullName -SimpleMatch -CaseSensitive -Pattern $pattern)) {
        Write-Error "Forbidden source symbol '$pattern' at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($pattern in $unfinishedPatterns) {
    foreach ($match in @(Select-String -LiteralPath $sourceFiles.FullName -SimpleMatch -CaseSensitive:$false -Pattern $pattern)) {
        Write-Error "Unfinished source marker '$pattern' at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
        $failed = $true
    }
}

$zigFiles = @($sourceFiles | Where-Object { $_.Extension -eq '.zig' })
$unreachablePattern = '(?m)(^\s*|[=(:,]\s*)un' + 'reachable\b'
foreach ($match in @(Select-String -LiteralPath $zigFiles.FullName -CaseSensitive -Pattern $unreachablePattern)) {
    Write-Error "Unfinished Zig keyword at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
    $failed = $true
}

$generatedJunk = @(
    foreach ($root in @('src', 'tests', 'build', 'tools')) {
        Get-ChildItem -File -Recurse -LiteralPath (Join-Path $repositoryRoot $root) -ErrorAction Stop |
            Where-Object { $_.Name -match '\.(tmp|bak|orig|rej)$' }
    }
)
foreach ($file in $generatedJunk) {
    Write-Error "Generated/editor artifact is present in an implementation tree: $($file.FullName)." -ErrorAction Continue
    $failed = $true
}

if ($failed) {
    exit 1
}
Write-Host "Repository hygiene passed for $($sourceFiles.Count) implementation and policy files."
exit 0
