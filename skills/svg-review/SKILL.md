---
name: svg-review
description: Review a hand-crafted SVG diagram for common visual issues — label/arrow overlaps, fan symmetry, consistent arrow-to-box clearances, box row/column alignment, legend/colour consistency, and semantic arrow direction. Invoke after creating or editing any SVG under `**/assets/*.svg` (the PostToolUse hook will remind you).
---

# SVG Visual Review

Catch clutter and asymmetry **before** the user has to point them out. Every item in this checklist is something a previous iteration got wrong; adding checks here is how we learn.

## When to run

- After writing or editing an SVG under `**/assets/*.svg` (the hook nudges you).
- Before reporting an SVG-authoring task complete.
- When the user reports a visual issue — run the full checklist so you catch the neighbouring problems too, not just the one they flagged.

## Before you start

- Read the SVG file you just wrote. Identify: title/subtitle text, phase bands / background panels, box elements (rect), connector elements (line, polyline, path), text labels, legend if any.
- For each text label, note whether `text-anchor` is `start` (default), `middle`, or `end`, and whether `dominant-baseline` is set (`middle`/`central` centres on `y`).
- Approximate bounding boxes: for Arial at `font-size="N"`, width ≈ `0.55 * N` per character (italic slightly narrower, bold slightly wider); height ≈ `N`. If `dominant-baseline` is unset, the baseline sits at `y` and text extends ≈ `0.75N` above and `0.25N` below.

## Checklist

### 1. Label / line collisions

For each `<text>` whose position is near any `<line>`, `<polyline>`, or `<path>`:

1. Compute the text's bounding box from its `x`, `y`, `text-anchor`, `dominant-baseline`, and character count.
2. Parameterise nearby line segments: for a line from `(x1,y1)` to `(x2,y2)`, compute `x(t) = x1 + t*(x2-x1)`, `y(t) = y1 + t*(y2-y1)` for `t ∈ [0,1]`.
3. Evaluate the line at the label's `y`-range; check whether the resulting `x` values fall inside the label's `x`-range. If they do — the line crosses the label.
4. Target clearance: ≥ 5 px between any point on the line and the label's bounding box.
5. **Fix**: move the label perpendicular to the line (simplest), or rotate it to run parallel to the line with a perpendicular offset, or move it to open whitespace outside the line's path.

### 2. Fan symmetry

A *fan* is a group of 2+ connectors that share a common endpoint (convergent) or common origin (divergent). M3→M5 and M4→M5 form a convergent fan; M5→M6 and M5→M7 a divergent one.

1. Find the common point's position on the axis of spread (usually `x`).
2. Compute the arithmetic mean of the other endpoints' positions on that same axis.
3. The common point must sit on the mean. Tolerance: ≤ 2 px.
4. Additionally: the `|dx|` and `|dy|` of each arrow in the fan must match, so the fan is mirror-symmetric.
5. If two fans share a visual axis (e.g., a convergent fan into M5 and a divergent fan out of M5), **both** fans' symmetry axes must align on the same `x`.
6. **Fix**: move the common-point element so its centre aligns with the axis, then recompute each arrow's endpoints to enforce matching slopes.

### 3. Consistent arrow-to-box clearance

For every connector whose endpoint lands on or near a box:

1. Compute the perpendicular distance from the arrow tip to the target box's edge.
2. All arrows landing on boxes should share a consistent clearance (e.g., 2 px, or 4 px — pick one and stick to it).
3. Flag any arrow whose clearance differs from its siblings by more than 1 px.
4. **Fix**: recompute the endpoint so the distance matches the chosen convention.

### 4. Row / column alignment

1. Group boxes by apparent row (same `y`) and column (same `x` or same `x + width/2`).
2. Within a group, all boxes should share the same top `y` (rows) or centre `x` (columns), and the same width/height.
3. Flag misalignment greater than 2 px.
4. **Fix**: snap misaligned boxes to the group's dominant coordinate.

### 5. Legend / colour consistency

If the diagram includes a legend describing colour meanings:

1. List the hex colours used as `fill` or `stroke` on shapes.
2. List the hex colours declared in the legend.
3. Every shape colour must map to a legend entry, and every legend entry must be used somewhere.
4. Flag unused legend entries and undeclared shape colours.

### 6. Semantic arrow direction

For each labelled arrow:

1. Re-read the label and state the implied causal/functional relationship ("X *finances* Y", "X *prices* Y", "X *clears* Y").
2. Verify the arrow points from cause/source to effect/target.
3. Common trap: it's easy to draw the arrow in the visually-convenient direction and then apply a label that assumes the opposite direction.
4. If in doubt, ask: "If I deleted the source node, would the relationship in the label still be possible?" — if no, the direction is correct.

### 7. Whitespace & balance

Eyeball-level checks:
- Labels should not cross phase-band boundaries, legend boxes, or other group containers without good reason.
- Title, subtitle, and footer should have breathing room (≥ 10 px) from neighbouring elements.
- Large empty regions often indicate a missed alignment or an opportunity to rebalance layout.

### 8. Structural wellformedness

- The SVG must parse as valid XML. Run a quick check:
  `python3 -c "import xml.etree.ElementTree as ET; ET.parse('<path>'); print('OK')"`

## Reporting

Report each finding as:
- **Element** — what's affected, by coordinate if possible (e.g., "caption 'balance-sheet cost' at (490, 503)").
- **Issue** — what's wrong, with numbers (e.g., "M5→M6 arrow passes through x≈550 at y=503; label spans x=440–540; 10 px clearance is below the 5 px minimum").
- **Fix** — concrete coordinates or strategy (e.g., "move label to x=470 for 30 px clearance while keeping symmetry about x=730").

If everything passes, say so in **one line**. Do not fabricate issues.

## Evolving this skill

Every time the user flags a visual issue that this checklist missed, add a new check here. The checklist is meant to grow with the pattern library of real problems, not with imagined edge cases.
