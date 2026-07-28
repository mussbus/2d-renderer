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
$appearanceSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/appearance.zig')
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
$cameraSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/camera2d.zig')
$cameraTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/camera_tests.zig')
$appearanceTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/appearance_tests.zig')
$anatomySource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/anatomy.zig')
$modularBodySource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/modular_body_demo.zig')
$anatomyTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/anatomy_tests.zig')
$equipmentSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/equipment.zig')
$equipmentDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/equipment_demo.zig')
$equipmentTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/equipment_tests.zig')
$characterPropertiesSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/character_properties.zig')
$characterPropertiesDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/character_properties_demo.zig')
$characterPropertiesTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/character_properties_tests.zig')
$deformationSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/deformation.zig')
$breathingDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/breathing_demo.zig')
$deformationTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/deformation_tests.zig')
$deformableMeshSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/deformable_mesh.zig')
$renderQueueSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/render_queue.zig')
$meshCatalogSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/mesh_gpu_catalog.zig')
$meshAttachmentDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/mesh_attachment_demo.zig')
$meshAttachmentTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/mesh_attachment_tests.zig')
$foundationSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/foundation_playground.zig')
$foundationTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/foundation_playground_tests.zig')
$artPackSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/art_pack.zig')
$imageDecodeSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/graphics/image_decode.zig')
$artAssetDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/art_asset_demo.zig')
$artPipelineTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/art_pipeline_tests.zig')
$imageDecodeTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/image_decode_tests.zig')
$presentationViewSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/presentation_view.zig')
$presentationPoseSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/presentation_pose.zig')
$characterArtSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/character_art.zig')
$characterPresentationDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/character_presentation_demo.zig')
$characterPresentationTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/character_presentation_tests.zig')
$wardrobeCatalogSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/wardrobe_catalog.zig')
$wardrobeArtSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/wardrobe_art.zig')
$wardrobePresentationSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/wardrobe_presentation.zig')
$wardrobeDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/wardrobe_demo.zig')
$wardrobeTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/wardrobe_tests.zig')
$environmentArtSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/environment_art.zig')
$environmentThemeSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/environment_theme.zig')
$environmentDemoSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/environment_demo.zig')
$environmentTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/environment_tests.zig')
$visualFoundationSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/visual_foundation.zig')
$foundationEvidenceSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/scene/foundation_evidence.zig')
$acceptanceHudSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/debug/acceptance_hud.zig')
$visualFoundationTestsSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/visual_foundation_tests.zig')
$p27aReviewSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tools/build_p27a_review_package.ps1')
$p27aRepeatSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tools/compare_p27a_repeats.ps1')
$buildSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'build.zig')
$shaderSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'assets/shaders/sprite.hlsl')
$meshShaderSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'assets/shaders/deformable_mesh.hlsl')
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

$cpuHierarchySource = $skeletonSource + [Environment]::NewLine + $poseSource + [Environment]::NewLine + $appearanceSource + [Environment]::NewLine + $humanoidSource
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

