///|
fn package_name_from_line(line : StringView) -> String? {
  let trimmed = line.trim()
  guard trimmed.has_prefix("package ") else { return None }
  let quoted = trimmed["package ".length():]
  let start = find_char(quoted, '"', 0)
  match start {
    Some(start) =>
      match find_char(quoted, '"', start + 1) {
        Some(end) => Some(substring(quoted, start + 1, end))
        None => None
      }
    None => None
  }
}

///|
fn public_declaration_kind(line : StringView) -> SymbolKind? {
  if line.has_prefix("pub fn") {
    Some(Function)
  } else if line.has_prefix("pub type ") {
    Some(TypeAlias)
  } else if line.has_prefix("pub struct ") ||
    line.has_prefix("pub(all) struct ") ||
    line.has_prefix("pub(open) struct ") {
    Some(Struct)
  } else if line.has_prefix("pub enum ") ||
    line.has_prefix("pub(all) enum ") ||
    line.has_prefix("pub(open) enum ") {
    Some(Enum)
  } else if line.has_prefix("pub trait ") || line.has_prefix("pub(open) trait ") {
    Some(Trait)
  } else if line.has_prefix("pub let ") || line.has_prefix("pub const ") {
    Some(Value)
  } else {
    None
  }
}

///|
fn read_identifier(text : StringView, start : Int32) -> (String, Int32) {
  let builder = StringBuilder()
  let mut index = start
  while index < text.length() {
    let ch = text.get_char(index).unwrap()
    if is_identifier_char(ch) {
      builder.write_char(ch)
      index += 1
    } else {
      break
    }
  }
  (builder.to_string(), index)
}

///|
fn skip_space(text : StringView, start : Int32) -> Int32 {
  let mut index = start
  while index < text.length() {
    let ch = text.get_char(index).unwrap()
    if ch.is_whitespace() {
      index += 1
    } else {
      break
    }
  }
  index
}

///|
fn symbol_name_and_rest(
  text : StringView,
  marker : String,
) -> (String, String, Int32)? {
  let marker_index = match text.find(marker) {
    Some(index) => index
    None => return None
  }
  let mut index = skip_space(text, marker_index + marker.length())
  if marker == "fn" && index < text.length() {
    let ch = text.get_char(index).unwrap()
    if ch == '[' {
      index = skip_balanced(text, index, '[', ']')
      index = skip_space(text, index)
    }
  }
  let (name, name_end) = read_identifier(text, index)
  guard !name.is_empty() else { return None }
  let rest = substring(text, name_end, text.length()).trim().to_owned()
  Some((name, rest, name_end))
}

///|
fn type_body(symbol : ApiSymbol) -> String {
  match symbol.kind {
    TypeAlias =>
      match find_char(symbol.signature, '=', 0) {
        Some(index) =>
          substring(symbol.signature, index + 1, symbol.signature.length())
          .trim()
          .to_owned()
        None => ""
      }
    Struct | Enum | Trait =>
      match find_char(symbol.signature, '{', 0) {
        Some(index) =>
          substring(symbol.signature, index, symbol.signature.length())
          .trim()
          .to_owned()
        None => ""
      }
    _ => ""
  }
}

///|
fn strip_mode_suffix(text : StringView) -> (String, ParameterMode) {
  let trimmed = text.trim()
  if trimmed.has_suffix("?") {
    (substring(trimmed, 0, trimmed.length() - 1).trim().to_owned(), Optional)
  } else if trimmed.has_suffix("~") {
    (substring(trimmed, 0, trimmed.length() - 1).trim().to_owned(), Labelled)
  } else if trimmed == "self" {
    ("self", Receiver)
  } else {
    (trimmed.to_owned(), Positional)
  }
}

///|
fn parse_parameter(
  raw : StringView,
  index : Int32,
  is_method : Bool,
) -> Parameter? {
  let text = raw.trim()
  if text.is_empty() {
    return None
  }
  if text == "self" {
    return Some(Parameter::{
      name: "self",
      type_text: "",
      mode: Receiver,
      default_value: None,
    })
  }
  match find_char(text, ':', 0) {
    Some(colon) => {
      let name_view = text[0:colon].trim()
      let type_view = text[colon + 1:].trim()
      let (name, mode) = strip_mode_suffix(name_view)
      let (type_text, default_value) = match
        top_level_assignment_index(type_view) {
        Some(index) =>
          (
            substring(type_view, 0, index).trim().to_owned(),
            Some(
              substring(type_view, index + 1, type_view.length())
              .trim()
              .to_owned(),
            ),
          )
        None => (type_view.to_owned(), None)
      }
      Some(Parameter::{ name, type_text, mode, default_value, })
    }
    None =>
      if is_method && index == 0 && text == "Self" {
        Some(Parameter::{
          name: "self",
          type_text: "Self",
          mode: Receiver,
          default_value: None,
        })
      } else {
        Some(Parameter::{
          name: "arg\{index}",
          type_text: text.to_owned(),
          mode: Positional,
          default_value: None,
        })
      }
  }
}

