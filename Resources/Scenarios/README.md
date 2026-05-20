# Bundled Scenarios

This directory contains the scenario JSON files that ship inside the app
bundle. **Each file here is a symlink** to the authoritative version in the
project's parent docs directory:

```
PhysicsGame/Resources/Scenarios/bb-freethrow-001.json
   → ../../../scenarios/bb-freethrow-001.json
```

## Why symlinks

The scenario JSON is the contract between the design docs (where it's
human-authored and voice-reviewed) and the engine (where it's loaded and
simulated). Keeping two copies means manual `cp` drift; that's what tripped
up the smoke-test calibration on 2026-05-19.

Symlinks give us:

- **Single source of truth** — edits to the parent file propagate to the
  bundled copy without any tooling.
- **Xcode-friendly** — Xcode's resource pipeline follows symlinks at copy
  time, so the *contents* (not the link itself) end up in `.app/Resources/`.
  Verified with `xcrun simctl` + the runtime ScenarioLoader.
- **Git-friendly** — git stores the symlink as a symlink (one path string),
  not as a duplicate file.

## Authoring new scenarios

1. Create `~/Desktop/arclab/scenarios/{scenario-id}.json` in the parent docs
   directory. Voice-review against `CONCEPT.md` Voice doc; verify against
   `SCENARIO_ENGINE_SPEC.md` schema; run the smoke test mentally.
2. Symlink it into the bundle:
   ```
   cd PhysicsGame/Resources/Scenarios
   ln -s ../../../scenarios/{scenario-id}.json {scenario-id}.json
   ```
3. Regenerate Xcode project with XcodeGen so the new resource is picked up:
   ```
   cd PhysicsGame && xcodegen generate
   ```
4. Add a CI smoke-test gate that loads the scenario and asserts the declared
   `smokeTest.answer` produces the `expectedOutcome` and `expectedFlavor`.
