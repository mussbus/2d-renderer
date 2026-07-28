[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

$requiredFiles = @(
    'docs/project/README.md',
    'docs/project/MASTER_ROADMAP.md',
    'docs/project/CURRENT_STATE.md',
    'docs/project/ARCHITECTURE_MAP.md',
    'docs/project/AUTHORING_CONTRACTS.md',
    'docs/project/WARDROBE_AUDIT.md',
    'docs/project/SCOPE_BOUNDARIES.md',
    'docs/project/KNOWN_GAPS.md',
    'docs/prompts/INDEX.md',
    'docs/prompts/000-022-reconstructed-ledger.md',
    'docs/prompts/exact/README.md',
    'docs/prompts/exact/023-027-roadmap-source.txt',
    'docs/prompts/exact/023-source.txt',
    'docs/prompts/exact/024-source.txt',
    'docs/prompts/exact/024A-source.txt',
    'docs/prompts/exact/025-source.txt',
    'docs/prompts/exact/025A-source.txt',
    'docs/prompts/exact/025B-source.txt',
    'docs/prompts/exact/025C-source.txt',
    'docs/prompts/exact/025D-source.txt',
    'docs/prompts/exact/025E-source.txt',
    'docs/prompts/exact/026-source.txt',
    'docs/prompts/exact/027-source.txt',
    'docs/decisions/README.md',
    'docs/reports/README.md',
    'docs/reports/prompt-implementation-reports/INDEX.md',
    'docs/reports/prompt-implementation-reports/025E-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/README.md',
    'docs/reports/prompt-implementation-reports/exact/023-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/024-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/024A-025-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/025A-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/025B-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/025B-final-visual-gate-report.md',
    'docs/reports/prompt-implementation-reports/exact/025C-implementation-report.md',
    'docs/reports/prompt-implementation-reports/exact/025D-implementation-report.md'
)

$failures = [Collections.Generic.List[string]]::new()
foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        $failures.Add("missing required file: $relativePath")
    }
}

$documentationRoots = @(
    (Join-Path $repositoryRoot 'docs/project'),
    (Join-Path $repositoryRoot 'docs/prompts'),
    (Join-Path $repositoryRoot 'docs/decisions'),
    (Join-Path $repositoryRoot 'docs/reports')
)

$markdownFiles = @(
    Join-Path $repositoryRoot 'README.md'
    Get-ChildItem -LiteralPath $documentationRoots -Recurse -File -Filter '*.md' |
        Where-Object {
            $_.FullName -notlike '*\docs\reports\prompt-implementation-reports\exact\*'
        } |
        ForEach-Object FullName
)

$inboundReferences = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)

foreach ($markdownFile in $markdownFiles) {
    $text = [IO.File]::ReadAllText($markdownFile)
    $matches = [regex]::Matches($text, '(?<!\!)\[[^\]]+\]\((?<target>[^)]+)\)')
    foreach ($match in $matches) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target.StartsWith('<') -and $target.EndsWith('>')) {
            $target = $target.Substring(1, $target.Length - 2)
        }
        if (
            $target.Length -eq 0 -or
            $target.StartsWith('#') -or
            $target -match '^(https?|mailto):'
        ) {
            continue
        }

        $pathOnly = ($target -split '#', 2)[0]
        if ($pathOnly -match '^[A-Za-z]:[\\/]') {
            $failures.Add(
                "absolute local link is not durable: $([IO.Path]::GetRelativePath($repositoryRoot, $markdownFile)) -> $target"
            )
            continue
        }

        $resolved = [IO.Path]::GetFullPath(
            (Join-Path ([IO.Path]::GetDirectoryName($markdownFile)) $pathOnly)
        )
        if (-not $resolved.StartsWith($repositoryRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $failures.Add(
                "link escapes repository: $([IO.Path]::GetRelativePath($repositoryRoot, $markdownFile)) -> $target"
            )
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failures.Add(
                "missing link target: $([IO.Path]::GetRelativePath($repositoryRoot, $markdownFile)) -> $target"
            )
            continue
        }
        if ([IO.Path]::GetExtension($resolved) -eq '.md') {
            [void]$inboundReferences.Add($resolved)
        }
    }
}

$orphanCandidates = Get-ChildItem -LiteralPath $documentationRoots -Recurse -File -Filter '*.md' |
    Where-Object {
        $_.Name -notin @('README.md', 'INDEX.md') -and
        $_.FullName -notlike '*\docs\reports\prompt-implementation-reports\exact\*'
    }
foreach ($candidate in $orphanCandidates) {
    if (-not $inboundReferences.Contains($candidate.FullName)) {
        $failures.Add(
            "orphaned consolidated document: $([IO.Path]::GetRelativePath($repositoryRoot, $candidate.FullName))"
        )
    }
}

$promptIndex = Join-Path $repositoryRoot 'docs/prompts/INDEX.md'
if (Test-Path -LiteralPath $promptIndex) {
    $indexText = [IO.File]::ReadAllText($promptIndex)
    foreach ($prompt in 0..27) {
        if ($indexText -notmatch "(?m)^\| $prompt \|") {
            $failures.Add("prompt index does not identify Prompt $prompt")
        }
    }
    foreach ($suffix in @('24A', '25A', '25B', '25C', '25D', '25E')) {
        if ($indexText -notmatch "(?m)^\| $suffix \|") {
            $failures.Add("prompt index does not identify Prompt $suffix")
        }
    }
}

