///|
test "legacy caller compiles unchanged through generated shim" {
  let amount : Money = parse_amount("12.50", currency="CNY")
  assert_eq(amount, 5)
  assert_eq(parse_amount("3"), 1)
  assert_eq(encode(b"moon"), "4")
  let buffer = Buffer::new()
  Buffer::write(buffer, "payload")
  let crate_value : Crate[Int32] = Crate::{ value: 7, }
  let legacy_box : Box[Int32] = crate_value
  assert_eq(legacy_box.value, 7)
}
