param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$atlases = @(
    [pscustomobject]@{
        Name = 'violet_crystal_ruin'
        Path = Join-Path $RepositoryRoot 'assets/art/environment_violet_crystal_ruin_atlas.png'
    },
    [pscustomobject]@{
        Name = 'neutral_debug'
        Path = Join-Path $RepositoryRoot 'assets/art/environment_neutral_debug_atlas.png'
    }
)
$regions = @(
    [pscustomobject]@{ Name = 'far_backdrop'; X = 0; Y = 0; W = 1024; H = 512; RequiresTransparency = $false },
    [pscustomobject]@{ Name = 'midground_structure'; X = 0; Y = 512; W = 512; H = 256; RequiresTransparency = $true },
    [pscustomobject]@{ Name = 'terrain_body'; X = 512; Y = 512; W = 512; H = 256; RequiresTransparency = $true },
    [pscustomobject]@{ Name = 'foreground_frame'; X = 0; Y = 768; W = 512; H = 256; RequiresTransparency = $true },
    [pscustomobject]@{ Name = 'decorative_ledge'; X = 512; Y = 768; W = 256; H = 256; RequiresTransparency = $true },
    [pscustomobject]@{ Name = 'accent_cluster'; X = 768; Y = 768; W = 256; H = 256; RequiresTransparency = $true }
)

foreach ($atlas in $atlases) {
    if (-not (Test-Path -LiteralPath $atlas.Path -PathType Leaf)) {
        Write-Error "Prompt 26 production environment atlas is missing: $($atlas.Path)"
        exit 1
    }
    $bitmap = [System.Drawing.Bitmap]::new($atlas.Path)
    try {
        if ($bitmap.Width -ne 1024 -or $bitmap.Height -ne 1024) {
            Write-Error "Prompt 26 atlas $($atlas.Name) must be exactly 1024x1024; found $($bitmap.Width)x$($bitmap.Height)."
            exit 1
        }
        foreach ($region in $regions) {
            $visible = 0
            $transparent = 0
            for ($y = $region.Y; $y -lt $region.Y + $region.H; $y++) {
                for ($x = $region.X; $x -lt $region.X + $region.W; $x++) {
                    if ($bitmap.GetPixel($x, $y).A -eq 0) {
                        $transparent++
                    } else {
                        $visible++
                    }
                }
            }
            if ($visible -eq 0) {
                Write-Error "Prompt 26 atlas $($atlas.Name) region $($region.Name) has no visible alpha."
                exit 1
            }
            if ($region.RequiresTransparency -and $transparent -eq 0) {
                Write-Error "Prompt 26 atlas $($atlas.Name) region $($region.Name) lost its transparent presentation boundary."
                exit 1
            }
        }
        for ($y = 1020; $y -lt 1024; $y++) {
            for ($x = 1020; $x -lt 1024; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -ne 255 -or $pixel.R -ne 255 -or
                    $pixel.G -ne 255 -or $pixel.B -ne 255) {
                    Write-Error "Prompt 26 atlas $($atlas.Name) surface-white region is not opaque white at ($x,$y)."
                    exit 1
                }
            }
        }
    } finally {
        $bitmap.Dispose()
    }
}

$hashes = $atlases | ForEach-Object {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $_.Path
    "$($_.Name)=$($hash.Hash.ToLowerInvariant())"
}
Write-Host "Prompt 26 environment art audit passed: 2 RGBA atlases, 6 layered regions each, alpha boundaries, and exact opaque-white surface sources."
$hashes | ForEach-Object { Write-Host $_ }
