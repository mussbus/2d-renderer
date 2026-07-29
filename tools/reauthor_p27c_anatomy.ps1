param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Open-Bitmap([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    return [System.Drawing.Bitmap]::new([string](Resolve-Path $path))
}

function Save-Copy(
    [string]$sourcePath,
    [string]$destinationPath,
    [scriptblock]$edit
) {
    $source = Open-Bitmap $sourcePath
    try {
        $bitmap = [System.Drawing.Bitmap]::new(
            $source.Width,
            $source.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CompositingMode =
                    [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.DrawImageUnscaled($source, 0, 0)
            }
            finally {
                $graphics.Dispose()
            }
            & $edit $bitmap
            $destination = Join-Path $RepositoryRoot $destinationPath
            $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

function Skin-Pixel(
    [System.Drawing.Color]$base,
    [int]$x,
    [int]$y,
    [int]$centerX
) {
    $horizontal = [math]::Min(10, [math]::Abs($x - $centerX) / 5)
    $vertical = [math]::Min(8, $y / 18)
    $shade = [int]($horizontal + $vertical)
    return [System.Drawing.Color]::FromArgb(
        255,
        [math]::Max(0, $base.R - $shade),
        [math]::Max(0, $base.G - $shade),
        [math]::Max(0, $base.B - [int]($shade / 2))
    )
}

function Fill-Front-Shoulders(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $originalMinimumX = $bounds[0]
    $originalMaximumX = $bounds[0] + $bounds[2] - 1
    # Recontour inside the existing visible torso envelope. Widening this
    # envelope changes the anatomy-relative fit authority for every front
    # garment, even though the intended correction is only the shoulder edge.
    $outerMargin = $originalMinimumX
    $lastX = $originalMaximumX
    $innerLeft = [int][math]::Round($width * 0.39)
    $innerRight = [int][math]::Round($width * 0.61)
    $outerDrop = [int][math]::Round($height * 0.078)
    $centerX = [int]($width / 2)

    for ($localX = $outerMargin; $localX -le $innerLeft; $localX++) {
        $t = ($innerLeft - $localX) / [double]($innerLeft - $outerMargin)
        $edgeY = [int][math]::Round(1 + $outerDrop * [math]::Pow($t, 1.30))
        $firstOpaque = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -ge 16) {
                $firstOpaque = $localY
                break
            }
        }
        $bottom = if ($localX -lt $originalMinimumX) {
            $capProgress = ($localX - $outerMargin) /
                [double]($originalMinimumX - $outerMargin)
            [int][math]::Round(
                $edgeY + 2 + 36 * [math]::Pow($capProgress, 0.60)
            )
        }
        elseif ($firstOpaque -lt $height) {
            $firstOpaque - 1
        }
        else {
            [int][math]::Round($edgeY + 20 + 10 * (1.0 - $t))
        }
        for ($localY = $edgeY; $localY -le $bottom; $localY++) {
            $existing = $bitmap.GetPixel($left + $localX, $top + $localY)
            if ($existing.A -ge 16) { continue }
            $color = Skin-Pixel $skin $localX $localY $centerX
            if ($localY -eq $edgeY -or $localX -eq $outerMargin) {
                $color = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
            }
            $bitmap.SetPixel($left + $localX, $top + $localY, $color)
        }
        if ($firstOpaque -lt $height -and $firstOpaque -gt $edgeY) {
            $seamEnd = if ($localX -le $originalMinimumX + 2) {
                $bottom
            }
            else {
                [math]::Min($bottom, $firstOpaque + 2)
            }
            for ($localY = $firstOpaque; $localY -le $seamEnd; $localY++) {
                $color = $bitmap.GetPixel($left + $localX, $top + $localY)
                if ($color.A -ge 16 -and (Is-Dark $color)) {
                    $bitmap.SetPixel(
                        $left + $localX,
                        $top + $localY,
                        (Skin-Pixel $skin $localX $localY $centerX)
                    )
                }
            }
        }
    }

    for ($localX = $innerRight; $localX -le $lastX; $localX++) {
        $t = ($localX - $innerRight) / [double]($lastX - $innerRight)
        $edgeY = [int][math]::Round(1 + $outerDrop * [math]::Pow($t, 1.30))
        $firstOpaque = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -ge 16) {
                $firstOpaque = $localY
                break
            }
        }
        $bottom = if ($localX -gt $originalMaximumX) {
            $capProgress = ($lastX - $localX) /
                [double]($lastX - $originalMaximumX)
            [int][math]::Round(
                $edgeY + 2 + 36 * [math]::Pow($capProgress, 0.60)
            )
        }
        elseif ($firstOpaque -lt $height) {
            $firstOpaque - 1
        }
        else {
            [int][math]::Round($edgeY + 20 + 10 * (1.0 - $t))
        }
        for ($localY = $edgeY; $localY -le $bottom; $localY++) {
            $existing = $bitmap.GetPixel($left + $localX, $top + $localY)
            if ($existing.A -ge 16) { continue }
            $color = Skin-Pixel $skin $localX $localY $centerX
            if ($localY -eq $edgeY -or $localX -eq $lastX) {
                $color = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
            }
            $bitmap.SetPixel($left + $localX, $top + $localY, $color)
        }
        if ($firstOpaque -lt $height -and $firstOpaque -gt $edgeY) {
            $seamEnd = if ($localX -ge $originalMaximumX - 2) {
                $bottom
            }
            else {
                [math]::Min($bottom, $firstOpaque + 2)
            }
            for ($localY = $firstOpaque; $localY -le $seamEnd; $localY++) {
                $color = $bitmap.GetPixel($left + $localX, $top + $localY)
                if ($color.A -ge 16 -and (Is-Dark $color)) {
                    $bitmap.SetPixel(
                        $left + $localX,
                        $top + $localY,
                        (Skin-Pixel $skin $localX $localY $centerX)
                    )
                }
            }
        }
    }

    # Continue each deltoid into the upper ribcage instead of leaving the
    # original torso's nearly vertical outer crop edge below the new slope.
    # This trim stays in the upper 23 percent of the torso, so chest/waist
    # garment-fit authority remains the inherited anatomy silhouette.
    $shoulderBandStart = [math]::Max(1, $outerDrop)
    $shoulderBandEnd = [int][math]::Round($height * 0.23)
    for ($localY = $shoulderBandStart; $localY -le $shoulderBandEnd; $localY++) {
        $progress = ($localY - $shoulderBandStart) /
            [double][math]::Max(1, $shoulderBandEnd - $shoulderBandStart)
        $trim = [int][math]::Round(4 * [math]::Sin($progress * [math]::PI))
        if ($trim -le 0) { continue }
        $rowMinimum = $width
        $rowMaximum = -1
        for ($localX = 0; $localX -lt $width; $localX++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -lt 16) {
                continue
            }
            $rowMinimum = [math]::Min($rowMinimum, $localX)
            $rowMaximum = [math]::Max($rowMaximum, $localX)
        }
        if ($rowMaximum -le $rowMinimum) { continue }
        for ($offset = 0; $offset -lt $trim; $offset++) {
            $bitmap.SetPixel(
                $left + $rowMinimum + $offset,
                $top + $localY,
                [System.Drawing.Color]::Transparent
            )
            $bitmap.SetPixel(
                $left + $rowMaximum - $offset,
                $top + $localY,
                [System.Drawing.Color]::Transparent
            )
        }
    }
}

