# RELIC & RESERVE R3 Source Checkpoint

This Godot 4.7.1 project is the corrected R3 source workspace derived from the preserved Manus R2 baseline. It contains the data-bound 3D conservation/auction core and the connected campaign through Grand Reserve, five endings, epilogue, and postgame.

## Run and test

- Open project.godot with Godot **4.7.1 stable Standard**, Compatibility renderer.
- Native Windows import: ./RUN_R3_IMPORT.ps1
- Native source tests: ./RUN_R3_TESTS.ps1
- Main scene: es://scenes/Main.tscn

The test workflow imports assets, then runs core (34), campaign (23), ending (5), and 1,000-run economy coverage. Reports live in qa/; design/catalog documents live in docs/.

## Release hold

Passing tests does **not** declare the game complete. Do not create or modify R3/R2 EXE, PCK, ZIP, 7z, or RAR artifacts unless the user later gives an explicit instruction. Build/package scripts enforce this with a required -UserAuthorized switch. No Windows build or archive was produced at this checkpoint.

See R3_BUILD_REPORT.md, R3_KNOWN_ISSUES.md, R3_VISUAL_QA.md, R3_RUNTIME_INTEGRATION_AUDIT.json, and R3_ASSET_AUDIT.json.
