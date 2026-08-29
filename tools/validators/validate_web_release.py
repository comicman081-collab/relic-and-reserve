#!/usr/bin/env python3
"""Validate and stage the committed Godot Web export for GitHub Pages.

The validator intentionally treats ``docs`` as an export/output directory, not
as the Pages artifact.  Only verified Godot runtime companions are copied to
the staging directory.  A deterministic manifest binds their hashes to a hash
of the production source tree so CI fails when source and the committed Web
export drift apart.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import unquote, urlsplit


SCHEMA_VERSION = 1
REQUIRED_RUNTIME_FILES = {
    "index.html",
    "index.js",
    "index.pck",
    "index.wasm",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
    ".nojekyll",
}
RUNTIME_SUFFIXES = (
    ".html",
    ".js",
    ".wasm",
    ".pck",
    ".png",
    ".ico",
    ".svg",
    ".webmanifest",
    ".json",
)
SOURCE_DIRECTORIES = (
    "assets",
    "audio",
    "data",
    "localization",
    "resources",
    "scenes",
    "scripts",
    "shaders",
)
SOURCE_TOP_LEVEL = (
    "project.godot",
    "default_bus_layout.tres",
    "export_presets.cfg",
)
REQUIRED_WEB_EXCLUDES = {
    ".godot/*",
    "qa/*",
    "tests/*",
    "tools/*",
    "source_assets/*",
    "BGM/*",
    "docs/*",
    "dist/*",
    "builds/*",
}
FORBIDDEN_PCK_PATHS = tuple(
    f"res://{relative}".encode("utf-8")
    for relative in (
        ".github/",
        ".tools/",
        ".codex_test",
        ".codex-test-",
        "BGM/",
        "builds/",
        "dist/",
        "docs/",
        "qa/",
        "source_assets/",
        "tests/",
        "tools/",
    )
)
IGNORED_SOURCE_SUFFIXES = (".import", ".tmp", ".bak", ".pyc")
TEXT_SUFFIXES = {
    ".bat",
    ".cfg",
    ".csv",
    ".gd",
    ".gdshader",
    ".godot",
    ".html",
    ".ini",
    ".json",
    ".md",
    ".mtl",
    ".obj",
    ".po",
    ".ps1",
    ".py",
    ".shader",
    ".sh",
    ".svg",
    ".toml",
    ".tres",
    ".tscn",
    ".tsv",
    ".txt",
    ".uid",
    ".xml",
    ".yaml",
    ".yml",
}


class ValidationError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_source_sha256(path: Path) -> str:
    """Hash text with Git-stable newlines and binary files byte-for-byte."""
    if path.suffix.lower() not in TEXT_SUFFIXES:
        return sha256_file(path)
    content = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(content).hexdigest()


def relative_posix(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def source_files(project_root: Path) -> list[Path]:
    files: set[Path] = set()
    for relative in SOURCE_TOP_LEVEL:
        candidate = project_root / relative
        if candidate.is_file():
            files.add(candidate)
    for relative in SOURCE_DIRECTORIES:
        directory = project_root / relative
        if not directory.is_dir():
            continue
        for candidate in directory.rglob("*"):
            if not candidate.is_file() or candidate.is_symlink():
                continue
            if candidate.name == "Thumbs.db" or candidate.name == ".DS_Store":
                continue
            if candidate.name == "__pycache__" or "__pycache__" in candidate.parts:
                continue
            if candidate.name.endswith(IGNORED_SOURCE_SUFFIXES):
                continue
            files.add(candidate)
    if not files:
        raise ValidationError("No production source files were found.")
    return sorted(files, key=lambda item: relative_posix(item, project_root))


def source_fingerprint(project_root: Path) -> dict[str, Any]:
    files = source_files(project_root)
    tree = hashlib.sha256()
    latest = max(files, key=lambda item: item.stat().st_mtime_ns)
    for path in files:
        relative = relative_posix(path, project_root)
        file_hash = canonical_source_sha256(path)
        tree.update(relative.encode("utf-8"))
        tree.update(b"\0")
        tree.update(file_hash.encode("ascii"))
        tree.update(b"\n")
    return {
        "tree_sha256": tree.hexdigest(),
        "file_count": len(files),
        "latest_mtime_ns": latest.stat().st_mtime_ns,
        "latest_path": relative_posix(latest, project_root),
    }


def quoted_value(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        try:
            return str(json.loads(value))
        except json.JSONDecodeError as exc:
            raise ValidationError(f"Invalid quoted preset value: {value}") from exc
    return value


def parse_export_presets(path: Path) -> dict[str, dict[str, str]]:
    if not path.is_file():
        raise ValidationError(f"Missing export preset file: {path}")
    sections: dict[str, dict[str, str]] = {}
    current = ""
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue
        if current and "=" in line:
            key, value = line.split("=", 1)
            sections[current][key.strip()] = quoted_value(value)
    return sections


def validate_web_preset(project_root: Path) -> dict[str, Any]:
    sections = parse_export_presets(project_root / "export_presets.cfg")
    preset_section = ""
    for section, values in sections.items():
        if re.fullmatch(r"preset\.\d+", section) and values.get("name") == "Web":
            preset_section = section
            break
    if not preset_section:
        raise ValidationError("A Web export preset was not found.")
    options_section = f"{preset_section}.options"
    options = sections.get(options_section, {})
    preset = sections[preset_section]
    if preset.get("platform") != "Web":
        raise ValidationError("The Web preset does not target the Web platform.")
    if options.get("threads/enabled", "").lower() != "false":
        raise ValidationError(
            "Web threads must remain disabled for GitHub Pages without COOP/COEP headers."
        )
    if options.get("progressive_web_app/enabled", "false").lower() != "false":
        raise ValidationError("The Pages preset must not require a generated service worker.")
    excludes = {
        item.strip()
        for item in preset.get("exclude_filter", "").split(",")
        if item.strip()
    }
    missing_excludes = sorted(REQUIRED_WEB_EXCLUDES - excludes)
    if missing_excludes:
        raise ValidationError(
            "Web preset is missing source-only exclude filters: "
            + ", ".join(missing_excludes)
        )
    return {
        "section": preset_section,
        "threads_enabled": False,
        "exclude_filters": sorted(excludes),
    }


def local_url_path(raw_url: str) -> str | None:
    decoded = html.unescape(raw_url.strip())
    if not decoded or decoded.startswith(("#", "data:", "blob:", "javascript:")):
        return None
    parsed = urlsplit(decoded)
    if parsed.scheme or parsed.netloc:
        return None
    path = unquote(parsed.path).replace("\\", "/")
    if path.startswith("/"):
        raise ValidationError(
            f"Root-absolute Web reference breaks repository subpaths: {raw_url}"
        )
    while path.startswith("./"):
        path = path[2:]
    if not path:
        return None
    if ".." in Path(path).parts:
        raise ValidationError(f"Web reference escapes the export directory: {raw_url}")
    return path


def parse_html_config(index_html: Path) -> tuple[dict[str, Any], set[str]]:
    text = index_html.read_text(encoding="utf-8")
    if not re.search(r"const\s+GODOT_THREADS_ENABLED\s*=\s*false\s*;", text):
        raise ValidationError("Exported index.html does not declare threads disabled.")
    match = re.search(r"const\s+GODOT_CONFIG\s*=\s*(\{.*?\})\s*;", text, re.DOTALL)
    if not match:
        raise ValidationError("Exported index.html has no readable GODOT_CONFIG.")
    try:
        config = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        raise ValidationError("GODOT_CONFIG is not valid JSON.") from exc

    references: set[str] = set()
    for value in re.findall(r"(?:src|href)\s*=\s*[\"']([^\"']+)[\"']", text, re.I):
        local = local_url_path(value)
        if local:
            references.add(local)
    for value in re.findall(r"url\(\s*[\"']?([^\"')]+)", text, re.I):
        local = local_url_path(value)
        if local:
            references.add(local)
    executable = config.get("executable")
    if not isinstance(executable, str) or not executable or executable.startswith("/"):
        raise ValidationError("GODOT_CONFIG executable must be a relative basename.")
    file_sizes = config.get("fileSizes")
    if not isinstance(file_sizes, dict) or not file_sizes:
        raise ValidationError("GODOT_CONFIG has no fileSizes map.")
    references.update(str(key) for key in file_sizes)
    return config, references


def is_runtime_companion(path: Path) -> bool:
    name = path.name
    if name == ".nojekyll":
        return True
    if name.endswith(".import") or not (name == "index.html" or name.startswith("index.")):
        return False
    return name.lower().endswith(RUNTIME_SUFFIXES)


def runtime_files(export_dir: Path) -> list[Path]:
    if not export_dir.is_dir():
        raise ValidationError(f"Web export directory does not exist: {export_dir}")
    files = sorted(
        (path for path in export_dir.iterdir() if path.is_file() and is_runtime_companion(path)),
        key=lambda item: item.name,
    )
    names = {path.name for path in files}
    missing = sorted(REQUIRED_RUNTIME_FILES - names)
    if missing:
        raise ValidationError("Missing Godot Web runtime files: " + ", ".join(missing))
    for path in files:
        if path.name != ".nojekyll" and path.stat().st_size <= 0:
            raise ValidationError(f"Runtime file is empty: {path.name}")
    return files


def validate_runtime(export_dir: Path) -> list[dict[str, Any]]:
    files = runtime_files(export_dir)
    names = {path.name for path in files}
    config, references = parse_html_config(export_dir / "index.html")
    for reference in sorted(references):
        if reference not in names:
            raise ValidationError(
                f"index.html references a file outside the staged runtime: {reference}"
            )
    for name, expected_size in config["fileSizes"].items():
        path = export_dir / str(name)
        if not path.is_file():
            raise ValidationError(f"GODOT_CONFIG file is missing: {name}")
        if not isinstance(expected_size, int) or expected_size != path.stat().st_size:
            raise ValidationError(
                f"GODOT_CONFIG size mismatch for {name}: "
                f"expected {expected_size}, actual {path.stat().st_size}"
            )
    pack_bytes = (export_dir / "index.pck").read_bytes()
    leaked_paths = [
        needle.decode("utf-8") for needle in FORBIDDEN_PCK_PATHS if needle in pack_bytes
    ]
    if leaked_paths:
        raise ValidationError(
            "Web PCK contains source-only paths: " + ", ".join(leaked_paths)
        )
    return [
        {
            "path": path.name,
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        for path in files
    ]


def manifest_payload(
    project_root: Path,
    preset: dict[str, Any],
    source: dict[str, Any],
    runtime: list[dict[str, Any]],
) -> dict[str, Any]:
    workflow = project_root / ".github" / "workflows" / "pages.yml"
    validator = project_root / "tools" / "validators" / "validate_web_release.py"
    deployment_files = [project_root / "export_presets.cfg", validator]
    if workflow.is_file():
        deployment_files.append(workflow)
    return {
        "schema": SCHEMA_VERSION,
        "product": "RELIC & RESERVE R3 MVP",
        "target": "GitHub Pages",
        "base_path": "./",
        "web": {
            "preset": "Web",
            "threads_enabled": preset["threads_enabled"],
            "subpath_compatible": True,
        },
        "source": {
            "tree_sha256": source["tree_sha256"],
            "file_count": source["file_count"],
        },
        "deployment": {
            relative_posix(path, project_root): canonical_source_sha256(path)
            for path in deployment_files
        },
        "runtime": runtime,
    }


def write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def validate_manifest(path: Path, expected: dict[str, Any]) -> None:
    if not path.is_file():
        raise ValidationError(f"Required Web build manifest is missing: {path}")
    try:
        actual = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Cannot read Web build manifest: {path}") from exc
    if actual != expected:
        actual_source = actual.get("source", {}) if isinstance(actual, dict) else {}
        raise ValidationError(
            "Web build manifest does not match current source/runtime. "
            f"manifest source={actual_source.get('tree_sha256', 'missing')}, "
            f"current source={expected['source']['tree_sha256']}. "
            "Re-export Web and regenerate the manifest."
        )


def ensure_export_is_fresh(source: dict[str, Any], export_dir: Path) -> None:
    # The PCK is the source-bearing output.  Godot may reuse an unchanged engine
    # WASM/template file, so its timestamp is not evidence that gameplay source
    # was omitted from a fresh export.
    export_time = (export_dir / "index.pck").stat().st_mtime_ns
    tolerance_ns = 2_000_000_000
    if export_time + tolerance_ns < int(source["latest_mtime_ns"]):
        raise ValidationError(
            "Web export predates production source "
            f"({source['latest_path']}). Re-export before writing the manifest."
        )


def safe_stage(
    project_root: Path,
    stage_dir: Path,
    export_dir: Path,
    runtime: Iterable[dict[str, Any]],
    manifest_path: Path,
) -> None:
    resolved_root = project_root.resolve()
    resolved_stage = stage_dir.resolve()
    if resolved_stage == resolved_root or resolved_stage in resolved_root.parents:
        raise ValidationError(f"Unsafe Pages staging directory: {stage_dir}")
    if resolved_stage.exists() and any(resolved_stage.iterdir()):
        raise ValidationError(f"Pages staging directory is not empty: {stage_dir}")
    resolved_stage.mkdir(parents=True, exist_ok=True)
    for entry in runtime:
        name = str(entry["path"])
        shutil.copy2(export_dir / name, resolved_stage / name)
    shutil.copy2(manifest_path, resolved_stage / manifest_path.name)

    staged_names = {path.name for path in resolved_stage.iterdir() if path.is_file()}
    expected_names = {str(entry["path"]) for entry in runtime} | {manifest_path.name}
    if staged_names != expected_names:
        raise ValidationError(
            "Staged Pages artifact contains an unexpected file set: "
            + ", ".join(sorted(staged_names ^ expected_names))
        )
    for entry in runtime:
        staged = resolved_stage / str(entry["path"])
        if staged.stat().st_size != int(entry["bytes"]):
            raise ValidationError(f"Staged size mismatch: {staged.name}")
        if sha256_file(staged) != str(entry["sha256"]):
            raise ValidationError(f"Staged hash mismatch: {staged.name}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    script_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=script_root)
    parser.add_argument("--export-dir", type=Path, default=Path("docs"))
    parser.add_argument("--manifest", type=Path, default=Path("docs/build-manifest.json"))
    parser.add_argument("--write-manifest", action="store_true")
    parser.add_argument("--require-manifest", action="store_true")
    parser.add_argument("--stage-dir", type=Path)
    return parser.parse_args(argv)


def display_path(path: Path, project_root: Path) -> str:
    try:
        return relative_posix(path, project_root)
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.write_manifest and args.require_manifest:
        raise ValidationError("Choose either --write-manifest or --require-manifest.")
    project_root = args.project_root.resolve()
    export_dir = args.export_dir
    if not export_dir.is_absolute():
        export_dir = project_root / export_dir
    manifest_path = args.manifest
    if not manifest_path.is_absolute():
        manifest_path = project_root / manifest_path

    preset = validate_web_preset(project_root)
    source = source_fingerprint(project_root)
    runtime = validate_runtime(export_dir)
    payload = manifest_payload(project_root, preset, source, runtime)

    if args.write_manifest:
        ensure_export_is_fresh(source, export_dir)
        write_json_atomic(manifest_path, payload)
    elif args.require_manifest or manifest_path.exists():
        validate_manifest(manifest_path, payload)

    if args.stage_dir:
        if not manifest_path.is_file():
            raise ValidationError("Staging requires a verified or newly written manifest.")
        if not args.write_manifest:
            validate_manifest(manifest_path, payload)
        stage_dir = args.stage_dir
        if not stage_dir.is_absolute():
            stage_dir = project_root / stage_dir
        safe_stage(project_root, stage_dir, export_dir, runtime, manifest_path)

    print(
        json.dumps(
            {
                "status": "PASS",
                "threads_enabled": False,
                "subpath_compatible": True,
                "source_tree_sha256": source["tree_sha256"],
                "source_files": source["file_count"],
                "runtime_files": len(runtime),
                "runtime_bytes": sum(int(entry["bytes"]) for entry in runtime),
                "manifest": display_path(manifest_path, project_root),
                "staged": str(args.stage_dir) if args.stage_dir else None,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except ValidationError as exc:
        print(f"WEB RELEASE VALIDATION: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
