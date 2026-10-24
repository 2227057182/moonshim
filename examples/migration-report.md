# MoonShim migration report

- Old interface: `fixtures/old.mbti`
- New interface: `fixtures/new.mbti`
- Changes: 4
- Generated shims: 4
- Review required: false

## Changes

| Status | Kind | Old | New | Reason |
| --- | --- | --- | --- | --- |
| SHIM | function | `parse_amount` | `parse_money` | Explicit rename rule maps APIs with compatible public shapes. |
| SHIM | type | `Money` | `Cash` | Explicit rename rule maps APIs with compatible public shapes. |
| SHIM | function | `encode` | `encode_bytes` | Explicit rename rule maps APIs with compatible public shapes. |
| SHIM | function | `Buffer::write` | `Buffer::write_all` | Explicit rename rule maps APIs with compatible public shapes. |

## Generated shims

```mbt
///|
pub fn parse_amount(
  input : StringView,
  currency~ : String = "CNY",
) -> Int32 raise {
  parse_money(input, currency~)
}
///|
pub type Money = Cash
///|
pub fn encode(arg0 : Bytes) -> String {
  encode_bytes(arg0)
}
///|
pub fn Buffer::write(
  self : Self,
  arg1 : StringView,
) -> Unit {
  Buffer::write_all(self, arg1)
}
```
