///|
test "balanced scanner ignores delimiters inside strings" {
  let source =
    #|pub fn f(value? : String = "[x, y]") -> Unit
  let start = find_char(source, '(', 0).unwrap()
  let end = skip_balanced(source, start, '(', ')')
  assert_eq(source.get_char(end - 1).unwrap(), ')')
  assert_eq(substring(source, end, source.length()).trim(), "-> Unit")
}

///|
test "top-level splitting keeps generic and array commas" {
  let parts = split_top_level(
    "a : Map[String, Int], b : (Int, String), c : Int",
  )
  assert_eq(parts.length(), 3)
  assert_eq(parts[0], "a : Map[String, Int]")
  assert_eq(parts[1], "b : (Int, String)")
}

///|
test "normalization collapses whitespace" {
  assert_eq(
    normalize_whitespace("pub  fn  f(\n  x : Int\n) -> Int"),
    "pub fn f( x : Int ) -> Int",
  )
}

///|
test "anonymous parameters receive stable synthetic names" {
  let interface =
    #|package "example/api"
    #|pub fn decode(Bytes, url_safe? : Bool) -> String
  let snapshot = parse_interface(interface)
  let symbol = find_symbol(snapshot, Function, "decode").unwrap()
  assert_eq(symbol.parameters[0].name, "arg0")
  assert_eq(symbol.parameters[1].name, "url_safe")
}

///|
test "method interfaces preserve receiver syntax" {
  let previous =
    #|package "example/api"
    #|pub fn Buffer::write(Self, StringView) -> Unit
  let current =
    #|package "example/api"
    #|pub fn Buffer::write_all(Self, StringView) -> Unit
  let rules = [
    MigrationRule::{
      symbol_kind: Function,
      old_name: "Buffer::write",
      new_name: "Buffer::write_all",
    },
  ]
  let plan = plan_migration(
    parse_interface(previous),
    parse_interface(current),
    rules,
  )
  let source = render_shim_source(plan)
  assert_true(
    source.contains(
      "pub fn Buffer::write(\n  self : Self,\n  arg1 : StringView,\n) -> Unit",
    ),
  )
  assert_true(source.contains("Buffer::write_all(self, arg1)"))
}
