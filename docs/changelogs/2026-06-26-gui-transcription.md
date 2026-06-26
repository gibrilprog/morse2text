# 2026-06-26 - GUI transcription

## Changes

- Connected the GUI hold button to `ClickInterpreter`.
- Added a Morse transcript in the top half of the right pane.
- Added decoded words in the bottom half of the right pane.
- Added Morse history storage to `ClickInterpreter` through `morse()`.
- Updated the GUI build target so it links the core Morse sources.
- Documented the active GUI transcription flow.

## Validation

- Run `make -B gui` to compile the graphical executable and linked core sources.
- Run `make -B test` to verify the interpreter and translator tests.
