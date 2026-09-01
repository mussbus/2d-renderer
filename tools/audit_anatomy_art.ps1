param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$pages = @(
    @{ path = 'assets/art/male_base_anatomy_atlas.png'; width = 1600; height = 983 },
    @{ path = 'assets/art/female_base_anatomy_atlas.png'; width = 1599; height = 984 },
    @{ path = 'assets/art/anatomy_components_atlas.png'; width = 1792; height = 1024 }
)
foreach ($page in $pages) {
    $path = Join-Path $RepositoryRoot $page.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Prompt 27C production art is missing: $path"
    }
    $bitmap = [System.Drawing.Bitmap]::new($path)
    try {
        if ($bitmap.Width -ne $page.width -or $bitmap.Height -ne $page.height) {
            throw "Prompt 27C atlas dimensions changed: $($page.path)"
        }
        $opaque = 0
        $transparent = 0
        for ($y = 0; $y -lt $bitmap.Height; $y += 8) {
            for ($x = 0; $x -lt $bitmap.Width; $x += 8) {
                if ($bitmap.GetPixel($x, $y).A -ge 16) {
                    $opaque++
                }
                else {
                    $transparent++
                }
            }
        }
        if ($opaque -eq 0 -or $transparent -eq 0) {
            throw "Prompt 27C atlas lacks real alpha separation: $($page.path)"
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

$componentPath = Join-Path $RepositoryRoot 'assets/art/anatomy_components_atlas.png'
$component = [System.Drawing.Bitmap]::new($componentPath)
try {
    $regions = @(
        @(72,103,102,53), @(335,111,87,26), @(612,111,55,34),
        @(857,51,60,155), @(1124,55,37,118), @(1373,103,70,49),
        @(1608,65,63,98), @(209,317,38,110), @(364,334,28,81),
        @(623,352,33,64), @(869,306,54,122), @(1123,313,39,104),
        @(1374,358,67,51), @(1607,292,122,70),
        @(72,617,102,52), @(335,624,87,27), @(612,624,55,31),
        @(854,563,62,155), @(1125,567,38,118), @(1373,616,70,48),
        @(1606,580,62,98), @(209,827,37,110), @(364,845,28,81),
        @(624,864,31,64), @(855,819,60,122), @(1126,817,40,104),
        @(1379,868,58,56), @(1580,833,128,66)
    )
    $index = 0
    foreach ($region in $regions) {
        $index++
        $opaque = 0
        for ($y = 0; $y -lt $region[3]; $y++) {
            for ($x = 0; $x -lt $region[2]; $x++) {
                if ($component.GetPixel(
                    $region[0] + $x,
                    $region[1] + $y
                ).A -ge 16) {
                    $opaque++
                }
            }
        }
        if ($opaque -eq 0) {
            throw "Prompt 27C component region $index is empty."
        }
    }
}
finally {
    $component.Dispose()
}

$oldHashes = @(
    (Get-FileHash -Algorithm SHA256 (
        Join-Path $RepositoryRoot 'assets/art/p25a_male_base_anatomy_atlas.png'
    )).Hash,
    (Get-FileHash -Algorithm SHA256 (
        Join-Path $RepositoryRoot 'assets/art/p25a_female_base_anatomy_atlas.png'
    )).Hash,
    (Get-FileHash -Algorithm SHA256 (
        Join-Path $RepositoryRoot 'assets/art/p25b_anatomy_components_atlas.png'
    )).Hash
)
for ($index = 0; $index -lt $pages.Count; $index++) {
    $newHash = (Get-FileHash -Algorithm SHA256 (
        Join-Path $RepositoryRoot $pages[$index].path
    )).Hash
    if ($newHash -eq $oldHashes[$index]) {
        throw "Prompt 27C page was not versioned from its preserved predecessor."
    }
}

Write-Host (
    'Prompt 27C art audit passed: 3 versioned RGBA pages, exact dimensions, ' +
    '28 nonempty semantic component regions, preserved predecessor hashes.'
)