///|
fn function_paren_range(
  signature : StringView,
  name : StringView,
) -> (Int32, Int32)? {
  let name_index = match signature.find(name) {
    Some(index) => index
    None => return None
  }
  let open_index = match find_char(signature, '(', name_index + name.length()) {
    Some(index) => index
    None => return None
  }
  let close_index = match find_matching_paren(signature, open_index) {
    Some(index) => index
    None => return None
  }
  Some((open_index, close_index))
}

///|
fn function_parameters(
  signature : StringView,
  name : StringView,
) -> Array[Parameter] {
  let (open_index, close_index) = match function_paren_range(signature, name) {
    Some(range) => range
    None => return []
  }
  let inner = signature[open_index + 1:close_index]
  let result = []
  let is_method = name.contains("::")
  for index, raw in split_top_level(inner) {
    if parse_parameter(raw, index, is_method) is Some(parameter) {
      result.push(parameter)
    }
  }
  result
}

///|
fn function_result(signature : StringView, name : StringView) -> String {
  let (_open_index, close_index) = match function_paren_range(signature, name) {
    Some(range) => range
    None => return ""
  }
  substring(signature, close_index + 1, signature.length()).trim().to_owned()
}

///|
fn parse_symbol(declaration : StringView) -> ApiSymbol? {
  let line = declaration.trim()
  let kind = match public_declaration_kind(line) {
    Some(kind) => kind
    None => return None
  }
  let marker = match kind {
    Function => "fn"
    TypeAlias => "type"
    Struct => "struct"
    Enum => "enum"
    Trait => "trait"
    Value => if line.has_prefix("pub let") { "let" } else { "const" }
  }
  let (name, _rest, _name_end) = match symbol_name_and_rest(line, marker) {
    Some(value) => value
    None => return None
  }
  let signature = normalize_whitespace(line)
  let parameters = match kind {
    Function => function_parameters(signature, name)
    _ => []
  }
  let result_text = match kind {
    Function => function_result(signature, name)
    _ => ""
  }
  Some(ApiSymbol::{ kind, name, signature, parameters, result_text, })
}

///|
/// Parses the stable declaration subset emitted by `moon info`.
///
/// Only public functions, type aliases, structs, enums, traits and values are
/// retained. Documentation and implementation details are intentionally omitted.
pub fn parse_interface(source : StringView) -> ApiSnapshot {
  let lines = source.split("\n").to_array()
  let mut package_name = ""
  let symbols = []
  let current = StringBuilder()
  let mut depth = 0
  let mut collecting = false
  for raw_line in lines {
    let line = raw_line.trim()
    if package_name.is_empty() {
      if package_name_from_line(line) is Some(name) {
        package_name = name
      }
    }
    if !collecting {
      if public_declaration_kind(line) is Some(_) {
        current.write_stringview(normalize_whitespace(line))
        depth = declaration_depth_delta(line)
        collecting = true
        if depth <= 0 {
          if parse_symbol(current.to_string()) is Some(symbol) {
            symbols.push(symbol)
          }
          current.reset()
          collecting = false
          depth = 0
        }
      }
    } else {
      current.write_char(' ')
      current.write_stringview(normalize_whitespace(line))
      depth += declaration_depth_delta(line)
      if depth <= 0 {
        if parse_symbol(current.to_string()) is Some(symbol) {
          symbols.push(symbol)
        }
        current.reset()
        collecting = false
        depth = 0
      }
    }
  }
  if collecting && parse_symbol(current.to_string()) is Some(symbol) {
    symbols.push(symbol)
  }
  ApiSnapshot::{ package_name, symbols, }
}

///|
pub fn find_symbol(
  snapshot : ApiSnapshot,
  kind : SymbolKind,
  name : StringView,
) -> ApiSymbol? {
  for symbol in snapshot.symbols {
    if same_symbol_kind(symbol.kind, kind) && symbol.name == name.to_owned() {
      return Some(symbol)
    }
  }
  None
}