$attachmentMatch = [regex]::Match($appearanceSource, 'pub const VisualAttachment = struct \{(.*?)\r?\n\};', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $attachmentMatch.Success -or [regex]::IsMatch($attachmentMatch.Groups[1].Value, '\bworld(_transform|_position)?\b')) {
    Write-Error 'VisualAttachment must retain only immutable local metadata and must not store authoritative world transforms.' -ErrorAction Continue
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
    Get-FunctionSection $appearanceSource '    pub fn evaluate' '    pub fn setVisible'
    Get-FunctionSection $humanoidSource '    pub fn applyProgrammaticPose' '    pub fn submitAttachments'
    Get-FunctionSection $humanoidSource '    pub fn submitAttachments' '    pub fn attachmentWorld'
)
foreach ($section in $hotSections) {
    if ([regex]::IsMatch($section, '\.alloc\s*\(|\.create\s*\(|std\.mem\.Allocator|std\.mem\.eql')) {
        Write-Error 'Pose, appearance, socket, and humanoid submission hot paths must remain allocation- and string-lookup-free.' -ErrorAction Continue
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
if (-not $debugDrawSource.Contains('pub const command_capacity: usize = 512') -or
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

if ([regex]::IsMatch($humanoidSource + [Environment]::NewLine + $characterSource, 'presentation_origin|pixels_per_meter|viewport_(width|height)|window_(width|height)')) {
    Write-Error 'Humanoid and character ownership may not include global presentation origin, zoom, viewport, or window dimensions.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($cameraSource, 'SDL_|@import\("sdl"\)|CreateGPU|DrawGPU|CharacterController|CollisionWorld|CharacterIntent')) {
    Write-Error 'Camera2D must remain testable without SDL, GPU, input, character-controller, or collision-world dependencies.' -ErrorAction Continue
    $failed = $true
}
if (-not $cameraSource.Contains('pub const Camera2D = struct') -or
    -not $cameraSource.Contains('pub fn worldToPresentation') -or
    -not $cameraSource.Contains('pub fn worldToClip') -or
    -not $cameraSource.Contains('pub fn setViewport') -or
    -not $cameraSource.Contains('pub const HorizontalFollower = struct')) {
    Write-Error 'Camera2D must own validated center, viewport, zoom, conversions, and deterministic horizontal following.' -ErrorAction Continue
    $failed = $true
}
if (-not $gpuSource.Contains('c.SDL_WINDOW_RESIZABLE') -or
    -not $gpuSource.Contains('c.SDL_GetWindowSizeInPixels') -or
    -not $gpuSource.Contains('c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED') -or
    -not $gpuSource.Contains('c.SDL_EVENT_WINDOW_MINIMIZED') -or
    -not $gpuSource.Contains('c.SDL_EVENT_WINDOW_RESTORED') -or
    -not $gpuSource.Contains('c.SDL_GetGPUSwapchainTextureFormat')) {
    Write-Error 'Visible SDL windows must use the pinned resizable, drawable-pixel, minimize/restore, and swapchain-format APIs.' -ErrorAction Continue
    $failed = $true
}
if (-not $gpuSource.Contains('offscreen_pipeline') -or
    -not $gpuSource.Contains('window_pipeline') -or
    -not $gpuSource.Contains('camera2d.Camera2D.initDefault()') -or
    [regex]::IsMatch($gpuSource, 'SDL_BlitGPUTexture')) {
    Write-Error 'Visible rendering must use the current swapchain camera directly while fixed offscreen readback remains separate.' -ErrorAction Continue
    $failed = $true
}
if (-not $batchSource.Contains('camera_x_factor: f32') -or
    -not $shaderSource.Contains('world.x - camera_center.x * input.camera_x_factor') -or
    -not $shaderSource.Contains('world.y - camera_center.y') -or
    -not $shaderSource.Contains('camera_relative * clip_scale')) {
    Write-Error 'The GPU instance and HLSL contracts must apply camera and horizontal parallax at the rendering boundary.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($controllerSource + [Environment]::NewLine + $collisionWorldSource, '(?i)camera|parallax')) {
    Write-Error 'Camera following and parallax may not enter authoritative controller or collision ownership.' -ErrorAction Continue
    $failed = $true
}
if (-not $playgroundSource.Contains('distant_camera_x_factor') -or
    -not $playgroundSource.Contains('midground_camera_x_factor') -or
    -not $playgroundSource.Contains('sideScrollingColliderInputs') -or
    -not $playgroundSource.Contains('SideScrollerScriptedInput')) {
    Write-Error 'The playground must provide distant, midground, gameplay, extended-world, and bounded side-scroll routes.' -ErrorAction Continue
    $failed = $true
}
$requiredCameraTestPhrases = @(
    'default camera preserves the original 640 by 480 presentation',
    'camera keeps zoom at 640 by 480 and two other aspect ratios',
    'positive world Y maps upward',
    'zero and invalid camera state is rejected transactionally',
    'parallax factors produce hand-derived relative camera displacement',
    'resize changes presentation without changing authoritative simulation',
    'camera follow cannot change controller physics',
    'repeated horizontal camera updates are bit deterministic'
)
foreach ($phrase in $requiredCameraTestPhrases) {
    if (-not $cameraTestsSource.Contains($phrase)) {
        Write-Error "Required camera deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $playgroundTestsSource.Contains('bounded side-scroller input crosses the extended world deterministically') -or
    -not $playgroundTestsSource.Contains('cave submission carries distant midground and gameplay camera factors')) {
    Write-Error 'Side-scroller traversal and three-layer parallax submission require deterministic coverage.' -ErrorAction Continue
    $failed = $true
}

if (-not $humanoidSource.Contains('pub const canonical_attachment_semantic_count: usize = 15') -or
    -not $humanoidSource.Contains('pub const default_visual_count: usize = 15') -or
    $humanoidSource.Contains('attachment_inputs.len !=') -or
    $humanoidSource.Contains('MissingAttachmentSemantic')) {
    Write-Error 'Prompt 15 must preserve the 15 canonical lookup semantics without requiring exactly 15 visual records.' -ErrorAction Continue
    $failed = $true
}
if (-not $appearanceSource.Contains('pub const maximum_visual_attachments: usize = 128') -or
    -not $appearanceSource.Contains('pub const maximum_hierarchy_depth: u8 = 16') -or
    -not $appearanceSource.Contains('pub const TransformSource = union(enum)') -or
    -not $appearanceSource.Contains('visual_attachment: VisualAttachmentId') -or
    -not $appearanceSource.Contains('return error.VisualAttachmentCycle') -or
    -not $appearanceSource.Contains('return error.AttachmentPointCycle')) {
    Write-Error 'Generalized visual and attachment hierarchies must use bounded resolved IDs and reject cycles.' -ErrorAction Continue
    $failed = $true
}
if (-not $appearanceSource.Contains('pub const AttachmentPointId = enum(u16)') -or
    -not $appearanceSource.Contains('pub const VisualAttachmentId = enum(u16)') -or
    -not $appearanceSource.Contains('pub const BodyRegionId = enum(u16)') -or
    -not $appearanceSource.Contains('pub const VisualGroupId = enum(u16)') -or
    -not $appearanceSource.Contains('pub fn attachmentPointId') -or
    -not $appearanceSource.Contains('pub fn visualId')) {
    Write-Error 'Appearance definitions must resolve initialization-time names to compact typed runtime IDs.' -ErrorAction Continue
    $failed = $true
}
if (-not $appearanceSource.Contains('pub const RigModule = struct') -or
    -not $appearanceSource.Contains('pub const ModuleJoint = struct') -or
    -not $appearanceSource.Contains('pub const ModuleSocket = struct') -or
    -not $appearanceSource.Contains('parent_attachment_point: AttachmentPointId') -or
    -not $appearanceSource.Contains('module_joint_local: []math.Transform2D') -or
    -not $appearanceSource.Contains('return error.ModuleJointCycle')) {
    Write-Error 'Optional rig modules must use bounded parented local joints and character-owned mutable local pose.' -ErrorAction Continue
    $failed = $true
}
if (-not $characterSource.Contains('appearance_runtime: appearance.Runtime') -and
    -not $humanoidSource.Contains('appearance_runtime: appearance.Runtime')) {
    Write-Error 'Mutable appearance and module state must be owned by each character runtime.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($appearanceSource, 'SDL_|SpriteBatch|batch\.submit|CreateGPU|DrawGPU') -or
    -not $characterSource.Contains('instance.character.appearance_runtime.evaluate') -or
    -not $characterSource.Contains('instance.definition.visual_definition')) {
    Write-Error 'Appearance evaluation must remain CPU-only and feed the established character submission path.' -ErrorAction Continue
    $failed = $true
}
$requiredAppearanceTestPhrases = @(
    'generalized definition keeps canonical rig invariant and assigns stable custom ids',
    'zero visuals and variable counts initialize submit and clean up without a special path',
    'multiple visuals share one data-defined attachment point and visual hierarchy is bounded',
    'invalid duplicate dangling and cyclic definitions fail transactionally',
    'appearance and module mutable state are instance-owned and resettable',
    'custom attachment and module visuals mirror with the canonical character root',
    'extended visuals preserve deterministic input order for equal draw layers',
    'appearance evaluation and mutation allocate zero bytes after initialization'
)
foreach ($phrase in $requiredAppearanceTestPhrases) {
    if (-not $appearanceTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 15 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

if ([regex]::IsMatch($anatomySource + [Environment]::NewLine + $modularBodySource, '\bis_male\b|BodyType\.(male|female)') -or
    -not $anatomySource.Contains('pub const BodyPartDefinition = struct') -or
    -not $anatomySource.Contains('pub const BodyPartInstance = struct') -or
    -not $anatomySource.Contains('pub const BodyPartInstanceId = enum(u16)') -or
    -not $anatomySource.Contains('pub const BodyPartParent = union(enum)') -or
    -not $anatomySource.Contains('return error.BodyPartHierarchyCycle')) {
    Write-Error 'Prompt 16 anatomy must use extensible repeated part records, resolved parents, and bounded cycle rejection rather than a sex boolean or closed topology.' -ErrorAction Continue
    $failed = $true
}
if (-not $anatomySource.Contains('pub const MorphologyChannelId = enum(u16)') -or
    -not $anatomySource.Contains('range.low + (range.high - range.low) * amount') -or
    -not $anatomySource.Contains('instance_override_set: []bool') -or
    -not $anatomySource.Contains('channel_override_set: []bool') -or
    -not $anatomySource.Contains('InvalidMorphologyRange')) {
    Write-Error 'Morphology must use data-defined channels and preset interpolation with channel and instance overrides plus range validation.' -ErrorAction Continue
    $failed = $true
}
if (-not $anatomySource.Contains('pub const PresentationProfile = struct') -or
    -not $anatomySource.Contains('topologyFingerprint') -or
    -not $anatomySource.Contains('applyAppearanceState') -or
    -not $anatomySource.Contains('selected_presentation_profile') -or
    [regex]::IsMatch($anatomySource, 'SDL_|CreateGPU|DrawGPU|CharacterController|Animator|arm_ik|leg_ik|foot_planting')) {
    Write-Error 'Presentation and morphology must remain allocation-free CPU appearance state with no GPU, controller, animation, or canonical IK ownership.' -ErrorAction Continue
    $failed = $true
}
if (-not $modularBodySource.Contains('"conventional_male"') -or
    -not $modularBodySource.Contains('"conventional_female"') -or
    -not $modularBodySource.Contains('"nonstandard_humanoid"') -or
    -not $modularBodySource.Contains('"two_penises"') -or
    -not $modularBodySource.Contains('"three_breasts"') -or
    -not $modularBodySource.Contains('"extra_arm_module"') -or
    -not $modularBodySource.Contains('"tail_module"') -or
    -not $modularBodySource.Contains('"angular_face"') -or
    -not $modularBodySource.Contains('"angular_left_eye"') -or
    -not $modularBodySource.Contains('"ponytail"')) {
    Write-Error 'The modular-body content route must prove two visibly distinct data-defined faces, conventional and repeated adult modules, articulated appendages, horns, and multi-style hair data.' -ErrorAction Continue
    $failed = $true
}
$requiredAnatomyTestPhrases = @(
    'morphology interpolates exactly and override precedence reset and preset isolation are deterministic',
    'morphology rejects invalid user values and invalid preset ranges',
    'repeated adult modules and conventional presets are compositional data',
    'hierarchical anatomy rejects dangling parents and cycles',
    'faces and hair are per-head groups with independently addressable features',
    'two facial configurations use shared modular data and derive distinct independent visuals',
    'presentation switching changes visuals without changing anatomy topology',
    'module articulation morphology and presentation leave canonical controller animation interaction and IK state unchanged',
    'characters share immutable presets but own independent anatomy runtime state',
    'modular body evidence route is deterministic and allocation free after initialization'
)
foreach ($phrase in $requiredAnatomyTestPhrases) {
    if (-not $anatomyTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 16 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

$requiredEquipmentTypes = @(
    'pub const EquipmentSlotId = enum(u16)',
    'pub const AnatomyRoleId = enum(u16)',
    'pub const VisualLayerId = enum(u16)',
    'pub const VisualComponentId = enum(u16)',
    'pub const EquipmentItemId = enum(u16)',
    'pub const AttributeId = properties.AttributeId',
    'pub const CapabilityId = properties.CapabilityId',
    'pub const ResolvedVisualInstance = struct',
    'pub const ActiveCoverage = struct',
    'pub const ActiveModifier = struct',
    'pub const ActiveCapability = struct'
)
foreach ($phrase in $requiredEquipmentTypes) {
    if (-not $equipmentSource.Contains($phrase)) {
        Write-Error "Prompt 17 typed equipment boundary is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

$loadoutStart = $equipmentSource.IndexOf('pub const Loadout = struct')
if ($loadoutStart -lt 0) {
    Write-Error 'Prompt 17 bounded per-character loadout implementation is missing.' -ErrorAction Continue
    $failed = $true
} else {
    $loadoutSource = $equipmentSource.Substring($loadoutStart)
    foreach ($phrase in @(
        'var candidate = loadout.*',
        'maximum_equipped_items',
        'maximum_resolved_visuals',
        'maximum_active_modifiers',
        'maximum_active_capabilities',
        'maximum_active_coverage',
        'pub fn equip(',
        'pub fn replace(',
        'pub fn unequip(',
        'pub fn resetToDefault(',
        'fn rebuildDerived('
    )) {
        if (-not $loadoutSource.Contains($phrase)) {
            Write-Error "Prompt 17 transactional bounded loadout evidence is missing: '$phrase'." -ErrorAction Continue
            $failed = $true
        }
    }
    if ($loadoutSource.Contains('allocator.alloc') -or $loadoutSource.Contains('std.ArrayList') -or $loadoutSource.Contains('StringHashMap')) {
        Write-Error 'Prompt 17 loadout mutation and query paths must remain allocation-free and compact-ID based.' -ErrorAction Continue
        $failed = $true
    }
}

foreach ($phrase in @(
    '.first_compatible',
    '.every_compatible',
    '.specific_instance',
    'MissingRequiredAnatomy',
    'CompatiblePartExpansionExceeded',
    'EquipmentSlotOccupied'
)) {
    if (-not $equipmentSource.Contains($phrase)) {
        Write-Error "Prompt 17 topology or transaction behavior is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

if ($equipmentSource.Contains('@import("sprite_batch")') -or
    $equipmentSource.Contains('SDL_') -or
    $equipmentSource.Contains('CharacterIntent') -or
    $equipmentSource.Contains('CharacterController'))
{
    Write-Error 'Equipment definitions/loadouts must not own rendering, SDL input, or controller behavior.' -ErrorAction Continue
    $failed = $true
}

foreach ($phrase in @(
    'same_sweatshirt=true',
    'two_arm_sleeves',
    'four_arm_sleeves',
    'conflict_rejected_transactionally',
    'multi_slot_replacement_proved',
    'unequip_restoration_proved',
    'long_sleeve_sweatshirt',
    'full_plate_armor',
    'speed_boots',
    'winged_boots'
)) {
    if (-not $equipmentDemoSource.Contains($phrase) -and -not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 17 demonstration evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($phrase in @(
    'character_module.addImport("equipment", equipment_module)',
    'app_module.addImport("equipment_demo", equipment_demo_module)',
    'test_module.addImport("equipment_demo", equipment_demo_module)'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 17 build wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

$requiredEquipmentTestPhrases = @(
    'equipment definition registration validates duplicates missing references and future identifiers',
    'one garment expands deterministically to two and four arms with bounded required matching',
    'transactional loadout layering replacement coverage reset effects and character isolation',
    'definition-sorted visual and effect views do not depend on equip request order',
    'equipment is allocation-free after initialization and preserves canonical sockets and facing reflection'
)
foreach ($phrase in $requiredEquipmentTestPhrases) {
    if (-not $equipmentTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 17 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($phrase in @(
    'pub const Response = struct',
    'pub const BreathingBinding = struct',
    'pub const BreathingConfiguration = struct',
    'pub const BreathingState = struct',
    'pub const ResolveInput = struct',
    'pub fn resolve(',
    'cycle_tick',
    'period_ticks',
    'fixed_step.simulation_hz'
)) {
    if (-not $deformationSource.Contains($phrase)) {
        Write-Error "Prompt 18 shared deformation boundary is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($deformationSource, 'allocator|ArrayList|HashMap|SDL_|CreateGPU|DrawGPU|nanoTimestamp|milliTimestamp')) {
    Write-Error 'Prompt 18 deformation must remain allocation-free deterministic CPU state with no wall-clock or GPU ownership.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'breathing_binding: deformation.BreathingBinding',
    'breathing: deformation.BreathingState',
    'part_deformation_local',
    'part_binding_world',
    'resolvedDeformationForPart',
    'advanceBreathing',
    'deformation_response: deformation.Response',
    'equipmentVisualWorld',
    '.anatomy_part => |part_id|'
)) {
    if (-not $anatomySource.Contains($phrase) -and
        -not $appearanceSource.Contains($phrase) -and
        -not $equipmentSource.Contains($phrase) -and
        -not $characterSource.Contains($phrase)) {
        Write-Error "Prompt 18 resolved instance deformation is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'four_independent_sleeve_bindings',
    'isolated_sleeve_override',
    'rigid_opt_out',
    'body_clothing_agreement',
    'fixed_ticks_per_frame',
    'BREATHING AND SHARED DEFORMATION EVIDENCE'
)) {
    if (-not $breathingDemoSource.Contains($phrase) -and -not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 18 bounded evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'deformation_module.addImport("fixed_step", fixed_step_module)',
    'character_module.addImport("deformation", deformation_module)',
    'app_module.addImport("breathing_demo", breathing_demo_module)',
    'test_module.addImport("breathing_demo", breathing_demo_module)'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 18 build wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$requiredDeformationTestPhrases = @(
    'breathing validates configuration and samples neutral extrema reset and repeated cycles',
    'independent breathing states keep phase rate and amplitude character local',
    'resolved deformation composes global morphology breathing and per visual response once',
    'topology generated clothing follows exact bound instances with isolated overrides and rigid opt out',
    'breathing and morph changes preserve physics controller canonical IK and declared effects',
    'interaction event timing is invariant across breathing configurations',
    'fixed tick breathing is deterministic across render frame grouping',
    'steady state breathing morphing and loadout changes do not grow character storage'
)
foreach ($phrase in $requiredDeformationTestPhrases) {
    if (-not $deformationTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 18 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($phrase in @(
    'pub const maximum_vertices_per_definition',
    'pub const maximum_indices_per_definition',
    'pub const DeformationBindingMetadata = struct',
    'pub const DefinitionView = struct',
    'pub const Definition = struct',
    'pub const InstanceState = struct',
    'pub const GpuBaseVertex = extern struct',
    'pub const GpuInstance = extern struct',
    'UnsupportedMeshTopology',
    'MeshIndexOutOfRange',
    'DegenerateMeshTriangle',
    'NonFiniteMeshVertex',
    'InvalidMeshUv'
)) {
    if (-not $deformableMeshSource.Contains($phrase)) {
        Write-Error "Prompt 19 immutable deformable-mesh contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($deformableMeshSource, 'SDL_|CreateGPU|DrawGPU|CharacterController|CharacterIntent')) {
    Write-Error 'Prompt 19 immutable mesh data and per-instance CPU state may not own SDL, GPU, input, or controller authority.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'pub const UnifiedRenderQueue = struct',
    'pub fn submitSprite(',
    'pub fn submitMesh(',
    'std.mem.sort(Entry',
    'appendPreparedSprite',
    'appendPreparedMesh',
    'sprite_ranges',
    'mesh_ranges',
    'sprite_draws',
    'mesh_draws',
    'sprite_upload_bytes',
    'mesh_upload_bytes'
)) {
    if (-not $renderQueueSource.Contains($phrase)) {
        Write-Error "Prompt 19 unified semantic queue contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$queuePrepare = Get-FunctionSection $renderQueueSource '    pub fn prepare(' '    pub fn recordUploads('
if ([regex]::IsMatch($queuePrepare, '\.alloc\s*\(|ArrayList|HashMap|StringHashMap')) {
    Write-Error 'Prompt 19 queue preparation must remain allocation-free after bounded initialization.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'pub const maximum_mesh_definitions',
    'pub const maximum_catalog_vertices',
    'pub const maximum_catalog_indices',
    'pub const Catalog = struct',
    'DuplicateMeshDefinition',
    'MeshCatalogCapacityExceeded'
)) {
    if (-not $meshCatalogSource.Contains($phrase)) {
        Write-Error "Prompt 19 persistent topology catalog contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const VisualPrimitiveInput = union(enum)',
    'deformable_mesh: mesh.DefinitionView',
    'owning_character: u32',
    'mesh_state: mesh.InstanceState',
    'pub fn submitUnified(',
    'submitUnifiedEquipment',
    'resolved_deformation = try anatomy_runtime.resolvedDeformationForPart'
)) {
    if (-not $equipmentSource.Contains($phrase) -and -not $characterSource.Contains($phrase)) {
        Write-Error "Prompt 19 shared equipment/deformation integration is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'initializeMeshRendering',
    'mesh_vertex_buffer',
    'mesh_index_buffer',
    'mesh_instance_buffer',
    'mesh_transfer_buffer',
    'encodeUnifiedQueue',
    'SDL_DrawGPUIndexedPrimitives',
    'createMeshPipeline',
    'releaseMeshSlotResources'
)) {
    if (-not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 19 SDL GPU path is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'float deformation_weight : TEXCOORD2',
    'float2 deformation_translation : TEXCOORD6',
    'float2 deformation_scale : TEXCOORD8',
    'lerp(input.local_position, fully_deformed, input.deformation_weight)'
)) {
    if (-not $meshShaderSource.Contains($phrase)) {
        Write-Error "Prompt 19 weighted mesh shader contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'fitted_garment_mesh_v1',
    'reusable_sleeve_mesh_v1',
    'upper_back_cape_mesh_v1',
    '.every_compatible',
    'cape_unequipped',
    'cape_reequipped',
    'independent_repeated_state',
    'independent_character_state',
    'deformation_changed',
    'breathing_deformation_changed',
    'build_deformation_changed',
    'mirrored_facing'
)) {
    if (-not $meshAttachmentDemoSource.Contains($phrase)) {
        Write-Error "Prompt 19 bounded mixed-scene evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'deformable_mesh_vs.dxil',
    'app_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module)',
    'test_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module)',
    'app_module.addImport("render_queue", render_queue_module)',
    'test_module.addImport("mesh_gpu_catalog", mesh_gpu_catalog_module)'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 19 build wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$requiredMeshAttachmentTestPhrases = @(
    'mesh definition validates finite vertices UVs topology indices capacities and degeneracy',
    'mesh ownership and partial allocation failure cleanup are explicit',
    'persistent topology catalog owns one immutable copy and cleans partial initialization',
    'GPU mesh records match the shader contract and weighted deformation is bounded',
    'unified queue interleaves semantic sprite and mesh order and batches compatible repeated meshes honestly',
    'topology-expanded equipment owns independent mesh state per binding and character',
    'queue capacities and allocation failure are deterministic'
)
foreach ($phrase in $requiredMeshAttachmentTestPhrases) {
    if (-not $meshAttachmentTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 19 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($forbiddenDependency in @(
    '@import("equipment")',
    '@import("character_controller")',
    '@import("sprite_batch")',
    '@import("camera2d")',
    'SDL_',
    'Allocator',
    '.alloc('
)) {
    if ($characterPropertiesSource.Contains($forbiddenDependency)) {
        Write-Error "Prompt 21 generic property resolver has a forbidden dependency or allocation path: '$forbiddenDependency'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const AttributeId = enum(u16)',
    'pub const CapabilityId = enum(u16)',
    'pub const SourceId = struct',
    'pub const BaseAttributeOverride = struct',
    'pub const Builder = struct',
    'insertionSortModifiers',
    'additive_totals',
    'multiplier_products',
    'capability_source_counts'
)) {
    if (-not $characterPropertiesSource.Contains($phrase)) {
        Write-Error "Prompt 21 bounded property-resolution contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'stepWithProperties',
    'additional_air_jumps_with_double_jump',
    'dash_ticks_remaining',
    'dash_cooldown_ticks_remaining',
    'properties.double_jump',
    'properties.dash'
)) {
    if (-not $controllerSource.Contains($phrase)) {
        Write-Error "Prompt 21 controller consumer contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($itemName in @('winged_boots', 'spring_boots', 'speed_boots', 'amulet')) {
    if ($controllerSource.Contains($itemName)) {
        Write-Error "Prompt 21 controller inspects an equipment item name: '$itemName'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'dash_pressed_pending',
    '.dash_pressed = pending.dash_pressed_pending',
    'SDL_SCANCODE_LSHIFT',
    'SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER'
)) {
    if (-not ($inputSource + $sdlInputSource).Contains($phrase)) {
        Write-Error "Prompt 21 platform-neutral dash input contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'default_movement_observed',
    'modified_movement_observed',
    'stronger_jump_observed',
    'double_jump_denied',
    'double_jump_allowed',
    'dash_collision_observed',
    'duplicate_grants_preserved',
    'character_isolation_observed'
)) {
    if (-not $characterPropertiesDemoSource.Contains($phrase)) {
        Write-Error "Prompt 21 deterministic evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'attribute definitions modifiers and base overrides reject invalid data',
    'resolution uses deterministic additive then multiplicative stacking and clamps bounds',
    'capabilities count independent sources and removal preserves remaining grants',
    'equipment lifecycle resolves modifiers grants replacement reset and appearance-independent state',
    'resolved equipment properties drive movement jump double jump and dash through the controller',
    'dash collides with walls and default resolved controller path is regression-equivalent',
    'property resolution performs no allocation growth'
)) {
    if (-not $characterPropertiesTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 21 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'app_module.addImport("character_properties", character_properties_module)',
    'test_module.addImport("character_properties", character_properties_module)',
    'app_module.addImport("character_properties_demo", character_properties_demo_module)'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 21 build wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'try scene.player.stepController(&scene.world, intent_value)',
    'try player.initializeEquipment(equipment_definition.view())',
    'try scene.player.submitUnified(queue)',
    'pub fn applyViewport(scene: *Scene, width: u32, height: u32)',
    'pub fn resetWorld(scene: *Scene)',
    'try scene.manager.updateTick(scene.simulation_tick, &participants_value)',
    'scene.evidence.conventional_sleeves != 2',
    'scene.evidence.nonstandard_sleeves != 4',
    'runtime_allocation_delta != 0',
    'gpu_resource_delta != 0'
)) {
    if (-not ($foundationSource + [Environment]::NewLine + $gpuSource).Contains($phrase)) {
        Write-Error "Prompt 22 integrated foundation contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($foundationSource, 'SDL_|CreateGPU|ReleaseGPU|DrawGPU|controller\.state\.(position|velocity|grounded|supporting_collider)\s*=|player\.world_position\s*=')) {
    Write-Error 'Prompt 22 scene must not poll SDL, own GPU APIs, or directly mutate authoritative controller/root state.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'bounded foundation script verifies world customization properties abilities interaction resize and reset',
    'synthetic viewport changes preserve gameplay loadout capabilities and pending input edges',
    'foundation reset restores the complete configured baseline without stale mesh or secondary state',
    'foundation unified ordering stays deterministic and bounded across topology and loadout changes'
)) {
    if (-not $foundationTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 22 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'app_module.addImport("foundation_playground", foundation_playground_module)',
    'test_module.addImport("foundation_playground", foundation_playground_module)',
    'b.step("test-foundation"'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 22 build wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @('SDL_SCANCODE_C', 'SDL_SCANCODE_V', 'SDL_SCANCODE_H', 'SDL_SCANCODE_L')) {
    if (-not $sdlInputSource.Contains($phrase)) {
        Write-Error "Prompt 22 platform-neutral customization mapping is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const maximum_texture_pages: usize = 8',
    'pub const TexturePageId = enum(u16)',
    'pub const AtlasRegionId = enum(u32)',
    'pub const VisualSemanticId = enum(u32)',
    'pub const ViewId = enum(u16)',
    'pub const SamplingPolicy = enum(u8)',
    'pub fn resolve(',
    'ReferenceAssetPathForbidden',
    'DuplicateVisualBinding',
    'AtlasRectangleOutOfBounds'
)) {
    if (-not $artPackSource.Contains($phrase)) {
        Write-Error "Prompt 23 immutable art-pack contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'LoadLibraryW',
    'clsid_wic_imaging_factory',
    'png_container_format',
    'rgba8_pixel_format',
    'pub fn decodePngFile',
    'ImageUploadSizeExceeded',
    'MissingImageFile',
    'MalformedImage',
    'UnsupportedPixelLayout'
)) {
    if (-not $imageDecodeSource.Contains($phrase)) {
        Write-Error "Prompt 23 Windows image-decoding contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($imageDecodeSource, 'std\.compress|IHDR|IDAT|inflate|deflate')) {
    Write-Error 'Prompt 23 must use Windows Imaging Component rather than a custom PNG codec.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'createArtTexturePage',
    'runArtTextureFaultChecks',
    'art texture page-set rollback passed',
    'textureBinding(range.texture_page)',
    'SDL_BindGPUFragmentSamplers',
    'image_decode.decodePngFile',
    'gpu_resource_delta != 0'
)) {
    if (-not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 23 multi-page GPU ownership or evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::Matches($gpuSource, 'image_decode\.decodePngFile').Count -ne 1) {
    Write-Error 'Prompt 23 must have exactly one initialization-only PNG decode call site.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'p23_mechanical_atlas.png',
    'p23_energy_atlas.png',
    'addInstallFileWithDir',
    'app_module.addImport("art_pack", art_pack_module)',
    'app_module.addImport("image_decode", image_decode_module)',
    'app_module.addImport("art_asset_demo", art_asset_demo_module)',
    'b.step("test-art"'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 23 build/install wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'sampling policy accepts a smooth future art page without changing renderer identity',
    'atlas UV normalization and semantic resolution survive source declaration reordering',
    'art metadata rejects duplicate ids names bindings and conflicting semantic names',
    'art metadata rejects malformed paths dimensions regions geometry and references',
    'focused art scene submits sprites and mesh across pages without steady-state allocation'
)) {
    if (-not $artPipelineTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 23 art-definition coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'PNG metadata catches unsupported layouts zero dimensions overflow and upload limits',
    'WIC decodes production PNG alpha and classifies missing corrupt and unsupported files',
    'PNG decode allocation failure leaves the fixed allocator unchanged'
)) {
    if (-not $imageDecodeTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 23 image-decoder coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    '.sampling = .nearest',
    'arbitrary_detail_view',
    '.kind = .character',
    '.kind = .equipment',
    '.kind = .environment',
    'renderer_page_offset'
)) {
    if (-not $artAssetDemoSource.Contains($phrase)) {
        Write-Error "Prompt 23 focused proof content is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($phrase in @(
    'pub const View = enum(u8)',
    'side,',
    'front,',
    'pub const DebugOverride = enum(u8)',
    'if (runtime.interaction_owner != 0) return runtime.interaction_view',
    '.automatic => automaticView(automatic_input)',
    '.idle => .front',
    '.walking, .dashing, .jumping, .rising, .falling, .landing => .side',
    'pub fn claimInteraction',
    'pub fn releaseInteraction'
)) {
    if (-not $presentationViewSource.Contains($phrase)) {
        Write-Error "Prompt 24 presentation-view authority is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($presentationViewSource, 'SDL_|CreateGPU|DrawGPU|CharacterController|CollisionWorld|world_position|velocity\s*=|Facing')) {
    Write-Error 'Prompt 24 presentation-view policy must remain platform, GPU, physics-root, and gameplay-facing independent.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'presentation: presentation_view.Runtime',
    'pub fn presentationView',
    'pub fn setPresentationOverride',
    'pub fn claimInteractionPresentation',
    'pub fn releaseInteraction(instance: *CharacterInstance, owner_id: u32)',
    'pub fn syncPresentationView',
    'if (change.changed()) try instance.clearAttachmentSecondaryMotion()'
)) {
    if (-not $characterSource.Contains($phrase)) {
        Write-Error "Prompt 24 character integration is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const PresentationDefinition = struct',
    'role_views: [participant_count]?presentation_view.View',
    'suppress_automatic_view: bool = false',
    'occlusion_profile: OcclusionProfileId = .none',
    '.presentation = input.presentation'
)) {
    if (-not $interactionDefinitionSource.Contains($phrase)) {
        Write-Error "Prompt 27 typed interaction-presentation contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $handshakeDefinitionSource.Contains('.role_views = .{ .side, .side }') -or
    -not $handshakeDefinitionSource.Contains('.occlusion_profile = .handshake_right_hand_contact') -or
    -not $interactionSystemSource.Contains('viewForRole(.initiator)') -or
    -not $interactionSystemSource.Contains('viewForRole(.receiver)') -or
    -not $interactionSystemSource.Contains('applyOcclusionProfile') -or
    -not $interactionSystemSource.Contains('claimInteractionPresentation') -or
    -not $characterSource.Contains('presentation.releaseInteraction(owner_id)')) {
    Write-Error 'Prompt 27 interaction presentation must resolve per-role views and typed occlusion while releasing through character cleanup.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    '[skeleton.maximum_bones]math.Mat3',
    '[appearance.maximum_attachment_points]math.Mat3',
    'pub const FrontProjection = struct',
    'state.local_deformation.localToParent()',
    'state.secondary.resolvedTransform'
)) {
    if (-not $presentationPoseSource.Contains($phrase)) {
        Write-Error "Prompt 24 bounded front projection is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($presentationPoseSource, 'allocator|SDL_|CreateGPU|CharacterController|CollisionWorld|Animator')) {
    Write-Error 'Prompt 24 front projection must remain fixed-capacity presentation math over the shared pose.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'p25a_male_base_anatomy_atlas.png',
    'p25a_female_base_anatomy_atlas.png',
    'p25b_anatomy_components_atlas.png',
    'pub const region_inputs = makeRegionInputs()',
    'pub const binding_inputs = makeBindingInputs()',
    'presentation_view.View',
    'frontBodyPartLayer',
    'presentationVisualWorld',
    'projection.visualWorld',
    'queue.submitSprite'
)) {
    if (-not $characterArtSource.Contains($phrase)) {
        Write-Error "Prompt 24 production character-art routing is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const Garment = enum(u8)',
    'side_training_vest',
    'front_training_vest',
    '.kind = .equipment',
    'validateAnatomyClothingBoundary',
    'resolveBaseAnatomy',
    'resolveGarment',
    'AnatomyGarmentIdentityCollision',
    'AnatomyGarmentCoPackingEvidenceMissing'
)) {
    if (-not $characterArtSource.Contains($phrase)) {
        Write-Error "Prompt 24A anatomy/clothing ownership boundary is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch($characterArtSource, '(?i)torso_wearing|arm_with_sleeve|leg_with_pants|foot_with_shoe')) {
    Write-Error 'Prompt 24A canonical anatomy names must not encode removable garments.' -ErrorAction Continue
    $failed = $true
}
if ($characterArtSource.Contains('p24_male_character_atlas.png') -or
    $characterArtSource.Contains('p24_female_character_atlas.png')) {
    Write-Error 'Prompt 24A production bindings must not retain the original clothing-baked atlas paths.' -ErrorAction Continue
    $failed = $true
}
if ([regex]::IsMatch($characterArtSource + [Environment]::NewLine + $characterPresentationDemoSource, 'FemaleRenderer|MaleRenderer|SDL_CreateGPU|SDL_DrawGPU|CharacterController\s*=|controller\.state\.(position|velocity|grounded|supporting_collider)\s*=')) {
    Write-Error 'Prompt 24 must not add sex-specific renderers, scene-owned GPU calls, or presentation-owned gameplay mutation.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'male_front_idle',
    'front_preserved_left_facing',
    'long_hair_motion_observed',
    'handshake_side_view_observed',
    'returned_to_front_after_interaction',
    'update_allocations={d} submission_allocations={d} queue_allocations={d} gpu_resource_delta={d}'
)) {
    if (-not ($characterPresentationDemoSource + [Environment]::NewLine + $gpuSource).Contains($phrase)) {
        Write-Error "Prompt 24 bounded evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'p25a_male_base_anatomy_atlas.png',
    'p25a_female_base_anatomy_atlas.png',
    'p25b_anatomy_components_atlas.png',
    'app_module.addImport("presentation_view", presentation_view_module)',
    'app_module.addImport("character_art", character_art_module)',
    'app_module.addImport("character_presentation_demo", character_presentation_demo_module)',
    '"test-presentation",'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 24 build/install wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $sdlInputSource.Contains('SDL_SCANCODE_Q') -or
    -not $inputSource.Contains('presentation_view_cycle')) {
    Write-Error 'Prompt 24 unused Q control must map to the platform-neutral presentation-view command.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'automatic presentation policy is authoritative and complete',
    'facing is preserved across view changes and reset restores automatic front',
    'side reflection remains single-root while front projection never reflects facing',
    'character art definitions cover both views bald buzz cut and long hair',
    'actual base anatomy resolves without a garment and garment identity cannot replace anatomy',
    'interaction owns side view and cancellation releases both participants to front',
    'view transition clears long-hair spring state without allocation or cross-character mutation'
)) {
    if (-not $characterPresentationTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 24 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}

foreach ($relativePath in @(
    'assets/art/p25_wardrobe_upper_atlas.png',
    'assets/art/p25_wardrobe_layers_atlas.png',
    'assets/art/p25_wardrobe_lower_atlas.png',
    'docs/OUTFIT_REFERENCE_INVENTORY.md',
    'docs/WARDROBE.md',
    'docs/WARDROBE_DECISION_RECORD.md'
)) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-Item -LiteralPath $path).Length -eq 0) {
        Write-Error "Prompt 25 required production asset/document is missing or empty: '$relativePath'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const visual_count: usize = 36',
    'pub const preset_count: usize = 15',
    'pub const custom_item_count: usize = 7',
    'presentation_semantic',
    '.selection = .every_compatible',
    '"upper_outer"',
    '"sleeves_outer"',
    '"wide_brim_crimson"',
    '"ivory_blouse_red_shorts"',
    '"base_only"',
    'customItems',
    '"ivory_blouse"',
    '"crimson_cardigan"',
    'skirt_secondary_motion',
    '.attribute_modifiers = &.{}',
    '.capability_grants = &.{}'
)) {
    if (-not $wardrobeCatalogSource.Contains($phrase)) {
        Write-Error "Prompt 25 typed wardrobe catalog contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'p25_wardrobe_upper_atlas.png',
    'p25_wardrobe_layers_atlas.png',
    'p25_wardrobe_lower_atlas.png',
    'pub const region_count: usize = wardrobe_catalog.visual_count * regions_per_visual',
    'pub const binding_count: usize = region_count',
    'validateCatalog',
    '.side',
    '.front'
)) {
    if (-not $wardrobeArtSource.Contains($phrase)) {
        Write-Error "Prompt 25 paired wardrobe-art binding is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'art_definition.resolve(presentation_semantic, false)',
    'art_definition.resolve(presentation_semantic, true)',
    'FrontAnatomyProjection.init',
    'projectedEquipmentTransform',
    'queue.submitSprite',
    'queue.submitMesh',
    'front_skirt_mesh',
    'side_skirt_mesh'
)) {
    if (-not $wardrobePresentationSource.Contains($phrase)) {
        Write-Error "Prompt 25 view-aware unified presentation is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$wardrobeSubmitStart = $wardrobePresentationSource.IndexOf('    pub fn submit(')
$wardrobeSubmitEnd = $wardrobePresentationSource.IndexOf('fn semantic(', $wardrobeSubmitStart)
if ($wardrobeSubmitStart -lt 0 -or $wardrobeSubmitEnd -le $wardrobeSubmitStart) {
    Write-Error 'Prompt 25 wardrobe submission audit could not isolate the steady-state implementation.' -ErrorAction Continue
    $failed = $true
} else {
    $wardrobeSubmitSource = $wardrobePresentationSource.Substring(
        $wardrobeSubmitStart,
        $wardrobeSubmitEnd - $wardrobeSubmitStart
    )
    if ([regex]::IsMatch($wardrobeSubmitSource, 'allocator|\.alloc\(|image_decode|SDL_CreateGPU|SDL_UploadToGPU')) {
        Write-Error 'Prompt 25 steady-state wardrobe submission must not allocate, decode, or create/upload GPU resources.' -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const required_frames: u32 = 600',
    'selectPreset',
    'selectCustom',
    'preset_front_observed',
    'preset_side_observed',
    'long_garment_secondary_motion',
    'long_hair_with_headwear',
    'footwear_observed',
    'male_unchanged',
    'scene.wardrobe.submit'
)) {
    if (-not $wardrobeDemoSource.Contains($phrase)) {
        Write-Error "Prompt 25 bounded demonstration evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch(
    $wardrobeCatalogSource + [Environment]::NewLine +
    $wardrobePresentationSource + [Environment]::NewLine +
    $wardrobeDemoSource,
    'SDL_CreateGPU|SDL_UploadToGPU|image_decode|FemaleRenderer|MaleRenderer'
)) {
    Write-Error 'Prompt 25 catalog/presentation/demo must not own GPU creation, runtime decoding, or sex-specific renderers.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'occupancy layering coverage and semantic foot binding remain independent',
    'repeated sleeves follow two and four arm topology while headwear preserves long hair',
    'preset selection is transactional and preserves non-equipment character state',
    'long garment mesh and secondary state clear on replacement and reset returns empty default',
    'front and side preset cycling and submission allocate nothing after initialization',
    'O and P controls produce focus-safe outfit-cycle and pause edges'
)) {
    if (-not $wardrobeTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 25 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'p25_wardrobe_upper_atlas.png',
    'p25_wardrobe_layers_atlas.png',
    'p25_wardrobe_lower_atlas.png',
    'app_module.addImport("wardrobe_demo", wardrobe_demo_module)',
    'test_module.addImport("wardrobe_demo", wardrobe_demo_module)',
    '"test-wardrobe",'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 25 build/install/test wiring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $sdlInputSource.Contains('SDL_SCANCODE_O') -or
    -not $sdlInputSource.Contains('SDL_SCANCODE_P') -or
    -not $inputSource.Contains('outfit_cycle') -or
    -not $inputSource.Contains('pause_toggle')) {
    Write-Error 'Prompt 25 O/P controls must map through the platform-neutral focus-safe input snapshot.' -ErrorAction Continue
    $failed = $true
}

foreach ($relativePath in @(
    'assets/art/p25a_male_base_anatomy_atlas.png',
    'assets/art/p25a_female_base_anatomy_atlas.png',
    'assets/art/p25b_anatomy_components_atlas.png',
    'docs/PROMPT25A_DECISION_RECORD.md',
    'docs/PROMPT25B_DECISION_RECORD.md',
    'docs/VISUAL_ACCEPTANCE_25A.md'
)) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-Item -LiteralPath $path).Length -eq 0) {
        Write-Error "Prompt 25A required production asset/document is missing or empty: '$relativePath'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'remapProjectedArmRest',
    'initBoneWorlds',
    '&authoritative_locals'
)) {
    if (-not $presentationPoseSource.Contains($phrase)) {
        Write-Error "Prompt 25D authoritative view composition is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($rejectedPhrase in @(
    'front_arm_x_compression',
    'side_arm_x_compression',
    'compressArmRoots'
)) {
    if ($presentationPoseSource.Contains($rejectedPhrase)) {
        Write-Error "Prompt 25D must not retain rejected arm-root compression: '$rejectedPhrase'." -ErrorAction Continue
        $failed = $true
    }
}
if (-not $presentationViewSource.Contains('spriteMorphologyScale')) {
    Write-Error "Prompt 25D shared quarter-turn morphology mapping is missing: 'spriteMorphologyScale'." -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'p25a_male_base_anatomy_atlas',
    'p25a_female_base_anatomy_atlas',
    'p25b_anatomy_components_atlas',
    'component_page_id',
    'mirrorsFrontRegion',
    'connectorLayer',
    'componentSourceRect'
)) {
    if (-not $characterArtSource.Contains($phrase)) {
        Write-Error "Prompt 25B production anatomy correction is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'std.mem.startsWith',
    '"left_"',
    'world_size.x = -world_size.x'
)) {
    if (-not $wardrobePresentationSource.Contains($phrase)) {
        Write-Error "Prompt 25B bilateral equipment mirroring is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'footwear_ankle_offset_metres: f32 = -0.35',
    '.pivot = .{ 0.70, 0.62 }'
)) {
    if (-not $wardrobeCatalogSource.Contains($phrase)) {
        Write-Error "Prompt 25D semantic footwear registration is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    '.{ .x = 1288, .y = 811, .width = 172, .height = 151 }',
    '.{ .x = 1281, .y = 307, .width = 120, .height = 205 }'
)) {
    if (-not $wardrobeArtSource.Contains($phrase)) {
        Write-Error "Prompt 25A alpha-tight region correction is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'visual_capture_transfer',
    'initializeVisualCaptureTransfer',
    'captureUnifiedToPpm',
    'source=same_prepared_global_queue'
)) {
    if (-not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 25A bounded D3D capture evidence is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'Prompt 25B production anatomy pages and regions have exact valid bounds',
    'Prompt 25D real component bindings are distinct with valid authored extents',
    'Prompt 25D component sizes and pivots follow view-specific rig spans',
    'Prompt 25D final front joins retain accepted authored geometry',
    'Prompt 25D side projection preserves one readable profile root per bilateral pair',
    'Prompt 25D wardrobe pivots match alpha-derived semantic anchors',
    'Prompt 25B bilateral footwear receives mirrored submission metadata',
    'Prompt 25A wardrobe regions are nonzero bounded and alpha-tight where required',
    'Prompt 25A side anatomy submission geometry remains registered at joints',
    'Prompt 25A front anatomy geometry overlaps every core limb joint',
    'Prompt 25A acceptance schedule is deterministic and allocation free'
)) {
    if (-not ($characterPresentationTestsSource + [Environment]::NewLine + $wardrobeTestsSource).Contains($phrase)) {
        Write-Error "Required Prompt 25A deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$prompt25bArtAudit = Join-Path $repositoryRoot 'tools/audit_p25b_art.ps1'
if (-not (Test-Path -LiteralPath $prompt25bArtAudit -PathType Leaf)) {
    Write-Error 'Prompt 25B automated source-alpha audit is missing.' -ErrorAction Continue
    $failed = $true
} else {
    & $prompt25bArtAudit -RepositoryRoot $repositoryRoot
    if (-not $?) {
        Write-Error 'Prompt 25B automated source-alpha audit failed.' -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const ThemeId = enum(u8)',
    'violet_crystal_ruin',
    'neutral_debug',
    'pub const SurfaceOverlay',
    'ground_query_eligible',
    'pub fn submit(',
    'pub fn cycle('
)) {
    if (-not ($environmentArtSource + [Environment]::NewLine + $environmentThemeSource).Contains($phrase)) {
        Write-Error "Required Prompt 26 environment-theme contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'wardrobe_demo.Scene',
    'GameplaySnapshot',
    'collision_fingerprint',
    'surface_fingerprint',
    'environment_theme_cycle',
    'scene.environment.submit'
)) {
    if (-not $environmentDemoSource.Contains($phrase)) {
        Write-Error "Required Prompt 26 production-composition proof is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'Prompt 26 art pack contains both complete nearest-sampled original themes',
    'standable surface overlay is an exact collision-authority projection',
    'theme switching preserves collision spawn view outfit clock input and interaction state',
    'environment submission orders terrain then white surfaces then characters and debug',
    'scripted Prompt 26 matrix proves front side parallax swap raised-platform landing reset resize and stability'
)) {
    if (-not $environmentTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 26 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
$prompt26ArtAudit = Join-Path $repositoryRoot 'tools/audit_p26_environment_art.ps1'
if (-not (Test-Path -LiteralPath $prompt26ArtAudit -PathType Leaf)) {
    Write-Error 'Prompt 26 automated environment-art audit is missing.' -ErrorAction Continue
    $failed = $true
} else {
    & $prompt26ArtAudit -RepositoryRoot $repositoryRoot
    if (-not $?) {
        Write-Error 'Prompt 26 automated environment-art audit failed.' -ErrorAction Continue
        $failed = $true
    }
}
if ([regex]::IsMatch(
    $environmentArtSource + [Environment]::NewLine +
    $environmentThemeSource + [Environment]::NewLine +
    $environmentDemoSource + [Environment]::NewLine +
    $environmentTestsSource,
    '(?i)prompt[ _-]?27|p27[_-]'
)) {
    Write-Error 'Prompt 27 orchestration must not be embedded in Prompt 26 environment ownership.' -ErrorAction Continue
    $failed = $true
}
foreach ($phrase in @(
    'environment_demo.Scene',
    'interaction_system.Manager',
    'production.stepFemale',
    'projected_hand_separation',
    'validateComplete',
    'required_frames: u32 = 2_400'
)) {
    if (-not $visualFoundationSource.Contains($phrase)) {
        Write-Error "Prompt 27 production-composed visual foundation is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'Prompt 27 bounded real-art foundation route proves presentation interaction and reset',
    'interaction presentation data can select front without a second interaction subsystem',
    'interaction presentation rejects suppression without both role views'
)) {
    if (-not $visualFoundationTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 27 deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'pub const specs = [_]CaptureSpec',
    'minimum_stable_ticks',
    'timeout_render_frames',
    'landing_surface_contact_threshold_m',
    'CapturePredicateTimeout',
    'CaptureCommitStateMismatch',
    'CaptureMatrixIncomplete'
)) {
    if (-not $foundationEvidenceSource.Contains($phrase)) {
        Write-Error "Prompt 27A state-conditioned evidence contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'maximum_hud_sprites',
    'foundation_evidence.Observation',
    'UnifiedRenderQueue',
    'cpu_allocations_after_stabilization'
)) {
    if (-not ($acceptanceHudSource + [Environment]::NewLine + $visualFoundationTestsSource).Contains($phrase)) {
        Write-Error "Prompt 27A bounded acceptance HUD contract is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'Prompt 27A timeout fails instead of omitting a capture',
    'Prompt 27A stability is independent of duplicate render observations',
    'Prompt 27A capture commit validates order and current metadata',
    'Prompt 27A raised landing requires measured bilateral surface contact',
    'Prompt 27A acceptance HUD is bounded and allocation free after initialization'
)) {
    if (-not $visualFoundationTestsSource.Contains($phrase)) {
        Write-Error "Required Prompt 27A deterministic coverage is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'Expected exactly $($expected.Count) PPM captures',
    'Duplicate D3D12 pixel payload detected',
    'payload_hash_matches_metadata',
    'manual_visual_acceptance = "PENDING OWNER REVIEW"',
    'New-ContactSheet "04_interaction_sequence"'
)) {
    if (-not $p27aReviewSource.Contains($phrase)) {
        Write-Error "Prompt 27A deterministic review package is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'semantic_metadata_match',
    'ppm_byte_identical',
    'metadata_byte_identical',
    'png_byte_identical',
    'canonical_metrics_identical'
)) {
    if (-not $p27aRepeatSource.Contains($phrase)) {
        Write-Error "Prompt 27A repeatability audit is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'src/scene/visual_foundation.zig',
    'src/scene/foundation_evidence.zig',
    'src/debug/acceptance_hud.zig',
    'tests/visual_foundation_tests.zig',
    'b.step(',
    '"test-visual-foundation"',
    '"p27a-review"'
)) {
    if (-not $buildSource.Contains($phrase)) {
        Write-Error "Prompt 27 build integration is missing: '$phrase'." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($phrase in @(
    'PROMPT 27A STATE-CONDITIONED VISUAL FOUNDATION EVIDENCE',
    'PROMPT 27 INTERACTIVE SESSION SUMMARY',
    'self.visual_captures_written != foundation_capture_count',
    'candidate_pending_owner_review',
    'consecutive_stable_ticks'
)) {
    if (-not $gpuSource.Contains($phrase)) {
        Write-Error "Prompt 27 GPU acceptance or interactive-session boundary is missing: '$phrase'." -ErrorAction Continue
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
Write-Host 'Prompt 26 environment audit passed: both preloaded themes use production art-pack assets, exact collision-derived walkable surface overlays, invariant gameplay authority, one global queue, bounded hot switching, and no Prompt 27 orchestration in environment ownership.'
Write-Host 'Prompt 27 visual-foundation audit passed: real-art production composition, typed per-role interaction presentation, focused deterministic coverage, and explicit build integration are present.'
Write-Host 'Prompt 27A evidence-integrity audit passed: state predicates, stable holds, fail-closed metadata, bounded HUD submission, D3D12 review packaging, and repeatability comparison are present.'
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
Write-Host 'Prompt 14 camera audit passed: world-metre submissions, pure camera math, same-zoom resizing, high-DPI drawable tracking, safe zero surfaces, deterministic follow, three-layer parallax, extended collision world, fixed smoke target, and one global draw path.'
Write-Host 'Prompt 15 appearance audit passed: stable runtime IDs, variable visuals, bounded attachment hierarchies, optional module-local joints, character-owned mutable state, canonical-rig isolation, and allocation-free hot paths.'
Write-Host 'Prompt 16 modular-anatomy audit passed: compositional repeated parts, bounded hierarchies, data morphs and presets, face/hair groups, presentation isolation, canonical-authority isolation, and allocation-free hot paths.'
Write-Host 'Prompt 17 equipment audit passed: extensible typed definitions, anatomy-aware bounded expansion, transactional loadouts, independent coverage/effects, character-owned state, and the global sprite path.'
Write-Host 'Prompt 18 deformation audit passed: fixed-tick breathing, shared instance-bound resolution, declarative visual response, gameplay isolation, bounded evidence, and allocation-free hot paths.'
Write-Host 'Prompt 19 mesh-attachment audit passed: validated immutable topology, per-binding mutable ownership, one semantic sprite/mesh queue, persistent SDL GPU topology, bounded frame slots, shared deformation, honest metrics, and deterministic evidence.'
Write-Host 'Prompt 21 character-property audit passed: typed finite definitions, stable-source stacking, counted capabilities, transactional character recomputation, generic controller consumption, platform-neutral dash, bounded evidence, and no renderer/allocation dependency.'
Write-Host 'Prompt 22 foundation audit passed: one production world/controller path, modular topology and loadouts, separated visual/property branches, unified mixed rendering, resize/reset invariance, bounded evidence, and no scene-owned SDL/GPU authority.'
Write-Host 'Prompt 23 art-pipeline audit passed: WIC PNG alpha decode, immutable stable semantics, bounded multi-page ownership, per-pack sampling, common sprite/mesh binding, installed original assets, rollback evidence, and allocation-free steady state.'
Write-Host 'Prompt 24 character-presentation audit passed: distinct facing/view authority, fixed-tick automatic policy, interaction-owned side view, shared-pose front projection, single-root side reflection, original segmented art, explicit front layers, bounded spring reset, one global queue, and allocation/resource-free view changes.'
Write-Host 'Prompt 24A art-boundary audit passed: production base anatomy resolves without garments, character/equipment identities remain distinct on shared pages, clothing-baked canonical names and legacy production paths are absent, and garment resolution cannot replace anatomy.'
Write-Host 'Prompt 25 wardrobe audit passed: original paired production art, typed reusable items/presets, independent slots/layers/coverage, topology-aware bindings, transactional cycling, cosmetic effects, long-mesh reuse, focus-safe controls, unified submission, and allocation/resource-free steady state.'
Write-Host 'Prompt 25A visual-correction audit passed: re-authored separated anatomy, view spacing, joint overlap, connector layers, alpha-tight wardrobe regions, mirrored footwear submission metadata, bounded D3D captures, and focused deterministic coverage.'
Write-Host 'Prompt 25B art-correction audit passed: real forearm/shin assets, bounded alpha/aspect checks, deterministic bilateral submission mirroring, authoritative single-pass side projection, corrected connector order, D3D comparison captures, and unchanged unified rendering ownership.'
Write-Host (('Place' + 'holder') + '/disabled-test audit passed: the audited implementation-file scan is empty.')
