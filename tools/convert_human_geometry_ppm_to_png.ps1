param(
    [string]$EvidenceDirectory = "assets/canonical_model/human_base/geometry/evidence/prompt_2b",
    [string]$ContactSheetName = "",
    [int]$ContactSheetColumns = 4,
    [int]$OutputWidth = 0,
    [int]$OutputHeight = 0
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Read-PpmToken {
    param(
        [byte[]]$Bytes,
        [ref]$Index
    )

    while ($Index.Value -lt $Bytes.Length) {
        $value = $Bytes[$Index.Value]
        if ($value -eq 35) {
            while ($Index.Value -lt $Bytes.Length -and $Bytes[$Index.Value] -ne 10) {
                $Index.Value++
            }
        }
        elseif ($value -in 9, 10, 13, 32) {
            $Index.Value++
        }
        else {
            break
        }
    }

    $start = $Index.Value
    while ($Index.Value -lt $Bytes.Length -and $Bytes[$Index.Value] -notin 9, 10, 13, 32) {
        $Index.Value++
    }
    if ($start -eq $Index.Value) {
        throw "Missing PPM header token."
    }
    return [System.Text.Encoding]::ASCII.GetString($Bytes, $start, $Index.Value - $start)
}

$resolvedDirectory = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $EvidenceDirectory))
if (-not [System.IO.Directory]::Exists($resolvedDirectory)) {
    throw "Evidence directory does not exist: $resolvedDirectory"
}

$converted = 0
$pngPaths = [System.Collections.Generic.List[string]]::new()
foreach ($ppmPath in [System.IO.Directory]::GetFiles($resolvedDirectory, "*.ppm") | Sort-Object) {
    $bytes = [System.IO.File]::ReadAllBytes($ppmPath)
    $index = 0
    $magic = Read-PpmToken -Bytes $bytes -Index ([ref]$index)
    $width = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    $height = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    $maximum = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    if ($magic -ne "P6" -or $maximum -ne 255 -or $width -le 0 -or $height -le 0) {
        throw "Unsupported PPM header in $ppmPath"
    }
    while ($index -lt $bytes.Length -and $bytes[$index] -in 9, 10, 13, 32) {
        $index++
    }
    $expectedLength = $width * $height * 3
    if ($bytes.Length - $index -ne $expectedLength) {
        throw "PPM pixel payload length mismatch in $ppmPath"
    }

    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $rectangle = [System.Drawing.Rectangle]::new(0, 0, $width, $height)
        $data = $bitmap.LockBits($rectangle, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $row = [byte[]]::new([Math]::Abs($data.Stride))
            for ($y = 0; $y -lt $height; $y++) {
                [Array]::Clear($row, 0, $row.Length)
                $sourceOffset = $index + $y * $width * 3
                for ($x = 0; $x -lt $width; $x++) {
                    $source = $sourceOffset + $x * 3
                    $destination = $x * 3
                    $row[$destination] = $bytes[$source + 2]
                    $row[$destination + 1] = $bytes[$source + 1]
                    $row[$destination + 2] = $bytes[$source]
                }
                $destinationPointer = [IntPtr]::Add($data.Scan0, $y * $data.Stride)
                [Runtime.InteropServices.Marshal]::Copy($row, 0, $destinationPointer, $row.Length)
            }
        }
        finally {
            $bitmap.UnlockBits($data)
        }
        $pngPath = [System.IO.Path]::ChangeExtension($ppmPath, ".png")
        if ($OutputWidth -gt 0 -and $OutputHeight -gt 0) {
            $reviewBitmap = [System.Drawing.Bitmap]::new($OutputWidth, $OutputHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $reviewGraphics = [System.Drawing.Graphics]::FromImage($reviewBitmap)
                try {
                    $reviewGraphics.Clear([System.Drawing.Color]::White)
                    $reviewGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                    $reviewGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $reviewGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $reviewGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $reviewGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $reviewGraphics.DrawImage($bitmap, 0, 0, $OutputWidth, $OutputHeight)
                }
                finally {
                    $reviewGraphics.Dispose()
                }
                $reviewBitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $reviewBitmap.Dispose()
            }
        }
        else {
            $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        $pngPaths.Add($pngPath)
        $converted++
    }
    finally {
        $bitmap.Dispose()
    }
}

if ($ContactSheetName.Length -gt 0) {
    if ($ContactSheetColumns -lt 1) {
        throw "ContactSheetColumns must be positive."
    }
    $tileWidth = 320
    $tileHeight = 400
    $labelHeight = 40
    $rows = [int][Math]::Ceiling($pngPaths.Count / [double]$ContactSheetColumns)
    $sheet = [System.Drawing.Bitmap]::new(
        $ContactSheetColumns * $tileWidth,
        $rows * ($tileHeight + $labelHeight),
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    $font = [System.Drawing.Font]::new([System.Drawing.FontFamily]::GenericSansSerif, 10)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(30, 35, 45))
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        for ($imageIndex = 0; $imageIndex -lt $pngPaths.Count; $imageIndex++) {
            $column = $imageIndex % $ContactSheetColumns
            $rowIndex = [int][Math]::Floor($imageIndex / [double]$ContactSheetColumns)
            $x = $column * $tileWidth
            $y = $rowIndex * ($tileHeight + $labelHeight)
            $source = [System.Drawing.Image]::FromFile($pngPaths[$imageIndex])
            try {
                $graphics.DrawImage($source, $x, $y, $tileWidth, $tileHeight)
            }
            finally {
                $source.Dispose()
            }
            $label = [System.IO.Path]::GetFileNameWithoutExtension($pngPaths[$imageIndex]).Replace("human_base_main_body_", "")
            $graphics.DrawString($label, $font, $brush, [single]($x + 6), [single]($y + $tileHeight + 8))
        }
        $sheetPath = Join-Path $resolvedDirectory $ContactSheetName
        $sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $brush.Dispose()
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

Write-Output "Converted $converted deterministic PPM evidence files to PNG inspection copies."
if ($ContactSheetName.Length -gt 0) {
    Write-Output "Created owner-review contact sheet: $ContactSheetName"
}
