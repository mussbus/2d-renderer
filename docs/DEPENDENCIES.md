# Dependencies

## Version policy

No dependency may use a floating branch, moving tag, package alias, or `latest` URL. The bootstrap process downloads named release assets and accepts them only after a SHA-256 match. The build does not silently use a system SDL or a different shader compiler.

## Pinned toolchain and archives

| Component | Exact identity | Windows x64 artifact | SHA-256 |
| --- | --- | --- | --- |
| Zig | 0.16.0 | Installed toolchain; `zig version` must print `0.16.0` | Distribution verification is external to this repository; the executable version is checked on every task and build entry point |
| SDL3 | release 3.4.10, embedded commit `8e37db5e797b6167f3a00d697d816a684bd259c7` | `SDL3-devel-3.4.10-VC.zip` | `e2b336b10b037934af98308027410732ef7b22f2c6697d58092aa1c209fae7d7` |
| DirectX Shader Compiler | stable release `v1.9.2602.24`, commit `d355aa8364d34df3f0822ba0de8d1dfc75ae6f48` | `dxc_2026_05_27.zip` | `cf658aacf070d3045e31b8f1f8a696c2945f37c1095019481ef7c513368db3b4` |

Official artifact URLs:

- `https://github.com/libsdl-org/SDL/releases/download/release-3.4.10/SDL3-devel-3.4.10-VC.zip`
- `https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.9.2602.24/dxc_2026_05_27.zip`

The SDL release page publishes the archive digest. The DXC release API publishes the archive digest and marks the release immutable. A release name is not trusted by itself; the local SHA-256 check is authoritative.

## Obtaining dependencies

The dependency-foundation milestone will add `tools/bootstrap_dependencies.ps1`. It will:

1. Refuse to continue unless `zig version` is exactly `0.16.0`.
2. Download each archive to `.deps/cache` under its exact filename.
3. Calculate SHA-256 and stop with the expected and actual values if they differ.
4. Extract to versioned directories under `.deps` using a temporary directory and atomic rename so a failed extraction is not accepted as complete.
5. Validate required files before reporting success.

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
```

`.deps` is local build input and will not be committed. The build fails with a diagnostic directing the developer to the bootstrap command if any validated path is missing; it does not search arbitrary environment locations.

## Header inspection record

Before this architecture was written, the official SDL VC archive was downloaded, hash-verified, and inspected. The archive contains SDL version macros `3`, `4`, and `10`, plus `.git-hash` value `8e37db5e797b6167f3a00d697d816a684bd259c7`.

The actual `include/SDL3/SDL_gpu.h` confirms the APIs and constants the renderer plan relies on:

- `SDL_CreateGPUDeviceWithProperties` and `SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING` for explicit backend selection.
- `SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN` and `SDL_GPU_SHADERFORMAT_DXIL` for DXIL capability declaration.
- `SDL_GetGPUDeviceDriver` and `SDL_GetGPUShaderFormats` for post-creation verification.
- `SDL_ClaimWindowForGPUDevice` and `SDL_WaitAndAcquireGPUSwapchainTexture` for presentation.
- `SDL_DrawGPUIndexedPrimitives` with an explicit `num_instances` parameter for instanced indexed drawing.
- Matching release functions for GPU buffers, transfer buffers, textures, samplers, shaders, graphics pipelines, fences, and claimed windows, plus `SDL_DestroyGPUDevice`.

The input headers confirm `SDL_GetKeyboardState`, gamepad add/remove events, `SDL_OpenGamepad`, `SDL_GetGamepadAxis`, `SDL_GetGamepadButton`, and `SDL_CloseGamepad`. Implementations must inspect these vendored headers again at the point of use.

The hash-verified DXC archive was also inspected and executed during this milestone. Its x64 compiler reported `1.9.2602.24` at commit `d355aa836`, and the inspected SDL x64 DLL reported file/product version `3.4.10.0`.

## Linking and runtime files

The initial supported target is Windows 11 x86_64. Zig links the exact VC archive import library at `.deps/SDL3-3.4.10/lib/x64/SDL3.lib` and includes `.deps/SDL3-3.4.10/include`. `SDL3.dll` is copied beside the installed executable for `zig build run` and packaged builds.

DXC is an offline build tool only. Shader compilation invokes the pinned x64 `dxc.exe` with `dxcompiler.dll` and `dxil.dll` beside it; `dxv.exe` validates emitted DXIL. These DXC files are not application runtime dependencies. Windows supplies the D3D12 system runtime and a compatible display driver.

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
