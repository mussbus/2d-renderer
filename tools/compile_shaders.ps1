[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DxcPath,
    [Parameter(Mandatory)][string]$DxcompilerPath,
    [Parameter(Mandatory)][string]$DxilPath,
    [Parameter(Mandatory)][string]$DxvPath,
    [Parameter(Mandatory)][string]$LockFile,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][ValidateSet('vertex', 'fragment')][string]$Stage,
    [Parameter(Mandatory)][string]$EntryPoint,
    [Parameter(Mandatory)][string]$TargetProfile,
    [Parameter(Mandatory)][string]$BuildConfiguration,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DxcPath = [System.IO.Path]::GetFullPath($DxcPath)
$DxcompilerPath = [System.IO.Path]::GetFullPath($DxcompilerPath)
$DxilPath = [System.IO.Path]::GetFullPath($DxilPath)
$DxvPath = [System.IO.Path]::GetFullPath($DxvPath)
$LockFile = [System.IO.Path]::GetFullPath($LockFile)
$SourcePath = [System.IO.Path]::GetFullPath($SourcePath)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

foreach ($requiredPath in @($DxcPath, $DxcompilerPath, $DxilPath, $DxvPath, $LockFile, $SourcePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Shader build input '$requiredPath' is missing."
    }
}

$lock = Get-Content -Raw -LiteralPath $LockFile | ConvertFrom-Json
$dxcLock = @($lock.dependencies) | Where-Object { $_.name -eq 'DXC' }
if ($dxcLock.Count -ne 1 -or [string]$dxcLock[0].version -ne '1.9.2602.24') {
    throw "Shader compilation requires locked DXC 1.9.2602.24 from '$LockFile'."
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($OutputPath)
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$temporaryOutput = $OutputPath + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp'

$compileArguments = @(
    '-nologo',
    '-E', $EntryPoint,
    '-T', $TargetProfile,
    '-HV', '2021',
    '-Ges',
    '-WX',
    '-Zpr',
    '-fdiagnostics-format=msvc'
)
if ($BuildConfiguration -eq 'Debug') {
    $compileArguments += @('-Od', '-Zi', '-Qembed_debug')
}
else {
    $compileArguments += @('-O3', '-Qstrip_debug', '-Qstrip_reflect')
}
$compileArguments += @('-Fo', $temporaryOutput, $SourcePath)

try {
    $compilerDiagnostics = (& $DxcPath @compileArguments 2>&1 | Out-String).Trim()
    $compilerExitCode = $LASTEXITCODE
    if ($compilerExitCode -ne 0) {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $OutputPath
        throw @"
Shader compiler failed.
Source: $SourcePath
Stage: $Stage
Entry point: $EntryPoint
Target profile: $TargetProfile
Build configuration: $BuildConfiguration
Compiler: $DxcPath
Exit code: $compilerExitCode
Diagnostics:
$compilerDiagnostics
"@
    }
    if (-not (Test-Path -LiteralPath $temporaryOutput -PathType Leaf)) {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $OutputPath
        throw "DXC reported success but did not create '$temporaryOutput' for '$SourcePath' ($Stage, $EntryPoint, $TargetProfile)."
    }

    $validatorDiagnostics = (& $DxvPath $temporaryOutput 2>&1 | Out-String).Trim()
    $validatorExitCode = $LASTEXITCODE
    if ($validatorExitCode -ne 0) {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $OutputPath
        throw @"
DXIL validation failed.
Source: $SourcePath
Stage: $Stage
Entry point: $EntryPoint
Target profile: $TargetProfile
Validator: $DxvPath
Exit code: $validatorExitCode
Diagnostics:
$validatorDiagnostics
"@
    }

    Move-Item -Force -LiteralPath $temporaryOutput -Destination $OutputPath
    Write-Host "Compiled '$SourcePath' stage '$Stage' entry '$EntryPoint' target '$TargetProfile' with DXC $($dxcLock[0].version) for '$BuildConfiguration'."
}
finally {
    Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $temporaryOutput
}

