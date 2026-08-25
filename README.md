# RELIC & RESERVE

A playable Godot 4.7.1 prototype of an artifact restoration and auction simulator.

## Run
Open this folder in Godot 4.7.1 and press Play. New Game → Market → Buy → Inventory → Inspection → Clean/Repair → Authenticate → Auction → Hammer.

## Tests
Run `RUN_TESTS.sh`. Windows users can use `RUN_TESTS.bat`.

## Controls
Click panels and buttons. Drag during inspection to orbit the artifact. Escape returns to the workshop.

## Build
`BUILD_WINDOWS.sh` attempts a Windows Desktop export when templates are available.

## Play / Download
Web: https://comicman081-collab.github.io/relic-and-reserve/

Windows: see the latest GitHub Release for the user-only R3 MVP build. Start a
New Game to enter the next uncleared Stage; cleared Stages can be replayed from
the progress screen.

## Layout
`scenes/` contains the canonical scene; `scripts/` contains state and UI; `data/` is data-driven content; `assets/` contains procedural originals; `tools/` contains generators, validators, and simulations; `qa/` contains reports.

## Known issues
This R1 uses a stylized 2.5D workshop renderer rather than a fully modeled 3D environment. Blender was not available in the cloud, so OBJ/SVG procedural fallbacks are canonical. Windows runtime is not verified inside Linux.

Cloud note: export templates are not bundled; install Godot 4.7.1 export templates for platform builds.
