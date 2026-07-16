[CmdletBinding()]
param(
    [string]$DependencyRoot,
    [string]$LockFile,
    [switch]$Offline,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DependencyRoot)) {
    $DependencyRoot = Join-Path $repositoryRoot '.deps'
}
if ([string]::IsNullOrWhiteSpace($LockFile)) {
    $LockFile = Join-Path $PSScriptRoot 'dependencies.lock.json'
}

$DependencyRoot = [System.IO.Path]::GetFullPath($DependencyRoot)
$LockFile = [System.IO.Path]::GetFullPath($LockFile)
$manifestName = '.dependency-manifest.json'

function Get-Sha256Lower {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-ArchiveHash {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Label
    )

    $actual = Get-Sha256Lower -Path $Path
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "Rejected archive '$Label': SHA-256 mismatch. Expected $Expected, actual $actual, path '$Path'."
    }
}

function Assert-DirectChild {
    param(
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Child
    )

    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $childFull = [System.IO.Path]::GetFullPath($Child)
    $childParent = [System.IO.Path]::GetDirectoryName($childFull).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    if (-not $childParent.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing filesystem operation outside '$parentFull': '$childFull'."
    }
}

function Remove-OwnedTree {
    param(
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Assert-DirectChild -Parent $Parent -Child $Path
        Remove-Item -Recurse -Force -LiteralPath $Path
    }
}

function Remove-OwnedFile {
    param(
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Assert-DirectChild -Parent $Parent -Child $Path
        Remove-Item -Force -LiteralPath $Path
    }
}

function Test-RequiredPayload {
    param(
        [Parameter(Mandatory)][string]$PayloadRoot,
        [Parameter(Mandatory)]$Dependency
    )

    foreach ($relativePath in @($Dependency.required_paths)) {
        $required = Join-Path $PayloadRoot ([string]$relativePath)
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            return $false
        }
    }

    foreach ($identity in @($Dependency.identity_checks)) {
        $identityPath = Join-Path $PayloadRoot ([string]$identity.path)
        if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) {
            return $false
        }
        $actualText = (Get-Content -Raw -LiteralPath $identityPath).Trim()
        if ($actualText -ne [string]$identity.text) {
            return $false
        }
    }

    return $true
}

function Write-DependencyManifest {
    param(
        [Parameter(Mandatory)][string]$PayloadRoot,
        [Parameter(Mandatory)]$Dependency
    )

    $manifestPath = Join-Path $PayloadRoot $manifestName
    $files = @(
        Get-ChildItem -Recurse -File -LiteralPath $PayloadRoot |
            Where-Object { -not $_.FullName.Equals($manifestPath, [System.StringComparison]::OrdinalIgnoreCase) } |
            Sort-Object FullName |
            ForEach-Object {
                [ordered]@{
                    path = [System.IO.Path]::GetRelativePath($PayloadRoot, $_.FullName).Replace('\', '/')
                    length = $_.Length
                    sha256 = Get-Sha256Lower -Path $_.FullName
                }
            }
    )

    $manifest = [ordered]@{
        schema_version = 1
        name = [string]$Dependency.name
        version = [string]$Dependency.version
        archive_sha256 = ([string]$Dependency.sha256).ToLowerInvariant()
        files = $files
    }
    $json = $manifest | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Test-DependencyDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Dependency
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }
    if (-not (Test-RequiredPayload -PayloadRoot $Path -Dependency $Dependency)) {
        return $false
    }

    $manifestPath = Join-Path $Path $manifestName
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $false
    }

    try {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        if ([int]$manifest.schema_version -ne 1) { return $false }
        if ([string]$manifest.name -ne [string]$Dependency.name) { return $false }
        if ([string]$manifest.version -ne [string]$Dependency.version) { return $false }
        if ([string]$manifest.archive_sha256 -ne ([string]$Dependency.sha256).ToLowerInvariant()) { return $false }

        $recordedFiles = @($manifest.files)
        $actualFiles = @(
            Get-ChildItem -Recurse -File -LiteralPath $Path |
                Where-Object { -not $_.FullName.Equals($manifestPath, [System.StringComparison]::OrdinalIgnoreCase) }
        )
        if ($recordedFiles.Count -ne $actualFiles.Count) { return $false }

        $rootPrefix = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($file in $recordedFiles) {
            if (-not $seenPaths.Add([string]$file.path)) { return $false }
            $candidate = [System.IO.Path]::GetFullPath((Join-Path $Path ([string]$file.path)))
            if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $false }
            $item = Get-Item -LiteralPath $candidate
            if ($item.Length -ne [long]$file.length) { return $false }
            if ((Get-Sha256Lower -Path $candidate) -ne [string]$file.sha256) { return $false }
        }
    }
    catch {
        return $false
    }

    return $true
}

