# Dependencies

## Version policy

No dependency may use a floating branch, moving tag, package alias, or `latest` URL. The bootstrap process downloads named release assets and accepts them only after a SHA-256 match. The build does not silently use a system SDL or a different shader compiler.

## Pinned toolchain and archives

| Component | Exact identity | Windows x64 artifact | SHA-256 |
| --- | --- | --- | --- |
| Zig | 0.16.0 | Installed toolchain; `zig version` must print `0.16.0` | Distribution verification is external to this repository; the executable version is checked on every task and build entry point |
| SDL3 | release 3.4.10, embedded commit `8e37db5e797b6167f3a00d697d816a684bd259c7` | `SDL3-devel-3.4.10-VC.zip` | `e2b336b10b037934af98308027410732ef7b22f2c6697d58092aa1c209fae7d7` |
| DirectX Shader Compiler | stable release `v1.9.2602.24`, commit `d355aa8364d34df3f0822ba0de8d1dfc75ae6f48` | `dxc_2026_05_27.zip` | `cf658aacf070d3045e31b8f1f8a696c2945f37c1095019481ef7c513368db3b4` |
| Blender | 4.5.9 LTS | `blender-4.5.9-windows-x64.zip` portable archive | `41da973b9bf95bb312cbeff4d1982feb13259b43c821686b9bafea4dfe5477cf` |

The machine-readable authority used by the bootstrap is `tools/dependencies.lock.json`, which embeds these exact URLs and hashes. Official artifact URLs:

- `https://github.com/libsdl-org/SDL/releases/download/release-3.4.10/SDL3-devel-3.4.10-VC.zip`
- `https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.9.2602.24/dxc_2026_05_27.zip`
- `https://mirror.blender.org/release/Blender4.5/blender-4.5.9-windows-x64.zip`

The SDL release page publishes the archive digest. The DXC release API publishes the archive digest and marks the release immutable. A release name is not trusted by itself; the local SHA-256 check is authoritative.

## Obtaining dependencies

From the repository root (including a path containing spaces), run:

```powershell
& '.\tools\bootstrap_dependencies.ps1'
```

`tools/bootstrap_dependencies.ps1`:

1. Refuse to continue unless `zig version` is exactly `0.16.0`.
2. Downloads each archive to a unique temporary `.download` filename.
3. Calculates SHA-256 and rejects the archive with expected and actual values if they differ; only a verified download is moved to the authoritative cache filename.
4. Extracts to a unique staging directory, validates required files and identities, records every extracted file's length and SHA-256 in `.dependency-manifest.json`, and only then moves the payload to its versioned directory.
5. Re-hashes the complete extracted manifest on every later invocation. A missing, extra, modified, partial, or corrupt payload is never accepted as installed and is replaced transactionally from a verified archive.
6. Preserves an old invalid directory until the newly staged payload passes post-move verification, then removes it. Repeated extraction is idempotent.

Run `& '.\tools\bootstrap_dependencies.ps1' -SelfTest` to exercise corrupt-archive, partial-directory, and corrupt-directory rejection. After the initial download, `& '.\tools\bootstrap_dependencies.ps1' -Offline` verifies or reinstalls exclusively from `.deps/cache`. Normal `zig build`, `zig build test`, and `zig build run` never invoke the network.

Expected validated paths are:

```text
.deps/SDL3-3.4.10/include/SDL3/SDL.h
.deps/SDL3-3.4.10/include/SDL3/SDL_gpu.h
.deps/SDL3-3.4.10/lib/x64/SDL3.lib
.deps/SDL3-3.4.10/lib/x64/SDL3.dll
.deps/dxc-1.9.2602.24/bin/x64/dxc.exe
.deps/dxc-1.9.2602.24/bin/x64/dxcompiler.dll
.deps/dxc-1.9.2602.24/bin/x64/dxil.dll
.deps/dxc-1.9.2602.24/bin/x64/dxv.exe
.deps/blender-4.5.9-windows-x64/blender.exe
.deps/blender-4.5.9-windows-x64/copyright.txt
```

`.deps` is ignored local build input and is not committed. The build fails with a diagnostic directing the developer to the bootstrap command if any pinned path is missing; it does not search arbitrary environment locations.

