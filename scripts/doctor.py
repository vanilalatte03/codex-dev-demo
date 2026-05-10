#!/usr/bin/env python3
"""Inspect whether the Codex operating template is ready to use."""

from __future__ import annotations

import subprocess
from pathlib import Path

import checks

ROOT = Path(__file__).resolve().parent.parent


def _status(ok: bool) -> str:
    return "ok" if ok else "missing"


def _git_hooks_path() -> str:
    result = subprocess.run(
        ["git", "config", "--get", "core.hooksPath"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _count_inline_adrs() -> int:
    path = ROOT / "docs" / "ADR.md"
    if not path.exists():
        return 0
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("### ADR-"))


def _count_split_adrs() -> int:
    adr_dir = ROOT / "docs" / "adr"
    if not adr_dir.is_dir():
        return 0
    return len([path for path in adr_dir.glob("*.md") if path.is_file()])


def main() -> int:
    profile = checks.load_project_profile(ROOT)
    print("Codex Project Ops Doctor")
    print(f"- profile: {profile.get('profile', 'unknown')}")
    print(f"- guardMode: {checks.guard_mode(ROOT)}")
    print(f"- git hooksPath: {_git_hooks_path() or 'not configured'}")

    required = [
        "AGENTS.md",
        "docs/PRD.md",
        "docs/ARCHITECTURE.md",
        "docs/ADR.md",
        "docs/COMMANDS.md",
        ".codex/hooks.json",
        ".codex/project-profile.json",
        ".codex/hooks/tdd-guard.sh",
        ".githooks/pre-commit",
        "issues/README.md",
    ]
    print("\nRequired files")
    for rel in required:
        print(f"- {rel}: {_status((ROOT / rel).exists())}")

    agents_lines = (ROOT / "AGENTS.md").read_text(encoding="utf-8").splitlines()
    print(f"\nAGENTS.md lines: {len(agents_lines)}")
    if len(agents_lines) > 110:
        print("- warning: AGENTS.md is above the 100-line target.")

    inline_adrs = _count_inline_adrs()
    split_adrs = _count_split_adrs()
    print(f"\nADR count: inline={inline_adrs}, split={split_adrs}")
    if inline_adrs > 3 and split_adrs == 0:
        print("- warning: split ADRs into docs/adr/ when ADR count exceeds 3.")

    print("\nSelected checks")
    selected = checks.collect_checks(ROOT, "manual")
    if selected:
        for check in selected:
            print(f"- {check.name}: {check.command} ({check.source})")
    else:
        print("- none configured or detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
