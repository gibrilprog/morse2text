# 2026-06-24 - Morse table README

## Summary

- Updated the README Morse table to match the grouped layout from the project sheet.
- Added extra spacing in the table so the Morse codes are easier to read in plain text.
- Added punctuation symbols to the Morse dictionary.

## Motivation

- The project sheet includes a more complete Morse table with letters, digits, and punctuation.
- The README should present the same information clearly and the code should support what the documentation shows.

## Tests

- Run `make test` to verify the Morse dictionary, text-to-Morse conversion, and Morse-to-text conversion with punctuation.

## Notes

- The project architecture did not need a major change for this update.
- The existing `MorseDictionary` remains the right place to centralize all supported characters.
