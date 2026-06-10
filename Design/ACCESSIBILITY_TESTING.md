# Device Testing Script — Accessibility branch

How to read this: **Do** = the action. **PASS** = what you should see/hear.
**FAIL (report)** = the symptom that means a real bug to fix — copy the
screen + what happened and send it back.

Toggle the OS settings at **Settings → Accessibility**. The in-app toggles
are behind the **gear** (top-right on Home).

---

## 1. VoiceOver — the most important pass

Turn on **Settings → Accessibility → VoiceOver**. (Triple-click the side
button to toggle it fast.) Navigation: swipe **right** = next element, swipe
**left** = previous, **double-tap** = activate. Two-finger swipe down = "read
from here."

### 1a. Home + Settings
- **Do:** swipe through the Home header.
  **PASS:** you hear "Profile. ROOKIE I, 0 day streak…" on the left chip and
  "Settings. Accessibility and app options." on the gear.
  **FAIL:** either chip is silent, reads "button" with no words, or reads an
  image/asset name.
- **Do:** open Settings, swipe through.
  **PASS:** each toggle announces its name + "on/off" ("High Legibility Text,
  off"). The sample text block reads as one sentence.
  **FAIL:** a toggle is unlabeled, or you can't tell its on/off state.

### 1b. Lesson reader (this was a hard blocker — test carefully)
- **Do:** open a sport → open a chapter → open its lesson. Swipe to the card.
  **PASS:** the whole card is **one** element. You hear "Card 1 of 7", then the
  headline and body, then the hint "Swipe up or down to change cards."
  **Do:** swipe **up** (one finger).
  **PASS:** it advances to card 2 and speaks the new card.
  **PASS:** opening the VoiceOver rotor (twist two fingers) shows **Next card**
  and **Previous card** actions.
  **FAIL (blocker):** you cannot move past card 1 — no way to advance, no
  swipe-up effect, no rotor actions. This would mean a blind user is stuck
  before the game. Report immediately.

### 1c. Basketball CALL scenario (the core loop)
- **Do:** start a basketball call scenario. Before doing anything, find the
  court (swipe to the big background area).
  **PASS:** it describes the scene — "Basketball court. Shooter 4.6 meters from
  the hoop. Rim 3 meters up, backboard behind it." and the live state "Shooter
  at the line, dribbling. No shot in the air."
  **FAIL:** the court reads as nothing / "image" / silent.
- **Do:** find and double-tap the **"Release the shot…"** button.
  **PASS:** it's a real labeled button; double-tap fires the shot.
  **FAIL:** there's no actionable element — the only way to shoot is an
  accidental double-tap on plain text.
- **Do:** after the ball freezes mid-flight, **don't touch anything for a
  second.**
  **PASS:** VoiceOver focus **jumps on its own** to "Call it. Ball frozen at the
  top of its arc — [about halfway to the hoop, a meter above the rim, the arc
  looks medium]. Will it go in? Yes and No buttons below." Then swipe right
  twice to reach **Yes** / **No** buttons.
  **FAIL:** silence after release — you have no idea a call is being asked, or
  the focus stays on the dead release button. Report.
- **Do:** double-tap Yes or No.
  **PASS:** the verdict **auto-speaks** without you scrubbing — "Nailed it. Read
  it right. Ball went in." (or the matching variant).
  **FAIL:** silence after the call — you must manually swipe around to find out
  what happened. Report.

### 1d. Numpad scenario (Level A / B / C — find θ, v, or d)
- **Do:** open a numpad scenario, swipe to the input cards.
  **PASS:** "Angle field, empty" (or the value), and it's marked **selected**
  when active; numpad keys read "1", "2", … "delete", "decimal point"; SHOOT
  reads "Shoot. Commit your answer." or "Shoot, awaiting input."
  **FAIL:** field can't be selected by VoiceOver, keys are silent, or you can't
  tell which field is active.

### 1e. Compute sliders (the "Try it yourself" beat)
- **Do:** after a verdict, open "Try it yourself", swipe to a slider.
  **PASS:** it reads "Launch angle, 50 degrees" and is **adjustable** (swipe up/
  down changes it); there are also **Increase / Decrease** buttons either side.
  **FAIL:** the slider reads a bare "50%" with no name, and there's no non-drag
  way to change it.

### 1f. Archery + Soccer
- **Do:** repeat 1c for an archery scenario ("Nock it / loose the arrow") and a
  soccer scenario (the call is at stance, before the kick).
  **PASS:** same shape — scene described, stance is a real button, verdict
  auto-speaks. Soccer's stance reads the aim + curve ("Curve strike, aimed at
  the center, a modest curve bending left").
  **FAIL:** any of those silent or unlabeled.

---

## 2. Larger Text (AX sizes)

**Settings → Accessibility → Display & Text Size → Larger Text** → turn on
"Larger Accessibility Sizes" and drag the slider to the **maximum**.

- **Do:** open a basketball numpad scenario.
  **PASS:** the input cards and numpad get noticeably bigger; the dock **grows
  and scrolls** so SHOOT stays reachable; the court reframes **above** the dock.
  **FAIL (blocker):** the numpad keys overlap each other or sit on top of the
  court, or SHOOT is unreachable with no way to scroll to it. Report.
- **Do:** open the chapter list and the daily question.
  **PASS:** text gets big, rows reflow, and the screen **scrolls** — nothing is
  cut off mid-sentence with no way to reach it.
  **FAIL:** content is clipped/truncated with no scroll to reveal it.
- **Note (expected, not a bug):** big display titles (the giant Anton headlines,
  outcome verbs like "NAILED IT", the splash wordmark) grow only up to a capped
  size, then shrink-to-fit — that's intentional so posters don't explode. As
  long as nothing is *cut off*, that's a PASS.

---

## 3. Increase Contrast

**Settings → Accessibility → Display & Text Size → Increase Contrast** → on.

- **PASS:** grey captions across the app get noticeably **brighter** (the High
  Legibility palette switches on automatically); pure-white text softens a touch.
- **Do:** open the in-app Settings gear.
  **PASS:** the "High Legibility Text" toggle shows **on and locked**, with the
  note "ON VIA iOS INCREASE CONTRAST".
  **FAIL:** the toggle still shows off while the app clearly brightened (a lie),
  or nothing changed at all.

---

## 4. Reduce Motion

**Settings → Accessibility → Motion → Reduce Motion** → on.

- **Do:** cold-launch the app (swipe it away first, reopen).
  **PASS:** the splash just **fades in** — the wordmark doesn't slide up from
  below, the glow doesn't bloom.
  **FAIL:** the wordmark still rises / the glow still animates in.
- **Do:** land on Home.
  **PASS:** the cards **fade** in without sliding up.
- **Do:** start a basketball scenario.
  **PASS:** the player isn't endlessly bouncing a dribble — it holds still.
  Releasing the shot does **not** flash the whole screen white. The ball still
  flies (that's the physics — it should stay).
  **FAIL:** dribble loop still bounces, or the white flash still fires.
- **Do:** finish a scenario / answer the daily.
  **PASS:** the stat numbers and +IQ appear at their final value immediately,
  no count-up roll or slide.
- **Do:** open the Settings gear.
  **PASS:** "Reduce Motion" toggle shows on + locked, "ON VIA iOS REDUCE MOTION".

---

## 5. Differentiate Without Color / Grayscale

**Settings → Accessibility → Display & Text Size → Color Filters → Grayscale**
(turn Color Filters on, pick Grayscale).

- **Do:** play through a hit and a miss, look at locked level types and the
  locked SOLUTION button.
  **PASS:** in pure greyscale you can **still tell** correct vs wrong (the words
  "NAILED IT" / "WRONG", spoken too), locked vs unlocked (a **lock glyph** +
  "AFTER ATTEMPT 3" in print, not just a colour), selected fields, etc.
  **FAIL:** any state you can only tell apart by colour (e.g. you genuinely
  can't tell a right answer from a wrong one in greyscale). Report it.

---

## 6. In-app Settings toggles (gear, top-right of Home)

- **High Legibility Text:** flip it.
  **PASS:** the SAMPLE block in Settings brightens **instantly**, and the rest
  of the app follows.
- **Reduce Motion:** flip it (with the iOS setting OFF).
  **PASS:** same motion-calming as section 4, driven from the app.
- **Game Sound:** flip it off, play a scenario.
  **PASS:** no shot/result sounds. Flip on → sounds return.
- **Haptics:** flip it off, tap buttons / get a verdict.
  **PASS:** no taps/buzzes you can feel. Flip on → they return.
  **FAIL:** any toggle does nothing.

---

## 7. Voice Control (optional, no extra hardware)

**Settings → Accessibility → Voice Control** → on. Say "Show names".

- **PASS:** labels appear over buttons; "Tap Yes", "Tap Shoot", "Tap Next card"
  all work. Sliders respond to "Increase Launch angle".
  **FAIL:** a core control has no name overlay / can't be tapped by voice.

---

## Known limitations (NOT bugs — don't report these)

- **Bold Text** (Settings → Accessibility → Display & Text Size → Bold Text):
  the mono readouts bold, but the custom display fonts (Anton, Barlow) do **not**
  thicken — we don't yet remap them to a heavier face. Expected.
- **Switch Control:** rides on the same labels as VoiceOver, but properly
  testing it needs a switch/adaptive setup. If you don't have one, skip it.
- **Audio after backgrounding:** if you background the app mid-scenario and
  return, the ambient dribble loop may not resume until you navigate. Known,
  deferred (it's an audio-engine thing, not an accessibility gap).
- **Personal-team signing:** the app may stop launching after ~7 days — just
  re-run from Xcode.