function Get-VerifiedArchive {
    param(
        [Parameter(Mandatory)]$Dependency,
        [Parameter(Mandatory)][string]$CacheRoot
    )

    $archivePath = Join-Path $CacheRoot ([string]$Dependency.archive_file)
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        try {
            Assert-ArchiveHash -Path $archivePath -Expected ([string]$Dependency.sha256) -Label ([string]$Dependency.name)
            return $archivePath
        }
        catch {
            if ($Offline) {
                throw
            }
            Write-Warning $_.Exception.Message
        }
    }
    elseif ($Offline) {
        throw "Offline bootstrap requires verified cache archive '$archivePath'."
    }

    $downloadPath = Join-Path $CacheRoot ('.{0}.{1}.download' -f [string]$Dependency.archive_file, [System.Guid]::NewGuid().ToString('N'))
    try {
        Write-Host "Downloading $($Dependency.name) $($Dependency.version) from $($Dependency.url)"
        Invoke-WebRequest -Uri ([string]$Dependency.url) -OutFile $downloadPath
        Assert-ArchiveHash -Path $downloadPath -Expected ([string]$Dependency.sha256) -Label ([string]$Dependency.name)
        Remove-OwnedFile -Parent $CacheRoot -Path $archivePath
        Move-Item -LiteralPath $downloadPath -Destination $archivePath
        return $archivePath
    }
    finally {
        Remove-OwnedFile -Parent $CacheRoot -Path $downloadPath
    }
}

function Install-Dependency {
    param(
        [Parameter(Mandatory)]$Dependency,
        [Parameter(Mandatory)][string]$CacheRoot
    )

    $target = Join-Path $DependencyRoot ([string]$Dependency.install_directory)
    Assert-DirectChild -Parent $DependencyRoot -Child $target
    if (Test-DependencyDirectory -Path $target -Dependency $Dependency) {
        Write-Host "Verified existing $($Dependency.name) $($Dependency.version) at '$target'."
        return
    }

    if (Test-Path -LiteralPath $target) {
        Write-Warning "Existing dependency directory '$target' is partial or corrupt and will not be accepted."
    }

    $archivePath = Get-VerifiedArchive -Dependency $Dependency -CacheRoot $CacheRoot
    $suffix = [System.Guid]::NewGuid().ToString('N')
    $stageContainer = Join-Path $DependencyRoot ('.stage-{0}-{1}' -f [string]$Dependency.name, $suffix)
    $extractRoot = Join-Path $stageContainer 'extracted'
    $backup = Join-Path $DependencyRoot ('.replaced-{0}-{1}' -f [string]$Dependency.name, $suffix)
    Assert-DirectChild -Parent $DependencyRoot -Child $stageContainer
    Assert-DirectChild -Parent $DependencyRoot -Child $backup

    $backupCreated = $false
    $targetInstalled = $false
    try {
        New-Item -ItemType Directory -Path $extractRoot | Out-Null
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot

        $archiveRoot = [string]$Dependency.archive_root
        $payload = if ([string]::IsNullOrEmpty($archiveRoot)) { $extractRoot } else { Join-Path $extractRoot $archiveRoot }
        if (-not (Test-Path -LiteralPath $payload -PathType Container)) {
            throw "Archive '$archivePath' does not contain expected root '$archiveRoot'."
        }
        if (-not (Test-RequiredPayload -PayloadRoot $payload -Dependency $Dependency)) {
            throw "Archive '$archivePath' is missing required $($Dependency.name) payload files."
        }

        Write-DependencyManifest -PayloadRoot $payload -Dependency $Dependency
        if (-not (Test-DependencyDirectory -Path $payload -Dependency $Dependency)) {
            throw "Staged $($Dependency.name) payload failed its complete manifest verification."
        }

        if (Test-Path -LiteralPath $target) {
            Move-Item -LiteralPath $target -Destination $backup
            $backupCreated = $true
        }
        Move-Item -LiteralPath $payload -Destination $target
        $targetInstalled = $true

        if (-not (Test-DependencyDirectory -Path $target -Dependency $Dependency)) {
            throw "Installed $($Dependency.name) directory failed post-move verification."
        }

        if ($backupCreated) {
            Remove-OwnedTree -Parent $DependencyRoot -Path $backup
            $backupCreated = $false
        }
        Write-Host "Installed and verified $($Dependency.name) $($Dependency.version) at '$target'."
    }
    catch {
        if ($targetInstalled) {
            Remove-OwnedTree -Parent $DependencyRoot -Path $target
            $targetInstalled = $false
        }
        if ($backupCreated) {
            Move-Item -LiteralPath $backup -Destination $target
            $backupCreated = $false
        }
        throw
    }
    finally {
        Remove-OwnedTree -Parent $DependencyRoot -Path $stageContainer
    }
}

