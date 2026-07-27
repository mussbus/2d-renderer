param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$atlasPath = Join-Path $RepositoryRoot 'assets/art/p25b_anatomy_components_atlas.png'
$maleBasePath = Join-Path $RepositoryRoot 'assets/art/p25a_male_base_anatomy_atlas.png'
$femaleBasePath = Join-Path $RepositoryRoot 'assets/art/p25a_female_base_anatomy_atlas.png'
foreach ($requiredPath in @($atlasPath, $maleBasePath, $femaleBasePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Write-Error "Prompt 25B audited production atlas is missing: $requiredPath"
        exit 1
    }
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::new($atlasPath)
try {
    if ($bitmap.Width -ne 1792 -or $bitmap.Height -ne 1024) {
        Write-Error "Prompt 25B component atlas must be exactly 1792x1024; found $($bitmap.Width)x$($bitmap.Height)."
        exit 1
    }

    $regions = @(
        [pscustomobject]@{ Name = 'male_side_upper_arm'; X = 72; Y = 103; W = 112; H = 50; AuthW = 0.72; AuthH = 0.30 },
        [pscustomobject]@{ Name = 'male_side_forearm'; X = 335; Y = 111; W = 97; H = 33; AuthW = 0.62; AuthH = 0.20 },
        [pscustomobject]@{ Name = 'male_side_hand'; X = 612; Y = 111; W = 55; H = 34; AuthW = 0.34; AuthH = 0.20 },
        [pscustomobject]@{ Name = 'male_side_thigh'; X = 857; Y = 51; W = 77; H = 154; AuthW = 0.43; AuthH = 1.00 },
        [pscustomobject]@{ Name = 'male_side_shin'; X = 1124; Y = 55; W = 55; H = 145; AuthW = 0.34; AuthH = 0.94 },
        [pscustomobject]@{ Name = 'male_side_foot'; X = 1373; Y = 103; W = 70; H = 49; AuthW = 0.44; AuthH = 0.30 },
        [pscustomobject]@{ Name = 'male_side_pelvis'; X = 1596; Y = 67; W = 136; H = 122; AuthW = 0.88; AuthH = 0.70 },
        [pscustomobject]@{ Name = 'male_front_upper_arm'; X = 209; Y = 317; W = 42; H = 124; AuthW = 0.255; AuthH = 0.70 },
        [pscustomobject]@{ Name = 'male_front_forearm'; X = 364; Y = 334; W = 33; H = 102; AuthW = 0.20; AuthH = 0.64 },
        [pscustomobject]@{ Name = 'male_front_hand'; X = 623; Y = 352; W = 33; H = 64; AuthW = 0.22; AuthH = 0.40 },
        [pscustomobject]@{ Name = 'male_front_thigh'; X = 869; Y = 306; W = 54; H = 156; AuthW = 0.36; AuthH = 1.00 },
        [pscustomobject]@{ Name = 'male_front_shin'; X = 1123; Y = 313; W = 58; H = 142; AuthW = 0.34; AuthH = 0.92 },
        [pscustomobject]@{ Name = 'male_front_foot'; X = 1374; Y = 358; W = 67; H = 51; AuthW = 0.42; AuthH = 0.31 },
        [pscustomobject]@{ Name = 'male_front_pelvis'; X = 1608; Y = 293; W = 103; H = 143; AuthW = 0.76; AuthH = 1.05 },
        [pscustomobject]@{ Name = 'female_side_upper_arm'; X = 72; Y = 617; W = 112; H = 45; AuthW = 0.72; AuthH = 0.27 },
        [pscustomobject]@{ Name = 'female_side_forearm'; X = 335; Y = 624; W = 97; H = 31; AuthW = 0.62; AuthH = 0.18 },
        [pscustomobject]@{ Name = 'female_side_hand'; X = 612; Y = 624; W = 55; H = 31; AuthW = 0.34; AuthH = 0.18 },
        [pscustomobject]@{ Name = 'female_side_thigh'; X = 854; Y = 563; W = 84; H = 154; AuthW = 0.48; AuthH = 1.00 },
        [pscustomobject]@{ Name = 'female_side_shin'; X = 1125; Y = 567; W = 54; H = 145; AuthW = 0.34; AuthH = 0.94 },
        [pscustomobject]@{ Name = 'female_side_foot'; X = 1373; Y = 616; W = 70; H = 48; AuthW = 0.44; AuthH = 0.30 },
        [pscustomobject]@{ Name = 'female_side_pelvis'; X = 1588; Y = 586; W = 151; H = 108; AuthW = 0.98; AuthH = 0.72 },
        [pscustomobject]@{ Name = 'female_front_upper_arm'; X = 209; Y = 827; W = 30; H = 126; AuthW = 0.18; AuthH = 0.72 },
        [pscustomobject]@{ Name = 'female_front_forearm'; X = 364; Y = 845; W = 24; H = 102; AuthW = 0.141; AuthH = 0.64 },
        [pscustomobject]@{ Name = 'female_front_hand'; X = 624; Y = 864; W = 31; H = 64; AuthW = 0.17; AuthH = 0.34 },
        [pscustomobject]@{ Name = 'female_front_thigh'; X = 855; Y = 819; W = 82; H = 154; AuthW = 0.46; AuthH = 1.00 },
        [pscustomobject]@{ Name = 'female_front_shin'; X = 1126; Y = 823; W = 51; H = 145; AuthW = 0.31; AuthH = 0.94 },
        [pscustomobject]@{ Name = 'female_front_foot'; X = 1379; Y = 868; W = 58; H = 56; AuthW = 0.36; AuthH = 0.34 },
        [pscustomobject]@{ Name = 'female_front_pelvis'; X = 1581; Y = 834; W = 166; H = 124; AuthW = 1.08; AuthH = 0.80 }
    )

    $seenRectangles = @{}
    foreach ($region in $regions) {
        if ($region.X -lt 0 -or $region.Y -lt 0 -or
            $region.X + $region.W -gt $bitmap.Width -or
            $region.Y + $region.H -gt $bitmap.Height) {
            Write-Error "Prompt 25B region is out of bounds: $($region.Name)."
            exit 1
        }
        $rectangleKey = "$($region.X),$($region.Y),$($region.W),$($region.H)"
        if ($seenRectangles.ContainsKey($rectangleKey)) {
            Write-Error "Prompt 25B regions alias the same source rectangle: $($seenRectangles[$rectangleKey]) and $($region.Name)."
            exit 1
        }
        $seenRectangles[$rectangleKey] = $region.Name

        $minimumX = $region.W
        $minimumY = $region.H
        $maximumX = -1
        $maximumY = -1
        for ($localY = 0; $localY -lt $region.H; $localY++) {
            for ($localX = 0; $localX -lt $region.W; $localX++) {
                if ($bitmap.GetPixel($region.X + $localX, $region.Y + $localY).A -le 8) {
                    continue
                }
                $minimumX = [Math]::Min($minimumX, $localX)
                $minimumY = [Math]::Min($minimumY, $localY)
                $maximumX = [Math]::Max($maximumX, $localX)
                $maximumY = [Math]::Max($maximumY, $localY)
            }
        }
        if ($maximumX -lt 0) {
            Write-Error "Prompt 25B region contains no visible alpha: $($region.Name)."
            exit 1
        }
        if ($minimumX -lt 1 -or $minimumY -lt 1 -or
            $maximumX -gt $region.W - 2 -or $maximumY -gt $region.H - 2) {
            Write-Error "Prompt 25B region lacks an alpha-safe packing margin: $($region.Name)."
            exit 1
        }

        $alphaWidth = $maximumX - $minimumX + 1
        $alphaHeight = $maximumY - $minimumY + 1
        if ($region.Name -in @('male_front_upper_arm', 'female_front_upper_arm')) {
            if ($minimumY -lt 10) {
                Write-Error "Prompt 25B front upper arm lost its torso-overlap registration lead-in: $($region.Name)."
                exit 1
            }
            $topVisiblePixels = 0
            for ($localX = $minimumX; $localX -le $maximumX; $localX++) {
                if ($bitmap.GetPixel($region.X + $localX, $region.Y + $minimumY).A -gt 8) {
                    $topVisiblePixels++
                }
            }
            if ($topVisiblePixels -gt [Math]::Ceiling($alphaWidth * 0.65)) {
                Write-Error "Prompt 25B front upper arm exposes a flat shoulder crop edge: $($region.Name)."
                exit 1
            }
        }
        $alphaAspect = [double]$alphaWidth / [double]$alphaHeight
        $authoredAspect = [double]$region.AuthW / [double]$region.AuthH
        $aspectRatio = $authoredAspect / $alphaAspect
        if ($aspectRatio -lt 0.82 -or $aspectRatio -gt 1.20) {
            Write-Error ("Prompt 25B region aspect distortion exceeds the accepted 0.82..1.20 band: " +
                "$($region.Name) alpha=${alphaWidth}x${alphaHeight} authored=$($region.AuthW)x$($region.AuthH) ratio=$aspectRatio.")
            exit 1
        }
    }

    if ($regions.Count -ne 28) {
        Write-Error "Prompt 25B audit must cover exactly 28 pelvis/arm/hand/leg/foot view-style components."
        exit 1
    }

    $torsoRegions = @(
        [pscustomobject]@{
            Name = 'male_front_torso'
            Path = $maleBasePath
            ExpectedW = 1600
            ExpectedH = 983
            X = 248
            Y = 430
            W = 150
            H = 182
            AuthW = 1.06
            AuthH = 1.30
        },
        [pscustomobject]@{
            Name = 'female_front_torso'
            Path = $femaleBasePath
            ExpectedW = 1599
            ExpectedH = 984
            X = 224
            Y = 446
            W = 124
            H = 182
            AuthW = 0.95
            AuthH = 1.30
        }
    )
    foreach ($region in $torsoRegions) {
        $baseBitmap = [System.Drawing.Bitmap]::new($region.Path)
        try {
            if ($baseBitmap.Width -ne $region.ExpectedW -or
                $baseBitmap.Height -ne $region.ExpectedH) {
                Write-Error "Prompt 25B base atlas has unexpected dimensions: $($region.Path)."
                exit 1
            }
            if ($region.X + $region.W -gt $baseBitmap.Width -or
                $region.Y + $region.H -gt $baseBitmap.Height) {
                Write-Error "Prompt 25B torso region is out of bounds: $($region.Name)."
                exit 1
            }

            $minimumX = $region.W
            $minimumY = $region.H
            $maximumX = -1
            $maximumY = -1
            $nearMaximumRows = 0
            $rowWidths = [System.Collections.Generic.List[int]]::new()
            for ($localY = 0; $localY -lt $region.H; $localY++) {
                $rowMinimum = $region.W
                $rowMaximum = -1
                for ($localX = 0; $localX -lt $region.W; $localX++) {
                    if ($baseBitmap.GetPixel(
                            $region.X + $localX,
                            $region.Y + $localY
                        ).A -le 8) {
                        continue
                    }
                    $minimumX = [Math]::Min($minimumX, $localX)
                    $minimumY = [Math]::Min($minimumY, $localY)
                    $maximumX = [Math]::Max($maximumX, $localX)
                    $maximumY = [Math]::Max($maximumY, $localY)
                    $rowMinimum = [Math]::Min($rowMinimum, $localX)
                    $rowMaximum = [Math]::Max($rowMaximum, $localX)
                }
                $rowWidths.Add($(if ($rowMaximum -ge 0) {
                            $rowMaximum - $rowMinimum + 1
                        } else {
                            0
                        }))
            }
            if ($maximumX -lt 0 -or $minimumX -lt 1 -or $minimumY -lt 1 -or
                $maximumX -gt $region.W - 2 -or $maximumY -gt $region.H - 2) {
                Write-Error "Prompt 25B torso region is empty or lacks an alpha-safe packing margin: $($region.Name)."
                exit 1
            }

            $alphaWidth = $maximumX - $minimumX + 1
            $alphaHeight = $maximumY - $minimumY + 1
            $maximumRowWidth = ($rowWidths | Measure-Object -Maximum).Maximum
            foreach ($rowWidth in $rowWidths) {
                if ($rowWidth -ge $maximumRowWidth - 2) {
                    $nearMaximumRows++
                }
            }
            if ($nearMaximumRows -lt 3) {
                Write-Error "Prompt 25B torso shoulder silhouette collapses to an isolated point: $($region.Name)."
                exit 1
            }

            $alphaAspect = [double]$alphaWidth / [double]$alphaHeight
            $authoredAspect = [double]$region.AuthW / [double]$region.AuthH
            $aspectRatio = $authoredAspect / $alphaAspect
            if ($aspectRatio -lt 0.82 -or $aspectRatio -gt 1.20) {
                Write-Error "Prompt 25B torso aspect distortion exceeds the accepted 0.82..1.20 band: $($region.Name)."
                exit 1
            }
        } finally {
            $baseBitmap.Dispose()
        }
    }

    Write-Host ("Prompt 25B art audit passed: 28 alpha-tight, non-aliased component regions; " +
        "2 compact front torso silhouettes; curved shoulder lead-in; aspect ratio band 0.82..1.20.")
} finally {
    $bitmap.Dispose()
}
