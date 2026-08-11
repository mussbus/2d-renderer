[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ImagesDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$r1Source = 'e501458b9cf78991aa4290bcecd81ebcc5cb112d4c735c2a9e0a381653766623'
$hm08Source = 'bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950'
$names = @('whole', 'head', 'shoulder', 'hand', 'pelvis', 'knee', 'ankle', 'foot')
$panelWidth = 900
$panelHeight = 900
$headerHeight = 104

foreach ($name in $names) {
    $leftPath = Join-Path $ImagesDirectory "panel_r1_$name.png"
    $rightPath = Join-Path $ImagesDirectory "panel_hm08_$name.png"
    $outputPath = Join-Path $ImagesDirectory "compare_r1_vs_hm08_$name.png"
    if (-not (Test-Path -LiteralPath $leftPath -PathType Leaf) -or -not (Test-Path -LiteralPath $rightPath -PathType Leaf)) {
        throw "Missing comparison panel for '$name'."
    }
    $left = [System.Drawing.Image]::FromFile($leftPath)
    $right = [System.Drawing.Image]::FromFile($rightPath)
    try {
        $bitmap = [System.Drawing.Bitmap]::new($panelWidth * 2, $panelHeight + $headerHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(29, 29, 34))
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($left, 0, $headerHeight, $panelWidth, $panelHeight)
            $graphics.DrawImage($right, $panelWidth, $headerHeight, $panelWidth, $panelHeight)
            $titleFont = [System.Drawing.Font]::new('Arial', 22, [System.Drawing.FontStyle]::Bold)
            $metaFont = [System.Drawing.Font]::new('Consolas', 11, [System.Drawing.FontStyle]::Regular)
            $white = [System.Drawing.Brushes]::White
            $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(194, 200, 210))
            try {
                $graphics.DrawString("R1 — $name", $titleFont, $white, 20, 12)
                $graphics.DrawString("hm08 — $name", $titleFont, $white, $panelWidth + 20, 12)
                $graphics.DrawString("R1 G=$($r1Source.Substring(0,16))…", $metaFont, $muted, 20, 56)
                $graphics.DrawString("hm08 A=$($hm08Source.Substring(0,16))…", $metaFont, $muted, $panelWidth + 20, 56)
                $graphics.DrawString('Derived qualification comparison; neither panel changes canonical authority.', $metaFont, $muted, 20, 79)
            }
            finally {
                $titleFont.Dispose()
                $metaFont.Dispose()
                $muted.Dispose()
            }
            $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
    finally {
        $left.Dispose()
        $right.Dispose()
    }
}

Write-Host "HM08_COMPARISON_COMPOSITION_PASS count=$($names.Count)"
