# MoonShim

**Compile-tested compatibility shims for evolving MoonBit APIs.**

MoonShim compares two generated `.mbti` interfaces and turns explicitly approved,
shape-compatible renames into a MoonBit compatibility layer. It also reports
breaking changes that need human review instead of guessing at their semantics.

The project is written primarily in MoonBit, runs without network access, and
uses a deterministic, fail-closed migration model.

## The problem

MoonBit and its package ecosystem are evolving quickly. A library upgrade may:

- rename a public function;
- rename a public type;
- change a parameter or return type;
- change a struct or enum shape;
- remove an API without an obvious replacement.

API checkers can expose these changes, but maintainers still have to write the
compatibility layer by hand. MoonShim prepares that layer and verifies it with an
end-to-end compilation fixture.

## What it does

1. Parses the public declarations in two `moon info` interfaces.
2. Normalizes function parameters, labels, defaults, results, and type bodies.
3. Classifies added, removed, renamed, and changed symbols.
4. Generates wrappers and type aliases only when an explicit rule maps two
   compatible public shapes.
5. Emits Markdown and JSON migration reports.
6. Fails closed when a change cannot be proved safe.

MoonShim deliberately does not infer business equivalence from a similar
signature. A rename must be declared by the maintainer.

## Quick start

Requirements: MoonBit 0.10.17 or newer and Node.js for the CLI target.

```bash
git clone <this-repository>
cd moonshim
moon update
moon check --deny-warn
moon test --deny-warn
```

Create two interface snapshots from the versions you want to compare:

```bash
git checkout <old-version>
moon info
cp pkg.generated.mbti ../old.mbti

git checkout <new-version>
moon info
cp pkg.generated.mbti ../new.mbti
```

Declare only the renames you have reviewed:

```json
{
  "version": 1,
  "renames": [
    { "kind": "function", "from": "parse_amount", "to": "parse_money" },
    { "kind": "type", "from": "Money", "to": "Cash" }
  ]
}
```

Generate a report and compatibility source:

```bash
moon run cmd/main -- diff old.mbti new.mbti \
  --rules renames.json \
  --markdown migration-report.md \
  --json migration-report.json \
  --shim compat_generated.mbt \
  --fail-on-breaking
```

`--fail-on-breaking` exits with status `2` if any change still requires manual
review. A partial shim may still be generated so that safe changes can proceed.

## Example output

```text
MoonShim: 0 added, 4 shimmable, 0 blocked, 4 shim declaration(s)
```

```mbt
pub fn parse_amount(
  input : StringView,
  currency~ : String = "CNY",
) -> Int32 raise {
  parse_money(input, currency~)
}

pub type Money = Cash
```

The repository's [compat fixture](compat_fixture/legacy_wbtest.mbt) keeps using
the old names. Regenerating the shim and running `moon test` proves that the old
consumer still compiles and runs.

## Three real use cases

**Library maintainer:** publish a major version while still allowing existing
consumers to compile for one migration cycle.

**Application maintainer:** inspect an upstream API change and obtain a reviewed
adapter instead of a list of compile errors.

**CI maintainer:** run MoonShim against release interfaces and require an
explicit rule or a reviewed breaking-change decision before merging.

## Safety model

A function rename is shimmable only when both sides have:

- the same number of parameters;
- the same parameter modes and public types;
- the same labels where labels affect callers;
- the same default values;
- the same result and raise clause.

A type rename is shimmable only for identical alias, struct, or enum bodies.
Traits, values, label renames, semantic changes, and body changes are reported
for manual implementation.

MoonShim never writes directly into a package unless the caller supplies
`--shim`. It does not edit arbitrary source files.

## Repository layout

```text
parser.mbt             .mbti parser and interface model
diff.mbt               conservative compatibility classification
rules.mbt              JSON migration rules
render.mbt             Markdown and JSON reports
cmd/main/              CLI
compat_fixture/        compile-time proof that generated shims work
fixtures/              old/new interfaces and reviewed rename rules
docs/                   architecture, rules, and submission material
scripts/                local end-to-end verification
```

See [Architecture](docs/architecture.md) and [Migration rules](docs/rules.md)
for the design boundaries.

## Verification

```bash
moon fmt --check
moon check --deny-warn
moon test --deny-warn
./scripts/e2e.sh
```

On Windows PowerShell:

```powershell
./scripts/e2e.ps1
```

The end-to-end script regenerates `compat_fixture/compat_generated.mbt`, verifies
that the generated file is stable under version control, and reruns the package
tests.

## Current limitations

- The parser targets declarations emitted by the current `moon info` format.
- Semantic equivalence is a maintainer decision, not an automated inference.
- The first release supports explicit function and type renames.
- Trait implementations, operators, and general-purpose codemods are roadmap
  items.

## License

Apache-2.0. See [LICENSE](LICENSE).
