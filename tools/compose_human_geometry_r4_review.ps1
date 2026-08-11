[CmdletBinding()]
param(
    [string]$EvidenceDirectory = 'assets/canonical_model/human_base/geometry/evidence/prompt_2c_r4_final_neutral',
    [string]$R3EvidenceDirectory = 'assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $EvidenceDirectory))
$imageRoot = Join-Path $evidenceRoot 'images'
$sheetRoot = Join-Path $evidenceRoot 'mobile_sheets'
$comparisonRoot = Join-Path $evidenceRoot 'comparisons'
$r3ImageRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot (Join-Path $R3EvidenceDirectory 'images')))
New-Item -ItemType Directory -Force -Path $sheetRoot, $comparisonRoot | Out-Null

$authority = '4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f'
$geometry = 'd7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096'
$topology = '335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191'

function Draw-ContainedImage {
    param([System.Drawing.Graphics]$Graphics, [System.Drawing.Image]$Image, [System.Drawing.RectangleF]$Bounds)
    $scale = [Math]::Min($Bounds.Width / $Image.Width, $Bounds.Height / $Image.Height)
    $width = [single]($Image.Width * $scale)
    $height = [single]($Image.Height * $scale)
    $x = [single]($Bounds.X + ($Bounds.Width - $width) / 2.0)
    $y = [single]($Bounds.Y + ($Bounds.Height - $height) / 2.0)
    $Graphics.DrawImage($Image, $x, $y, $width, $height)
}

