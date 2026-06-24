# 2026-06-24 - Project foundation

## Summary

- Added the initial C++ project structure with `include`, `src`, `tests`, documentation, and a `Makefile`.
- Added the Morse dictionary, text-to-Morse conversion, Morse-to-text conversion, and click timing interpreter.
- Added a minimal command-line interface to test translation manually.

## Tests

- Run `make test` to compile and execute the unit tests.
- Run `./build/morse2text --text "SOS TEST"` to manually verify text-to-Morse conversion.
- Run `./build/morse2text --morse "... --- ... / - . ... -"` to manually verify Morse-to-text conversion.
