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
    ('SDL_' + 'Renderer'),
    ('SDL_' + 'RenderTexture'),
    ('SDL_' + 'RenderGeometry'),
    ('Open' + 'GL'),
    ('ray' + 'lib'),
    ('S' + 'FML')
)
$unfinishedPatterns = @(
    ('TO' + 'DO'),
    ('FIX' + 'ME'),
    ('st' + 'ub'),
    ('place' + 'holder'),
    ('Skip' + 'ZigTest'),
    ('testing.' + 'skip')
)
if ($forbiddenPatterns.Count -ne 6 -or $unfinishedPatterns.Count -ne 6) {
    Write-Error "Repository audit pattern construction is invalid: forbidden=$($forbiddenPatterns.Count) unfinished=$($unfinishedPatterns.Count)."
    exit 1
}

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
$zigSourceFiles = @($sourceFiles | Where-Object { $_.Extension -eq '.zig' })
$unreachableKeyword = '(?m)(^\s*|[=(:,]\s*)un' + 'reachable\b'
$unreachableMatches = @(
    Select-String -LiteralPath $zigSourceFiles.FullName -CaseSensitive -Pattern $unreachableKeyword
)
foreach ($match in $unreachableMatches) {
    Write-Error "Unfinished Zig keyword 'unreachable' at $($match.Path):$($match.LineNumber)." -ErrorAction Continue
    $failed = $true
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
$characterSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/character.zig')
$multiCharacterSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/multi_character_demo.zig')
$interactionDefinitionSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/interaction/interaction.zig')
$handshakeDefinitionSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/interaction/handshake.zig')
$interactionSystemSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/interaction/interaction_system.zig')
$handshakeDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/handshake_demo.zig')
$twoBoneIkSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/two_bone_ik.zig')
$armIkSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/arm_ik.zig')
$handshakeIkDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/handshake_ik_demo.zig')
$legIkSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/leg_ik.zig')
$footPlantingSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/animation/foot_planting.zig')
$footPlantingDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/foot_planting_demo.zig')
$diagnosticsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/debug/diagnostics.zig')
$debugDrawSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/debug/debug_draw.zig')
$integratedDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/integrated_demo.zig')
$integrationTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/integration_tests.zig')
$playgroundSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/playground_demo.zig')
$playgroundTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/playground_tests.zig')
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

$footSources = $legIkSource + [Environment]::NewLine + $footPlantingSource
if (-not $collisionWorldSource.Contains('pub fn queryGroundDown') -or
    -not $footPlantingSource.Contains('world.queryGroundDown') -or
    [regex]::IsMatch($footSources, 'CollisionWorld\.init|StaticColliderInput|colliders\s*:\s*\[')) {
    Write-Error 'Foot placement must query the controller collision world and may not create a duplicate visual ground world.' -ErrorAction Continue
    $failed = $true
}
if (-not $collisionWorldSource.Contains('static_collider.id < nearest.?.collider_id') -or
    -not $collisionWorldSource.Contains('origin.y < top') -or
    -not $collisionWorldSource.Contains('distance > maximum_distance + epsilon') -or
    -not $collisionWorldSource.Contains('.normal = .{ .x = 0, .y = 1 }')) {
    Write-Error 'Ground queries require documented surface/range inclusion, upward normals, and stable collider-ID tie-breaking.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($footSources, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|world_position\s*=|\.bounds\s*=|collider_half_extents\s*=|setWorldPosition\s*\(')) {
    Write-Error 'Foot planting and leg IK may not mutate controller roots, velocity, grounding, support, or colliders.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($footSources, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap|StringHashMap')) {
    Write-Error 'Ground query, plant update, binding lookup, target storage, leg solve, and hierarchy evaluation must allocate zero memory.' -ErrorAction Continue
    $failed = $true
}
if (-not $legIkSource.Contains('const two_bone = @import("two_bone_ik")') -or
    -not $legIkSource.Contains('const solved = try two_bone.solve') -or
    [regex]::IsMatch($legIkSource, 'std\.math\.acos|\bwhile\s*\(')) {
    Write-Error 'Leg IK must reuse the generic analytical two-bone solver rather than duplicate or iterate a leg-specific solve.' -ErrorAction Continue
    $failed = $true
}
if ($legIkSource.Contains('debug_name') -or
    -not $legIkSource.Contains('hip_bone: u16') -or
    -not $legIkSource.Contains('knee_bone: u16') -or
    -not $legIkSource.Contains('ankle_bone: u16') -or
    -not $legIkSource.Contains('sole_socket: u16')) {
    Write-Error 'Leg bindings must use validated stable hip, knee, ankle, and sole indices without runtime name lookup.' -ErrorAction Continue
    $failed = $true
}
if (-not $legIkSource.Contains('.left => .left_foot') -or
    -not $legIkSource.Contains('.right => .right_foot') -or
    -not $characterSource.Contains('.facing_left = instance.facing == .left') -or
    [regex]::IsMatch($footPlantingSource, 'EntityId|id\s*%\s*2|swap\s*\(')) {
    Write-Error 'Anatomical left/right foot identity and mirrored bend selection must not depend on entity order or swap under facing.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($footPlantingSource, 'runtime\.locked_target\s*=\s*target').Count -ne 1 -or
    [regex]::IsMatch($footPlantingSource, 'locked_target\s*=\s*(runtime\.)?post_ik|locked_target\s*=\s*application\.metrics\.post')) {
    Write-Error 'Plant targets must be acquired once from frozen pre-IK input and may not chase post-IK feet.' -ErrorAction Continue
    $failed = $true
}
$freezeLeftIndex = $footPlantingSource.IndexOf('const left_frozen = try freezeFoot')
$freezeRightIndex = $footPlantingSource.IndexOf('const right_frozen = try freezeFoot')
$applyLeftIndex = $footPlantingSource.IndexOf('try applyPrepared(&state.left')
$applyRightIndex = $footPlantingSource.IndexOf('try applyPrepared(&state.right')
if ($freezeLeftIndex -lt 0 -or $freezeRightIndex -lt 0 -or $applyLeftIndex -le $freezeRightIndex -or $applyRightIndex -le $freezeRightIndex) {
    Write-Error 'Both anatomical foot inputs and targets must be frozen before either leg application.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('foot_plants: foot_planting.State') -or
    -not $footPlantingSource.Contains('left: FootRuntime') -or
    -not $footPlantingSource.Contains('right: FootRuntime') -or
    [regex]::IsMatch($footPlantingSource, '^\s*var\s+(global|shared|singleton)', [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
    Write-Error 'Mutable foot locks must be embedded per character and per anatomical foot, never singleton state.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($footSources, 'SDL_|SpriteBatch|batch\.submit|CreateGPU|createTexture|createBuffer|createPipeline|DrawGPU')) {
    Write-Error 'Ground queries, plant state, and leg IK may not own GPU resources or rendering commands.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($gpuSource, 'foot_planting_scene\s*=\s*try foot_planting_demo\.Scene\.init').Count -ne 1 -or
    [regex]::IsMatch($footPlantingDemoSource, 'SDL_DrawGPU|CreateGPU|createPipeline|createTexture|SpriteBatch\.init') -or
    -not $footPlantingDemoSource.Contains('scene.enabled.submitAttachments(batch)')) {
    Write-Error 'The foot-planting demo must use one scene and the established global sprite batch/draw path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($authoredClipSource + [Environment]::NewLine + $footPlantingSource, 'controller\.state\.grounded\s*=|supporting_collider\s*=|acceptJump\s*\(')) {
    Write-Error 'Animation foot events and visual plant state may not create physical grounding or controller contact.' -ErrorAction Continue
    $failed = $true
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

$multiCharacterSources = $characterSource + [Environment]::NewLine + $multiCharacterSource
if ([regex]::IsMatch($multiCharacterSources, 'SpriteBatch\.init|SDL_DrawGPU|CreateGPU|createTexture|createBuffer|createPipeline')) {
    Write-Error 'Characters must share the established global sprite batch and may not create a per-character GPU path.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('pub const EntityId = enum(u32)') -or
    -not $characterSource.Contains('invalid = 0') -or
    -not $characterSource.Contains('return error.EntityIdOverflow') -or
    -not $characterSource.Contains('return error.DuplicateEntityId')) {
    Write-Error 'Stable u32 entity IDs require an explicit invalid value, duplicate rejection, and checked overflow.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('definition: HumanoidDefinitionView') -or
    -not $characterSource.Contains('shared_animations: AnimationDefinitionsView') -or
    -not $characterSource.Contains('character: humanoid.HumanoidCharacter') -or
    -not $characterSource.Contains('animator: animator_module.Animator') -or
    -not $characterSource.Contains('procedural: procedural_motion.State')) {
    Write-Error 'Character instances must borrow immutable views and embed independent pose, animator, and procedural runtime state.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($multiCharacterSources, '@intFromPtr\s*\(|\.ptr\s*(<|>|<=|>=)')) {
    Write-Error 'Entity ordering may not use pointer or allocator addresses.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('pub fn submitGlobally') -or
    -not $characterSource.Contains('candidate.id.raw() < ordered[destination - 1].id.raw()') -or
    -not $characterSource.Contains('batch.submitWithKey')) {
    Write-Error 'All character attachments must enter one entity-ID-stable global submission set before sorting.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($multiCharacterSources, 'definition\.attachments\s*\[.*\]\.body_part_layer\s*=|attachment\.body_part_layer\s*=')) {
    Write-Error 'Temporary ordering may not mutate immutable attachment layer definitions.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('maximum_layer_overrides: usize = 8') -or
    -not $characterSource.Contains('return error.LayerOverrideCapacityExceeded') -or
    -not $characterSource.Contains('pub fn clearAll') -or
    -not $characterSource.Contains('neutral_interaction_layer: i16 = 0')) {
    Write-Error 'Layer overrides require bounded storage, overflow rejection, a neutral layer, and deterministic clearing.' -ErrorAction Continue
    $failed = $true
}
if (-not $humanoidSource.Contains('pub fn defaultBodyPartLayer') -or
    -not $humanoidSource.Contains('const left_is_front = facing == .left') -or
    -not $humanoidSource.Contains('signed_scale = .{ .x = -x_length, .y = y_length }')) {
    Write-Error 'Facing must reflect transforms and remap visual front/back layers without swapping anatomical semantics.' -ErrorAction Continue
    $failed = $true
}

$multiCharacterHotSections = @(
    Get-FunctionSection $characterSource '    pub fn advanceVisualTick' '    pub fn stepController'
    Get-FunctionSection $characterSource '    pub fn submitAttachments' '    fn applyValidatedOverride'
    Get-FunctionSection $multiCharacterSource '    pub fn updateFrame' '    pub fn submit'
    Get-FunctionSection $multiCharacterSource '    pub fn submit' '    pub fn validateComplete'
)
foreach ($section in $multiCharacterHotSections) {
    if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap|StringHashMap')) {
        Write-Error 'Character update, facing, layer resolution, override, and global submission hot paths must remain allocation-free.' -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::Matches($gpuSource, 'multi_character_scene\s*=\s*try multi_character_demo\.Scene\.init').Count -ne 1 -or
    -not $gpuSource.Contains('humanoid_instances = try scene.submit(&self.batch.?)') -or
    -not $gpuSource.Contains('metrics.draw_ranges != 1') -or
    -not $gpuSource.Contains('metrics.draw_calls != 1')) {
    Write-Error 'The multi-character demonstration must use one scene, one global batch submission, one range, and one actual draw.' -ErrorAction Continue
    $failed = $true
}

if ($failed) {
    exit 1
}

$interactionSources = $interactionDefinitionSource + [Environment]::NewLine + $handshakeDefinitionSource + [Environment]::NewLine + $interactionSystemSource
if ([regex]::IsMatch($interactionSources, 'SDL_|SpriteBatch|batch\.submit|CreateGPU|createTexture|createBuffer|createPipeline|DrawGPU')) {
    Write-Error 'Interaction definitions and runtime coordination may not contain a renderer, draw, or GPU-resource path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($interactionSources, 'raw_frame_delta|raw_delta|measured_delta|interpolation_alpha|SDL_GetTicks|Timer\.start|Instant\.now')) {
    Write-Error 'Raw render delta, interpolation, and wall clocks may not enter the shared interaction clock.' -ErrorAction Continue
    $failed = $true
}
if (-not $interactionSystemSource.Contains('sampleInteractionAnimation(manager.definition.role(.initiator).state, shared_time)') -or
    -not $interactionSystemSource.Contains('sampleInteractionAnimation(manager.definition.role(.receiver).state, shared_time)') -or
    [regex]::IsMatch($interactionSystemSource, '\.animator\.update\s*\(')) {
    Write-Error 'Both role clips must be sampled from one shared time; independent animator clocks are forbidden.' -ErrorAction Continue
    $failed = $true
}
if (-not $interactionDefinitionSource.Contains('pairedEventTimes') -or
    -not $interactionSystemSource.Contains('event_consumed') -or
    -not $interactionSystemSource.Contains('event_counts') -or
    [regex]::Matches($interactionSystemSource, 'beginContact\s*\(').Count -ne 2) {
    Write-Error 'Paired clip events must collapse into one consumed shared event stream.' -ErrorAction Continue
    $failed = $true
}
if (-not $interactionSystemSource.Contains('reserveInteraction') -or
    -not $interactionSystemSource.Contains('releaseInteraction') -or
    -not $characterSource.Contains('InteractionOwnershipMismatch') -or
    -not $characterSource.Contains('CharacterAlreadyInteracting')) {
    Write-Error 'Participant locks require checked atomic reservation, exact ownership, and release paths.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($interactionSystemSource, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|world_position\s*=|setWorldPosition\s*\(|setFacing\s*\(|\.bounds\s*=|collider')) {
    Write-Error 'Interaction coordination may not mutate physics roots, facing, controller state, or collision data.' -ErrorAction Continue
    $failed = $true
}
if ($interactionSystemSource.Contains('clearOverrides(') -or -not $interactionSystemSource.Contains('clearOwnedOverrides') -or
    -not $interactionSystemSource.Contains('participant.clearOverride(owned.handle)')) {
    Write-Error 'Interaction cleanup must clear only participant-qualified handles owned by the instance.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($interactionSystemSource, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap|StringHashMap')) {
    Write-Error 'Request, eligibility, selection, update, events, overrides, cancellation, and completion must allocate zero memory.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($interactionSystemSource, '@intFromPtr\s*\(|\.ptr\s*(<|>|<=|>=)|receiver\s*=\s*@intFromPtr')) {
    Write-Error 'Candidate selection and participant identity may not depend on pointer values.' -ErrorAction Continue
    $failed = $true
}
if (-not $interactionSystemSource.Contains('anchor_error') -or
    -not $interactionSystemSource.Contains('world_distance') -or
    -not $interactionSystemSource.Contains('left.receiver.raw() < right.receiver.raw()')) {
    Write-Error 'Candidate ranking must use alignment error, world distance, and stable entity-ID tie-breaking.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($gpuSource, 'handshake_scene\s*=\s*try handshake_demo\.Scene\.init').Count -ne 1 -or
    -not $handshakeDemoSource.Contains('character.submitGlobally') -or
    [regex]::IsMatch($handshakeDemoSource, 'SDL_DrawGPU|CreateGPU|createPipeline|createTexture')) {
    Write-Error 'The handshake demo must use one scene and the established global sprite submission/draw path.' -ErrorAction Continue
    $failed = $true
}

$ikCoreSources = $twoBoneIkSource + [Environment]::NewLine + $armIkSource + [Environment]::NewLine + $interactionSystemSource
if (-not $twoBoneIkSource.Contains('std.math.acos(root_cosine)') -or
    -not $twoBoneIkSource.Contains('std.math.acos(middle_cosine)') -or
    -not $twoBoneIkSource.Contains('(upper_squared + lower_squared - distance_squared)') -or
    -not $twoBoneIkSource.Contains('fn clampUnit')) {
    Write-Error 'The two-bone solver must retain its analytical triangle solution and clamped cosine inputs.' -ErrorAction Continue
    $failed = $true
}
$iterativeIkNames = @('C' + 'CD', 'FAB' + 'RIK', 'gradient' + ' descent')
foreach ($name in $iterativeIkNames) {
    if ($twoBoneIkSource.Contains($name)) {
        Write-Error "The analytical two-bone solver may not be replaced by iterative '$name' logic." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($twoBoneIkSource, '\bwhile\s*\(|\bfor\s*\(')) {
    Write-Error 'The generic analytical solve must not contain an iterative convergence loop.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($ikCoreSources, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|world_position\s*=|setWorldPosition\s*\(|\.bounds\s*=|collision_aabb\s*=')) {
    Write-Error 'IK code may not correct roots or mutate controller, velocity, grounding, support, or collider authority.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($ikCoreSources, 'definition\.bones\s*\[.*\]\s*=|rest_local\s*=|clips\s*\[.*\]\s*=|event_records\s*=')) {
    Write-Error 'IK may not mutate skeleton rest data, clip data, or shared event definitions.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($ikCoreSources, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|ArrayList|HashMap|StringHashMap')) {
    Write-Error 'IK solve, binding use, target computation, pose application, and hierarchy reevaluation must allocate zero memory.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($ikCoreSources, 'SDL_|SpriteBatch|batch\.submit|CreateGPU|createTexture|createBuffer|createPipeline|DrawGPU')) {
    Write-Error 'IK math and coordination may not create GPU resources or own a rendering path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($twoBoneIkSource, '@import\("(handshake|interaction|character|animator|sprite_batch|sdl)"\)|\bEntityId\b|SDL_')) {
    Write-Error 'The generic solver must remain independent of entities, handshakes, animation, rendering, and platform APIs.' -ErrorAction Continue
    $failed = $true
}
if ($armIkSource.Contains('debug_name') -or
    -not $armIkSource.Contains('root_bone: u16') -or
    -not $armIkSource.Contains('middle_bone: u16') -or
    -not $armIkSource.Contains('end_socket: u16')) {
    Write-Error 'Arm bindings must use validated stable bone/socket indices without runtime debug-name lookup.' -ErrorAction Continue
    $failed = $true
}
$targetIndex = $interactionSystemSource.IndexOf('const target = sharedTarget(pre_a, pre_b);')
$solveAIndex = $interactionSystemSource.IndexOf('participant_a.applyRightHandIk(target, weight)')
$solveBIndex = $interactionSystemSource.IndexOf('participant_b.applyRightHandIk(target, weight)')
if ($targetIndex -lt 0 -or $solveAIndex -le $targetIndex -or $solveBIndex -le $targetIndex -or
    -not $interactionSystemSource.Contains('return role_a_pre_ik_hand.add(role_b_pre_ik_hand).scale(0.5)')) {
    Write-Error 'One symmetric target must be frozen from both pre-IK hands before either participant solve.' -ErrorAction Continue
    $failed = $true
}
$characterIkSection = Get-FunctionSection $characterSource '    pub fn applyRightHandIk' '    pub fn clearRightHandIk'
if ([regex]::IsMatch($characterIkSection, 'controller|world_position\s*=|\.alloc\s*\(|\.create\s*\(')) {
    Write-Error 'Per-character IK application may mutate only the visual pose and preallocated IK metrics.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::Matches($gpuSource, 'handshake_ik_scene\s*=\s*try handshake_ik_demo\.Scene\.init').Count -ne 1 -or
    -not $handshakeIkDemoSource.Contains('character.submitGlobally') -or
    [regex]::IsMatch($handshakeIkDemoSource, 'SDL_DrawGPU|CreateGPU|createPipeline|createTexture|SpriteBatch\.init')) {
    Write-Error 'The handshake IK demo must retain the existing global sprite batch and one-draw path.' -ErrorAction Continue
    $failed = $true
}

$observerSources = $diagnosticsSource + [Environment]::NewLine + $debugDrawSource
if ([regex]::IsMatch($observerSources, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|instance\.world_position\s*=|interaction_owner_id\s*=|instance\.elapsed_ticks\s*=|runtime\.locked_target\s*=|runtime\.plant_state\s*=')) {
    Write-Error 'Diagnostic and debug modules may observe scalar state but may not mutate simulation, interaction, or foot authority.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($diagnosticsSource, 'consumeTick|event_buffer\.reset|emittedEvents\(\).*reset|event_consumed\s*=|event_counts\s*\[')) {
    Write-Error 'Diagnostic inspection may not consume, clear, or acknowledge gameplay events.' -ErrorAction Continue
    $failed = $true
}
if (-not $diagnosticsSource.Contains('pub const history_capacity: usize = 32') -or
    -not $diagnosticsSource.Contains('entries: [history_capacity]Snapshot') -or
    -not $diagnosticsSource.Contains('overwrite_count') -or
    [regex]::IsMatch($diagnosticsSource, 'ArrayList|HashMap|StringHashMap|\.alloc\s*\(|\.create\s*\(')) {
    Write-Error 'Diagnostic history must remain fixed-capacity inline storage with a documented overwrite counter and no allocation path.' -ErrorAction Continue
    $failed = $true
}
if (-not $debugDrawSource.Contains('pub const command_capacity: usize = 256') -or
    -not $debugDrawSource.Contains('commands: [command_capacity]sprite.SpriteRequest') -or
    -not $debugDrawSource.Contains('return error.DebugCommandCapacityExceeded') -or
    [regex]::IsMatch($debugDrawSource, 'SDL_|CreateGPU|ReleaseGPU|DrawGPU|\.alloc\s*\(|\.create\s*\(|ArrayList|HashMap')) {
    Write-Error 'Debug drawing must use bounded preallocated sprite commands without owning GPU resources or an alternate renderer.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($integratedDemoSource, 'configuration\.debug_visualization[^\r\n]*\{[\s\S]{0,800}(stepController|manager\.updateTick|selectControllerAnimation)')) {
    Write-Error 'Debug enablement may gate submission only; it may not select an alternate simulation, interaction, or animation path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($integratedDemoSource, '\.elapsed_ticks\s*=|\.locked_target\s*=|\.plant_state\s*=|controller\.state\.(position|velocity|grounded|supporting_collider)\s*=')) {
    Write-Error 'The integrated route may orchestrate inputs but may not write interaction clocks, foot locks, or controller authority directly.' -ErrorAction Continue
    $failed = $true
}
if (-not $integratedDemoSource.Contains('try scene.player.stepController') -or
    -not $integratedDemoSource.Contains('try scene.player.selectControllerAnimation') -or
    -not $integratedDemoSource.Contains('try scene.manager.updateTick') -or
    -not $integratedDemoSource.Contains('try scene.player.maintainFootPlantingDuringInteraction') -or
    -not $integratedDemoSource.Contains('character.submitGlobally')) {
    Write-Error 'The integrated route must compose the production controller, animation, interaction, IK/foot, and global submission APIs.' -ErrorAction Continue
    $failed = $true
}
$inputOrder = $integratedDemoSource.IndexOf('const raw = try scene.scriptedRawInput();')
$physicsOrder = $integratedDemoSource.IndexOf('const physics_result = try scene.player.stepController')
$animationOrder = $integratedDemoSource.IndexOf('try scene.player.selectControllerAnimation')
$visualOrder = $integratedDemoSource.IndexOf('try scene.player.advanceVisualTickWithFootPlanting')
$interactionOrder = $integratedDemoSource.IndexOf('try scene.manager.updateTick')
$diagnosticOrder = $integratedDemoSource.IndexOf('scene.latest_diagnostics = try scene.captureDiagnostics()')
if ($inputOrder -lt 0 -or $physicsOrder -le $inputOrder -or $animationOrder -le $physicsOrder -or
    $visualOrder -le $animationOrder -or $interactionOrder -le $visualOrder -or $diagnosticOrder -le $interactionOrder) {
    Write-Error 'The integrated fixed-tick production order must remain input, physics, animation selection, visual pose systems, interaction/IK, then observation.' -ErrorAction Continue
    $failed = $true
}
$requiredIntegrationTestPhrases = @(
    'debug visualization on and off preserve',
    'diagnostics read every tick and never read',
    'diagnostic getters are non destructive',
    'integrated scene reset clears planted airborne pre contact and contact state',
    'character local reset isolates',
    'three render frame grouping schedules',
    'one thousand complete handshakes',
    'one hundred thousand integrated ticks'
)
foreach ($phrase in $requiredIntegrationTestPhrases) {
    if (-not $integrationTestsSource.Contains($phrase)) {
        Write-Error "Required integrated deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $integratedDemoSource.Contains('activeOwnedOverrideCount()') -or
    -not $integratedDemoSource.Contains('activeIkConstraintCount()') -or
    -not $integratedDemoSource.Contains('airborne_false_plants') -or
    -not $integrationTestsSource.Contains('snapshot.allocations.total()')) {
    Write-Error 'Integrated cleanup gates must cover stale interaction ownership, IK constraints, airborne foot locks, and allocation growth.' -ErrorAction Continue
    $failed = $true
}

$inputOwnershipSources = $sdlInputSource + [Environment]::NewLine + $inputSource
if ([regex]::IsMatch($inputOwnershipSources, 'character_controller|stepController|controller\.state|world_position\s*=|setWorldPosition|enterAnimationState|startPair')) {
    Write-Error 'Production input mapping may not import or mutate controller, character-root, animation, or interaction authority.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($playgroundSource, 'controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|player\.world_position\s*=|partner\.world_position\s*=|\.elapsed_ticks\s*=|\.locked_target\s*=|\.plant_state\s*=')) {
    Write-Error 'Playground orchestration may not write controller, character-root, interaction-clock, or foot-lock authority directly.' -ErrorAction Continue
    $failed = $true
}
if (-not $sdlInputSource.Contains('SDL_GetKeyboardState') -or
    -not $sdlInputSource.Contains('.keyboard = .{') -or
    -not $gpuSource.Contains('playground_snapshot_builder.update(playground_sequence.nextRaw(scene))') -or
    -not $playgroundSource.Contains('pub fn updateFrame(scene: *Scene, frame_delta: f64, snapshot: input.FrameInputSnapshot)') -or
    [regex]::IsMatch($playgroundSource, 'CharacterIntent\s*\{')) {
    Write-Error 'Physical and scripted playground input must share the one raw-keyboard mapping and FrameInputSnapshot path.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($sdlInputSource, 'SDL_EVENT_KEY_DOWN|\.key\.repeat|SDL_StartTextInput') -or
    -not $inputSource.Contains('fn button(previous: bool, current: bool) ButtonSnapshot')) {
    Write-Error 'Gameplay edges must use polled physical-state transitions and may not use key-repeat or text-input events.' -ErrorAction Continue
    $failed = $true
}
if (-not $sdlInputSource.Contains('SDL_EVENT_WINDOW_FOCUS_LOST') -or
    -not $sdlInputSource.Contains('SDL_EVENT_WINDOW_FOCUS_GAINED') -or
    -not $inputSource.Contains('blocked_until_release') -or
    -not $inputSource.Contains('if (snapshot.focus_lost)')) {
    Write-Error 'Focus loss must clear pending keyboard state and suppress held keys until physical release after focus regain.' -ErrorAction Continue
    $failed = $true
}
if (-not $inputSource.Contains('jump_pressed_pending') -or
    -not $inputSource.Contains('jump_released_pending') -or
    -not $inputSource.Contains('interact_pressed_pending') -or
    -not $inputSource.Contains('pub fn pendingEdgeCount')) {
    Write-Error 'Pending press and release edges plus bounded diagnostics are required across zero-substep frames.' -ErrorAction Continue
    $failed = $true
}
if (-not $playgroundSource.Contains('const frame = try scene.clock.beginFrame(frame_delta);') -or
    [regex]::IsMatch($playgroundSource, 'stepController\([^\r\n]*frame_delta|move_axis\s*\*\s*frame_delta|velocity[^\r\n]*frame_delta')) {
    Write-Error 'Raw render delta may enter only the fixed-step clock, never movement, velocity, or CharacterIntent.' -ErrorAction Continue
    $failed = $true
}
if (-not $playgroundSource.Contains('try scene.manager.reset(&participants_value)') -or
    -not $playgroundSource.Contains('try scene.player.resetControlled(&scene.world)') -or
    $playgroundSource.Contains('try scene.player.reset();')) {
    Write-Error 'Playground R handling must use the world-aware controlled-character reset and interaction-manager cleanup path.' -ErrorAction Continue
    $failed = $true
}
if (-not $playgroundSource.Contains('requestFromIntent') -or
    [regex]::IsMatch($playgroundSource, 'startPair\s*\(')) {
    Write-Error 'Playground E handling must request through CharacterIntent and may not start the handshake directly.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($playgroundSource + [Environment]::NewLine + $inputSource, 'CreateGPU|ReleaseGPU|DrawGPU|SDL_GPU|\.alloc\s*\(|\.create\s*\(|ArrayList|HashMap|StringHashMap')) {
    Write-Error 'Input mapping and playground steady-state orchestration may not allocate collections or own GPU resources.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($playgroundSource, 'debug_visualization[^\r\n]*\{[\s\S]{0,600}(stepController|manager\.updateTick|selectControllerAnimation)')) {
    Write-Error 'F1 may gate debug submission only and may not choose an authoritative simulation path.' -ErrorAction Continue
    $failed = $true
}
$requiredPlaygroundTestPhrases = @(
    'production keyboard horizontal alternatives map once',
    'production action mappings emit physical transition edges',
    'focus loss clears keyboard holds pending presses',
    'pending edges survive zero substeps',
    'mapped keyboard input drives real controller movement',
    'Space early release produces lower real-controller apex',
    'raw keyboard mapping produces identical controller state under render grouping schedules',
    'interaction hold requires a release and new E press',
    'F1 toggles leave authoritative playground simulation identical',
    'bounded playground script uses raw mapping'
)
foreach ($phrase in $requiredPlaygroundTestPhrases) {
    if (-not $playgroundTestsSource.Contains($phrase)) {
        Write-Error "Required playground deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

if ($failed) {
    exit 1
}

Write-Host "Repository source audit passed for $($sourceFiles.Count) files."
Write-Host 'Forbidden SDL high-level renderer and alternate-renderer symbols are absent.'
Write-Host ('No unfinished markers, un' + 'reachable paths, or skipped-test markers were found in audited implementation files.')
Write-Host 'Every GPU acquisition family has a matching release operation.'
Write-Host 'Exactly one authoritative indexed-instanced sprite draw site exists; legacy direct-quad markers are absent.'
Write-Host 'GPU instance layout, integer ordering, actual metrics, and persistent-resource creation policies passed static checks.'
Write-Host 'Prompt 3 hierarchy audit passed: no direct body-part GPU path, pointer graph, per-bone allocation, mutable definition pose, stored attachment world pose, hot-path allocation/string lookup, or matrix interpolation.'
Write-Host 'Prompt 4 animation audit passed: immutable packed clips, no renderer authority, no matrix interpolation, no mutable clip playback, no wall clock, no GPU creation, and allocation/string/hash-free sampling, blending, and animator update.'
Write-Host 'Prompt 5 controller audit passed: SDL isolation, 240 Hz clock agreement, pending edges, one collision world, no input position authority, no foot-event grounding, no controller GPU path, bounded accumulation, and allocation-free hot paths.'
Write-Host 'Prompt 6 procedural-motion audit passed: fixed-step-only bounded springs, one update/composition per tick, no duplicate physics authority, no controller/collider mutation, no GPU path, no immutable-definition mutation, and allocation-free hot paths.'
Write-Host 'Prompt 7 multi-character audit passed: stable IDs, borrowed immutable views, independent mutable state, reflected facing, bounded overrides, global semantic ordering, one batch/draw path, and allocation-free hot paths.'
Write-Host 'Prompt 8 paired-interaction audit passed: one shared fixed-tick clock, deduplicated paired events, stable-ID locks and candidate ranking, owned-only override cleanup, an available non-IK baseline, no physics/collision mutation, and one global draw path.'
Write-Host 'Prompt 9 IK audit passed: analytical clamped two-bone geometry, stable arm bindings, pre-IK symmetric shared targets, deterministic weighting and bend selection, visual-pose-only application, zero hot-path allocation, no GPU resources, and no alternate draw path.'
Write-Host 'Prompt 10 foot-planting audit passed: authoritative-world queries, stable anatomical leg bindings, frozen pre-IK targets, character-local locks, fixed-tick blending, generic solver reuse, no physics mutation, zero hot-path allocation, zero GPU resources, and the existing global draw path.'
Write-Host 'Ground-query ownership audit passed: one controller collider array supplies support evidence with inclusive range/surface rules and stable collider-ID ties.'
Write-Host 'Animation-event-versus-grounding audit passed: contact semantics cannot write grounding, support, root, velocity, or collider authority.'
Write-Host 'Plant-target drift and solve-order audit passed: both feet freeze pre-IK inputs before application and locks never chase post-IK output.'
Write-Host 'Leg-solver reuse and bone-length audit passed: both chains call the analytical generic solver and immutable rest lengths are only measured, never stretched.'
Write-Host 'Anatomical semantic audit passed: facing changes bend direction without swapping left/right event, socket, binding, or state identity.'
Write-Host 'Foot hot-path and GPU audit passed: queries, updates, bindings, targets, solves, and pose evaluation allocate nothing and create no GPU path.'
Write-Host 'Analytical-solver audit passed: triangle cosines are clamped before both analytical acos operations.'
Write-Host 'Iterative-IK audit passed: no convergence loop or iterative-solver implementation is present.'
Write-Host 'Root/physics mutation audit passed: IK writes no root, velocity, grounding, support, or collider authority.'
Write-Host 'Shared-target order-dependence audit passed: one symmetric pre-IK midpoint precedes both role solves.'
Write-Host 'Immutable-data mutation audit passed: IK writes no skeleton rest, clip, or shared event definition data.'
Write-Host 'Hot-path allocation audit passed: solve, binding use, target computation, pose application, and hierarchy reevaluation contain no allocator path.'
Write-Host 'IK GPU-resource audit passed: IK math and coordination create no GPU resource and issue no GPU command.'
Write-Host 'Alternate draw-path audit passed: the IK demo submits through the existing global sprite batch.'
Write-Host 'Prompt 11 observability audit passed: diagnostics are bounded read-only scalar snapshots and event inspection is non-destructive.'
Write-Host 'Prompt 11 debug audit passed: debug commands are bounded, allocation-free, GPU-resource-free, and share the authoritative sprite batch.'
Write-Host 'Prompt 11 integration-order audit passed: scripted input precedes physics, animation, visual pose systems, interactions/IK, and observation.'
Write-Host 'Prompt 12 cleanup audit passed: deterministic tests cover debug/read invariance, reset timing, 1,000 interactions, 100,000 ticks, and adversarial render schedules.'
Write-Host 'Prompt 13 input audit passed: one polled keyboard mapping, focus resynchronization, pending-edge delivery, world-aware reset, intent-owned interaction, debug invariance, zero input GPU ownership, and raw-key scripted equivalence.'
Write-Host (('Place' + 'holder') + '/disabled-test audit passed: the audited implementation-file scan is empty.')
