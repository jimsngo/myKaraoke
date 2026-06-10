#!/usr/bin/env python3
"""Validate project asset paths, naming consistency, and dashboard script links."""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set


RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
RED = "\033[1;31m"
CYAN = "\033[1;36m"


def c(text: str, color: str) -> str:
    return f"{color}{text}{RESET}"


def resolve_case_insensitive(root: Path, rel_path: str) -> Optional[Path]:
    candidate = Path(rel_path)
    if candidate.is_absolute():
        current = Path(candidate.anchor)
        parts = candidate.parts[1:]
    else:
        current = root
        parts = candidate.parts

    for part in parts:
        if part in ("", "."):
            continue
        if part == "..":
            return None
        if not current.exists() or not current.is_dir():
            return None
        matches = [child for child in current.iterdir() if child.name.lower() == part.lower()]
        if not matches:
            return None
        current = matches[0]
    return current


def status_line(level: str, label: str, rel_path: str, note: str = "") -> None:
    if level == "ok":
        prefix = c("OK", GREEN)
    elif level == "warn":
        prefix = c("WARN", YELLOW)
    else:
        prefix = c("ERR", RED)

    suffix = f" - {note}" if note else ""
    print(f"  [{prefix}] {label}: {rel_path}{suffix}")


def validate_path(
    root: Path,
    label: str,
    rel_path: str,
    counts: Dict[str, int],
    required: bool = True,
    missing_note: str = "Missing or broken path.",
) -> Optional[str]:
    if not rel_path:
        status_line("warn", label, "<empty>", "Path is empty in assets.json.")
        counts["warnings"] += 1
        return None

    rel_candidate = Path(rel_path)
    abs_path = rel_candidate if rel_candidate.is_absolute() else (root / rel_candidate)
    if abs_path.exists():
        status_line("ok", label, rel_path)
        counts["ok"] += 1
        return str(abs_path)

    resolved = resolve_case_insensitive(root, rel_path)
    if resolved is not None and resolved.exists():
        try:
            found_rel = str(resolved.relative_to(root))
        except Exception:
            found_rel = str(resolved)
        status_line(
            "warn",
            label,
            rel_path,
            f"Case mismatch. Found: {found_rel}",
        )
        counts["warnings"] += 1
        return str(resolved)

    if required:
        status_line("err", label, rel_path, missing_note)
        counts["errors"] += 1
    else:
        status_line("warn", label, rel_path, missing_note)
        counts["warnings"] += 1
    return None


def collect_path_variants(rel_paths: List[str]) -> Dict[str, Set[str]]:
    variants: Dict[str, Set[str]] = {}
    for rel_path in rel_paths:
        if not rel_path:
            continue
        parent = str(Path(rel_path).parent)
        if parent in (".", ""):
            continue
        key = parent.lower()
        variants.setdefault(key, set()).add(parent)
    return variants


def main() -> int:
    project_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/Users/jim/myKaraoke")
    presets = project_root / "assets.json"

    if not presets.exists():
        print(c("❌ assets.json not found.", RED))
        return 1

    with presets.open("r", encoding="utf-8") as f:
        config = json.load(f)

    print(c("🔎 Project Asset Validation", CYAN))
    print(c("=" * 58, CYAN))

    counts = {"ok": 0, "warnings": 0, "errors": 0}
    checked_paths: List[str] = []

    input_checks = [
        ("Mixed Audio", config.get("inputs", {}).get("mixed_audio", "")),
        ("Instruments Stem", config.get("inputs", {}).get("instruments_only", "")),
        ("Vocals Stem", config.get("inputs", {}).get("vocals_only", "")),
        ("Source MIDI", config.get("inputs", {}).get("source_midi", "")),
        ("SynthV Preview SRT", config.get("inputs", {}).get("subtitles_srt_synthv", "")),
        ("Production ASS", config.get("inputs", {}).get("subtitles_ass", "")),
        ("Background Video", config.get("inputs", {}).get("background", "")),
    ]

    output_checks = [
        ("Karaoke Video", config.get("outputs", {}).get("karaoke_video", "")),
        ("Lyrics Video", config.get("outputs", {}).get("lyrics_video", "")),
    ]

    print(c("\nInputs", BOLD))
    for label, rel_path in input_checks:
        checked = validate_path(project_root, label, rel_path, counts)
        if checked:
            checked_paths.append(rel_path)

    print(c("\nOutputs", BOLD))
    for label, rel_path in output_checks:
        checked = validate_path(
            project_root,
            label,
            rel_path,
            counts,
            required=False,
            missing_note="Output not rendered yet.",
        )
        if checked:
            checked_paths.append(rel_path)

    print(c("\nDashboard Scripts", BOLD))
    routing = config.get("dashboard_routing", {})
    for key in sorted(routing.keys(), key=lambda item: int(item)):
        route = routing.get(key, {})
        script_path = route.get("script", "")
        checked = validate_path(project_root, f"Route {key} script", script_path, counts)
        if checked:
            checked_paths.append(script_path)

    print(c("\nNaming Consistency", BOLD))
    variants = collect_path_variants(checked_paths)
    inconsistency_found = False
    for group in sorted(variants.values(), key=lambda item: sorted(item)[0] if item else ""):
        if len(group) > 1:
            inconsistency_found = True
            print(
                f"  [{c('WARN', YELLOW)}] Directory casing variants detected: "
                + ", ".join(sorted(group))
            )

    if not inconsistency_found:
        print(f"  [{c('OK', GREEN)}] No directory casing conflicts detected.")

    print(c("\nSummary", BOLD))
    print(f"  OK: {counts['ok']}")
    print(f"  WARN: {counts['warnings']}")
    print(f"  ERR: {counts['errors']}")

    if counts["errors"] > 0:
        print(c("\n❌ Validation completed with errors.", RED))
        return 1

    if counts["warnings"] > 0 or inconsistency_found:
        print(c("\n⚠️ Validation completed with warnings.", YELLOW))
        return 0

    print(c("\n✅ All tracked assets look healthy.", GREEN))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