Blender is a portable, repository-local, offline authoring dependency only.
The bootstrap verifies the archive before extraction and installs it under
`.deps/blender-4.5.9-windows-x64/`; the empty local `portable/` directory keeps
preferences beside that installation rather than in machine-global Blender
configuration. The runtime, renderer, canonical parser, normal geometry
validation, and production packages do not link, launch, or ship Blender.
Only the explicitly specialized Blender bridge commands depend on it.

### External qualification asset: MakeHuman/MPFB `hm08`

Prompt 2C-T2 qualified and Prompt 2C-T3 adopted the visible-body topology of
the official `hm08` basemesh bundled with MPFB2. The reproducible provenance
input is pinned to MPFB2
commit `437dd513888a92399d1d3200d2e80859fae55abc` at
`src/mpfb/data/3dobjs/base.obj`. The OBJ is 1,808,470 bytes with SHA-256
`bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950`.
Its header identifies `hm08` and its CC0 release; the pinned
`LICENSE.ASSETS.md` is 7,003 bytes with SHA-256
`5f3ab0cf6f7ebe92efe4b83213131c617d308d164eeefd5da230373640b0c226`.

The sparse upstream checkout lives only under the ignored
`.deps/external/mpfb2-437dd513888a92399d1d3200d2e80859fae55abc/` inspection
location. It is not a runtime dependency, is no longer geometry authority after
promotion, and is not fetched by ordinary bootstrap, build, test, or runtime
routes. Machine-readable qualification and adoption provenance is committed
under `evidence/prompt_2c_t2_hm08/` and
`evidence/prompt_2c_t3_hm08_adoption/`; the canonical JSON owns the adopted
topology.

## Header inspection record

Before this architecture was written, the official SDL VC archive was downloaded, hash-verified, and inspected. The archive contains SDL version macros `3`, `4`, and `10`, plus `.git-hash` value `8e37db5e797b6167f3a00d697d816a684bd259c7`.

The actual `include/SDL3/SDL_gpu.h` confirms the APIs and constants the renderer plan relies on:

- `SDL_CreateGPUDeviceWithProperties` and `SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING` for explicit backend selection.
- `SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN` and `SDL_GPU_SHADERFORMAT_DXIL` for DXIL capability declaration.
- `SDL_GetGPUDeviceDriver` and `SDL_GetGPUShaderFormats` for post-creation verification.
- `SDL_ClaimWindowForGPUDevice` and `SDL_WaitAndAcquireGPUSwapchainTexture` for presentation.
- `SDL_WINDOW_RESIZABLE`, `SDL_GetWindowSizeInPixels`, and window resized/pixel-size/minimized/restored events for resizable high-DPI drawable tracking.
- `SDL_GetGPUSwapchainTextureFormat` for the persistent swapchain-compatible graphics pipeline; fixed readback retains `R8G8B8A8_UNORM`.
- `SDL_DrawGPUIndexedPrimitives` with an explicit `num_instances` parameter for instanced indexed drawing.
- Matching release functions for GPU buffers, transfer buffers, textures, samplers, shaders, graphics pipelines, fences, and claimed windows, plus `SDL_DestroyGPUDevice`.

The input headers confirm `SDL_GetKeyboardState`, gamepad add/remove events, `SDL_OpenGamepad`, `SDL_GetGamepadAxis`, `SDL_GetGamepadButton`, and `SDL_CloseGamepad`. Implementations must inspect these vendored headers again at the point of use.

The hash-verified DXC archive was also inspected and executed during this milestone. Its x64 compiler reported `1.9.2602.24` at commit `d355aa836`, and the inspected SDL x64 DLL reported file/product version `3.4.10.0`.

One pinned compiler/header conflict was demonstrated during the required release builds: Zig 0.16.0 translates MinGW's fortified `wcscat` and `wcscpy` inline wrappers, pulled in transitively by `SDL.h`, into unused local declarations that ReleaseSafe and ReleaseFast reject. `src/platform/sdl.zig` therefore defines `_FORTIFY_SOURCE=0` only inside `@cImport`. The project compiles no C source through that import, and Zig safety settings plus the linked pinned SDL runtime are unchanged; this is a header-translation workaround, not an architecture or backend change.

