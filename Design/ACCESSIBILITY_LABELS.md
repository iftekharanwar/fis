# App Store Accessibility Nutrition Labels — Phisios

Apple's Accessibility Nutrition Labels (App Store Connect → Apps → App
Accessibility) let us declare which accessibility features the app supports.
They render on the product page, factor into App Store search relevance for
feature-named queries, and will eventually be mandatory. Declaring is a
**console action** (no binary, no version bump); this doc maps each feature to
what we shipped and the manual test that must pass before ticking it.

Declare per device family (iPhone, iPad). Re-evaluate every release.

## Test matrix (run before declaring)

Settings → Accessibility on the device/simulator:
- **VoiceOver** — full run of the core loop per sport.
- **Display & Text Size → Larger Text** — drag to the largest AX size.
- **Display & Text Size → Increase Contrast** — on.
- **Display & Text Size → Bold Text** — on.
- **Display & Text Size → Reduce Motion** — on.
- **Display & Text Size → Differentiate Without Color** — on.
- **Display & Text Size → Color Filters → Grayscale** — Apple's "can you still
  use it?" smoke test.

---

## ✅ VoiceOver — declare: SUPPORTED

What we shipped (Phases 1–2):
- Every interactive control is a real `Button`/labeled element — stance docks,
  lesson paging, celebration/mastery takeovers, numpad fields, slider step
  chips (`ParameterSliderRow`), splash retry.
- State changes announce via `Announce` (`AccessibilityNotification`): verdicts,
  outcomes (`SwishView`/`MissedView`), reveal cards, daily result, lesson cards,
  compute verdicts.
- The frozen call beat moves focus to the prompt (`@AccessibilityFocusState`).
- SpriteKit scenes are narrated (`SceneNarration`): static geometry in the
  label, the live per-phase read (the call evidence) in the value.
- Lesson cards are an adjustable element (swipe up/down pages) + named
  Next/Previous actions; decorative art is hidden, never read as a filename.

Verify: blind run-through of basketball, archery, soccer — open → pick sport →
lesson → scenario → call → read verdict, with no sighted assistance.

## ✅ Larger Text — declare: SUPPORTED

What we shipped: global Dynamic Type lifted to **AX5**; all three font families
scale (`Font+Tokens`). The numpad dock measures its content and grows/scrolls
instead of overlapping the court (`PlayView` intrinsic dock). Fixed posters
(lesson reader, outcome verbs, splash) cap at a safe per-screen ceiling so they
scale substantially without clipping; scrolling surfaces (chapter list, daily)
reach AX5.

Verify: largest AX size — confirm no lost content on home, chapter list, lesson,
play (numpad reachable by scroll), daily, settings.

## ✅ Sufficient Contrast — declare: SUPPORTED

What we shipped: the default palette clears WCAG AA (`arclabMidGrey` 6:1); the
**High Legibility** mode (toggle, or auto under iOS Increase Contrast) lifts
secondary text to ~10:1 and softens white to cut halation. Locked/disabled
states no longer double-dim below the floor (Phase 2): they keep full-strength
grey + a lock glyph + printed rule.

Verify: Increase Contrast + Bold Text on; confirm every text style reads. (No
automated checker catches halation — eyeball white-on-black at size.)

## ✅ Reduced Motion — declare: SUPPORTED

What we shipped (Phase 3): `AccessibilitySettings.reduceMotionActive` (in-app
toggle OR the iOS setting, live). Gated: idle dribble loop, shoot flash, splash
rise/bloom, home entrance, outcome count-ups, lesson-reader zoom (→ crossfade).
The ball-flight trajectory stays — it's the physics lesson, not decoration
(Apple permits essential motion).

Verify: Reduce Motion on — confirm no decorative motion in the core loop; the
shot still flies.

## ✅ Differentiate Without Color — declare: SUPPORTED

What we shipped: the black/white/amber identity carries no color-only meaning —
correct/incorrect is text-led (NAILED IT / WRONG + spoken), locked states use a
lock glyph + label, selection uses `.isSelected`. `systemDifferentiateWithoutColor`
is observed as a regression hook for any future color-coded feature.

Verify: Grayscale color filter — run the core loop; every state still legible.

## ➖ Dark Interface — declare: SUPPORTED (already dark-only)

The app ships dark-only (`UIUserInterfaceStyle = Dark`). Confirm no white
interstitials/sheets appear in any common flow.

## ❌ Captions — do NOT declare (not applicable)

No video and no spoken dialogue/narration. Apple's guidance: don't declare
features irrelevant to the app. (If a narrated lesson/cutscene ships later,
revisit — synchronized captions or a transcript would be required.)

## ➖ Voice Control — supported by construction, not a separate label

Rides on the same element tree as VoiceOver: every control is a labeled button
with named actions, so "tap <name>" and the action menu work. No timed beats
gate the core loop. Verify a Voice Control pass when convenient.