function Fill-Profile-Shoulders(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $minimumX = $bounds[0]
    $maximumX = $bounds[0] + $bounds[2] - 1
    $neckLeft = [int][math]::Round($minimumX + $bounds[2] * 0.34)
    $neckRight = [int][math]::Round($minimumX + $bounds[2] * 0.63)
    $outerDrop = [int][math]::Round($height * 0.075)
    $centerX = [int]($width / 2)

    for ($localX = $minimumX; $localX -le $maximumX; $localX++) {
        if ($localX -lt $neckLeft) {
            $t = ($neckLeft - $localX) / [double]($neckLeft - $minimumX)
        }
        elseif ($localX -gt $neckRight) {
            $t = ($localX - $neckRight) / [double]($maximumX - $neckRight)
        }
        else {
            $t = 0
        }
        $edgeY = [int][math]::Round(
            1 + $outerDrop * [math]::Pow($t, 1.80)
        )
        $originalFirstOpaque = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -ge 16) {
                $originalFirstOpaque = $localY
                break
            }
        }
        if ($t -gt 0) {
            for ($localY = 0; $localY -lt $edgeY; $localY++) {
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    [System.Drawing.Color]::Transparent
                )
            }
        }
        $firstOpaque = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -ge 16) {
                $firstOpaque = $localY
                break
            }
        }
        for ($localY = $edgeY; $localY -lt $firstOpaque; $localY++) {
            $color = Skin-Pixel $skin $localX $localY $centerX
            if ($localY -eq $edgeY) {
                $color = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
            }
            $bitmap.SetPixel($left + $localX, $top + $localY, $color)
        }
        if ($originalFirstOpaque -gt $edgeY -and
            $originalFirstOpaque -lt $height) {
            for ($localY = $originalFirstOpaque;
                $localY -le [math]::Min($height - 1, $originalFirstOpaque + 2);
                $localY++) {
                $color = $bitmap.GetPixel($left + $localX, $top + $localY)
                if ($color.A -ge 16 -and (Is-Dark $color)) {
                    $bitmap.SetPixel(
                        $left + $localX,
                        $top + $localY,
                        (Skin-Pixel $skin $localX $localY $centerX)
                    )
                }
            }
        }
    }
}

