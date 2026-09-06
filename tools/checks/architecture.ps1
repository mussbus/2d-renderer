[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failed = $false

function Add-Failure([string]$Message) {
    Write-Error $Message -ErrorAction Continue
    $script:failed = $true
}
function Read-RepositoryFile([string]$RelativePath) {
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot $RelativePath)
}

# F2C supported-surface and internal white-box separation.
$sceneCoreRoot = Read-RepositoryFile 'src/scene_core/root.zig'
$runtimeScene = Read-RepositoryFile 'src/scene_core/runtime_scene.zig'
if ([regex]::IsMatch($sceneCoreRoot, 'pub\s+const\s+(registry|runtime_entity)\s*=') -or
    $runtimeScene.Contains('pub const EntityRegistry') -or
    $runtimeScene.Contains('pub const RuntimeEntity')) {
    Add-Failure 'F2C authority violation: mutable scene registry/entity storage escaped the supported scene_core surface.'
}
$internalScenePattern = '@import\s*\(\s*"[^"]*scene_core[/\\](registry|runtime_entity)\.zig"\s*\)|@import\s*\(\s*"scene_core_(internal|registry_internal|runtime_entity_internal)"\s*\)'
$sceneCoreDirectory = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'src/scene_core')) + [IO.Path]::DirectorySeparatorChar
foreach ($file in @(Get-ChildItem -File -Recurse -Filter '*.zig' -LiteralPath (Join-Path $repositoryRoot 'src'))) {
    if (-not $file.FullName.StartsWith($sceneCoreDirectory, [StringComparison]::OrdinalIgnoreCase) -and
        [regex]::IsMatch((Get-Content -Raw -LiteralPath $file.FullName), $internalScenePattern)) {
        Add-Failure "F2C authority violation: production source imports scene_core internals: $($file.FullName)."
    }
}
foreach ($file in @(Get-ChildItem -File -Recurse -Filter '*.zig' -LiteralPath (Join-Path $repositoryRoot 'tests/scene_core') |
    Where-Object { $_.Name -ne 'registry_tests.zig' })) {
    if ([regex]::IsMatch((Get-Content -Raw -LiteralPath $file.FullName), $internalScenePattern)) {
        Add-Failure "F2C test boundary violation: public contract test imports scene_core internals: $($file.FullName)."
    }
}

