---
name: finance-diagram
description: Generate a finance course chart — option payoff/profit diagram, instrument cashflow timeline, or party/flow swap box diagram — by authoring a short driver script against the finma-course-visuals library and running it to emit an SVG. Use when asked to create or regenerate a payoff / spread / straddle / strangle / collar chart, a swap or bond cashflow timeline, or a fixed-for-floating (party box-and-arrow) diagram.
---

# Finance Diagram

Generate finance diagrams through the shared
[`finma-course-visuals`](https://github.com/howesrichard/finma-course-visuals)
library, never by hand-writing matplotlib. The library owns the canonical
palette, the payoff math, and the house style; this skill is the thin
orchestrator that picks the right API, writes a ~15-line driver into the
consuming repo, runs it, and hands the SVG to `svg-review`.

**Core rule:** never inline `matplotlib` in a generator. Always go through
`finma_visuals` so every chart shares one palette and one style. If the library
can't yet express a diagram, say so and propose extending the library — do not
fall back to bespoke matplotlib.

## When to run

- The user asks for an **option payoff or profit** chart: a single leg
  (long/short call/put), or a multi-leg strategy (vertical spread, straddle,
  strangle, collar, or an arbitrary combination).
- The user asks for a **cashflow timeline**: periodic payments along a time
  axis (interest-rate swap schedule, bond coupons, etc.).
- The user asks for a **party / flow box diagram**: counterparties as boxes with
  labelled cashflow arrows between them (e.g. a fixed-for-floating swap).
- The user asks to **regenerate** an existing such chart through the library.

## When to skip

- The diagram is a bespoke conceptual figure (timeline of ideas, an org chart, a
  balance-sheet schematic) with no payoff/timeline/party-flow structure — that's
  a hand-authored SVG; use `svg-review` after drawing it instead.
- The request is to edit an existing hand-drawn SVG under `**/assets/`.

When skipping, say so in one line so the user knows you considered it.

## Step 1 — Confirm the library is installed

Run, in the active repo's Python environment:

```bash
python -c "import finma_visuals as fv; print(fv.__version__)"
```

If it fails, **do not** `pip install` silently. Tell the user to pin it in the
repo's `requirements.txt` and install:

```
finma-course-visuals @ git+https://github.com/howesrichard/finma-course-visuals.git@v0.1.0
```

```bash
pip install -r requirements.txt
```

(During pre-release local development the library may instead be installed
editable from a sibling checkout: `pip install -e /workspaces/finma-course-visuals`.)

## Step 2 — Map the request to the API

| Request shape | Module | Entry point |
|---|---|---|
| Single option leg, or one strategy on one panel | `payoffs` | `plot_strategy` |
| "Show it built up from its legs" (`leg + leg = combined`) | `payoffs` | `plot_strategy_decomposition` |
| Several independent positions side by side (e.g. the four basics) | `payoffs` | `plot_grid` |
| Periodic cashflows along a time axis | `timeline` | `plot_cashflow_timeline` (+ `periodic_flows`) |
| Parties exchanging cashflows (general) | `flows` | `plot_party_flows` |
| Fixed-for-floating swap, two parties | `flows` | `fixed_for_floating` |

Strategy constructors available out of the box:
`Strategy.long_call/short_call/long_put/short_put(K, premium)`,
`Strategy.bull_call_spread(K1, K2, p1, p2)`,
`Strategy.straddle(K, call_premium, put_premium)`,
`Strategy.strangle(K_put, K_call, put_premium, call_premium)`,
`Strategy.collar(S0, K_put, K_call, p_put, p_call)`.
For anything else, compose `Strategy([Leg(kind, strike, premium, quantity), ...])`
where `quantity` is `+N` long / `-N` short and `kind` is `'call' | 'put' | 'stock'`.

`mode` is `'profit'` (default), `'payoff'`, or `'both'`. Profit subtracts
premium; payoff is intrinsic value only.

## Step 3 — Write a driver into the COURSE repo

**Where — read this before writing anything.** The driver *and* its SVG belong
in the **course repo you are authoring** — the one holding the course content
(`Session_*/` folders, the `Makefile`, the Typst sources). For a real course
that is that course's own repo; in this template it is `finma-course-template`.

**Never write into the `finma-course-visuals` checkout.** In a tooling-dev
workspace several repos are open at once, and `finma-course-visuals` is the
*installed library dependency*, not an output location — its `out/` and
`examples/` exist only for developing the library, and anything saved there
would never ship with a course. Likewise never write into `finma-course-tools`
(the plugin). If several repos are open, the course repo is simply the one that
is **not** `finma-course-visuals` and **not** `finma-course-tools`.

**Use an absolute path anchored at the course repo root** (e.g.
`/workspaces/<course-repo>/...`), never a bare relative path — a relative path
resolves against whatever happens to be the cwd, which is how output wrongly
lands in the library's `out/`. Confirm the course repo root first (e.g. the
directory containing the `Makefile` and `Session_*/`).

