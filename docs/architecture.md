# Architecture

MoonShim is split into a deterministic library and a thin filesystem CLI.

## Pipeline

```text
old.mbti ─┐
          ├─ parse_interface ─ compare ─ MigrationPlan ─ Markdown
new.mbti ─┘                           │                 JSON
                                      └─ shim.mbt
rules.json ─ rules_from_json ─────────┘
```

### Interface model

`parse_interface` keeps only public declarations emitted by `moon info`.
Documentation and implementation details do not participate in comparison.

The parser tracks delimiter depth so multiline structs and long function
signatures remain one declaration. It ignores braces and brackets inside quoted
text.

### Compatibility model

`plan_migration` compares symbols by public kind and name. Removed symbols are
matched to new symbols only through an explicit `MigrationRule`.

The generator produces source for two conservative cases:

1. Functions with identical callable shapes.
2. Type aliases, structs, or enums with identical bodies.

Everything else produces a blocked finding.

### Generation invariants

- A generated function wrapper preserves the old public signature.
- Anonymous parameters receive stable names (`arg0`, `arg1`, ...).
- The first `Self` parameter of a method becomes the receiver `self`.
- Optional and labelled arguments are forwarded with named-argument syntax.
- A type rename becomes a public alias.
- Generated output is deterministic and contains no timestamps.

## Why fail closed

Two functions can have the same type and still implement different behavior.
Silently inventing semantic equivalence is unsafe. MoonShim therefore requires
an explicit rename rule and produces code only for mechanically compatible
shapes.

## Verification

The `compat_fixture` package maintains a legacy caller that uses old names.
`compat_generated.mbt` is produced by the CLI. The normal MoonBit test suite
compiles the fixture, and the end-to-end script checks that regeneration is
stable.
