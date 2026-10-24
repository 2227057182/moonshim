# Migration rules

MoonShim accepts a small JSON document:

```json
{
  "version": 1,
  "renames": [
    {
      "kind": "function",
      "from": "old_public_name",
      "to": "new_public_name"
    }
  ]
}
```

## Supported kinds

| `kind` | Meaning |
| --- | --- |
| `function` | Free function or method such as `Type::method` |
| `type` | Public type alias |
| `struct` | Public struct rename |
| `enum` | Public enum rename |

`trait` and `value` are recognized by the rule parser but are always reported
for manual review in this release.

## Method names

Use the same qualified name shown in `.mbti`:

```json
{
  "kind": "function",
  "from": "Buffer::write",
  "to": "Buffer::write_all"
}
```

## Rules are assertions, not guesses

A rule says that the maintainer has reviewed the rename. MoonShim still refuses
to generate a wrapper if callable shapes differ.

Examples that are blocked:

- `Int` changes to `Double`;
- an error type changes;
- a required parameter is added;
- an optional default changes;
- a struct field changes;
- a method moves to another receiver.

These cases need a hand-written adapter or a source migration.
