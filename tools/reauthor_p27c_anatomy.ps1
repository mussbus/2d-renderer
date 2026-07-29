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
    $bitmap = Open-Bitmap $sourcePath
    try {
        # Edit the decoded 32-bit source directly. Copying it through a
        # Graphics surface rounds straight-alpha edge RGB on untouched pixels,
        # which makes a bounded semantic correction silently rewrite the page.
        & $edit $bitmap
        $destination = Join-Path $RepositoryRoot $destinationPath
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-SurfaceCopy(
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
    Refine-Torso-Shoulder `
        $bitmap $left $top $width $height $skin 0.28 0.045 24.0 1.0
    Smooth-Front-Shoulder-Samples `
        $bitmap $left $top $width $height $skin 20.0
}

function Fill-Profile-Shoulders(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin
) {
    Refine-Profile-Shoulder `
        $bitmap $left $top $width $height $skin 24.0
}

function Refine-Torso-Shoulder(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin,
    [double]$shoulderBandFraction,
    [double]$neckBandFraction,
    [double]$targetSlopeDegrees,
    [double]$curvePower
) {
    $shoulderBandEnd = [int][math]::Round(
        $height * $shoulderBandFraction
    )
    $neckBandEnd = [int][math]::Round($height * $neckBandFraction)
    $firstOpaque = [int[]]::new($width)
    $shoulderMinimumX = $width
    $shoulderMaximumX = -1
    $neckMinimumX = $width
    $neckMaximumX = -1

    for ($localX = 0; $localX -lt $width; $localX++) {
        $firstOpaque[$localX] = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel(
                $left + $localX,
                $top + $localY
            ).A -ge 16) {
                $firstOpaque[$localX] = $localY
                break
            }
        }
        if ($firstOpaque[$localX] -le $shoulderBandEnd) {
            $shoulderMinimumX = [math]::Min($shoulderMinimumX, $localX)
            $shoulderMaximumX = [math]::Max($shoulderMaximumX, $localX)
        }
        if ($firstOpaque[$localX] -le $neckBandEnd) {
            $neckMinimumX = [math]::Min($neckMinimumX, $localX)
            $neckMaximumX = [math]::Max($neckMaximumX, $localX)
        }
    }
    if ($shoulderMaximumX -le $shoulderMinimumX -or
        $neckMaximumX -le $neckMinimumX) {
        throw 'Torso shoulder/neck contour is incomplete.'
    }
    $neckY = $height
    for ($localX = $neckMinimumX; $localX -le $neckMaximumX; $localX++) {
        $neckY = [math]::Min($neckY, $firstOpaque[$localX])
    }
    $targetSlope = [math]::Tan(
        $targetSlopeDegrees * [math]::PI / 180.0
    )
    $outline = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
    $centerX = [int]($width / 2)

    for ($localX = $shoulderMinimumX;
        $localX -le $shoulderMaximumX;
        $localX++) {
        if ($localX -lt $neckMinimumX) {
            $distance = $neckMinimumX - $localX
            $maximumDistance = [math]::Max(
                1,
                $neckMinimumX - $shoulderMinimumX
            )
        }
        elseif ($localX -gt $neckMaximumX) {
            $distance = $localX - $neckMaximumX
            $maximumDistance = [math]::Max(
                1,
                $shoulderMaximumX - $neckMaximumX
            )
        }
        else {
            $distance = 0
            $maximumDistance = 1
        }
        $progress = $distance / [double]$maximumDistance
        if ($progress -le 0 -or
            $firstOpaque[$localX] -gt $shoulderBandEnd) {
            continue
        }
        $outerDrop = $targetSlope * $maximumDistance
        $targetEdge = [int][math]::Round(
            $neckY + $outerDrop * [math]::Pow($progress, $curvePower)
        )
        $targetEdge = [math]::Max(0, [math]::Min(
            $targetEdge,
            $shoulderBandEnd
        ))
        if ($targetEdge -lt $firstOpaque[$localX]) {
            for ($localY = $targetEdge;
                $localY -lt $firstOpaque[$localX];
                $localY++) {
                $color = if ($localY -eq $targetEdge) {
                    $outline
                }
                else {
                    Skin-Pixel $skin $localX $localY $centerX
                }
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    $color
                )
            }
        }
        elseif ($targetEdge -gt $firstOpaque[$localX]) {
            for ($localY = $firstOpaque[$localX];
                $localY -lt $targetEdge;
                $localY++) {
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
                )
            }
        }
    }
}

function Normalize-Transparent-Rgb(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height
) {
    for ($localY = 0; $localY -lt $height; $localY++) {
        for ($localX = 0; $localX -lt $width; $localX++) {
            $color = $bitmap.GetPixel($left + $localX, $top + $localY)
            if ($color.A -eq 0 -and
                ($color.R -ne 0 -or $color.G -ne 0 -or $color.B -ne 0)) {
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
                )
            }
        }
    }
}

function Refine-Profile-Shoulder(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin,
    [double]$targetSlopeDegrees
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $visibleMinimumX = $bounds[0]
    $visibleWidth = $bounds[2]
    $startX = $visibleMinimumX + [int][math]::Round(
        0.34 * ($visibleWidth - 1)
    )
    $endX = $visibleMinimumX + [int][math]::Round(
        0.06 * ($visibleWidth - 1)
    )
    if ($startX -le $endX) {
        throw 'Profile shoulder contour is degenerate.'
    }
    $firstOpaque = [int[]]::new($width)
    for ($localX = 0; $localX -lt $width; $localX++) {
        $firstOpaque[$localX] = $height
        for ($localY = 0; $localY -lt $height; $localY++) {
            if ($bitmap.GetPixel(
                $left + $localX,
                $top + $localY
            ).A -ge 16) {
                $firstOpaque[$localX] = $localY
                break
            }
        }
    }
    $startY = $height
    for ($sampleX = $startX - 1; $sampleX -le $startX + 1; $sampleX++) {
        if ($sampleX -ge 0 -and $sampleX -lt $width) {
            $startY = [math]::Min($startY, $firstOpaque[$sampleX])
        }
    }
    if ($startY -eq $height) {
        throw 'Profile shoulder contour start is transparent.'
    }
    $targetSlope = [math]::Tan(
        $targetSlopeDegrees * [math]::PI / 180.0
    )
    $outline = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
    $centerX = [int]($width / 2)
    for ($localX = $endX - 1; $localX -le $startX + 1; $localX++) {
        if ($localX -lt 0 -or $localX -ge $width) { continue }
        $distance = [math]::Max(0, $startX - $localX)
        $progress = $distance / [double]($startX - $endX)
        $curve = [math]::Sin(
            [math]::Min(1.0, $progress) * [math]::PI
        )
        $targetEdge = [int][math]::Round(
            $startY + $targetSlope * $distance + $curve
        )
        $targetEdge = [math]::Max(0, [math]::Min(
            $targetEdge,
            $height - 1
        ))
        if ($targetEdge -lt $firstOpaque[$localX]) {
            for ($localY = $targetEdge;
                $localY -lt $firstOpaque[$localX];
                $localY++) {
                $color = if ($localY -eq $targetEdge) {
                    $outline
                }
                else {
                    Skin-Pixel $skin $localX $localY $centerX
                }
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    $color
                )
            }
        }
        elseif ($targetEdge -gt $firstOpaque[$localX]) {
            for ($localY = $firstOpaque[$localX];
                $localY -lt $targetEdge;
                $localY++) {
                $bitmap.SetPixel(
                    $left + $localX,
                    $top + $localY,
                    [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
                )
            }
        }
    }
}

function Smooth-Front-Shoulder-Samples(
    [System.Drawing.Bitmap]$bitmap,
    [int]$left,
    [int]$top,
    [int]$width,
    [int]$height,
    [System.Drawing.Color]$skin,
    [double]$targetSlopeDegrees
) {
    $bounds = Get-Alpha-Bounds $bitmap $left $top $width $height
    $minimumX = $bounds[0]
    $visibleWidth = $bounds[2]
    $outline = [System.Drawing.Color]::FromArgb(255, 96, 39, 21)
    $centerX = [int]($width / 2)
    $targetSlope = [math]::Tan(
        $targetSlopeDegrees * [math]::PI / 180.0
    )
    foreach ($arc in @(
        @{ start = 0.34; finish = 0.06 },
        @{ start = 0.66; finish = 0.94 }
    )) {
        $startX = $minimumX + [int][math]::Round(
            $arc.start * ($visibleWidth - 1)
        )
        $finishX = $minimumX + [int][math]::Round(
            $arc.finish * ($visibleWidth - 1)
        )
        $direction = if ($finishX -gt $startX) { 1 } else { -1 }
        $distanceTotal = [math]::Abs($finishX - $startX)
        if ($distanceTotal -le 0) {
            throw 'Front shoulder sample arc is degenerate.'
        }
        $firstOpaque = [int[]]::new($width)
        for ($localX = 0; $localX -lt $width; $localX++) {
            $firstOpaque[$localX] = $height
            for ($localY = 0; $localY -lt $height; $localY++) {
                if ($bitmap.GetPixel(
                    $left + $localX,
                    $top + $localY
                ).A -ge 16) {
                    $firstOpaque[$localX] = $localY
                    break
                }
            }
        }
        $startY = $height
        for ($sampleX = $startX - 1; $sampleX -le $startX + 1; $sampleX++) {
            if ($sampleX -ge 0 -and $sampleX -lt $width) {
                $startY = [math]::Min($startY, $firstOpaque[$sampleX])
            }
        }
        if ($startY -eq $height) {
            throw 'Front shoulder contour start is transparent.'
        }
        for ($step = 0; $step -le $distanceTotal + 1; $step++) {
            $localX = $startX + $direction * $step
            if ($localX -lt 0 -or $localX -ge $width) { continue }
            $progress = [math]::Min(1.0, $step / [double]$distanceTotal)
            $curve = [math]::Sin($progress * [math]::PI)
            $targetEdge = [int][math]::Round(
                $startY + $targetSlope * $step + $curve
            )
            $targetEdge = [math]::Max(0, [math]::Min(
                $targetEdge,
                $height - 1
            ))
            if ($targetEdge -lt $firstOpaque[$localX]) {
                for ($localY = $targetEdge;
                    $localY -lt $firstOpaque[$localX];
                    $localY++) {
                    $color = if ($localY -eq $targetEdge) {
                        $outline
                    }
                    else {
                        Skin-Pixel $skin $localX $localY $centerX
                    }
                    $bitmap.SetPixel(
                        $left + $localX,
                        $top + $localY,
                        $color
                    )
                }
            }
            elseif ($targetEdge -gt $firstOpaque[$localX]) {
                for ($localY = $firstOpaque[$localX];
                    $localY -lt $targetEdge;
                    $localY++) {
                    $bitmap.SetPixel(
                        $left + $localX,
                        $top + $localY,
                        [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
                    )
                }
            }
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
        Fill-Profile-Shoulders $bitmap 284 17 95 216 $maleSkin
        Normalize-Transparent-Rgb $bitmap 248 430 150 182
        Normalize-Transparent-Rgb $bitmap 284 17 95 216
    }

Save-Copy `
    'assets/art/p25a_female_base_anatomy_atlas.png' `
    'assets/art/p27c_female_base_anatomy_atlas.png' `
    {
        param($bitmap)
        Fill-Front-Shoulders $bitmap 224 446 124 182 $femaleSkin
        Fill-Profile-Shoulders $bitmap 245 39 99 190 $femaleSkin
        Normalize-Transparent-Rgb $bitmap 224 446 124 182
        Normalize-Transparent-Rgb $bitmap 245 39 99 190
    }

# Preserve the accepted Prompt 27C component-page byte output. The R1
# straight-alpha copy correction is intentionally restricted to torso pages.
Save-SurfaceCopy `
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
