# Plan Audit

## Task

Task 000: Plan Audit.

## Result

The Orbisonic planning package is coherent enough to begin the guarded implementation sequence.

No blocking contradiction requires changing the audio contracts before Task 001.

## Findings

1. The UI freeze documents describe the desired transport as preserving the current transport, with examples that mention a combined Play/Stop control. The current copied app source exposes a compact icon transport row with Back, Play, Pause, and Forward; the `stop` enum case exists but is not in the visible `allCases` list. Task 001 should baseline the actual current source, not force a theoretical combined control.

2. The active implementation source lives in ``, while current instructions live in ``. The copied app repo still contains deprecated control files and dirty Git state from the restructuring. Implementation tasks should treat `project control` as current and avoid restoring deleted legacy root docs or launchers.

3. `AudioContracts` already contains some earlier shared contracts such as `SourceDescriptor`, `ConversionLedger`, and route/session formats. Task 002 should extend rather than replace those types unless a later task explicitly migrates existing call sites.

## Blocking Questions

None for Task 001.

## Non-Blocking Assumptions

- Static Swift source tests are acceptable for the first UI freeze guard because the current app has existing source-structure tests and no screenshot harness in the repo.
- The Pure Spherical Lossless badge can be absent in the initial baseline; tests should allow only that label as a future visible addition.
- Deprecated files in the copied app repo are reference material only.

## Recommended Corrections

- Add a UI baseline document that records the actual current screen, source, and transport structure.
- Add UI freeze tests before audio-contract implementation.
- Leave existing audio contract names intact and add the current contracts around them in later tasks.

## Verification

Task 001 adds the first executable verification for this audit: `ExistingUIFreezeTests`.
