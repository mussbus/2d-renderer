[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceFiles = @(
    Get-ChildItem -File -Recurse -LiteralPath (Join-Path $repositoryRoot 'src'), (Join-Path $repositoryRoot 'tests'), (Join-Path $repositoryRoot 'assets') -ErrorAction Stop |
        Where-Object { $_.Extension -in @('.zig', '.hlsl') }
)
$sourceFiles += @(
    Get-ChildItem -File -LiteralPath (Join-Path $repositoryRoot 'tools') -ErrorAction Stop |
        Where-Object { $_.Extension -in @('.ps1', '.json') }
)
$sourceFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'build.zig')
$sourceFiles += Get-Item -LiteralPath (Join-Path $repositoryRoot 'build.zig.zon')

$forbiddenPatterns = @(
    'SDL_' + 'Renderer',
    'SDL_' + 'RenderTexture',
    'SDL_' + 'RenderGeometry',
    'Open' + 'GL',
    'ray' + 'lib',
    'S' + 'FML'
)
$unfinishedPatterns = @(
    'TO' + 'DO',
    'FIX' + 'ME',
    'un' + 'reachable',
    'Skip' + 'ZigTest',
    'testing.' + 'skip'
)

$failed = $false
foreach ($pattern in $forbiddenPatterns) {
    $matches = @(Select-String -LiteralPath $sourceFiles.FullName -SimpleMatch -CaseSensitive -Pattern $pattern)
    foreach ($match in $matches) {
        Write-Error "Forbidden source symbol '$pattern' at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($pattern in $unfinishedPatterns) {
    $matches = @(Select-String -LiteralPath $sourceFiles.FullName -SimpleMatch -CaseSensitive:$false -Pattern $pattern)
    foreach ($match in $matches) {
        Write-Error "Unfinished source marker '$pattern' at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

$gpuSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/gpu_demo.zig')
$batchSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/sprite_batch.zig')
$skeletonSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/skeleton.zig')
$poseSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/pose.zig')
$humanoidSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/humanoid.zig')
$mathSource = @(
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/math/vec2.zig')
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/math/mat3.zig')
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/math/transform2d.zig')
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/math/interpolation.zig')
) -join [Environment]::NewLine
$ownershipPairs = @(
    @('SDL_CreateGPUDeviceWithProperties', 'SDL_DestroyGPUDevice'),
    @('SDL_ClaimWindowForGPUDevice', 'SDL_ReleaseWindowFromGPUDevice'),
    @('SDL_CreateGPUShader', 'SDL_ReleaseGPUShader'),
    @('SDL_CreateGPUSampler', 'SDL_ReleaseGPUSampler'),
    @('SDL_CreateGPUTexture', 'SDL_ReleaseGPUTexture'),
    @('SDL_CreateGPUBuffer', 'SDL_ReleaseGPUBuffer'),
    @('SDL_CreateGPUTransferBuffer', 'SDL_ReleaseGPUTransferBuffer'),
    @('SDL_CreateGPUGraphicsPipeline', 'SDL_ReleaseGPUGraphicsPipeline'),
    @('SDL_SubmitGPUCommandBufferAndAcquireFence', 'SDL_ReleaseGPUFence')
)
foreach ($pair in $ownershipPairs) {
    if (-not $gpuSource.Contains($pair[0]) -or -not $gpuSource.Contains($pair[1])) {
        Write-Error "GPU ownership audit requires both '$($pair[0])' and '$($pair[1])'." -ErrorAction Continue
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

$drawSymbol = 'SDL_' + 'DrawGPUIndexedPrimitives'
$drawCallCount = [regex]::Matches($gpuSource, ('c\.' + $drawSymbol + '\s*\(')).Count
if ($drawCallCount -ne 1) {
    Write-Error "The authoritative sprite batch must own exactly one '$drawSymbol' call site; found $drawCallCount." -ErrorAction Continue
    $failed = $true
}

$legacyPatterns = @(
    'fn encode' + 'Draw',
    'fn render' + 'VisibleFrame',
    'instance_' + 'upload_offset',
    'const inst' + 'ances ='
)
foreach ($pattern in $legacyPatterns) {
    if (@(Select-String -LiteralPath $sourceFiles.FullName -SimpleMatch -CaseSensitive -Pattern $pattern).Count -ne 0) {
        Write-Error "Legacy direct-quad marker '$pattern' remains in executable source." -ErrorAction Continue
        $failed = $true
    }
}

if ([regex]::Matches($gpuSource, 'c\.SDL_CreateGPUGraphicsPipeline\s*\(').Count -ne 1 -or
    [regex]::Matches($gpuSource, 'c\.SDL_CreateGPUTexture\s*\(').Count -ne 1) {
    Write-Error 'Persistent pipeline and texture creation must remain centralized initialization helpers, not frame-loop calls.' -ErrorAction Continue
    $failed = $true
}

if ([regex]::IsMatch($gpuSource, 'frame_metrics\.draw_calls\s*=\s*[1-9]')) {
    Write-Error 'Hard-coded nonzero draw-call metrics are forbidden.' -ErrorAction Continue
    $failed = $true
}

if ([regex]::IsMatch($batchSource, '(?i)(sort|order)[^\r\n]*f32|f32[^\r\n]*(sort|order)')) {
    Write-Error 'Float values must not be the authoritative sprite ordering key.' -ErrorAction Continue
    $failed = $true
}

$gpuLayout = [regex]::Match($batchSource, 'pub const GpuInstance = extern struct \{(.*?)\r?\n\};', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $gpuLayout.Success -or [regex]::IsMatch($gpuLayout.Groups[1].Value, '\[\]|\*|\?|\bbool\b|\benum\b|\busize\b')) {
    Write-Error 'GpuInstance must remain an explicit fixed-scalar layout without pointers, slices, optionals, bools, enums, or usize.' -ErrorAction Continue
    $failed = $true
}

$cpuHierarchySource = $skeletonSource + [Environment]::NewLine + $poseSource + [Environment]::NewLine + $humanoidSource
if ([regex]::IsMatch($cpuHierarchySource, 'SDL_(Draw|CreateGPU|BindGPU|UploadToGPU)')) {
    Write-Error 'CPU hierarchy, pose, and attachment code must not contain a direct GPU path or create GPU resources.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($humanoidSource, '\bbatch\.submit\s*\(').Count -ne 1) {
    Write-Error 'Humanoid attachments must enter the renderer through exactly one SpriteBatch submission site.' -ErrorAction Continue
    $failed = $true
}

$boneDefinition = [regex]::Match($skeletonSource, 'pub const BoneDefinition = struct \{(.*?)\r?\n\};', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $boneDefinition.Success -or [regex]::IsMatch($boneDefinition.Groups[1].Value, '\*|\[\]|\?\s*\*|\ballocator\b')) {
    Write-Error 'BoneDefinition must remain an inline index-based record without pointers, slices, or per-bone allocators.' -ErrorAction Continue
    $failed = $true
}
if (-not $skeletonSource.Contains('allocator.alloc(BoneDefinition, bone_inputs.len)') -or
    -not $poseSource.Contains('allocator.alloc(math.Transform2D, definition.boneCount())') -or
    -not $poseSource.Contains('allocator.alloc(math.Mat3, definition.boneCount())')) {
    Write-Error 'Bones and local/world poses must remain contiguous array allocations.' -ErrorAction Continue
    $failed = $true
}

$skeletonFieldsStart = $skeletonSource.IndexOf('pub const SkeletonDefinition = struct {')
$skeletonFieldsEnd = $skeletonSource.IndexOf('    pub fn initHumanoid', $skeletonFieldsStart)
if ($skeletonFieldsStart -lt 0 -or $skeletonFieldsEnd -lt 0) {
    Write-Error 'Could not audit SkeletonDefinition fields.' -ErrorAction Continue
    $failed = $true
} else {
    $skeletonFields = $skeletonSource.Substring($skeletonFieldsStart, $skeletonFieldsEnd - $skeletonFieldsStart)
    if ([regex]::IsMatch($skeletonFields, 'local_transforms|world_transforms|current_pose|character_to_world|GPU')) {
        Write-Error 'Immutable SkeletonDefinition must not contain mutable pose, character-world, or GPU state.' -ErrorAction Continue
        $failed = $true
    }
}

$attachmentMatch = [regex]::Match($humanoidSource, 'pub const RenderAttachment = struct \{(.*?)\r?\n\};', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $attachmentMatch.Success -or [regex]::IsMatch($attachmentMatch.Groups[1].Value, '\bworld(_transform|_position)?\b')) {
    Write-Error 'RenderAttachment must retain only local metadata and must not store authoritative world transforms.' -ErrorAction Continue
    $failed = $true
}

function Get-FunctionSection {
    param(
        [string]$Source,
        [string]$StartMarker,
        [string]$EndMarker
    )
    $start = $Source.IndexOf($StartMarker)
    $end = $Source.IndexOf($EndMarker, $start + $StartMarker.Length)
    if ($start -lt 0 -or $end -lt 0) {
        throw "Could not audit function section '$StartMarker'."
    }
    return $Source.Substring($start, $end - $start)
}

$hotSections = @(
    Get-FunctionSection $poseSource '    pub fn evaluateWorld' '    pub fn worldForBone'
    Get-FunctionSection $poseSource '    pub fn socketWorld' '    pub fn socketPosition'
    Get-FunctionSection $humanoidSource '    pub fn applyProgrammaticPose' '    pub fn submitAttachments'
    Get-FunctionSection $humanoidSource '    pub fn submitAttachments' '    pub fn attachmentWorld'
)
foreach ($section in $hotSections) {
    if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|std\.mem\.eql')) {
        Write-Error 'Pose evaluation, socket evaluation, pose changes, and humanoid submission must remain allocation- and string-lookup-free.' -ErrorAction Continue
        $failed = $true
    }
}

if ([regex]::IsMatch($mathSource, '(?i)(lerp|interpolate)[^\r\n]*Mat3|Mat3[^\r\n]*(lerp|interpolate)')) {
    Write-Error 'Matrix-element interpolation is forbidden; transforms must interpolate components.' -ErrorAction Continue
    $failed = $true
}

if ($failed) {
    exit 1
}

Write-Host "Repository source audit passed for $($sourceFiles.Count) files."
Write-Host 'Forbidden SDL high-level renderer and alternate-renderer symbols are absent.'
Write-Host ('No unfinished markers, un' + 'reachable paths, or skipped-test markers were found.')
Write-Host 'Every GPU acquisition family has a matching release operation.'
Write-Host 'Exactly one authoritative indexed-instanced sprite draw site exists; legacy direct-quad markers are absent.'
Write-Host 'GPU instance layout, integer ordering, actual metrics, and persistent-resource creation policies passed static checks.'
Write-Host 'Prompt 3 hierarchy audit passed: no direct body-part GPU path, pointer graph, per-bone allocation, mutable definition pose, stored attachment world pose, hot-path allocation/string lookup, or matrix interpolation.'