$wardrobeCatalog = Join-Path $repositoryRoot 'src/scene/wardrobe_catalog.zig'
$wardrobeAudit = Join-Path $repositoryRoot 'docs/project/WARDROBE_AUDIT.md'
if (
    (Test-Path -LiteralPath $wardrobeCatalog -PathType Leaf) -and
    (Test-Path -LiteralPath $wardrobeAudit -PathType Leaf)
) {
    $catalogText = [IO.File]::ReadAllText($wardrobeCatalog)
    $auditText = [IO.File]::ReadAllText($wardrobeAudit)
    $itemMatches = [regex]::Matches($catalogText, 'cosmeticItem\("(?<id>[^"]+)"')
    $itemIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($itemMatch in $itemMatches) {
        [void]$itemIds.Add($itemMatch.Groups['id'].Value)
    }
    if ($itemIds.Count -ne 30) {
        $failures.Add("wardrobe source exposes $($itemIds.Count) logical items; audit expects 30")
    }
    foreach ($itemId in $itemIds) {
        if (-not $auditText.Contains("``$itemId``", [StringComparison]::Ordinal)) {
            $failures.Add("wardrobe audit omits logical item: $itemId")
        }
    }
}

$exactPromptHashes = [ordered]@{
    '023-027-roadmap-source.txt' = '9d8dde03c10c2b9b64e532896a025cac2144c6bf817c76d1b5c2f81874cc9cb8'
    '023-source.txt' = '3deabb54518313869c3e81d91b6b8848c6d156f1a42477b2d1d8c2a1920d97bd'
    '024-source.txt' = '366d96ddf9e43b8c1fb098cc1a6e7598cca47e4d6f5c369c773b49c2ebeb61b0'
    '024A-source.txt' = '42487e8bd09c86d6a693806a361d9c8ce477c8f1bbda4772e3d30b0f4ddc2d7a'
    '025-source.txt' = '4090101f2ce3399dddbe34b406655affc4cd9f79d9c835cae16adeb442c0c39c'
    '025A-source.txt' = '3b88aa15bc68fd5bdedfe3010d55ee72545ee3e859e14d195edd15f04bbc4542'
    '025B-source.txt' = 'fd57b8ed703816503956cd403bf67a5dcb507ffaf6a07593809b9a4be6ab4029'
    '025C-source.txt' = '354d810f85c3b20a9f2ba140b2c9e221ad6eddcf2970a8dde62674a94c3607fe'
    '025D-source.txt' = '8b114d87eb5b3c97c50bbecfd05cdbb7e79a3533d78b74b695f5bf218d05e7fb'
    '025E-source.txt' = '6715311891e09858bbb278d034612e22928d4b4410767a5aa13d6d4066ffd1a5'
    '026-source.txt' = 'e6e19c484fcd79d0ab8eea1030a1aa037c3a569a44abaf31ece3e3a4d5f1a532'
    '027-source.txt' = '66ce11018f66dbf004ad6a5723bad2d6c94fabb6f9b15b93b39ab893a5f610dd'
}
$exactPromptRoot = Join-Path $repositoryRoot 'docs/prompts/exact'
foreach ($hashEntry in $exactPromptHashes.GetEnumerator()) {
    $promptPath = Join-Path $exactPromptRoot $hashEntry.Key
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        continue
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $promptPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $hashEntry.Value) {
        $failures.Add(
            "exact prompt hash mismatch: $($hashEntry.Key) expected=$($hashEntry.Value) actual=$actualHash"
        )
    }
}

$exactReportHashes = [ordered]@{
    '023-implementation-report.md' = '8a153a766f1b2b01bae7316c951fdfed98a3dac44cd19212868b6b1897d4042d'
    '024-implementation-report.md' = '6be2939ede3805c6d94600936ae42adfae494283d2d84bf92df1110b8cc3d6a3'
    '024A-025-implementation-report.md' = '958fdc0ae76c2fe96d0d0f476b109c3da043dfdf05eb9e3430307a6438410575'
    '025A-implementation-report.md' = '87220f1f14a2ef10d7794435c001599c3cdaec734e7fccfadd53a329a4ab5335'
    '025B-implementation-report.md' = 'd41e28914733792216b441e52acdf233a1bb1e18b8f2904979ee779d5624996c'
    '025B-final-visual-gate-report.md' = '37261074658c10abdf2d95a829a746ed2628f39d5cf5bf6dc795f9124333f525'
    '025C-implementation-report.md' = '301feba6f46e4731305ec88d04fa5b815b6e3dcef1822395ac9bce8ec03741bb'
    '025D-implementation-report.md' = 'ce5c11c8a95b53172038e3abdf6728d6979d5fa2650bbf20b7e4ab7c0add9a4a'
}
$exactReportRoot = Join-Path $repositoryRoot 'docs/reports/prompt-implementation-reports/exact'
foreach ($hashEntry in $exactReportHashes.GetEnumerator()) {
    $reportPath = Join-Path $exactReportRoot $hashEntry.Key
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        continue
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $reportPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $hashEntry.Value) {
        $failures.Add(
            "exact report hash mismatch: $($hashEntry.Key) expected=$($hashEntry.Value) actual=$actualHash"
        )
    }
}

if ($failures.Count -ne 0) {
    Write-Error ("documentation audit failed ({0} finding(s)):`n- {1}" -f
        $failures.Count,
        ($failures -join "`n- "))
}

Write-Output (
    'documentation audit PASS: {0} required files, {1} Markdown files, {2} local Markdown targets' -f
    $requiredFiles.Count,
    $markdownFiles.Count,
    $inboundReferences.Count
)
