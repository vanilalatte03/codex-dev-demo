#!/usr/bin/env bash
set -u

mode="${1:-}"
payload="$(cat || true)"

emit_policy_decision() {
  HOOK_MODE="$mode" HOOK_PAYLOAD="$payload" /usr/bin/python3 - <<'PY'
import json
import os
import re

mode = os.environ.get("HOOK_MODE", "")
raw_payload = os.environ.get("HOOK_PAYLOAD", "")

try:
    payload = json.loads(raw_payload) if raw_payload.strip() else {}
except json.JSONDecodeError:
    payload = {}

tool_input = payload.get("tool_input")
if isinstance(tool_input, dict):
    command = tool_input.get("command") or tool_input.get("cmd") or json.dumps(tool_input)
elif isinstance(tool_input, str):
    command = tool_input
else:
    command = ""

rules = [
    (re.compile(r"\brm\s+--?[A-Za-z]*r[A-Za-z]*f[A-Za-z]*\b"), "recursive forced removal is blocked"),
    (re.compile(r"\brm\s+--?[A-Za-z]*f[A-Za-z]*r[A-Za-z]*\b"), "recursive forced removal is blocked"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "hard resets are blocked"),
    (re.compile(r"\bgit\s+clean\s+-[A-Za-z]*[fdx][A-Za-z]*\b"), "git clean with file deletion is blocked"),
    (re.compile(r"\bgit\s+push\b[^\n;&|]*\s--force(?:-with-lease)?\b"), "force pushes are blocked"),
    (re.compile(r"\bchmod\s+-R\s+777\b"), "recursive world-writable chmod is blocked"),
    (re.compile(r"\bsudo\b"), "sudo commands are blocked"),
    (re.compile(r"\bDROP\s+TABLE\b", re.IGNORECASE), "DROP TABLE statements are blocked"),
    (re.compile(r"\b(?:curl|wget)\b[^\n;&|]*\|\s*(?:sh|bash)\b"), "curl/wget piped to a shell is blocked"),
]

reason = None
for pattern, message in rules:
    if pattern.search(command):
        reason = f"{message}: {command.strip()}"
        break

if not reason:
    raise SystemExit(0)

if mode == "permission-request":
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "decision": {
                "behavior": "deny",
                "message": reason,
            },
        }
    }
else:
    output = {
        "decision": "block",
        "reason": reason,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
    }

print(json.dumps(output, ensure_ascii=False), end="")
PY
}

emit_tdd_decision() {
  HOOK_PAYLOAD="$payload" /usr/bin/python3 - <<'PY'
import json
import os
import re
from pathlib import Path

RAW_PAYLOAD = os.environ.get("HOOK_PAYLOAD", "")

SOURCE_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cs",
    ".go",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".php",
    ".py",
    ".rb",
    ".rs",
    ".swift",
    ".ts",
    ".tsx",
}

SKIP_PREFIXES = (
    ".agents/",
    ".codex/",
    ".git/",
    ".githooks/",
    "docs/",
    "phases/",
)

SKIP_NAMES = {
    ".gitignore",
    "AGENTS.md",
    "README.md",
    "package-lock.json",
    "package.json",
    "pnpm-lock.yaml",
    "pyproject.toml",
    "tsconfig.json",
    "yarn.lock",
}


def load_payload():
    try:
        return json.loads(RAW_PAYLOAD) if RAW_PAYLOAD.strip() else {}
    except json.JSONDecodeError:
        return {}


def normalize_path(value):
    if not isinstance(value, str) or not value.strip():
        return None
    return value.strip().lstrip("./")


def extract_paths_from_patch(patch_text):
    paths = []
    if not isinstance(patch_text, str):
        return paths
    for line in patch_text.splitlines():
        match = re.match(r"\*\*\* (?:Add|Update|Delete) File: (.+)$", line)
        if match:
            path = normalize_path(match.group(1))
            if path:
                paths.append(path)
    return paths


def extract_paths(payload):
    tool_input = payload.get("tool_input", {})
    paths = []

    if isinstance(tool_input, dict):
        for key in ("file_path", "path", "target_file", "target_path"):
            path = normalize_path(tool_input.get(key))
            if path:
                paths.append(path)

        for key in ("files", "paths"):
            values = tool_input.get(key)
            if isinstance(values, list):
                for value in values:
                    path = normalize_path(value)
                    if path:
                        paths.append(path)

        for key in ("patch", "input", "content"):
            paths.extend(extract_paths_from_patch(tool_input.get(key)))
    elif isinstance(tool_input, str):
        paths.extend(extract_paths_from_patch(tool_input))

    result = []
    seen = set()
    for path in paths:
        if path not in seen:
            seen.add(path)
            result.append(path)
    return result


