///|
fn same_function_shape(old : ApiSymbol, new : ApiSymbol) -> Bool {
  if old.parameters.length() != new.parameters.length() {
    return false
  }
  for index, old_parameter in old.parameters {
    let new_parameter = new.parameters[index]
    if !same_parameter_mode(old_parameter.mode, new_parameter.mode) ||
      old_parameter.type_text != new_parameter.type_text ||
      old_parameter.default_value != new_parameter.default_value {
      return false
    }
    if (
        same_parameter_mode(old_parameter.mode, Optional) ||
        same_parameter_mode(old_parameter.mode, Labelled)
      ) &&
      old_parameter.name != new_parameter.name {
      return false
    }
  }
  old.result_text == new.result_text
}

///|
fn same_type_body(old : ApiSymbol, new : ApiSymbol) -> Bool {
  same_symbol_kind(old.kind, new.kind) &&
  (
    same_symbol_kind(old.kind, TypeAlias) ||
    same_symbol_kind(old.kind, Struct) ||
    same_symbol_kind(old.kind, Enum)
  ) &&
  type_body(old) == type_body(new) &&
  !type_body(old).is_empty()
}

///|
fn find_rule(
  rules : Array[MigrationRule],
  kind : SymbolKind,
  old_name : String,
) -> MigrationRule? {
  for rule in rules {
    if same_symbol_kind(rule.symbol_kind, kind) && rule.old_name == old_name {
      return Some(rule)
    }
  }
  None
}

///|
fn candidate_target(added : Array[ApiSymbol], old : ApiSymbol) -> ApiSymbol? {
  for symbol in added {
    if !same_symbol_kind(symbol.kind, old.kind) {
      continue
    }
    if old.kind is Function && same_function_shape(old, symbol) {
      return Some(symbol)
    }
    if same_type_body(old, symbol) {
      return Some(symbol)
    }
  }
  None
}

///|
fn function_call_arguments(parameters : Array[Parameter]) -> String {
  let builder = StringBuilder()
  for index, parameter in parameters {
    if index > 0 {
      builder.write_string(", ")
    }
    match parameter.mode {
      Optional | Labelled => builder.write_string("\{parameter.name}~")
      Positional | Receiver => builder.write_string(parameter.name)
    }
  }
  builder.to_string()
}

///|
fn format_parameter(parameter : Parameter) -> String {
  match parameter.mode {
    Receiver => "self : \{canonicalize_types(parameter.type_text)}"
    Optional =>
      match parameter.default_value {
        Some(default) =>
          "\{parameter.name}~ : \{canonicalize_types(parameter.type_text)} = \{default}"
        None =>
          "\{parameter.name}~ : \{canonicalize_types(parameter.type_text)}"
      }
    Labelled =>
      match parameter.default_value {
        Some(default) =>
          "\{parameter.name}~ : \{canonicalize_types(parameter.type_text)} = \{default}"
        None =>
          "\{parameter.name}~ : \{canonicalize_types(parameter.type_text)}"
      }
    Positional =>
      "\{parameter.name} : \{canonicalize_types(parameter.type_text)}"
  }
}

///|
fn parameterized_signature(symbol : ApiSymbol) -> String {
  let (open_index, close_index) = match
    function_paren_range(symbol.signature, symbol.name) {
    Some(range) => range
    None => return symbol.signature
  }
  let builder = StringBuilder()
  builder.write_string(
    canonicalize_types(substring(symbol.signature, 0, open_index + 1)),
  )
  if symbol.parameters.length() > 1 {
    builder.write_char('\n')
    for parameter in symbol.parameters {
      builder.write_string("  \{format_parameter(parameter)},\n")
    }
  } else if symbol.parameters.length() == 1 {
    builder.write_string(format_parameter(symbol.parameters[0]))
  }
  builder.write_string(
    canonicalize_types(
      substring(symbol.signature, close_index, symbol.signature.length()),
    ),
  )
  builder.to_string()
}

///|
fn generate_function_shim(old : ApiSymbol, new : ApiSymbol) -> String {
  let args = function_call_arguments(old.parameters)
  "///|\n\{parameterized_signature(old)} {\n  \{new.name}(\{args})\n}\n"
}

///|
fn generate_type_shim(old : ApiSymbol, new : ApiSymbol) -> String {
  "///|\npub type \{old.name} = \{new.name}\n"
}

