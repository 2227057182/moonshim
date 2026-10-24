# Changelog

## 0.1.1

- Preserve type parameters when generating compatibility aliases for renamed
  generic structs, enums, and type aliases.
- Reject renames whose generic arity differs.
- Add an end-to-end legacy consumer check for a renamed generic struct.
- Expand the suite to 16 automated tests.

## 0.1.0

- Add `.mbti` parsing for public functions, methods, aliases, structs, enums,
  traits, and values.
- Add conservative API change classification.
- Add explicit JSON rename rules.
- Generate compile-oriented function wrappers and type aliases.
- Add anonymous-parameter and `Self` receiver handling.
- Add Markdown, JSON, and strict CI exit modes.
- Add compile-and-run legacy fixture with 13 automated tests.
