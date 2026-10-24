///|
pub fn parse_money(
  input : StringView,
  currency~ : String = "CNY",
) -> Int32 raise {
  ignore(currency)
  if input.is_empty() {
    raise Failure("empty amount")
  }
  input.length()
}

///|
pub fn stable(value : Int32) -> Int32 {
  value + 1
}

///|
pub type Cash = Int32

///|
pub fn encode_bytes(value : Bytes) -> String {
  value.length().to_string()
}

///|
pub struct Buffer {
  value : String
}

///|
pub fn Buffer::new() -> Self {
  { value: "", }
}

///|
pub fn Buffer::write_all(self : Self, value : StringView) -> Unit {
  ignore(self)
  ignore(value)
}

///|
#warnings("-struct_never_constructed")
pub struct Crate[T] {
  value : T
}
