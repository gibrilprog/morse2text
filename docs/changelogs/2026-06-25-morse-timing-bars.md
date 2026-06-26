# 2026-06-25 - Morse timing bars

## Changes

- Updated click timing defaults to target 200 ms for dots and 500 ms for dashes.
- Updated the letter gap timing to 1000 ms and the word gap timing to 2000 ms.
- Updated the GUI button area with an appui timer from 0 to 0.5 second, including a 0.2 second marker.
- Added an inactivity countdown bar labelled "Temps restant avant fin de mot".
- Updated the README timing and GUI documentation.

## Validation

- Run `make gui` to compile the graphical executable.
- Run `make test` to verify the interpreter and translation tests.
