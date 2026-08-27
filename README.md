# RELIC & RESERVE — R3

A data-driven artifact investigation, restoration, and auction game built with Godot 4.7.1.

## Play

Web: https://comicman081-collab.github.io/relic-and-reserve/

Start **New Game** to enter the tutorial and the next uncleared Stage. The guide can be skipped from the upper-right corner. Clearing a Stage unlocks the next one; cleared Stages remain available for replay.

## Local source

Open this folder in Godot 4.7.1 and run `scenes/Main.tscn`. Godot and Blender validation for this project is performed headlessly/background-only.

The core loop is:

`acquire → investigate → cite → report → appraise → restore → list → auction → settle`

## QA

Run the canonical PowerShell suites from the repository root:

```powershell
.\RUN_R3_IMPORT.ps1
.\RUN_R3_TESTS.ps1
.\RUN_R3_VIEWPORT_QA.ps1
```

Automated PASS is a technical source milestone, not a declaration that the game is complete.

## Controls

Use the mouse or keyboard focus to select panels and actions. Drag during artifact inspection to orbit the object. Escape returns to the workshop where supported. Audio, text size, portrait motion, display mode, and language are available under Settings.

## Repository layout

- `scenes/` and `scripts/`: canonical runtime scene and source
- `data/`: authored cases, artifacts, characters, events, and progression data
- `assets/`: repo-native visual and audio assets
- `tests/` and `qa/`: deterministic validation and visual evidence
- `tools/`: validators and release helpers
- `docs/`: verified GitHub Pages Web export

Existing Windows release artifacts are intentionally left untouched unless a new Windows packaging instruction is given. The Web URL above is the current deploy target for this source revision.
