///|
let old_interface =
  #|// Generated using `moon info`, DON'T EDIT IT
  #|package "example/money"
  #|
  #|pub fn parse_amount(input : StringView, currency? : String = "CNY") -> Int raise
  #|pub fn encode_amount(value : Int) -> String
  #|pub type Money = Int
  #|
  #|pub struct Account {
  #|  balance : Int
  #|} derive(Show)

///|
let new_interface =
  #|// Generated using `moon info`, DON'T EDIT IT
  #|package "example/money"
  #|
  #|pub fn parse_money(input : StringView, currency? : String = "CNY") -> Int raise
  #|pub fn encode_amount(value : Double) -> String
  #|pub type Cash = Int
  #|pub fn format_money(value : Int) -> String
  #|
  #|pub struct Account {
  #|  balance : Int
  #|} derive(Show)

///|
test "parse interface records public declarations" {
  let snapshot = @moonshim.parse_interface(old_interface)
  assert_eq(snapshot.package_name, "example/money")
  assert_eq(snapshot.symbols.length(), 4)
  let parse = @moonshim.find_symbol(
    snapshot,
    @moonshim.Function,
    "parse_amount",
  ).unwrap()
  assert_eq(parse.parameters.length(), 2)
  assert_eq(parse.parameters[0].name, "input")
  assert_eq(parse.parameters[1].name, "currency")
  assert_true(parse.parameters[1].mode is @moonshim.Optional)
  assert_eq(parse.parameters[1].default_value.unwrap(), "\"CNY\"")
  assert_eq(parse.result_text, "-> Int raise")
}

///|
test "rules JSON is parsed and rendered" {
  let source =
    #|{
    #|  "version": 1,
    #|  "renames": [
    #|    { "kind": "function", "from": "parse_amount", "to": "parse_money" },
    #|    { "kind": "type", "from": "Money", "to": "Cash" }
    #|  ]
    #|}
  let rules = @moonshim.rules_from_json(source)
  assert_eq(rules.length(), 2)
  assert_eq(rules[0].old_name, "parse_amount")
  assert_eq(rules[1].new_name, "Cash")
  let round_trip = @moonshim.rules_to_json(rules)
  assert_true(round_trip.contains("parse_amount"))
  assert_true(round_trip.contains("\"kind\": \"type\""))
}

///|
test "safe renames generate compile-oriented wrappers" {
  let rules_source =
    #|{"renames":[
    #|  {"kind":"function","from":"parse_amount","to":"parse_money"},
    #|  {"kind":"type","from":"Money","to":"Cash"}
    #|]}
  let rules = @moonshim.rules_from_json(rules_source)
  let plan = @moonshim.plan_migration(
    @moonshim.parse_interface(old_interface),
    @moonshim.parse_interface(new_interface),
    rules,
  )
  assert_eq(plan.shim_sources.length(), 2)
  let source = @moonshim.render_shim_source(plan)
  assert_true(source.contains("currency~ : String = \"CNY\","))
  assert_true(source.contains("-> Int32 raise {"))
  assert_true(source.contains("parse_money(input, currency~)"))
  assert_true(source.contains("pub type Money = Cash"))
}

///|
test "same-name signature changes block migration" {
  let previous =
    #|package "example/api"
    #|pub fn encode(value : Int) -> String
  let current =
    #|package "example/api"
    #|pub fn encode(value : Double) -> String
  let plan = @moonshim.plan_migration(
    @moonshim.parse_interface(previous),
    @moonshim.parse_interface(current),
    [],
  )
  assert_true(@moonshim.has_unresolved_breaking_changes(plan))
  assert_eq(plan.changes.length(), 1)
  assert_true(plan.changes[0].change_kind is @moonshim.SignatureChanged)
}

///|
test "incompatible rename remains explicit and blocked" {
  let previous =
    #|package "example/api"
    #|pub fn encode(value : Int) -> String
  let current =
    #|package "example/api"
    #|pub fn render(value : Int) -> Int
  let rules = [
    @moonshim.MigrationRule::{
      symbol_kind: @moonshim.Function,
      old_name: "encode",
      new_name: "render",
    },
  ]
  let plan = @moonshim.plan_migration(
    @moonshim.parse_interface(previous),
    @moonshim.parse_interface(current),
    rules,
  )
  assert_true(@moonshim.has_unresolved_breaking_changes(plan))
  assert_eq(plan.shim_sources.length(), 0)
  assert_true(plan.changes[0].change_kind is @moonshim.Renamed)
}

///|
test "additive changes are safe without shims" {
  let previous =
    #|package "example/api"
    #|pub fn stable() -> Int
  let current =
    #|package "example/api"
    #|pub fn stable() -> Int
    #|pub fn added(value : Int) -> Int
  let plan = @moonshim.plan_migration(
    @moonshim.parse_interface(previous),
    @moonshim.parse_interface(current),
    [],
  )
  assert_false(@moonshim.has_unresolved_breaking_changes(plan))
  assert_eq(plan.shim_sources.length(), 0)
}

///|
test "machine report is stable JSON" {
  let plan = @moonshim.plan_migration(
    @moonshim.parse_interface(old_interface),
    @moonshim.parse_interface(new_interface),
    [],
  )
  let report = @moonshim.render_json(plan, "old.mbti", "new.mbti")
  assert_true(report.contains("\"schema_version\": 1"))
  assert_true(report.contains("\"review_required\": true"))
  assert_true(@json.valid(report))
}