function Soften-Front-Shoulder-Outline(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    $bandEnd = [int][math]::Round($height * 0.26)
    for ($localY = 3; $localY -le $bandEnd; $localY++) {
        for ($localX = 1; $localX -lt $width - 1; $localX++) {
            $color = $bitmap.GetPixel($left + $localX, $top + $localY)
            if ($color.A -lt 16 -or -not (Is-Dark $color)) { continue }
            $leftAlpha = $bitmap.GetPixel(
                $left + $localX - 1,
                $top + $localY
            ).A
            $rightAlpha = $bitmap.GetPixel(
                $left + $localX + 1,
                $top + $localY
            ).A
            if ($leftAlpha -ge 16 -and $rightAlpha -ge 16) { continue }
            $bitmap.SetPixel(
                $left + $localX,
                $top + $localY,
                (Skin-Pixel $skin $localX $localY ([int]($width / 2)))
            )
        }
    }
}

function Get-Alpha-Bounds(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height
) {
    $minimumX = $width
    $minimumY = $height
    $maximumX = -1
    $maximumY = -1
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            if ($bitmap.GetPixel($left + $x, $top + $y).A -lt 16) { continue }
            $minimumX = [math]::Min($minimumX, $x)
            $minimumY = [math]::Min($minimumY, $y)
            $maximumX = [math]::Max($maximumX, $x)
            $maximumY = [math]::Max($maximumY, $y)
        }
    }
    if ($maximumX -lt 0) { throw 'An anatomy region has no opaque pixels.' }
    return @(
        $minimumX,
        $minimumY,
        ($maximumX - $minimumX + 1),
        ($maximumY - $minimumY + 1)
    )
}

function Is-Dark([System.Drawing.Color]$color) {
    return ($color.R * 54 + $color.G * 183 + $color.B * 19) -lt (110 * 256)
}

function Fill-Pelvis-Bridge(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    $centerX = [int][math]::Floor($width / 2)
    $startY = [int][math]::Round($height * 0.62)
    $endY = $height - 5
    for ($localY = $startY; $localY -le $endY; $localY++) {
        $progress = ($localY - $startY) / [double][math]::Max(1, $endY - $startY)
        $halfWidth = [int][math]::Round(12 - 7 * $progress)
        for ($localX = $centerX - $halfWidth;
            $localX -le $centerX + $halfWidth;
            $localX++) {
            if ($bitmap.GetPixel($left + $localX, $top + $localY).A -ge 16) {
                continue
            }
            $color = Skin-Pixel $skin $localX $localY $centerX
            $bitmap.SetPixel($left + $localX, $top + $localY, $color)
        }
    }
}

function Taper-Longitudinal-Region(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [bool]$horizontal,
    [int]$maximumTrim
) {
    $longitudinalLength = if ($horizontal) { $width } else { $height }
    for ($along = 0; $along -lt $longitudinalLength; $along++) {
        $progress = $along / [double][math]::Max(1, $longitudinalLength - 1)
        if ($progress -lt 0.55) { continue }
        $trim = [int][math]::Round(
            $maximumTrim * (($progress - 0.55) / 0.45)
        )
        if ($trim -le 0) { continue }
        $minimum = if ($horizontal) { $height } else { $width }
        $maximum = -1
        $crossLength = if ($horizontal) { $height } else { $width }
        for ($cross = 0; $cross -lt $crossLength; $cross++) {
            $x = if ($horizontal) { $left + $along } else { $left + $cross }
            $y = if ($horizontal) { $top + $cross } else { $top + $along }
            if ($bitmap.GetPixel($x, $y).A -lt 16) { continue }
            $minimum = [math]::Min($minimum, $cross)
            $maximum = [math]::Max($maximum, $cross)
        }
        if ($maximum -lt $minimum) { continue }
        for ($offset = 0; $offset -lt $trim; $offset++) {
            foreach ($cross in @(($minimum + $offset), ($maximum - $offset))) {
                $x = if ($horizontal) { $left + $along } else { $left + $cross }
                $y = if ($horizontal) { $top + $cross } else { $top + $along }
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }
        }
    }
}