///|
fn add_rename_change(
  changes : Array[ApiChange],
  shims : Array[String],
  old : ApiSymbol,
  new : ApiSymbol,
) -> Unit {
  let compatible = if old.kind is Function {
    same_function_shape(old, new)
  } else {
    same_type_body(old, new)
  }
  let reason = if compatible {
    "Explicit rename rule maps APIs with compatible public shapes."
  } else {
    "Explicit rename rule exists, but parameter, result, or type body shapes differ."
  }
  changes.push(ApiChange::{
    change_kind: Renamed,
    symbol_kind: old.kind,
    old_name: Some(old.name),
    new_name: Some(new.name),
    old_signature: Some(old.signature),
    new_signature: Some(new.signature),
    safely_shimmable: compatible,
    reason,
  })
  if compatible {
    match old.kind {
      Function => shims.push(generate_function_shim(old, new))
      TypeAlias | Struct | Enum => shims.push(generate_type_shim(old, new))
      _ => ()
    }
  }
}

///|
/// Compares two public interfaces and creates a conservative migration plan.
pub fn plan_migration(
  old : ApiSnapshot,
  new : ApiSnapshot,
  rules : Array[MigrationRule],
) -> MigrationPlan {
  let changes = []
  let shims = []
  let diagnostics = []
  let mapped_targets : Map[String, Bool] = Map([])
  let old_keys : Map[String, Bool] = Map([])
  for old_symbol in old.symbols {
    old_keys.set(symbol_key(old_symbol.kind, old_symbol.name), true)
  }
  for old_symbol in old.symbols {
    match find_symbol(new, old_symbol.kind, old_symbol.name) {
      Some(new_symbol) =>
        if old_symbol.signature != new_symbol.signature {
          changes.push(ApiChange::{
            change_kind: SignatureChanged,
            symbol_kind: old_symbol.kind,
            old_name: Some(old_symbol.name),
            new_name: Some(new_symbol.name),
            old_signature: Some(old_symbol.signature),
            new_signature: Some(new_symbol.signature),
            safely_shimmable: false,
            reason: "The public declaration changed under the same name; review semantics before adding a wrapper.",
          })
        }
      None =>
        match find_rule(rules, old_symbol.kind, old_symbol.name) {
          Some(rule) =>
            match find_symbol(new, old_symbol.kind, rule.new_name) {
              Some(new_symbol) => {
                add_rename_change(changes, shims, old_symbol, new_symbol)
                mapped_targets.set(
                  symbol_key(new_symbol.kind, new_symbol.name),
                  true,
                )
              }
              None =>
                changes.push(ApiChange::{
                  change_kind: Removed,
                  symbol_kind: old_symbol.kind,
                  old_name: Some(old_symbol.name),
                  new_name: Some(rule.new_name),
                  old_signature: Some(old_symbol.signature),
                  new_signature: None,
                  safely_shimmable: false,
                  reason: "A rename rule targets a symbol that does not exist in the new interface.",
                })
            }
          None =>
            changes.push(ApiChange::{
              change_kind: Removed,
              symbol_kind: old_symbol.kind,
              old_name: Some(old_symbol.name),
              new_name: None,
              old_signature: Some(old_symbol.signature),
              new_signature: None,
              safely_shimmable: false,
              reason: "Removed API has no explicit migration rule.",
            })
        }
    }
  }
  for new_symbol in new.symbols {
    let key = symbol_key(new_symbol.kind, new_symbol.name)
    if old_keys.contains(key) || mapped_targets.contains(key) {
      continue
    }
    changes.push(ApiChange::{
      change_kind: Added,
      symbol_kind: new_symbol.kind,
      old_name: None,
      new_name: Some(new_symbol.name),
      old_signature: None,
      new_signature: Some(new_symbol.signature),
      safely_shimmable: true,
      reason: "Additive public API.",
    })
  }

  let removed = changes.filter(change => change.change_kind is Removed)
  let added = changes.filter(change => change.change_kind is Added)
  if !removed.is_empty() && !added.is_empty() {
    for change in removed {
      if change.old_name is Some(old_name) {
        let old_symbol = find_symbol(old, change.symbol_kind, old_name)
        if old_symbol is Some(symbol) {
          let added_symbols = added
            .filter(entry => entry.new_name is Some(_))
            .map(entry => {
              let name = entry.new_name.unwrap()
              find_symbol(new, entry.symbol_kind, name).unwrap()
            })
          if candidate_target(added_symbols, symbol) is Some(candidate) {
            diagnostics.push(
              "Candidate rename for `\{symbol.name}` -> `\{candidate.name}`. Add an explicit rule to generate a verified shim.",
            )
          }
        }
      }
    }
  }
  MigrationPlan::{ changes, shim_sources: shims, diagnostics, }
}

///|
pub fn has_unresolved_breaking_changes(plan : MigrationPlan) -> Bool {
  for change in plan.changes {
    if !change.safely_shimmable && !(change.change_kind is Added) {
      return true
    }
  }
  false
}
