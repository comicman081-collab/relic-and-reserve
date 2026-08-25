# R1 → R2 Remediation

## R1 problems verified from source

R1 used a `Node2D`/`draw_rect()` main runtime, 8-vertex box OBJ files, text-card SVG props, hardcoded tool behavior in the UI, temporary bidder labels, and print-only generator stubs. R1 also reported counts without separating duplicate hashes, runtime references, or executed tests.

## R2 fixes

R2 replaces the main scene with a `Workshop3D` Node3D containing Camera3D, DirectionalLight3D, OmniLight3D, Environment, workbench geometry, runtime-loaded workshop props, and a real MeshInstance3D artifact loader. Twelve genuinely unique artifact mesh hashes are present across the 27 artifact OBJ files; the 8 hero targets have multi-component silhouettes, with Clock, Camera, and Radio receiving part meshes and detachable panel state.

The R2 runtime registry loads ArtifactSpecs, makers, tools, bidders, events, upgrades, localization, model paths, and materials. Restoration now carries selected tool state, correct-tool effectiveness, wrong-tool integrity risk, visual damage markers, disassembly part state, clue evidence, player-selected hypotheses, and data-driven bidders. AudioStreamPlayer playback and language toggling are wired into the runtime UI.

## Evidence

The R2 P0 test harness executed 40 independent assertions with 40 passed and 0 failed. The Xvfb screenshot harness generated and opened 11 rendered screens. The Windows Desktop export produced `RelicAndReserve.exe` and its `.pck` in `builds/windows/`.

## Remaining limitations

The artifact interchange format is OBJ rather than GLB because Blender was unavailable in the cloud. The Windows executable was generated on Linux but not run on real Windows in this environment. The R2 workshop is stylized low/mid-poly rather than photorealistic. These are recorded as limitations, not counted as PASS claims.
