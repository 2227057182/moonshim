///|
/// The kind of a public API declaration found in a generated `.mbti` file.
pub(all) enum SymbolKind {
  Function
  TypeAlias
  Struct
  Enum
  Trait
  Value
}

///|
/// How callers pass an argument to a MoonBit function.
pub(all) enum ParameterMode {
  Positional
  Optional
  Labelled
  Receiver
}

///|
/// A normalized function parameter extracted from a public interface.
pub(all) struct Parameter {
  name : String
  type_text : String
  mode : ParameterMode
  default_value : String?
}

///|
/// One public symbol extracted from a generated MoonBit interface.
pub(all) struct ApiSymbol {
  kind : SymbolKind
  name : String
  signature : String
  parameters : Array[Parameter]
  result_text : String
}

///|
/// A parsed package interface.
pub(all) struct ApiSnapshot {
  package_name : String
  symbols : Array[ApiSymbol]
}

///|
/// A compatibility finding produced by comparing two snapshots.
pub(all) enum ChangeKind {
  Added
  Removed
  Renamed
  SignatureChanged
  BodyChanged
}

///|
/// One actionable API change.
pub(all) struct ApiChange {
  change_kind : ChangeKind
  symbol_kind : SymbolKind
  old_name : String?
  new_name : String?
  old_signature : String?
  new_signature : String?
  safely_shimmable : Bool
  reason : String
}

///|
/// A user-authored mapping between an old and a new symbol name.
pub(all) struct MigrationRule {
  symbol_kind : SymbolKind
  old_name : String
  new_name : String
}

///|
/// Complete migration result consumed by both the CLI and library users.
pub(all) struct MigrationPlan {
  changes : Array[ApiChange]
  shim_sources : Array[String]
  diagnostics : Array[String]
}

///|
/// Errors produced while loading a migration rule file.
pub(all) suberror RuleError {
  RuleError(String)
}

///|
pub fn symbol_kind_name(kind : SymbolKind) -> String {
  match kind {
    Function => "function"
    TypeAlias => "type"
    Struct => "struct"
    Enum => "enum"
    Trait => "trait"
    Value => "value"
  }
}

///|
pub fn same_symbol_kind(left : SymbolKind, right : SymbolKind) -> Bool {
  match (left, right) {
    (Function, Function) => true
    (TypeAlias, TypeAlias) => true
    (Struct, Struct) => true
    (Enum, Enum) => true
    (Trait, Trait) => true
    (Value, Value) => true
    _ => false
  }
}

///|
pub fn same_parameter_mode(left : ParameterMode, right : ParameterMode) -> Bool {
  match (left, right) {
    (Positional, Positional) => true
    (Optional, Optional) => true
    (Labelled, Labelled) => true
    (Receiver, Receiver) => true
    _ => false
  }
}

///|
pub fn change_kind_name(kind : ChangeKind) -> String {
  match kind {
    Added => "added"
    Removed => "removed"
    Renamed => "renamed"
    SignatureChanged => "signature_changed"
    BodyChanged => "body_changed"
  }
}

///|
pub fn parameter_mode_name(mode : ParameterMode) -> String {
  match mode {
    Positional => "positional"
    Optional => "optional"
    Labelled => "labelled"
    Receiver => "receiver"
  }
}

///|
pub fn symbol_key(kind : SymbolKind, name : StringView) -> String {
  "\{symbol_kind_name(kind)}:\{name}"
}
