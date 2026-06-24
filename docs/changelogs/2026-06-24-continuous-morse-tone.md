# 2026-06-24 - Continuous Morse tone

## Summary

- Replaced the short looped sound with a continuous generated tone.
- Added AVFoundation linking for the GUI executable.
- Updated the README wording for the GUI sound behavior.

## Tests

- Run `make gui` to compile the graphical executable.
- Run `./build/morse2text_gui` and hold the button for more than one second to verify the tone stays continuous.
