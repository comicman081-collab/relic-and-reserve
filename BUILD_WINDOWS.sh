#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT/builds/windows"
"$ROOT/.tools/godot4.7.1" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/builds/windows/RelicAndReserve.exe"
