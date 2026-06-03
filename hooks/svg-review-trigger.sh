#!/usr/bin/env bash
# PostToolUse hook.  After a Write/Edit/MultiEdit touches an SVG under
# an assets/ directory, emit a reminder to Claude to run the svg-review skill
# before reporting the task complete.
#
# Stdin:  tool-event JSON payload (contains tool_input.file_path).
# Stderr: message surfaced to Claude when exit code is 2.
# Exit 0: nothing to do (not an SVG, or parse failure).

set -euo pipefail

payload=$(cat)

file_path=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
print((data.get("tool_input") or {}).get("file_path", ""))
')

case "$file_path" in
  */assets/*.svg)
    cat <<MSG >&2
SVG file modified: ${file_path}
Before reporting the task complete, invoke the svg-review skill.
It checks: label/arrow overlaps, fan symmetry, consistent arrow-to-box
clearances, row/column alignment, legend/colour consistency, and
semantic arrow direction.
MSG
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
