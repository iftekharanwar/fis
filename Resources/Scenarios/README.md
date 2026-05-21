# Bundled Scenarios

This directory contains the scenario JSON files that ship inside the app
bundle. **Each file is a real, committed JSON** — no symlinks, no external
dependencies. Clone the `PhysicsGame/` repo on its own and it builds.

## Why inlined (and not symlinked)

The earlier convention used symlinks to a sibling `scenarios/` directory in
the parent `arclab/` docs folder. That worked locally but broke fresh
clones — the symlink target lived outside the git repo, so anyone pulling
`PhysicsGame/` saw `couldn't be opened because there is no such file`
(reproduced on 2026-05-21 when a teammate tried to open the repo).

The fix on 2026-05-21: replace each symlink with the actual scenario file
contents and commit them as regular files. The `PhysicsGame/` repo is now
self-contained.

## Authoring or updating a scenario

The authoritative human-authored version still lives in the parent docs
directory (`~/Desktop/arclab/scenarios/{scenario-id}.json`) for voice review
and schema audit. After editing there, **copy** (don't symlink) the new
content into this directory:

```
cp ~/Desktop/arclab/scenarios/{scenario-id}.json \
   PhysicsGame/Resources/Scenarios/{scenario-id}.json
```

Then commit the updated bundled copy in the same change as any code that
depends on the new content.

### Adding a brand-new scenario

1. Author it at `~/Desktop/arclab/scenarios/{scenario-id}.json`. Voice-review
   against the CONCEPT doc; verify against `SCENARIO_ENGINE_SPEC.md` schema.
2. Copy into this directory (see above).
3. Regenerate the Xcode project so the new resource is picked up:
   ```
   cd PhysicsGame && xcodegen generate
   ```
4. CI smoke-test gate loads the scenario and asserts the declared
   `smokeTest.answer` produces the `expectedOutcome` and `expectedFlavor`.

## What this means for the design docs

The docs in `~/Desktop/arclab/` stay outside the repo intentionally — they
hold lesson copy, scenario drafts, design rationale, and other long-form
material that isn't part of the shipped app. The bundled `.json` files here
are the **inlined snapshot** of the doc-side authoritative file at the time
the code change was committed.

Manual `cp` drift is the tradeoff: easier onboarding for new clones, but
you must remember to re-copy when scenarios change. Light-touch CI script
to diff bundled vs. doc-side and warn on drift is a TODO.
