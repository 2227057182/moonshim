///|
fn is_digit_char(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_identifier_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn is_identifier_char(ch : Char) -> Bool {
  is_identifier_start(ch) || is_digit_char(ch) || ch == ':'
}

///|
fn is_type_identifier_char(ch : Char) -> Bool {
  is_identifier_start(ch) || is_digit_char(ch)
}

///|
fn canonicalize_types(text : StringView) -> String {
  let builder = StringBuilder()
  let token = StringBuilder()
  for ch in text {
    if is_type_identifier_char(ch) {
      token.write_char(ch)
    } else {
      if !token.is_empty() {
        let value = token.to_string()
        match value {
          "Int" => builder.write_string("Int32")
          "UInt" => builder.write_string("UInt32")
          _ => builder.write_string(value)
        }
        token.reset()
      }
      builder.write_char(ch)
    }
  }
  if !token.is_empty() {
    let value = token.to_string()
    match value {
      "Int" => builder.write_string("Int32")
      "UInt" => builder.write_string("UInt32")
      _ => builder.write_string(value)
    }
  }
  builder.to_string()
}

///|
fn find_char(text : StringView, target : Char, start : Int32) -> Int32? {
  for index, ch in text.iter2() {
    if index >= start && ch == target {
      return Some(index)
    }
  }
  None
}

///|
fn substring(text : StringView, start : Int32, end : Int32) -> String {
  text.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn normalize_whitespace(text : StringView) -> String {
  let builder = StringBuilder()
  let mut pending_space = false
  for ch in text {
    if ch.is_whitespace() {
      if !builder.is_empty() {
        pending_space = true
      }
    } else {
      if pending_space {
        builder.write_char(' ')
        pending_space = false
      }
      builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn skip_balanced(
  text : StringView,
  start : Int32,
  open : Char,
  close : Char,
) -> Int32 {
  let mut index = start
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  while index < text.length() {
    let ch = text.get_char(index).unwrap()
    if in_string {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_string = false
      }
    } else if ch == '"' {
      in_string = true
    } else if ch == open {
      depth += 1
    } else if ch == close {
      depth -= 1
      if depth == 0 {
        return index + 1
      }
    }
    index += 1
  }
  text.length()
}

///|
fn find_matching_paren(text : StringView, open_index : Int32) -> Int32? {
  let end = skip_balanced(text, open_index, '(', ')')
  if end <= text.length() && end > open_index {
    Some(end - 1)
  } else {
    None
  }
}

///|
fn split_top_level(text : StringView) -> Array[String] {
  let result = []
  let mut start = 0
  let mut round = 0
  let mut square = 0
  let mut curly = 0
  let mut angle = 0
  let mut in_string = false
  let mut escaped = false
  for index, ch in text.iter2() {
    if in_string {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_string = false
      }
      continue
    }
    match ch {
      '"' => in_string = true
      '(' => round += 1
      ')' => round -= 1
      '[' => square += 1
      ']' => square -= 1
      '{' => curly += 1
      '}' => curly -= 1
      '<' => angle += 1
      '>' => angle -= 1
      ',' =>
        if round == 0 && square == 0 && curly == 0 && angle == 0 {
          result.push(substring(text, start, index).trim().to_owned())
          start = index + 1
        }
      _ => ()
    }
  }
  let tail = substring(text, start, text.length()).trim().to_owned()
  if !tail.is_empty() {
    result.push(tail)
  }
  result
}

///|
fn top_level_assignment_index(text : StringView) -> Int32? {
  let mut round = 0
  let mut square = 0
  let mut curly = 0
  let mut angle = 0
  for index, ch in text.iter2() {
    match ch {
      '(' => round += 1
      ')' => round -= 1
      '[' => square += 1
      ']' => square -= 1
      '{' => curly += 1
      '}' => curly -= 1
      '<' => angle += 1
      '>' => angle -= 1
      '=' =>
        if round == 0 && square == 0 && curly == 0 && angle == 0 {
          return Some(index)
        }
      _ => ()
    }
  }
  None
}

///|
fn declaration_depth_delta(text : StringView) -> Int32 {
  let mut delta = 0
  let mut in_string = false
  let mut escaped = false
  for ch in text {
    if in_string {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_string = false
      }
      continue
    }
    match ch {
      '"' => in_string = true
      '(' | '[' | '{' => delta += 1
      ')' | ']' | '}' => delta -= 1
      _ => ()
    }
  }
  delta
}

///|
fn json_escape(text : StringView) -> String {
  let builder = StringBuilder()
  for ch in text {
    match ch {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(ch)
    }
  }
  builder.to_string()
}
