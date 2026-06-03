# Lesson illustration art direction

Per-card briefs for the lesson story-card illustrations. Generate each image in
the established ARCLAB editorial style (the same look as the archery `arc-l1-*`
set), drop the PNG into the matching imageset under
`Resources/Assets.xcassets/<slot>.imageset/`, and add its `filename` to that
imageset's `Contents.json` (Xcode does this automatically if you drag the file
onto the image well).

Until the PNG is present, the card renders **type-only** — `LessonView` guards
with `if let uiImage = UIImage(named:)`, so a missing slot is never a crash and
never a broken-image icon. Ship copy first, art when ready.

## House style (all lesson illustrations)

A flat, editorial, almost-monochrome poster look — not rendered 3D, not photo.

- **Background:** scene panel `#181818` (`arclabSceneBg`). Never pure black —
  the card already sits on near-black, so the illustration zone is one notch up.
- **Figures:** pure-black silhouette `#000000` (`arclabSilhouette`). Read as
  shape, not detail — no faces, no jersey numbers, no logos.
- **Ball / rim:** orange `#E8782B` (`arclabBallOrange` / `arclabRimOrange`).
  This is the ONLY saturated hero color. Ball seam shadow `#8B3F10`.
- **Floor / court wood:** amber `#B57B3F` (`arclabFloorWood`), used sparingly —
  a baseline strip, not a full court.
- **Lines (paint, arcs, backboard, trajectory):** cream `#F5F1E8`
  (`arclabFloorLine`). Thin, confident, hand-drawn-straight.
- **Type inside art:** avoid. Headlines live in the app, not the image. A single
  small numeric label (e.g. "9.8 m/s²") is the only exception.
- **NEVER** use crimson `#FF3037` — it is sacred to the MISS state. An orange
  ball must never drift red.
- **Aspect:** 3:2 landscape (match archery: 1536 × 1024), renders in a
  220pt-tall rounded card. Compose for the top two-thirds; keep the focal point
  off-center-left to echo the left-aligned headline beneath it.

---

## Basketball · Chapter 1 — "The Arc"

The chapter teaches: once the ball leaves the hand, only gravity acts on it, so
every shot is the same parabola. Six beats, hook → force → equation → myth-bust
→ payoff. Each illustration should add visual weight to its beat, not re-explain
the headline.

### `bb-l1-01` — "Every shot is the same shape."
Hook. One clean orange ball at the apex of a cream parabola, arcing right-to-left
toward a simple rim at far left. The arc is the hero — draw the full parabola as
a thin cream line, ball sitting on it near the top. Quiet, iconic, no figure yet.

### `bb-l1-02` — "Gravity."
Name the force. The same ball, now with a single straight cream arrow pointing
straight **down** from it. Optional tiny label "9.8 m/s²" beside the arrow in
cream. Strip the arc back to a faint ghost so the downward pull dominates. This
is the most diagrammatic card.

### `bb-l1-03` — "That's the whole story. / Two ingredients."
The release + gravity. A black silhouette shooter at lower-left in follow-through
(wrist snapped, arm extended), the cream arc leaving the fingertips. Show the two
ingredients visually: the release (figure) and the fall (arc bending down toward
the rim). First appearance of the figure.

### `bb-l1-04` — "And it has an equation."
The formula-reveal beat (the card also shows `y(t) = h + v·sin(θ) − ½gt²`). Keep
the art SPARE so it doesn't fight the math token below it: just the cream arc
with three faint tick marks along it (release height h, angle θ at the base as a
small cream angle wedge, and the peak). Diagram, not scene.

### `bb-l1-05` — "Hang time is a myth."
Myth-bust — the strongest image. A black silhouette frozen mid-jump near the
apex, with 3–4 faint "ghost" silhouettes of the same figure spaced along the arc
to show even spacing at the top = the slowdown is just the parabola's peak, not
floating. The ghosts bunch slightly at the top (slowest) and spread toward the
bottom (faster). Subtle; the eye should read "evenly falling," not "hanging."

### `bb-l1-06` — "The arc is already decided."
Payoff / close. Pull back: the full cream parabola complete from release to rim,
ball mid-flight, silhouette shooter small at the origin. Calm and resolved — the
whole shape visible at once, the way the lesson says the math already "sees" it.
Mirror of card 01 but complete rather than hinting.

---

## Adding a new chapter's briefs

Append a new `## Basketball · Chapter N — "<title>"` section, list one `### <slot>`
per card, and wire the slots in `BasketballCurriculum.swift` with
`illustration: "<slot>"`. Keep slot names `bb-lN-MM` (chapter N, card MM).