function New-ReviewSheet {
    param([string]$Title, [array]$Panels, [int]$Columns, [int]$Rows, [string]$OutputPath)
    $width = 1600
    $header = 142
    $cellWidth = [int]($width / $Columns)
    $cellHeight = 500
    $bitmap = [System.Drawing.Bitmap]::new($width, $header + $Rows * $cellHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(29, 29, 34))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $titleFont = [System.Drawing.Font]::new('Arial', 24, [System.Drawing.FontStyle]::Bold)
        $metaFont = [System.Drawing.Font]::new('Consolas', 11, [System.Drawing.FontStyle]::Regular)
        $labelFont = [System.Drawing.Font]::new('Arial', 14, [System.Drawing.FontStyle]::Bold)
        try {
            $graphics.DrawString($Title, $titleFont, [System.Drawing.Brushes]::White, 20, 12)
            $graphics.DrawString("Prompt 2C-R4  A=$authority", $metaFont, [System.Drawing.Brushes]::LightGray, 20, 54)
            $graphics.DrawString("G=$geometry", $metaFont, [System.Drawing.Brushes]::LightGray, 20, 78)
            $graphics.DrawString("T=$topology", $metaFont, [System.Drawing.Brushes]::LightGray, 20, 102)
            for ($index = 0; $index -lt $Panels.Count; $index++) {
                $panel = $Panels[$index]
                if (-not (Test-Path -LiteralPath $panel.Path -PathType Leaf)) {
                    throw "Missing R4 review image '$($panel.Path)'."
                }
                $column = $index % $Columns
                $row = [Math]::Floor($index / $Columns)
                $x = $column * $cellWidth
                $y = $header + $row * $cellHeight
                $image = [System.Drawing.Image]::FromFile($panel.Path)
                try {
                    Draw-ContainedImage -Graphics $graphics -Image $image -Bounds ([System.Drawing.RectangleF]::new($x + 8, $y + 34, $cellWidth - 16, $cellHeight - 42))
                }
                finally { $image.Dispose() }
                $graphics.DrawString($panel.Label, $labelFont, [System.Drawing.Brushes]::White, $x + 14, $y + 6)
            }
            $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $titleFont.Dispose()
            $metaFont.Dispose()
            $labelFont.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Panel([string]$Name, [string]$Label) {
    return @{ Path = Join-Path $imageRoot "human_base_main_body_$Name.png"; Label = $Label }
}

$sheetA = @(
    (Panel 'whole_front' 'Front'), (Panel 'whole_back' 'Back'),
    (Panel 'whole_left' 'Left'), (Panel 'whole_right' 'Right'),
    (Panel 'whole_front_three_quarter' 'Front 3/4'), (Panel 'whole_back_three_quarter' 'Back 3/4')
)
New-ReviewSheet -Title 'Sheet A - final shared-human neutrality' -Panels $sheetA -Columns 2 -Rows 3 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r4_mobile_sheet_a_neutrality.png')

$sheetB = @(
    (Panel 'whole_wire_front' 'Whole front'), (Panel 'whole_wire_side' 'Whole side'),
    (Panel 'head_wire' 'Face / head'), (Panel 'shoulder_armpit_wire' 'Shoulder / armpit'),
    (Panel 'breast_wire' 'Breast root'), (Panel 'hand_wire' 'Hand'),
    (Panel 'pelvis_wire' 'Pelvis / groin'), (Panel 'toe_wire' 'Foot / toes')
)
New-ReviewSheet -Title 'Sheet B - accepted topology preservation' -Panels $sheetB -Columns 2 -Rows 4 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r4_mobile_sheet_b_topology.png')

$sheetC = @(
    (Panel 'head_front' 'Head'), (Panel 'shoulder_armpit' 'Shoulder'), (Panel 'torso_front' 'Torso'),
    (Panel 'breast_front' 'Breast baseline'), (Panel 'hand_palm' 'Hand'), (Panel 'pelvis_front' 'Pelvis'),
    (Panel 'pelvis_back' 'Glutes'), (Panel 'knee_side' 'Knee'), (Panel 'ankle_achilles' 'Ankle'),
    (Panel 'foot_side' 'Foot')
)
New-ReviewSheet -Title 'Sheet C - retained anatomical credibility' -Panels $sheetC -Columns 2 -Rows 5 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r4_mobile_sheet_c_anatomy.png')

$comparisons = @(
    @{ Name = 'front'; File = 'human_base_main_body_whole_front.png' },
    @{ Name = 'side'; File = 'human_base_main_body_whole_left.png' },
    @{ Name = 'back'; File = 'human_base_main_body_whole_back.png' }
)
foreach ($comparison in $comparisons) {
    $leftPath = Join-Path $r3ImageRoot $comparison.File
    $rightPath = Join-Path $imageRoot $comparison.File
    if (-not (Test-Path -LiteralPath $leftPath -PathType Leaf) -or -not (Test-Path -LiteralPath $rightPath -PathType Leaf)) {
        throw "Missing R3/R4 comparison source for '$($comparison.Name)'."
    }
    $left = [System.Drawing.Image]::FromFile($leftPath)
    $right = [System.Drawing.Image]::FromFile($rightPath)
    try {
        $bitmap = [System.Drawing.Bitmap]::new(1800, 1010)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(29, 29, 34))
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $titleFont = [System.Drawing.Font]::new('Arial', 20, [System.Drawing.FontStyle]::Bold)
            $metaFont = [System.Drawing.Font]::new('Consolas', 10, [System.Drawing.FontStyle]::Regular)
            try {
                $graphics.DrawString("R3 - $($comparison.Name)", $titleFont, [System.Drawing.Brushes]::White, 18, 10)
                $graphics.DrawString("R4 neutral - $($comparison.Name)", $titleFont, [System.Drawing.Brushes]::White, 918, 10)
                $graphics.DrawString('R3 A=35a7ab3c433795bc...', $metaFont, [System.Drawing.Brushes]::LightGray, 18, 48)
                $graphics.DrawString("R4 A=$authority", $metaFont, [System.Drawing.Brushes]::LightGray, 918, 48)
                Draw-ContainedImage -Graphics $graphics -Image $left -Bounds ([System.Drawing.RectangleF]::new(0, 78, 900, 920))
                Draw-ContainedImage -Graphics $graphics -Image $right -Bounds ([System.Drawing.RectangleF]::new(900, 78, 900, 920))
                $bitmap.Save((Join-Path $comparisonRoot "r3_vs_r4_$($comparison.Name).png"), [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $titleFont.Dispose()
                $metaFont.Dispose()
            }
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

Write-Host "R4_REVIEW_COMPOSITION_PASS mobile_sheets=3 comparisons=$($comparisons.Count)"
