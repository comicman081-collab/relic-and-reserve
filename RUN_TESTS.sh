#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="$ROOT/.tools/godot4.7.1"
"$GODOT" --headless --path "$ROOT" --editor --quit
python3 "$ROOT/tools/validators/validate_data.py"
python3 "$ROOT/tools/simulation/run_simulations.py" > "$ROOT/qa/ECONOMY_SIMULATION.json"
echo TESTS_PASS