## Linking and runtime files

The initial supported target is Windows 11 x86_64. Zig links the exact VC archive import library at `.deps/SDL3-3.4.10/lib/x64/SDL3.lib` and includes `.deps/SDL3-3.4.10/include`. The install step copies the pinned `.deps/SDL3-3.4.10/lib/x64/SDL3.dll` beside `zig-out/bin/skeletal_gpu_demo.exe`; `zig build run` depends on that installed layout instead of a global DLL.

DXC is an offline build tool only. Shader compilation invokes the pinned x64 `dxc.exe` with structured PowerShell process arguments, with `dxcompiler.dll` and `dxil.dll` beside it; `dxv.exe` validates emitted DXIL. Build dependencies include the HLSL source, compiler/validator binaries and companion DLLs, lock file, compile script, stage, entry point, target profile, flags, and Zig optimization configuration. A changed input regenerates the DXIL. Compilation and validation use temporary output and delete any authoritative output on failure, so stale shaders are not silently accepted. These DXC files are not application runtime dependencies. Windows supplies the D3D12 system runtime and a compatible display driver.

## Shader format and backend policy

The expected and required Windows GPU backend is SDL's `direct3d12` driver. The application advertises only DXIL and explicitly requests `direct3d12`. It does not allow SDL to select Vulkan, does not advertise SPIR-V, and does not fall back if D3D12 creation fails.

SDL 3.4.10's D3D12 backend can consume DXBC SM 5.1 or DXIL SM 6.0, but this project supports one application artifact format on Windows: DXIL Shader Model 6.0 generated from HLSL. Each HLSL entry point is compiled offline as `vs_6_0` or `ps_6_0`; the compiled bytes are build outputs, not hand-maintained source files.

## Diagnosing backend or shader-format mismatch

Startup and `zig build gpu-smoke` must report enough information to distinguish capability, packaging, and shader errors:

1. Enumerate names from `SDL_GetNumGPUDrivers` and `SDL_GetGPUDriver` in debug output.
2. Call `SDL_GPUSupportsShaderFormats(SDL_GPU_SHADERFORMAT_DXIL, "direct3d12")` before device creation. A false result is a hard `UnsupportedGpuBackend` failure.
3. Create the device with the name property `direct3d12` and only the DXIL shader property enabled.
4. Verify `SDL_GetGPUDeviceDriver` returns `direct3d12` and `SDL_GetGPUShaderFormats` includes `SDL_GPU_SHADERFORMAT_DXIL`. A mismatch is fatal rather than a fallback trigger.
5. On any SDL failure, log the operation and `SDL_GetError()` text. Enable SDL GPU debug and verbose device properties in debug builds.
6. Verify the runtime `SDL3.dll` file version/path and rerun the bootstrap hash check if a symbol or behavior differs from the inspected headers.
7. Run pinned `dxc.exe --version`, rebuild both shader stages, and run pinned `dxv.exe` on each output. A missing entry point, wrong target profile, or validation failure stops the build.
8. If device creation still fails, check Windows graphics-driver support for Direct3D 12 Feature Level 11_0 and Resource Binding Tier 2. The design does not silently switch APIs.
## Prompt 23 image platform capability

PNG decoding uses Windows Imaging Component from Windows 11. It adds no downloaded or redistributed dependency, so there is no new archive, package hash, runtime DLL, or third-party license to pin. `ole32.dll` and WIC codecs are licensed and serviced as Windows components. The implementation dynamically loads the installed `ole32.dll` and fails with `ImageDecoderUnavailable` if the required COM entry points or WIC factory are unavailable.

The COM method order, GUID values, decode options, and RGBA conversion contract were checked against the `objbase.h` and `wincodec.h` headers shipped with the pinned Zig 0.16.0 toolchain. Required input is a one-frame PNG convertible by WIC to 32-bit RGBA. No SDL_image, stb_image, game framework, or custom PNG decoder is used.

The two project atlases are ordinary committed content, not dependencies. `zig build` validates their presence and installs them under `zig-out/bin/art`. Runtime lookup begins at `SDL_GetBasePath()` and does not depend on the repository working directory.