function Invoke-BootstrapSelfTest {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('2d Renderer bootstrap self-test ' + [System.Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $testRoot | Out-Null
        $archive = Join-Path $testRoot 'corrupt.zip'
        [System.IO.File]::WriteAllBytes($archive, [byte[]](0x50, 0x4b, 0x03, 0x04, 0xde, 0xad, 0xbe, 0xef))
        $rejected = $false
        try {
            Assert-ArchiveHash -Path $archive -Expected ('0' * 64) -Label 'self-test archive'
        }
        catch {
            $rejected = $_.Exception.Message.Contains('SHA-256 mismatch')
        }
        if (-not $rejected) {
            throw 'Hash rejection self-test did not reject corrupt archive bytes.'
        }
        Write-Host 'Hash rejection self-test passed.'

        $dependency = [pscustomobject]@{
            name = 'self-test dependency'
            version = '1.0.0'
            sha256 = ('a' * 64)
            required_paths = @('required.txt')
            identity_checks = @([pscustomobject]@{ path = 'required.txt'; text = 'expected identity' })
        }
        $payload = Join-Path $testRoot 'payload'
        New-Item -ItemType Directory -Path $payload | Out-Null
        if (Test-DependencyDirectory -Path $payload -Dependency $dependency) {
            throw 'Partial dependency directory self-test was incorrectly accepted.'
        }

        [System.IO.File]::WriteAllText((Join-Path $payload 'required.txt'), 'expected identity', [System.Text.UTF8Encoding]::new($false))
        Write-DependencyManifest -PayloadRoot $payload -Dependency $dependency
        if (-not (Test-DependencyDirectory -Path $payload -Dependency $dependency)) {
            throw 'Complete dependency directory self-test was incorrectly rejected.'
        }

        [System.IO.File]::WriteAllText((Join-Path $payload 'required.txt'), 'corrupt identity', [System.Text.UTF8Encoding]::new($false))
        if (Test-DependencyDirectory -Path $payload -Dependency $dependency) {
            throw 'Corrupt dependency directory self-test was incorrectly accepted.'
        }
        Write-Host 'Partial and corrupt dependency directory rejection self-tests passed.'
    }
    finally {
        $tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        $testFull = [System.IO.Path]::GetFullPath($testRoot)
        if ((Test-Path -LiteralPath $testFull) -and $testFull.StartsWith($tempParent + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -Recurse -Force -LiteralPath $testFull
        }
    }
}

$zigCommand = Get-Command zig -ErrorAction Stop
$zigVersion = (& $zigCommand.Source version).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Failed to execute Zig compiler at '$($zigCommand.Source)'."
}

$lock = Get-Content -Raw -LiteralPath $LockFile | ConvertFrom-Json
if ([int]$lock.schema_version -ne 1) {
    throw "Unsupported dependency lock schema '$($lock.schema_version)' in '$LockFile'."
}
if ($zigVersion -ne [string]$lock.zig_version) {
    throw "Dependency bootstrap requires Zig $($lock.zig_version), active compiler is $zigVersion."
}

if ($SelfTest) {
    Invoke-BootstrapSelfTest
    exit 0
}

New-Item -ItemType Directory -Force -Path $DependencyRoot | Out-Null
$cacheRoot = Join-Path $DependencyRoot 'cache'
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

foreach ($dependency in @($lock.dependencies)) {
    Install-Dependency -Dependency $dependency -CacheRoot $cacheRoot
}

Write-Host "Dependency bootstrap completed for Zig $zigVersion."