def is_test_path(path):
    lowered = path.lower()
    name = Path(path).name.lower()
    return (
        "/test/" in lowered
        or "/tests/" in lowered
        or "/__tests__/" in lowered
        or name.startswith("test_")
        or name.endswith("_test.py")
        or ".test." in name
        or ".spec." in name
        or name.endswith("test.java")
        or name.endswith("tests.java")
    )


def should_skip(path):
    normalized = path.lstrip("./")
    if normalized in SKIP_NAMES:
        return True
    if normalized.startswith(SKIP_PREFIXES):
        return True
    if is_test_path(normalized):
        return True
    return Path(normalized).suffix not in SOURCE_EXTENSIONS


def candidate_tests(path):
    target = Path(path)
    directory = target.parent
    suffix = target.suffix
    stem = target.stem
    candidates = [
        directory / f"{stem}.test{suffix}",
        directory / f"{stem}.spec{suffix}",
        directory / "__tests__" / f"{stem}{suffix}",
        directory / "__tests__" / f"{stem}.test{suffix}",
        directory / "__tests__" / f"{stem}.spec{suffix}",
        Path("tests") / f"{stem}.test{suffix}",
        Path("tests") / f"{stem}.spec{suffix}",
    ]

    if suffix == ".py":
        candidates.extend(
            [
                directory / f"test_{stem}.py",
                directory / f"{stem}_test.py",
                Path("tests") / f"test_{stem}.py",
                Path("tests") / f"{stem}_test.py",
            ]
        )

    if suffix in {".js", ".jsx", ".ts", ".tsx"}:
        candidates.extend(
            [
                Path("test") / f"{stem}.test{suffix}",
                Path("test") / f"{stem}.spec{suffix}",
                Path("tests") / f"{stem}{suffix}",
            ]
        )

    return candidates


def has_matching_test(path):
    return any(candidate.exists() for candidate in candidate_tests(path))


def emit_block(message):
    output = {
        "decision": "block",
        "reason": message,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": message,
        },
    }
    print(json.dumps(output, ensure_ascii=False), end="")


payload = load_payload()
missing = [
    path for path in extract_paths(payload)
    if not should_skip(path) and not has_matching_test(path)
]

if missing:
    emit_block(
        "TDD Guard: implementation changes need a matching test first. "
        f"Create or update tests before editing: {', '.join(missing)}"
    )
PY
}

emit_stop_continue() {
  printf '{"continue":true}'
}

emit_stop_block() {
  HOOK_REASON="$1" /usr/bin/python3 - <<'PY'
import json
import os

print(json.dumps({
    "decision": "block",
    "reason": os.environ.get("HOOK_REASON", "Project checks failed."),
}, ensure_ascii=False), end="")
PY
}

has_npm_script() {
  /usr/bin/python3 - "$1" <<'PY'
import json
import sys

script = sys.argv[1]
try:
    with open("package.json", "r", encoding="utf-8") as f:
        package = json.load(f)
except FileNotFoundError:
    raise SystemExit(1)
except json.JSONDecodeError:
    raise SystemExit(1)

scripts = package.get("scripts", {})
raise SystemExit(0 if script in scripts else 1)
PY
}

run_npm_checks() {
  if [ ! -f package.json ]; then
    return 0
  fi

  for script in lint build test; do
    if has_npm_script "$script"; then
      output="$(npm run "$script" 2>&1)"
      status=$?
      if [ "$status" -ne 0 ]; then
        printf 'npm run %s failed:\n%s' "$script" "$output"
        return "$status"
      fi
    fi
  done
}

case "$mode" in
  pre-tool-use|permission-request)
    emit_policy_decision
    ;;
  tdd-pre-tool-use)
    emit_tdd_decision
    ;;
  stop)
    if output="$(run_npm_checks 2>&1)"; then
      emit_stop_continue
    else
      emit_stop_block "$output"
    fi
    ;;
  git-pre-commit)
    run_npm_checks
    ;;
  *)
    exit 0
    ;;
esac