function Flare-Proximal-Region(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [bool]$horizontal,
    [System.Drawing.Color]$skin,
    [int]$radius
) {
    $longitudinalLength = if ($horizontal) { $width } else { $height }
    for ($along = 0; $along -lt [int]($longitudinalLength * 0.42); $along++) {
        $crossLength = if ($horizontal) { $height } else { $width }
        $minimum = $crossLength
        $maximum = -1
        for ($cross = 0; $cross -lt $crossLength; $cross++) {
            $x = if ($horizontal) { $left + $along } else { $left + $cross }
            $y = if ($horizontal) { $top + $cross } else { $top + $along }
            if ($bitmap.GetPixel($x, $y).A -lt 16) { continue }
            $minimum = [math]::Min($minimum, $cross)
            $maximum = [math]::Max($maximum, $cross)
        }
        if ($maximum -lt $minimum) { continue }
        for ($offset = 1; $offset -le $radius; $offset++) {
            foreach ($cross in @(($minimum - $offset), ($maximum + $offset))) {
                if ($cross -lt 0 -or $cross -ge $crossLength) { continue }
                $x = if ($horizontal) { $left + $along } else { $left + $cross }
                $y = if ($horizontal) { $top + $cross } else { $top + $along }
                if ($bitmap.GetPixel($x, $y).A -lt 16) {
                    $bitmap.SetPixel($x, $y, $skin)
                }
            }
        }
    }
}

function Round-Longitudinal-Endpoint(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [bool]$horizontal,
    [bool]$atStart,
    [int]$depth
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $minimumAlong = if ($horizontal) { $bounds[0] } else { $bounds[1] }
    $maximumAlong = if ($horizontal) {
        $bounds[0] + $bounds[2] - 1
    }
    else {
        $bounds[1] + $bounds[3] - 1
    }
    $crossLength = if ($horizontal) { $height } else { $width }
    for ($step = 0; $step -lt $depth; $step++) {
        $along = if ($atStart) {
            $minimumAlong + $step
        }
        else {
            $maximumAlong - $step
        }
        $crossMinimum = $crossLength
        $crossMaximum = -1
        for ($cross = 0; $cross -lt $crossLength; $cross++) {
            $x = if ($horizontal) { $left + $along } else { $left + $cross }
            $y = if ($horizontal) { $top + $cross } else { $top + $along }
            if ($bitmap.GetPixel($x, $y).A -lt 16) { continue }
            $crossMinimum = [math]::Min($crossMinimum, $cross)
            $crossMaximum = [math]::Max($crossMaximum, $cross)
        }
        if ($crossMaximum -le $crossMinimum) { continue }
        $progress = 1.0 - ($step / [double][math]::Max(1, $depth - 1))
        $trim = [int][math]::Round(
            ($crossMaximum - $crossMinimum + 1) * 0.18 *
            [math]::Pow($progress, 1.5)
        )
        for ($offset = 0; $offset -lt $trim; $offset++) {
            foreach ($cross in @(
                ($crossMinimum + $offset),
                ($crossMaximum - $offset)
            )) {
                $x = if ($horizontal) { $left + $along } else { $left + $cross }
                $y = if ($horizontal) { $top + $cross } else { $top + $along }
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }
        }
    }
}

