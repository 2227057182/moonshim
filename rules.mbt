///|
fn rule_kind_from_string(value : StringView) -> SymbolKind? {
  match value {
    "function" => Some(Function)
    "type" | "type_alias" => Some(TypeAlias)
    "struct" => Some(Struct)
    "enum" => Some(Enum)
    "trait" => Some(Trait)
    "value" => Some(Value)
    _ => None
  }
}

///|
fn required_rule_string(
  fields : Map[String, Json],
  key : String,
) -> String raise RuleError {
  match fields.get(key) {
    Some(String(value)) => value
    Some(_) => raise RuleError("Rule field `\{key}` must be a string")
    None => raise RuleError("Rule is missing required field `\{key}`")
  }
}

///|
fn rule_from_json(value : Json) -> MigrationRule? raise RuleError {
  guard value is Object(fields) else {
    raise RuleError("Each rename rule must be a JSON object")
  }
  let old_name = required_rule_string(fields, "from")
  let new_name = required_rule_string(fields, "to")
  let kind_text = match fields.get("kind") {
    Some(String(kind)) => kind
    Some(_) => raise RuleError("Rule field `kind` must be a string")
    None => "function"
  }
  let symbol_kind = match rule_kind_from_string(kind_text) {
    Some(kind) => kind
    None => raise RuleError("Unsupported rule kind `\{kind_text}`")
  }
  Some(MigrationRule::{ symbol_kind, old_name, new_name, })
}

///|
/// Loads migration rules from the documented JSON format.
///
/// Example:
///
/// ```json
/// {
///   "version": 1,
///   "renames": [
///     { "kind": "function", "from": "parse_amount", "to": "parse_money" }
///   ]
/// }
/// ```
pub fn rules_from_json(
  source : StringView,
) -> Array[MigrationRule] raise RuleError {
  let document = @json.parse(source) catch {
    error => raise RuleError("Invalid rules JSON: \{error.to_string()}")
  }
  let entries = match document {
    Object(fields) =>
      match fields.get("renames") {
        Some(Array(values)) => values
        Some(_) => raise RuleError("`renames` must be an array")
        None => raise RuleError("Rules JSON must contain a `renames` array")
      }
    Array(values) => values
    _ => raise RuleError("Rules JSON must be an object or an array")
  }
  let result = []
  for entry in entries {
    if rule_from_json(entry) is Some(rule) {
      result.push(rule)
    }
  }
  result
}

///|
pub fn rules_to_json(rules : Array[MigrationRule]) -> String {
  let builder = StringBuilder()
  builder.write_string("{\n  \"version\": 1,\n  \"renames\": [")
  for index, rule in rules {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string(
      "\n    {\"kind\": \"\{symbol_kind_name(rule.symbol_kind)}\", \"from\": \"\{json_escape(rule.old_name)}\", \"to\": \"\{json_escape(rule.new_name)}\"}",
    )
  }
  if !rules.is_empty() {
    builder.write_string("\n  ")
  }
  builder.write_string("]\n}\n")
  builder.to_string()
}