Place the driver in the course repo's diagram convention (e.g.
`/workspaces/<course-repo>/Week_X/diagrams/generate_<name>.py`, or an
`assets/` generators folder) and save the SVG into an `assets/` folder so
`svg-review` / `slide-fit-check` (which match `**/assets/*.svg`) can lint it.
Keep it to the house shape: `use_house_style("svg")` → build the model →
`plot_*` → `save_figure(..., "/workspaces/<course-repo>/.../<name>.svg")`.
Default to SVG.

**Option strategy (single panel):**

```python
from finma_visuals import use_house_style, save_figure, Strategy, plot_strategy

use_house_style("svg")
spread = Strategy.bull_call_spread(K1=45, K2=55, p1=7, p2=3)
fig = plot_strategy(spread, s_min=30, s_max=70, mode="profit",
                    info_box="Long Call @45 / Short Call @55\nNet debit: 4")
save_figure(fig, "/workspaces/<course-repo>/assets/bull_call_spread.svg")
```

**Decomposition strip (built up from legs):**

```python
from finma_visuals import use_house_style, save_figure, Strategy, plot_strategy_decomposition

use_house_style("svg")
collar = Strategy.collar(S0=100, K_put=95, K_call=110)
fig = plot_strategy_decomposition(collar, s_min=80, s_max=125)  # auto "+ + ="
save_figure(fig, "/workspaces/<course-repo>/assets/collar.svg")
```

**Grid of independent positions:**

```python
from finma_visuals import use_house_style, save_figure, Strategy, plot_grid

use_house_style("svg")
strategies = [Strategy.long_call(50, 5), Strategy.short_call(50, 5),
              Strategy.long_put(50, 5), Strategy.short_put(50, 5)]
fig = plot_grid(strategies, s_min=30, s_max=70, ncols=2, footer="K=$50 | Premium=$5")
save_figure(fig, "/workspaces/<course-repo>/assets/basic_payoffs.svg")
```

**Cashflow timeline:**

```python
from finma_visuals import (use_house_style, save_figure, plot_cashflow_timeline,
                           periodic_flows, TimePoint, Palette)

use_house_style("svg")
flows = periodic_flows(1, 5, 1, up_label="Pay Fixed 4.50%", down_label="Receive 3M BBSW")
points = [TimePoint(0, "T=0"), TimePoint(1, "Q1"), TimePoint(2, "Q2"),
          TimePoint(3, "..."), TimePoint(4, "Q19"), TimePoint(5, "Q20 (5Y)")]
points[3].marker = False  # the ellipsis tick draws no dot
fig = plot_cashflow_timeline(
    flows, points, title="IR Swap: Cash Flow Timeline (Fixed-Rate Payer)",
    period_label="one quarter", period_span=(1, 2),
    insight="No principal exchange — notional is reference only",
    legend=[(Palette.NAVY, "Fixed leg (pay)"), (Palette.GOLD, "Floating leg (receive)")])
save_figure(fig, "/workspaces/<course-repo>/assets/ir_swap_timeline.svg")
```

**Party / flow box diagram:**

```python
from finma_visuals import use_house_style, save_figure, fixed_for_floating

use_house_style("svg")
fig = fixed_for_floating(payer="Corporate", receiver="Swap Dealer",
                         fixed="Fixed 4.50%", floating="3M BBSW")
save_figure(fig, "/workspaces/<course-repo>/assets/fixed_float_swap.svg")
```

For a general multi-party flow, build `Party(id, label, pos=(x, y))` boxes and
`FlowArrow(src, dst, label=..., offset=±d)` arrows (give two opposing arrows
`+offset`/`-offset` so they don't overlap) and call `plot_party_flows`.

## Step 4 — Run it

```bash
python <path/to/generate_name.py>
```

Confirm the SVG was written to the repo's `assets/` (or its convention). If the
driver raises, fix the driver — do not switch to inline matplotlib.

## Step 5 — Hand off to svg-review

Because the output is an SVG under the repo's assets, the `svg-review` skill (and
its PostToolUse hook) own the visual QA — overlaps, arrow direction, alignment,
palette consistency. Defer to it rather than re-implementing visual checks here.

For **PNG** output (which `svg-review` can't read) or to gate layout in a test,
the library exposes an in-process fallback:

```python
from finma_visuals import assert_no_overlaps
fig.canvas.draw()
assert_no_overlaps(fig, max_severity="high")  # raises on dense overlaps
```

## Reporting

State which entry point you used, the driver path, and the output SVG path in
one or two lines, then note that `svg-review` should run (or has run). Don't
restate the whole driver.

## Evolving this skill

When the user needs a diagram the library can't yet express, the fix is to
**extend `finma-course-visuals`** (a new `Strategy` constructor, a new plot
mode, a new diagram module) and bump its tag — not to special-case matplotlib in
a driver. Record the new capability in the decision table above once it ships.