function Soften-Endpoint(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [double]$endpointX,
    [double]$endpointY,
    [double]$interiorX,
    [double]$interiorY,
    [System.Drawing.Color]$fallback
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $visibleWidth = [double]($bounds[2] - 1)
    $visibleHeight = [double]($bounds[3] - 1)
    $originX = $left + $bounds[0] + $endpointX * $visibleWidth
    $originY = $top + $bounds[1] + $endpointY * $visibleHeight
    $inwardX = ($interiorX - $endpointX) * $visibleWidth
    $inwardY = ($interiorY - $endpointY) * $visibleHeight
    $length = [math]::Sqrt($inwardX * $inwardX + $inwardY * $inwardY)
    $inwardX /= $length
    $inwardY /= $length
    $perpendicularX = -$inwardY
    $perpendicularY = $inwardX
    $halfWidth = [int][math]::Max(2, [math]::Min(24, $bounds[2] * 0.45))

    $targets = [System.Collections.Generic.HashSet[string]]::new()
    for ($depth = 0; $depth -le 6; $depth++) {
        for ($lateral = -$halfWidth; $lateral -le $halfWidth; $lateral++) {
            $x = [int][math]::Round($originX + $inwardX * $depth + $perpendicularX * $lateral)
            $y = [int][math]::Round($originY + $inwardY * $depth + $perpendicularY * $lateral)
            if ($x -lt $left -or $x -ge $left + $width -or
                $y -lt $top -or $y -ge $top + $height) { continue }
            $color = $bitmap.GetPixel($x, $y)
            if ($color.A -ge 16 -and (Is-Dark $color)) {
                [void]$targets.Add("$x,$y")
            }
        }
    }

    foreach ($target in $targets) {
        $parts = $target.Split(',')
        $x = [int]$parts[0]
        $y = [int]$parts[1]
        $replacement = $fallback
        for ($distance = 5; $distance -le 14; $distance++) {
            $sampleX = [int][math]::Round($x + $inwardX * $distance)
            $sampleY = [int][math]::Round($y + $inwardY * $distance)
            if ($sampleX -lt $left -or $sampleX -ge $left + $width -or
                $sampleY -lt $top -or $sampleY -ge $top + $height) { continue }
            $sample = $bitmap.GetPixel($sampleX, $sampleY)
            if ($sample.A -ge 16 -and -not (Is-Dark $sample)) {
                $replacement = [System.Drawing.Color]::FromArgb(
                    $bitmap.GetPixel($x, $y).A,
                    $sample.R,
                    $sample.G,
                    $sample.B
                )
                break
            }
        }
        $bitmap.SetPixel($x, $y, $replacement)
    }
}

