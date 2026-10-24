# MoonShim migration report

- Old interface: `examples/blocked-old.mbti`
- New interface: `examples/blocked-new.mbti`
- Changes: 2
- Generated shims: 0
- Review required: true

## Changes

| Status | Kind | Old | New | Reason |
| --- | --- | --- | --- | --- |
| BLOCK | function | `encode` | — | Removed API has no explicit migration rule. |
| ADD | function | — | `render` | Additive public API. |
