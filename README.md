# finma-course-tools

Claude Code plugin providing shared tooling for FINMA course repos built on
[typst-dual-format](https://github.com/howesrichard/typst-dual-format).

## Contents

- **Agent:** `content-modularizer` — extracts session file sections into
  reusable modules under `modules/Session_N/`, preserving dual-format output.
- **Skills:** `slide-fit-check` (verifies slide content fits the canvas),
  `svg-review` (visual review checklist for hand-crafted SVGs), and
  `finance-diagram` (generates option payoff, cashflow timeline, and party/flow
  swap diagrams via the `finma-course-visuals` library).
- **Hooks:** PostToolUse hooks that nudge Claude to run the above skills after
  editing module files (`modules/Session_*/*.typ`) or SVGs (`**/assets/*.svg`).

## Install

In a course repo:

```bash
claude plugin install https://github.com/howesrichard/finma-course-tools.git --scope project
```

This writes an entry to `.claude/settings.json` that all cloners pick up
automatically (after workspace trust).

## Update

```bash
claude plugin update finma-course-tools
```

No `version` field is set in the manifest, so every commit is the latest
version — `/plugin update` pulls the newest commit.

## License

[MIT](LICENSE)