# F4C1 production-definition ownership and scenario dependency direction.
$scenarioModules = @(
    'controller_demo', 'handshake_ik_demo', 'integrated_demo', 'playground_demo',
    'modular_body_demo', 'equipment_demo', 'mesh_attachment_demo',
    'foundation_playground', 'visual_foundation',
    'wardrobe_demo', 'environment_demo'
)
$allowedScenarioImports = @{
    'src/main.zig' = @('visual_foundation')
    'src/app/demo_application.zig' = $scenarioModules
    'src/scene/anatomy_quality_report.zig' = @('wardrobe_demo')
    'src/scene/environment_demo.zig' = @('wardrobe_demo')
    'src/scene/foundation_coherence_report.zig' = @('visual_foundation')
    'src/scene/visual_foundation.zig' = @('environment_demo', 'wardrobe_demo')
    'src/scene/visual_geometry_report.zig' = @('wardrobe_demo')
}
$scenarioPattern = '@import\s*\(\s*"(?<module>' + (($scenarioModules | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')"\s*\)'
$productionFiles = @(Get-ChildItem -File -Recurse -Filter '*.zig' -LiteralPath (Join-Path $repositoryRoot 'src'))
foreach ($file in $productionFiles) {
    $relative = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')
    $allowed = @($allowedScenarioImports[$relative])
    $source = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($source, $scenarioPattern)) {
        if ($match.Groups['module'].Value -notin $allowed) {
            Add-Failure "F4C1 dependency violation: '$relative' imports scenario module '$($match.Groups['module'].Value)' outside its allowlist."
        }
    }
}
$ownershipRequirements = @(
    @('src/scene/modular_humanoid.zig', 'pub fn initDefinition'),
    @('src/scene/equipment_catalog.zig', 'pub fn initDefinition'),
    @('src/scene/attachment_meshes.zig', 'pub fn initFittedGarmentMesh'),
    @('src/scene/attachment_meshes.zig', 'pub fn initSleeveMesh'),
    @('src/scene/attachment_meshes.zig', 'pub fn initCapeMesh'),
    @('src/scene/art_asset_catalog.zig', 'pub fn definitionInput'),
    @('src/scene/foundation_world.zig', 'pub fn colliderInputs')
)
foreach ($requirement in $ownershipRequirements) {
    if (-not (Read-RepositoryFile $requirement[0]).Contains($requirement[1])) {
        Add-Failure "F4C1 production ownership is missing '$($requirement[1])' in '$($requirement[0])'."
    }
}

# F4C2 renderer/application/evidence authority.
$renderer = Read-RepositoryFile 'src/graphics/sdl_gpu_renderer.zig'
$application = Read-RepositoryFile 'src/app/demo_application.zig'
$captureContract = Read-RepositoryFile 'src/graphics/frame_capture.zig'
$captureWriter = Read-RepositoryFile 'src/evidence/capture_writer.zig'
foreach ($forbidden in $scenarioModules + @('foundation_evidence', 'foundation_coherence', 'acceptance_hud', 'visual_truth', 'anatomy_evidence', 'capture_writer', 'demo_application')) {
    if ([regex]::IsMatch($renderer, '@import\s*\(\s*"' + [regex]::Escape($forbidden) + '"\s*\)')) {
        Add-Failure "F4C2 dependency violation: renderer imports '$forbidden'."
    }
}
if (-not $renderer.Contains('pub const Renderer = struct') -or
    -not $renderer.Contains('const State = struct') -or
    $renderer.Contains('pub const State = struct') -or
    -not $renderer.Contains('pub fn captureUnified') -or
    -not $renderer.Contains('frame_capture.CapturedFrame') -or
    [regex]::IsMatch($renderer, 'createFile|createDirPath|writeRgbaPng|writeStreamingAll')) {
    Add-Failure 'F4C2 renderer handle/capture boundary is incomplete.'
}
$rawGpuPattern = 'SDL_(Create|Destroy|Release|Acquire|Submit|Map|Unmap|Download|Upload)[A-Za-z0-9_]*GPU|SDL_GPU(Device|Texture|Buffer|Shader|Sampler|Fence|GraphicsPipeline|TransferBuffer)'
if ([regex]::IsMatch($application, $rawGpuPattern) -or
    [regex]::IsMatch($captureWriter, 'SDL_GPU|@import\s*\(\s*"sdl_gpu_renderer"') -or
    [regex]::IsMatch($captureContract, 'SDL_GPU|@import\s*\(\s*"sdl"')) {
    Add-Failure 'F4C2 authority violation: application or evidence code owns raw GPU backend state.'
}
$engineSmoke = Read-RepositoryFile 'src/app/engine_smoke.zig'
if (-not $engineSmoke.Contains('renderer_module.Renderer.init') -or
    -not $engineSmoke.Contains('renderer.runSmoke()') -or
    $engineSmoke.Contains('demo_application') -or
    $engineSmoke.Contains('gpu_demo')) {
    Add-Failure 'F4E GPU-smoke route is not independently owned by the production renderer client.'
}

# F4C3 opaque character and interaction state.
$character = Read-RepositoryFile 'src/scene/character.zig'
$interaction = Read-RepositoryFile 'src/interaction/interaction_system.zig'
foreach ($file in $productionFiles) {
    $source = Get-Content -Raw -LiteralPath $file.FullName
    $relative = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')
    if ([regex]::IsMatch($source, '\b(character|interaction_system)\.testing\b')) {
        Add-Failure "F4C3 authority violation: production source references a white-box route: '$relative'."
    }
    if ($relative -notin @('src/scene/character.zig', 'src/interaction/interaction_system.zig') -and
        $source.Contains('.opaque_storage')) {
        Add-Failure "F4C3 authority violation: production source reaches opaque storage: '$relative'."
    }
}
if (-not $character.Contains('const CharacterState = struct') -or
    -not $character.Contains('pub const CharacterInstance = struct') -or
    -not $character.Contains('pub const testing = if (@import("builtin").is_test) struct') -or
    $character.Contains('pub const CharacterState = struct') -or $character.Contains('pub fn stateMut')) {
    Add-Failure 'F4C3 character state is not confined behind its supported facade.'
}
if (-not $interaction.Contains('const ManagerState = struct') -or
    -not $interaction.Contains('pub const Manager = struct') -or
    -not $interaction.Contains('pub fn metricsSnapshot') -or
    -not $interaction.Contains('pub fn lastTerminal') -or
    $interaction.Contains('pub const ManagerState = struct') -or $interaction.Contains('pub fn stateMut')) {
    Add-Failure 'F4C3 interaction state is not confined behind its supported facade.'
}

# F4C4 F-backed identity and physical/application/domain input boundaries.
$physicalInput = Read-RepositoryFile 'src/platform/input.zig'
$sdlInput = Read-RepositoryFile 'src/platform/sdl_input.zig'
$actions = Read-RepositoryFile 'src/app/demo_actions.zig'
$binding = Read-RepositoryFile 'src/scene/character_entity_binding.zig'
$integrated = Read-RepositoryFile 'src/scene/integrated_demo.zig'
foreach ($semantic in @('FrameInputSnapshot', 'SnapshotBuilder', 'PendingInput', 'CharacterIntent', 'manual_debug_capture', 'body_preset_cycle', 'build_cycle', 'hair_cycle', 'loadout_cycle', 'outfit_cycle', 'pause_toggle', 'presentation_view_cycle', 'environment_theme_cycle')) {
    if ($physicalInput.Contains($semantic) -or $sdlInput.Contains($semantic)) {
        Add-Failure "F4C4 platform-action violation: physical input contains '$semantic'."
    }
}
if ([regex]::IsMatch($physicalInput + [Environment]::NewLine + $sdlInput, '@import\s*\(\s*"(character|wardrobe|environment|foundation_evidence|character_intent|demo_actions)"\s*\)')) {
    Add-Failure 'F4C4 platform input imports application/domain ownership.'
}
foreach ($phrase in @('const physical = @import("physical_input")', 'const character_intent = @import("character_intent")', 'pub const FrameInputSnapshot = struct', 'pub const SnapshotBuilder = struct')) {
    if (-not $actions.Contains($phrase)) { Add-Failure "F4C4 action mapping is missing '$phrase'." }
}
foreach ($phrase in @('const foundation = @import("foundation")', 'const scene_core = @import("scene_core")', 'pub const CharacterEntityBindings = struct', 'PublicationParticipant', 'pub fn createPersistent', 'pub fn destroyEntity', 'pub fn acquireSnapshot')) {
    if (-not $binding.Contains($phrase)) { Add-Failure "F4C4 F binding is missing '$phrase'." }
}
foreach ($phrase in @('entity_bindings: character_entity_binding.CharacterEntityBindings', 'player_entity: foundation.identity.EntityHandle', 'partner_entity: foundation.identity.EntityHandle', 'prepareFBackedSimulation', 'publishFBackedTransforms', 'fEntityObservation', 'requireLiveFParticipants')) {
    if (-not $integrated.Contains($phrase)) { Add-Failure "F4C4 integrated lifecycle is missing '$phrase'." }
}
$allowedEntityDeclarations = @('src/foundation/identity.zig', 'src/scene/character.zig')
foreach ($file in $productionFiles) {
    $relative = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')
    $source = Get-Content -Raw -LiteralPath $file.FullName
    if ([regex]::IsMatch($source, '(?m)^\s*(pub\s+)?const\s+EntityId\s*=') -and $relative -notin $allowedEntityDeclarations) {
        Add-Failure "F4C4 identity violation: '$relative' declares a competing EntityId."
    }
}

# F4C5 explicit registration ownership and aggregate separation.
$rootBuild = Read-RepositoryFile 'build.zig'
$modulesBuild = Read-RepositoryFile 'build/modules.zig'
$appsBuild = Read-RepositoryFile 'build/apps.zig'
$engineBuild = Read-RepositoryFile 'build/tests_engine.zig'
$contentBuild = Read-RepositoryFile 'build/tests_content.zig'
$evidenceBuild = Read-RepositoryFile 'build/evidence.zig'
$gatesBuild = Read-RepositoryFile 'build/gates.zig'
foreach ($import in @('build/modules.zig', 'build/apps.zig', 'build/tests_engine.zig', 'build/tests_content.zig', 'build/evidence.zig', 'build/gates.zig')) {
    if (-not $rootBuild.Contains('@import("' + $import + '")')) {
        Add-Failure "F4C5 build ownership violation: root composition is missing '$import'."
    }
}
if ([regex]::IsMatch($rootBuild, '\.addTest\s*\(') -or
    [regex]::IsMatch($rootBuild, '\.addExecutable\s*\(') -or
    [regex]::IsMatch($rootBuild, 'tests[/\\][^"]+\.zig')) {
    Add-Failure 'F4C5 build ownership violation: root build directly registers a concrete application or test root.'
}
$allBuildHelpers = $modulesBuild + $appsBuild + $engineBuild + $contentBuild + $evidenceBuild + $gatesBuild
if ([regex]::IsMatch($allBuildHelpers, 'Get-ChildItem|walk\s*\(|openDir\s*\([^\)]*iterate')) {
    Add-Failure 'F4C5 build ownership violation: build registration uses directory auto-discovery.'
}
foreach ($step in @('"check"', '"test-full"', '"test-content"', '"verify"')) {
    if (-not $gatesBuild.Contains($step)) { Add-Failure "F4C5 aggregate gate is missing $step." }
}
foreach ($step in @('"gpu-smoke"', '"visual-acceptance"', '"evidence-history"')) {
    if (-not ($rootBuild + $appsBuild + $evidenceBuild).Contains($step)) { Add-Failure "F4C5 specialized gate is missing $step." }
}
if (-not $gatesBuild.Contains('tools/check_documentation.ps1') -or
    -not $gatesBuild.Contains('tools/check_repository.ps1') -or
    -not $gatesBuild.Contains('tools/check_content.ps1')) {
    Add-Failure 'F4C5 gate ownership is missing documentation, architecture, or content policy registration.'
}
if ($gatesBuild.Contains('.history') -or
    [regex]::IsMatch($gatesBuild, 'check_step\.dependOn\([^\)]*content') -or
    [regex]::IsMatch($gatesBuild, 'check_step\.dependOn\([^\)]*evidence')) {
    Add-Failure 'F4C5 gate violation: routine check depends on content or historical evidence.'
}

# F4D independent application composition and transitive dependency boundary.
$engineSmoke = Read-RepositoryFile 'src/app/engine_smoke.zig'
$engineSmokeClient = Read-RepositoryFile 'src/app/engine_smoke_client.zig'
$engineCompositionTests = Read-RepositoryFile 'tests/engine_composition_tests.zig'
$independentSource = $engineSmoke + [Environment]::NewLine + $engineSmokeClient
$independentForbidden = $scenarioModules + @(
    'demo_application', 'gpu_demo', 'foundation_evidence', 'foundation_coherence',
    'acceptance_hud', 'visual_truth', 'anatomy_evidence', 'capture_writer'
)
foreach ($forbidden in $independentForbidden) {
    if ([regex]::IsMatch($independentSource, '@import\s*\(\s*"' + [regex]::Escape($forbidden) + '"\s*\)')) {
        Add-Failure "F4D independence violation: independent application imports '$forbidden'."
    }
}
if ([regex]::IsMatch($independentSource, '@import\s*\(\s*"[^"]*_demo"\s*\)')) {
    Add-Failure 'F4D independence violation: independent application imports a demo scenario module.'
}
foreach ($phrase in @(
    'const client_module = @import("engine_smoke_client")',
    'const renderer_module = @import("sdl_gpu_renderer")',
    'scene_core.runtime_scene.RuntimeScene',
    'pub fn renderRequest',
    'renderer.captureUnified',
    'renderer.deinitWithMetrics'
)) {
    if (-not $independentSource.Contains($phrase)) {
        Add-Failure "F4D composition proof is missing '$phrase'."
    }
}
if (-not $appsBuild.Contains('.name = "engine_sandbox"') -or
    -not $appsBuild.Contains('.name = "engine_smoke"') -or
    -not $appsBuild.Contains('"run-engine-smoke"') -or
    -not $engineBuild.Contains('"test-engine-composition"') -or
    -not $gatesBuild.Contains('run_engine_composition')) {
    Add-Failure 'F4D build registration is missing the independent app or fast CPU composition proof.'
}
$independentModuleRegistrations = @(
    [regex]::Matches(
        $modulesBuild,
        'engine_smoke_(entry|client)_module\.addImport\(\s*"(?<module>[^"]+)"'
    )
)
foreach ($match in $independentModuleRegistrations) {
    $module = $match.Groups['module'].Value
    if ($module -in $independentForbidden -or $module -match '_demo$') {
        Add-Failure "F4D build dependency violation: independent module graph injects '$module'."
    }
}
foreach ($directory in @('src/scene_core', 'src/physics', 'src/animation', 'src/interaction')) {
    foreach ($file in @(Get-ChildItem -File -Recurse -Filter '*.zig' -LiteralPath (Join-Path $repositoryRoot $directory))) {
        $source = Get-Content -Raw -LiteralPath $file.FullName
        if ([regex]::IsMatch($source, '@import\s*\(\s*"(demo_application|gpu_demo|[^"]*_demo)"\s*\)')) {
            Add-Failure "F4D lower-layer dependency violation: '$($file.FullName)' imports application/demo authority."
        }
    }
}
foreach ($forbidden in @('demo_application', 'gpu_demo') + $scenarioModules) {
    if ([regex]::IsMatch($renderer, '@import\s*\(\s*"' + [regex]::Escape($forbidden) + '"\s*\)')) {
        Add-Failure "F4D renderer independence violation: renderer imports '$forbidden'."
    }
}
if ([regex]::IsMatch($engineCompositionTests, '@import\s*\(\s*"(demo_application|gpu_demo|[^"]*_demo)"\s*\)')) {
    Add-Failure 'F4D CPU proof imports demo/application scenario authority.'
}

# PSM01 stays dimension-neutral and headless, including its transitive core.
$motionCoreImports = @{
    'src/physics/secondary_motion.zig' = @('std', 'fixed_step', 'spring')
    'src/physics/secondary_motion_rate.zig' = @('std', 'secondary_motion', 'fixed_step')
    'src/physics/spring.zig' = @('std')
    'src/physics/fixed_step.zig' = @('std')
}
foreach ($relative in $motionCoreImports.Keys) {
    $source = Read-RepositoryFile $relative
    foreach ($match in [regex]::Matches($source, '@import\s*\(\s*"(?<module>[^"]+)"\s*\)')) {
        if ($match.Groups['module'].Value -notin $motionCoreImports[$relative]) {
            Add-Failure "PSM01 headless boundary violation: '$relative' imports '$($match.Groups['module'].Value)'."
        }
    }
}
$motionCore = (Read-RepositoryFile 'src/physics/secondary_motion.zig') + [Environment]::NewLine +
    (Read-RepositoryFile 'src/physics/secondary_motion_rate.zig')
if ([regex]::IsMatch($motionCore, 'std\.(heap|time|Io|Random|posix)\b|(?m)^var\s')) {
    Add-Failure 'PSM01 core must not acquire ambient allocation, time, IO, randomness or mutable global state.'
}
foreach ($match in [regex]::Matches($modulesBuild, '(?m)^\s*secondary_motion_module\.addImport\(\s*"(?<module>[^"]+)"')) {
    if ($match.Groups['module'].Value -notin @('fixed_step', 'spring')) {
        Add-Failure 'PSM01 build registration injects a dependency outside the scalar physics core.'
    }
}
foreach ($match in [regex]::Matches($modulesBuild, '(?m)^\s*secondary_motion_rate_module\.addImport\(\s*"(?<module>[^"]+)"')) {
    if ($match.Groups['module'].Value -notin @('secondary_motion', 'fixed_step')) {
        Add-Failure 'PSM01 rate resolution must depend only on scalar physics.'
    }
}
if (-not $engineBuild.Contains('"test-psm01"') -or
    -not $gatesBuild.Contains('test_step.dependOn(&options.engine.run_secondary_motion.step)')) {
    Add-Failure 'PSM01 focused proof must remain registered in the fast engine gate.'
}

if ($failed) {
    exit 1
}
Write-Host 'Current architecture policy passed: F2C and F4C1-F4E authority/dependency boundaries are intact.'
exit 0
