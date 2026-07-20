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
$eventSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/events.zig')
$clipSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/clip.zig')
$stateMachineSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/state_machine.zig')
$animatorSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/animator.zig')
$authoredClipSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/authored_clips.zig')
$animationSystemSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/animation_system.zig')
$inputSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/platform/input.zig')
$sdlInputSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/platform/sdl_input.zig')
$fixedStepSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/physics/fixed_step.zig')
$colliderSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/physics/collider.zig')
$collisionWorldSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/physics/collision_world.zig')
$controllerSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/physics/character_controller.zig')
$controllerDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/controller_demo.zig')
$springSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/physics/spring.zig')
$proceduralMotionSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/procedural_motion.zig')
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

$animationSource = @(
    $eventSource
    $clipSource
    $stateMachineSource
    $animatorSource
    $authoredClipSource
    $animationSystemSource
) -join [Environment]::NewLine

if ([regex]::IsMatch($animationSource, 'SDL_|SpriteRequest|SpriteSubmission|batch\.submit\s*\(')) {
    Write-Error 'Animation definitions and hot paths must not manipulate renderer submissions or contain an SDL/GPU path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($animationSource, '(?i)(lerp|interpolate)[^\r\n]*Mat3|Mat3[^\r\n]*(lerp|interpolate)')) {
    Write-Error 'Animation must blend Transform2D components and must not interpolate matrix elements.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($animationSource, 'milliTimestamp|microTimestamp|nanoTimestamp|Instant\.now|Timer\.start|SDL_GetTicks')) {
    Write-Error 'Animator code must use caller-supplied deterministic delta and must not read a wall clock.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($animationSource, 'SDL_CreateGPU|createTexture|createBuffer|createPipeline')) {
    Write-Error 'Animation state changes must not create GPU resources.' -ErrorAction Continue
    $failed = $true
}

$clipFieldsStart = $clipSource.IndexOf('pub const ClipDefinition = struct {')
$clipFieldsEnd = $clipSource.IndexOf('    pub fn init(', $clipFieldsStart)
if ($clipFieldsStart -lt 0 -or $clipFieldsEnd -lt 0) {
    Write-Error 'Could not audit immutable ClipDefinition fields.' -ErrorAction Continue
    $failed = $true
} else {
    $clipFields = $clipSource.Substring($clipFieldsStart, $clipFieldsEnd - $clipFieldsStart)
    if ([regex]::IsMatch($clipFields, 'current_time|previous_time|loop_count|completed|state_entered|current_pose|world_transform|Mat3|GPU|renderer')) {
        Write-Error 'Immutable ClipDefinition contains mutable playback, sampled pose, world matrix, or renderer state.' -ErrorAction Continue
        $failed = $true
    }
}

if (-not $clipSource.Contains('bone_track_indices: []const ?u16') -or
    -not $clipSource.Contains('translation_keys: []const TranslationKey') -or
    -not $clipSource.Contains('rotation_keys: []const RotationKey') -or
    -not $clipSource.Contains('scale_keys: []const ScaleKey') -or
    -not $clipSource.Contains('event_records: []const events.EventRecord')) {
    Write-Error 'Clip definitions must retain contiguous immutable mapping, key, and event arrays.' -ErrorAction Continue
    $failed = $true
}

$clipHotStart = $clipSource.IndexOf('pub fn sampleWithSource')
$clipHotEnd = $clipSource.IndexOf('fn validateSamplingInputs', $clipHotStart)
$animatorHotStart = $animatorSource.IndexOf('    pub fn update(')
$animatorHotEnd = $animatorSource.IndexOf('    fn beginTransition(', $animatorHotStart)
$blendHotStart = $animatorSource.IndexOf('pub fn blendLocalPoses')
$blendHotEnd = $animatorSource.IndexOf('fn newPlayback', $blendHotStart)
if ($clipHotStart -lt 0 -or $clipHotEnd -lt 0 -or $animatorHotStart -lt 0 -or $animatorHotEnd -lt 0 -or $blendHotStart -lt 0 -or $blendHotEnd -lt 0) {
    Write-Error 'Could not audit animation sampling, update, and blending hot paths.' -ErrorAction Continue
    $failed = $true
} else {
    $animationHotSections = @(
        $clipSource.Substring($clipHotStart, $clipHotEnd - $clipHotStart)
        $animatorSource.Substring($animatorHotStart, $animatorHotEnd - $animatorHotStart)
        $animatorSource.Substring($blendHotStart, $blendHotEnd - $blendHotStart)
    )
    foreach ($section in $animationHotSections) {
        if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|HashMap|StringHashMap|std\.mem\.eql|degreesToRadians')) {
            Write-Error 'Animation sampling, blending, event traversal, transitions, and update must remain allocation-, hash-, and string-lookup-free.' -ErrorAction Continue
            $failed = $true
        }
    }
}

