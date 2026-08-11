[CmdletBinding()]
param(
    [string]$EvidenceDirectory = 'assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation',
    [string]$T3EvidenceDirectory = 'assets/canonical_model/human_base/geometry/evidence/prompt_2c_t3_hm08_adoption'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $EvidenceDirectory))
$imageRoot = Join-Path $evidenceRoot 'images'
$sheetRoot = Join-Path $evidenceRoot 'mobile_sheets'
$comparisonRoot = Join-Path $evidenceRoot 'comparisons'
$t3Root = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot (Join-Path $T3EvidenceDirectory 'images')))
New-Item -ItemType Directory -Force -Path $sheetRoot, $comparisonRoot | Out-Null

$authority = '35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7'
$geometry = '7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417'
$topology = '335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191'

function Draw-ContainedImage {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Image,
        [System.Drawing.RectangleF]$Bounds
    )
    $scale = [Math]::Min($Bounds.Width / $Image.Width, $Bounds.Height / $Image.Height)
    $width = [single]($Image.Width * $scale)
    $height = [single]($Image.Height * $scale)
    $x = [single]($Bounds.X + ($Bounds.Width - $width) / 2.0)
    $y = [single]($Bounds.Y + ($Bounds.Height - $height) / 2.0)
    $Graphics.DrawImage($Image, $x, $y, $width, $height)
}