function Reauthor-Front-Foot(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    # The inherited front region was a side-profile foot rotated toward the
    # camera, which produced a long hooked spike. Draw a bounded top/three-
    # quarter silhouette in the same alpha-tight region. The ankle section at
    # the declared 0.24 local-x landmark occupies about 86% of the authored
    # width perpendicular to the foot axis, preserving shin continuity without
    # moving the skeletal socket.
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode =
            [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.FillRectangle(
            [System.Drawing.Brushes]::Transparent,
            $left,
            $top,
            $width,
            $height
        )
        $graphics.CompositingMode =
            [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.SmoothingMode =
            [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $point = {
            param([double]$x, [double]$y)
            return [System.Drawing.PointF]::new(
                [single]($left + $x * ($width - 1)),
                [single]($top + $y * ($height - 1))
            )
        }
        [System.Drawing.PointF[]]$points = @(
            (& $point 0.05 0.50),
            (& $point 0.14 0.43),
            (& $point 0.34 0.38),
            (& $point 0.35 0.06),
            (& $point 0.40 0.06),
            (& $point 0.41 0.38),
            (& $point 0.56 0.35),
            (& $point 0.81 0.30),
            (& $point 0.95 0.35),
            (& $point 0.98 0.48),
            (& $point 0.94 0.63),
            (& $point 0.81 0.79),
            (& $point 0.56 0.85),
            (& $point 0.38 0.68),
            (& $point 0.35 0.85),
            (& $point 0.30 0.85),
            (& $point 0.18 0.64),
            (& $point 0.12 0.56)
        )
        $shade = [System.Drawing.Color]::FromArgb(
            255,
            [math]::Max(0, $skin.R - 28),
            [math]::Max(0, $skin.G - 20),
            [math]::Max(0, $skin.B - 12)
        )
        $bounds = [System.Drawing.RectangleF]::new(
            [single]$left,
            [single]$top,
            [single]$width,
            [single]$height
        )
        $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $bounds,
            $skin,
            $shade,
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        $outline = [System.Drawing.Pen]::new(
            [System.Drawing.Color]::FromArgb(255, 96, 39, 21),
            1.25
        )
        try {
            $graphics.FillPolygon($brush, $points)
            $graphics.DrawPolygon($outline, $points)
            $jointPen = [System.Drawing.Pen]::new($skin, 2.0)
            try {
                $graphics.DrawLine(
                    $jointPen,
                    (& $point 0.35 0.06),
                    (& $point 0.40 0.06)
                )
            }
            finally {
                $jointPen.Dispose()
            }
        }
        finally {
            $outline.Dispose()
            $brush.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }
}

$maleSkin = [System.Drawing.Color]::FromArgb(255, 224, 119, 66)
$femaleSkin = [System.Drawing.Color]::FromArgb(255, 210, 104, 58)

Save-Copy `
    'assets/art/p25a_male_base_anatomy_atlas.png' `
    'assets/art/p27c_male_base_anatomy_atlas.png' `
    {
        param($bitmap)
        Fill-Front-Shoulders $bitmap 248 430 150 182 $maleSkin
        Soften-Front-Shoulder-Outline $bitmap 248 430 150 182 $maleSkin
        Fill-Profile-Shoulders $bitmap 284 17 95 216 $maleSkin
    }

Save-Copy `
    'assets/art/p25a_female_base_anatomy_atlas.png' `
    'assets/art/p27c_female_base_anatomy_atlas.png' `
    {
        param($bitmap)
        Fill-Front-Shoulders $bitmap 224 446 124 182 $femaleSkin
        Soften-Front-Shoulder-Outline $bitmap 224 446 124 182 $femaleSkin
        Fill-Profile-Shoulders $bitmap 245 39 99 190 $femaleSkin
    }

Save-Copy `
    'assets/art/p25b_anatomy_components_atlas.png' `
    'assets/art/p27c_anatomy_components_atlas.png' `
    {
        param($bitmap)
        $styles = @(
            @{
                skin = $maleSkin
                side_upper = @(72, 103, 102, 53)
                side_forearm = @(335, 111, 87, 26)
                side_hand = @(612, 111, 55, 34)
                side_thigh = @(857, 51, 60, 155)
                side_shin = @(1124, 55, 37, 118)
                side_foot = @(1373, 103, 70, 49)
                side_pelvis = @(1608, 65, 63, 98)
                front_upper = @(209, 317, 38, 110)
                front_forearm = @(364, 334, 28, 81)
                front_hand = @(623, 352, 33, 64)
                front_thigh = @(869, 306, 54, 122)
                front_shin = @(1123, 313, 39, 104)
                front_foot = @(1374, 358, 67, 51)
                front_pelvis = @(1607, 292, 122, 70)
                upperStart = 0.045
                upperEnd = 0.968
                thighEnd = 0.977
                footAnkle = 0.3055
                sideForearmTrim = 1
                frontForearmTrim = 1
                flareForearm = $true
                flareRadius = 2
                flareHand = $true
            },
            @{
                skin = $femaleSkin
                side_upper = @(72, 617, 102, 52)
                side_forearm = @(335, 624, 87, 27)
                side_hand = @(612, 624, 55, 31)
                side_thigh = @(854, 563, 62, 155)
                side_shin = @(1125, 567, 38, 118)
                side_foot = @(1373, 616, 70, 48)
                side_pelvis = @(1606, 580, 62, 98)
                front_upper = @(209, 827, 37, 110)
                front_forearm = @(364, 845, 28, 81)
                front_hand = @(624, 864, 31, 64)
                front_thigh = @(855, 819, 60, 122)
                front_shin = @(1126, 817, 40, 104)
                front_foot = @(1379, 868, 58, 56)
                front_pelvis = @(1580, 833, 128, 66)
                upperStart = 0.035
                upperEnd = 0.978
                thighEnd = 0.947
                footAnkle = 0.337086
                sideForearmTrim = 2
                frontForearmTrim = 1
                flareForearm = $true
                flareRadius = 1
                flareHand = $false
            }
        )
        foreach ($style in $styles) {
            $skin = $style.skin
            $r = $style.side_upper
            Soften-Endpoint $bitmap @r 1.0 0.5 0.0 0.5 $skin
            $r = $style.side_forearm
            Soften-Endpoint $bitmap @r 0.0 0.5 1.0 0.5 $skin
            Soften-Endpoint $bitmap @r 1.0 0.5 0.0 0.5 $skin
            if ($style.flareForearm) {
                Flare-Proximal-Region $bitmap @r $true $skin $style.flareRadius
            }
            Taper-Longitudinal-Region $bitmap @r $true $style.sideForearmTrim
            $r = $style.side_hand
            Soften-Endpoint $bitmap @r 0.0 0.5 0.97 0.5 $skin
            if ($style.flareHand) {
                Flare-Proximal-Region $bitmap @r $true $skin 1
            }
            $r = $style.side_thigh
            Soften-Endpoint $bitmap @r 0.5 1.0 0.5 0.0 $skin
            $r = $style.side_shin
            Soften-Endpoint $bitmap @r 0.5 0.0 0.5 1.0 $skin
            Soften-Endpoint $bitmap @r 0.5 1.0 0.5 0.0 $skin
            $r = $style.side_foot
            Soften-Endpoint $bitmap @r 0.243 0.0 0.98 0.75 $skin

            $r = $style.front_upper
            Soften-Endpoint $bitmap @r 0.5 $style.upperEnd 0.5 $style.upperStart $skin
            $r = $style.front_forearm
            Soften-Endpoint $bitmap @r 0.5 0.001 0.5 0.999 $skin
            Soften-Endpoint $bitmap @r 0.5 0.999 0.5 0.001 $skin
            if ($style.flareForearm) {
                Flare-Proximal-Region $bitmap @r $false $skin $style.flareRadius
            }
            Taper-Longitudinal-Region $bitmap @r $false $style.frontForearmTrim
            $r = $style.front_hand
            Soften-Endpoint $bitmap @r 0.5 0.001 0.5 0.97 $skin
            $r = $style.front_thigh
            Soften-Endpoint $bitmap @r 0.5 $style.thighEnd 0.5 0.04 $skin
            $r = $style.front_shin
            Soften-Endpoint $bitmap @r 0.5 0.001 0.5 0.999 $skin
            Soften-Endpoint $bitmap @r 0.5 0.999 0.5 0.001 $skin
            $r = $style.front_foot
            Reauthor-Front-Foot $bitmap @r $skin
            Soften-Endpoint $bitmap @r $style.footAnkle 0.0 0.97 0.78 $skin
            $r = $style.side_pelvis
            Soften-Endpoint $bitmap @r 0.5 1.0 0.5 0.0 $skin
            $r = $style.front_pelvis
            Soften-Endpoint $bitmap @r 0.5 1.0 0.5 0.0 $skin

            foreach ($rounding in @(
                @{ region = $style.side_upper; horizontal = $true; start = $true; depth = 4 },
                @{ region = $style.side_upper; horizontal = $true; start = $false; depth = 4 },
                @{ region = $style.side_forearm; horizontal = $true; start = $true; depth = 4 },
                @{ region = $style.side_forearm; horizontal = $true; start = $false; depth = 4 },
                @{ region = $style.side_hand; horizontal = $true; start = $true; depth = 3 },
                @{ region = $style.side_thigh; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.side_thigh; horizontal = $false; start = $false; depth = 4 },
                @{ region = $style.side_shin; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.side_shin; horizontal = $false; start = $false; depth = 4 },
                @{ region = $style.front_upper; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.front_upper; horizontal = $false; start = $false; depth = 4 },
                @{ region = $style.front_forearm; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.front_forearm; horizontal = $false; start = $false; depth = 4 },
                @{ region = $style.front_hand; horizontal = $false; start = $false; depth = 3 },
                @{ region = $style.front_thigh; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.front_thigh; horizontal = $false; start = $false; depth = 4 },
                @{ region = $style.front_shin; horizontal = $false; start = $true; depth = 4 },
                @{ region = $style.front_shin; horizontal = $false; start = $false; depth = 4 }
            )) {
                $r = $rounding.region
                Round-Longitudinal-Endpoint `
                    $bitmap `
                    @r `
                    $rounding.horizontal `
                    $rounding.start `
                    $rounding.depth
            }
        }
        Fill-Pelvis-Bridge $bitmap 1607 292 122 70 $maleSkin
        Fill-Pelvis-Bridge $bitmap 1580 833 128 66 $femaleSkin
    }

Get-FileHash -Algorithm SHA256 @(
    (Join-Path $RepositoryRoot 'assets/art/p27c_male_base_anatomy_atlas.png'),
    (Join-Path $RepositoryRoot 'assets/art/p27c_female_base_anatomy_atlas.png'),
    (Join-Path $RepositoryRoot 'assets/art/p27c_anatomy_components_atlas.png')
) | ForEach-Object {
    '{0}  {1}' -f $_.Hash.ToLowerInvariant(), (Split-Path -Leaf $_.Path)
}
