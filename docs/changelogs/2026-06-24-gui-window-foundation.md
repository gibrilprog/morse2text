# 2026-06-24 - GUI window foundation

## Summary

- Added a native macOS window for the first graphical prototype.
- Added a split layout with a left interaction area and an empty right transcription area.
- Added a hold button that stays visually pressed while the mouse click is held.
- Added the `make gui` target to build the graphical executable.
- Updated the default `make` and `make re` flow so the graphical executable is also generated.

## Motivation

- Morse2Text needs a first visual base before connecting real click timing to text transcription.

## Tests

- Run `make gui` to compile the graphical executable.
- Run `make re` to rebuild both the command-line executable and the graphical executable.
- Run `./build/morse2text_gui` and hold the button with the mouse to verify the pressed state.
- Run `make test` to ensure the existing translation logic still works.

## Notes

- The graphical executable is macOS-specific because it uses AppKit.
- The existing command-line executable remains available with `make`.