function New-ReviewSheet {
    param(
        [string]$Title,
        [array]$Panels,
        [int]$Columns,
        [int]$Rows,
        [string]$OutputPath
    )
    $width = 1600
    $header = 142
    $cellWidth = [int]($width / $Columns)
    $cellHeight = 500
    $height = $header + $Rows * $cellHeight
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(29, 29, 34))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $titleFont = [System.Drawing.Font]::new('Arial', 24, [System.Drawing.FontStyle]::Bold)
        $metaFont = [System.Drawing.Font]::new('Consolas', 11, [System.Drawing.FontStyle]::Regular)
        $labelFont = [System.Drawing.Font]::new('Arial', 14, [System.Drawing.FontStyle]::Bold)
        $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(198, 204, 214))
        try {
            $graphics.DrawString($Title, $titleFont, [System.Drawing.Brushes]::White, 20, 12)
            $graphics.DrawString("Prompt 2C-R3  A=$authority", $metaFont, $muted, 20, 54)
            $graphics.DrawString("G=$geometry", $metaFont, $muted, 20, 78)
            $graphics.DrawString("T=$topology", $metaFont, $muted, 20, 102)
            for ($index = 0; $index -lt $Panels.Count; $index++) {
                $panel = $Panels[$index]
                if (-not (Test-Path -LiteralPath $panel.Path -PathType Leaf)) {
                    throw "Missing R3 review image '$($panel.Path)'."
                }
                $column = $index % $Columns
                $row = [Math]::Floor($index / $Columns)
                $x = $column * $cellWidth
                $y = $header + $row * $cellHeight
                $image = [System.Drawing.Image]::FromFile($panel.Path)
                try {
                    Draw-ContainedImage -Graphics $graphics -Image $image -Bounds ([System.Drawing.RectangleF]::new($x + 8, $y + 34, $cellWidth - 16, $cellHeight - 42))
                }
                finally {
                    $image.Dispose()
                }
                $graphics.DrawString($panel.Label, $labelFont, [System.Drawing.Brushes]::White, $x + 14, $y + 6)
            }
            $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $titleFont.Dispose()
            $metaFont.Dispose()
            $labelFont.Dispose()
            $muted.Dispose()
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
New-ReviewSheet -Title 'Sheet A - neutral human silhouette and proportions' -Panels $sheetA -Columns 2 -Rows 3 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r3_mobile_sheet_a_whole_body.png')

$sheetB = @(
    (Panel 'whole_wire_front' 'Whole front'), (Panel 'whole_wire_side' 'Whole side'), (Panel 'head_wire' 'Head / face'),
    (Panel 'eye_topology' 'Eye loops'), (Panel 'shoulder_armpit_wire' 'Shoulder / armpit'), (Panel 'breast_wire' 'Breast root'),
    (Panel 'hand_wire' 'Hand / digits'), (Panel 'pelvis_wire' 'Pelvis / groin'), (Panel 'toe_wire' 'Foot / toes')
)
New-ReviewSheet -Title 'Sheet B - deformation-critical control topology' -Panels $sheetB -Columns 3 -Rows 3 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r3_mobile_sheet_b_topology.png')

$sheetC = @(
    (Panel 'head_front' 'Head front'), (Panel 'head_side' 'Head side'), (Panel 'nose_mouth' 'Nose / mouth'),
    (Panel 'shoulder_armpit' 'Shoulder'), (Panel 'breast_front' 'Torso / breast'), (Panel 'hand_palm' 'Hand / palm'),
    (Panel 'pelvis_front' 'Pelvis'), (Panel 'perineal_receiver' 'Perineal receiver'), (Panel 'knee_side' 'Knee'),
    (Panel 'ankle_achilles' 'Ankle / Achilles'), (Panel 'foot_side' 'Foot side'), (Panel 'foot_top' 'Foot top')
)
New-ReviewSheet -Title 'Sheet C - anatomical closeups' -Panels $sheetC -Columns 3 -Rows 4 -OutputPath (Join-Path $sheetRoot 'prompt_2c_r3_mobile_sheet_c_anatomy.png')

$comparisons = @(
    @{ Name = 'whole_body'; T3 = 'human_base_main_body_whole_front.png'; R3 = 'human_base_main_body_whole_front.png' },
    @{ Name = 'head'; T3 = 'human_base_main_body_head_front.png'; R3 = 'human_base_main_body_head_front.png' },
    @{ Name = 'shoulder'; T3 = 'human_base_main_body_shoulder_armpit.png'; R3 = 'human_base_main_body_shoulder_armpit.png' },
    @{ Name = 'breast_torso'; T3 = 'human_base_main_body_torso_breast_front.png'; R3 = 'human_base_main_body_breast_front.png' },
    @{ Name = 'hand'; T3 = 'human_base_main_body_hand_palm.png'; R3 = 'human_base_main_body_hand_palm.png' },
    @{ Name = 'pelvis'; T3 = 'human_base_main_body_pelvis_front.png'; R3 = 'human_base_main_body_pelvis_front.png' },
    @{ Name = 'knee'; T3 = 'human_base_main_body_knee.png'; R3 = 'human_base_main_body_knee_front.png' },
    @{ Name = 'ankle'; T3 = 'human_base_main_body_ankle.png'; R3 = 'human_base_main_body_ankle_achilles.png' },
    @{ Name = 'foot'; T3 = 'human_base_main_body_foot_side.png'; R3 = 'human_base_main_body_foot_side.png' }
)
foreach ($comparison in $comparisons) {
    $leftPath = Join-Path $t3Root $comparison.T3
    $rightPath = Join-Path $imageRoot $comparison.R3
    if (-not (Test-Path -LiteralPath $leftPath -PathType Leaf) -or -not (Test-Path -LiteralPath $rightPath -PathType Leaf)) {
        throw "Missing T3/R3 comparison source for '$($comparison.Name)'."
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
                $graphics.DrawString("T3 adopted HM08 - $($comparison.Name)", $titleFont, [System.Drawing.Brushes]::White, 18, 10)
                $graphics.DrawString("R3 adapted human_base - $($comparison.Name)", $titleFont, [System.Drawing.Brushes]::White, 918, 10)
                $graphics.DrawString("T3 A=29552addc3d550c4...", $metaFont, [System.Drawing.Brushes]::LightGray, 18, 48)
                $graphics.DrawString("R3 A=$authority", $metaFont, [System.Drawing.Brushes]::LightGray, 918, 48)
                Draw-ContainedImage -Graphics $graphics -Image $left -Bounds ([System.Drawing.RectangleF]::new(0, 78, 900, 920))
                Draw-ContainedImage -Graphics $graphics -Image $right -Bounds ([System.Drawing.RectangleF]::new(900, 78, 900, 920))
                $output = Join-Path $comparisonRoot "t3_vs_r3_$($comparison.Name).png"
                $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
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

Write-Host "R3_REVIEW_COMPOSITION_PASS mobile_sheets=3 comparisons=$($comparisons.Count)"
