#!/usr/bin/env bash
# PostToolUse hook.  After a Write/Edit/MultiEdit touches a Typst module
# file under modules/Session_*/, emit a reminder to Claude to run the
# slide-fit-check skill before reporting the task complete.
#
# Typst silently clips content that overflows the slide canvas rather than
# erroring, so layout-affecting edits need a post-build verification.
#
# Stdin:  tool-event JSON payload (contains tool_input.file_path).
# Stderr: message surfaced to Claude when exit code is 2.
# Exit 0: nothing to do (not a slide-emitting Typst file, or parse failure).

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
  */modules/Session_*/*.typ)
    cat <<MSG >&2
Slide-emitting Typst module modified: ${file_path}
Before reporting the task complete, invoke the slide-fit-check skill.
It rebuilds the session slides, locates the edited content-block(s) in
the PDF, and checks whether any element's bbox extends past the slide
canvas (Typst silently clips overflow rather than erroring).

Skip the check when the edit only touched a \`details:\` block, a
\`content-block-doc-only(...)\`, or anything else that does not affect
slide layout (typo fixes in prose, etc).
MSG
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
