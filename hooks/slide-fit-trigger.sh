#!/usr/bin/env bash
# PostToolUse hook.  After a Write/Edit/MultiEdit touches a Typst module
# file under modules/Session_*/, emit a reminder to Claude to run the
# slide-fit-check AND box-fit-check skills before reporting the task complete.
#
# Typst silently overflows content rather than erroring in two places:
#   - slide canvas         -> slide-fit-check  (content-block summary spill)
#   - document callout box  -> box-fit-check   (takeaways/definition/example/
#                             concept boxes use block(breakable: false))
# Both are layout-affecting edits that need a post-build verification.
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
Typst module modified: ${file_path}
Before reporting the task complete, consider two post-build checks
(Typst silently overflows rather than erroring in both):

1. slide-fit-check — if the edit changed a \`content-block\`'s \`summary:\`
   (the slide body). Rebuilds the session slides and checks whether any
   element's bbox extends past the slide canvas.
   Skip if the edit only touched \`details:\`, a \`content-block-doc-only(...)\`,
   or anything that cannot affect slide layout.

2. box-fit-check — if the edit changed the body of a document callout box
   (\`takeaways-box\`, \`definition-box\`, \`example-box\`, \`concept-box\`; these
   often live in \`details:\` prose). Rebuilds the session document and checks
   whether any box's content spills past its border off the page bottom.
   Skip if the edit is outside any callout box.

Run whichever applies (often neither, sometimes both). Say in one line
which you ran or why you skipped.
MSG
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