foreach ($requiredClip in @('createIdle', 'createWalk', 'createJumpStart', 'createRising', 'createFalling', 'createLanding', 'createHandshakeA', 'createHandshakeB')) {
    if (-not $authoredClipSource.Contains(('fn ' + $requiredClip + '('))) {
        Write-Error "Required authored clip function '$requiredClip' is absent." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::Matches($authoredClipSource, 'fn createHandshake(A|B)\(').Count -ne 2 -or
    [regex]::Matches($authoredClipSource, 'handshakeMotion\(').Count -lt 5 -or
    -not $authoredClipSource.Contains('hand_contact') -or
    -not $authoredClipSource.Contains('hand_release') -or
    -not $authoredClipSource.Contains('interaction_complete')) {
    Write-Error 'Both handshake clips must contain real arm tracks and the shared typed event timeline.' -ErrorAction Continue
    $failed = $true
}

if ($failed) {
    exit 1
}

$controllerSources = $fixedStepSource + [Environment]::NewLine + $colliderSource + [Environment]::NewLine +
    $collisionWorldSource + [Environment]::NewLine + $controllerSource + [Environment]::NewLine + $controllerDemoSource
if ([regex]::IsMatch($controllerSources, 'SDL_(GetKeyboardState|GetGamepad|OpenGamepad|PollEvent)')) {
    Write-Error 'SDL keyboard/gamepad access must remain isolated to PlatformInput.' -ErrorAction Continue
    $failed = $true
}
if (-not $sdlInputSource.Contains('pub const PlatformInput') -or
    -not $sdlInputSource.Contains('SDL_GetKeyboardState') -or
    -not $sdlInputSource.Contains('SDL_GetGamepadAxis') -or
    -not $sdlInputSource.Contains('SDL_EVENT_GAMEPAD_ADDED') -or
    -not $sdlInputSource.Contains('SDL_EVENT_GAMEPAD_REMOVED') -or
    -not $sdlInputSource.Contains('SDL_CloseGamepad')) {
    Write-Error 'PlatformInput must retain real pinned SDL keyboard/gamepad polling, hot-plug, and close paths.' -ErrorAction Continue
    $failed = $true
}
if (-not $fixedStepSource.Contains('pub const simulation_hz: u32 = 240') -or
    -not $controllerSource.Contains('fixed_step.fixed_dt_seconds') -or
    -not $controllerDemoSource.Contains('@floatCast(fixed_step.fixed_dt_seconds)')) {
    Write-Error 'Physics and gameplay animation must share the authoritative 240 Hz fixed timestep.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($controllerSource, 'position\.[xy]\s*=.*intent') -or
    [regex]::IsMatch($controllerDemoSource, '(?i)input[^\r\n]*position\s*=|position\s*=[^\r\n]*input')) {
    Write-Error 'Input may not directly assign authoritative character-world position.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($controllerSources, 'left_foot_contact|right_foot_contact')) {
    Write-Error 'Animation foot-contact events may not alter controller or collision grounding.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($controllerSources, 'SDL_CreateGPU|SDL_DrawGPU|createPipeline|createTexture')) {
    Write-Error 'Controller, collision, input, and fixed-step code may not create GPU resources or draw directly.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($controllerSources, 'pub const CollisionWorld\s*=\s*struct').Count -ne 1) {
    Write-Error 'Exactly one authoritative CollisionWorld representation is required.' -ErrorAction Continue
    $failed = $true
}
if (-not $inputSource.Contains('pub const CharacterIntent = extern struct') -or
    -not $inputSource.Contains('jump_pressed_pending') -or
    -not $inputSource.Contains('pub fn consumeTick')) {
    Write-Error 'Renderer-independent CharacterIntent and explicit pending-edge consumption are required.' -ErrorAction Continue
    $failed = $true
}

$controllerHotSections = @(
    Get-FunctionSection $inputSource '    pub fn acceptFrame' '    pub fn consumeTick'
    Get-FunctionSection $inputSource '    pub fn consumeTick' '    pub fn reset'
    Get-FunctionSection $fixedStepSource '    pub fn beginFrame' '    pub fn reset'
    Get-FunctionSection $controllerSource '    pub fn step(' '    pub fn interpolatedPosition'
    Get-FunctionSection $controllerDemoSource '    pub fn simulateTick' '    pub fn renderPosition'
)
foreach ($section in $controllerHotSections) {
    if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap')) {
        Write-Error 'Input, clock, controller, collision, animation selection, and interpolation hot paths must remain allocation-free.' -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($fixedStepSource, 'while\s*\(')) {
    Write-Error 'The fixed-step clock must not contain an unbounded accumulator loop.' -ErrorAction Continue
    $failed = $true
}

$proceduralStateStart = $proceduralMotionSource.IndexOf('pub const State = struct {')
$proceduralStateEnd = $proceduralMotionSource.IndexOf('pub fn walkAmplitudeForSpeed', $proceduralStateStart)
if ($proceduralStateStart -lt 0 -or $proceduralStateEnd -lt 0) {
    Write-Error 'Could not audit per-character procedural state fields.' -ErrorAction Continue
    $failed = $true
} else {
    $proceduralStateFields = $proceduralMotionSource.Substring($proceduralStateStart, $proceduralStateEnd - $proceduralStateStart)
    if ([regex]::IsMatch($proceduralStateFields, '\bphysics_position\b|\bphysics_velocity\b|\bgrounded\b|\bsupporting_collider\b|\bcollision_aabb\b|\bstatic_collision\b|GPU|renderer')) {
        Write-Error 'Procedural state may not duplicate authoritative physics, collision, GPU, or renderer state.' -ErrorAction Continue
        $failed = $true
    }
}

$proceduralSources = $springSource + [Environment]::NewLine + $proceduralMotionSource
if ([regex]::IsMatch($proceduralSources, 'SDL_|SpriteRequest|batch\.submit\s*\(|CreateGPU|createTexture|createBuffer|createPipeline')) {
    Write-Error 'Springs and procedural motion may not create GPU resources, submit sprites, or call SDL.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($proceduralMotionSource, 'raw_delta|raw_frame_delta|measured_delta|interpolation_alpha')) {
    Write-Error 'Raw render delta and interpolation state may not enter procedural spring simulation.' -ErrorAction Continue
    $failed = $true
}
if (-not $proceduralMotionSource.Contains('pub const procedural_fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds)') -or
    -not $proceduralMotionSource.Contains('if (procedural_fixed_dt != @as(f32, 1.0 / 240.0))')) {
    Write-Error 'Procedural motion must derive its only timestep from the authoritative fixed-step module.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($proceduralMotionSource, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|collider_half_extents\s*=|\.bounds\s*=')) {
    Write-Error 'Procedural motion may not mutate controller or collider authority.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($proceduralMotionSource, 'definition\.bones\s*\[.*\]\s*=|clips\s*\[.*\]\s*=')) {
    Write-Error 'Procedural motion may not mutate immutable skeleton definitions or clip keys.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($controllerDemoSource, 'runtime\.procedural\.update\s*\(').Count -ne 1 -or
    [regex]::Matches($controllerDemoSource, 'runtime\.procedural\.composePose\s*\(').Count -ne 1) {
    Write-Error 'Controller simulation must update and compose procedural motion exactly once per fixed tick.' -ErrorAction Continue
    $failed = $true
}

$proceduralHotSections = @(
    Get-FunctionSection $proceduralMotionSource '    pub fn update(' '    pub fn composePose'
    Get-FunctionSection $proceduralMotionSource '    pub fn composePose' '    fn consumeLandingEvent'
    Get-FunctionSection $springSource '    pub fn step(' '};'
)
foreach ($section in $proceduralHotSections) {
    if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap|StringHashMap')) {
        Write-Error 'Spring update and procedural pose composition must remain allocation-free.' -ErrorAction Continue
        $failed = $true
    }
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
Write-Host 'Prompt 4 animation audit passed: immutable packed clips, no renderer authority, no matrix interpolation, no mutable clip playback, no wall clock, no GPU creation, and allocation/string/hash-free sampling, blending, and animator update.'
Write-Host 'Prompt 5 controller audit passed: SDL isolation, 240 Hz clock agreement, pending edges, one collision world, no input position authority, no foot-event grounding, no controller GPU path, bounded accumulation, and allocation-free hot paths.'
Write-Host 'Prompt 6 procedural-motion audit passed: fixed-step-only bounded springs, one update/composition per tick, no duplicate physics authority, no controller/collider mutation, no GPU path, no immutable-definition mutation, and allocation-free hot paths.'
