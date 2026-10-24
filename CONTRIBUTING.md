# Contributing

## Development

```bash
moon update
moon fmt
moon check --deny-warn
moon test --deny-warn
./scripts/e2e.sh
```

The Windows equivalent is `./scripts/e2e.ps1`.

## Compatibility rule

Generated code is accepted only when the change is mechanically supportable.
Please add both a positive generation test and a blocked-change test for every
new classifier rule.

## Pull requests

- Keep generated files deterministic.
- Explain the public API shape being supported.
- Update `CHANGELOG.md` for user-visible changes.
- Do not add timestamps, machine paths, or network dependencies to generated
  output.
