///|
suberror CliError {
  CliError(String)
}

///|
struct CliOptions {
  old_path : String
  new_path : String
  rules_path : String?
  markdown_path : String?
  json_path : String?
  shim_path : String?
  fail_on_breaking : Bool
}

///|
fn help_text() -> String {
  let text =
    #|MoonShim - compile-tested compatibility shims for MoonBit APIs
    #|
    #|USAGE
    #|  moon run cmd/main -- diff <old.mbti> <new.mbti> [OPTIONS]
    #|
    #|OPTIONS
    #|  --rules <path>             Load explicit rename rules from JSON
    #|  --markdown <path>          Write a Markdown migration report
    #|  --json <path>              Write a machine-readable JSON report
    #|  --shim <path>              Write generated MoonBit compatibility source
    #|  --fail-on-breaking         Exit with status 2 when review is required
    #|  --help                     Show this help
    #|
    #|Generate interfaces with:
    #|  moon info
    #|  cp pkg.generated.mbti old.mbti
  text
}

///|
fn require_next(
  args : ArrayView[String],
  index : Int32,
  flag : String,
) -> String raise CliError {
  if index + 1 >= args.length() {
    raise CliError("Missing value after \{flag}")
  }
  args[index + 1]
}

///|
fn parse_options(args : ArrayView[String]) -> CliOptions? raise CliError {
  let subcommand_index = match args.search("diff") {
    Some(index) => index
    None => {
      if args.contains("--help") || args.contains("-h") {
        println(help_text())
        return None
      }
      raise CliError(
        "Expected the `diff` subcommand. Run with `--help` for usage.",
      )
    }
  }
  let positionals = []
  let mut rules_path : String? = None
  let mut markdown_path : String? = None
  let mut json_path : String? = None
  let mut shim_path : String? = None
  let mut fail_on_breaking = false
  let mut index = subcommand_index + 1
  while index < args.length() {
    let arg = args[index]
    match arg {
      "--rules" | "-r" => {
        rules_path = Some(require_next(args, index, arg))
        index += 2
      }
      "--markdown" | "-m" => {
        markdown_path = Some(require_next(args, index, arg))
        index += 2
      }
      "--json" | "-j" => {
        json_path = Some(require_next(args, index, arg))
        index += 2
      }
      "--shim" | "-s" => {
        shim_path = Some(require_next(args, index, arg))
        index += 2
      }
      "--fail-on-breaking" => {
        fail_on_breaking = true
        index += 1
      }
      "--help" | "-h" => {
        println(help_text())
        return None
      }
      _ =>
        if arg.has_prefix("-") {
          raise CliError("Unknown option `\{arg}`")
        } else {
          positionals.push(arg)
          index += 1
        }
    }
  }
  if positionals.length() != 2 {
    raise CliError(
      "The `diff` command requires exactly two `.mbti` paths; received \{positionals.length()}.",
    )
  }
  Some(CliOptions::{
    old_path: positionals[0],
    new_path: positionals[1],
    rules_path,
    markdown_path,
    json_path,
    shim_path,
    fail_on_breaking,
  })
}

///|
fn load_rules(path : String?) -> Array[@moonshim.MigrationRule] raise {
  match path {
    Some(path) => {
      let source = @fs.read_file_to_string(path, encoding="utf8")
      @moonshim.rules_from_json(source)
    }
    None => []
  }
}

///|
fn print_plan_summary(plan : @moonshim.MigrationPlan) -> Unit {
  let mut added = 0
  let mut shimmed = 0
  let mut blocked = 0
  for change in plan.changes {
    if change.change_kind is @moonshim.Added {
      added += 1
    } else if change.safely_shimmable {
      shimmed += 1
    } else {
      blocked += 1
    }
  }
  println(
    "MoonShim: \{added} added, \{shimmed} shimmable, \{blocked} blocked, \{plan.shim_sources.length()} shim declaration(s)",
  )
}

///|
fn run(args : ArrayView[String]) -> Int32 raise {
  let options = match parse_options(args) {
    Some(options) => options
    None => return 0
  }
  let old_source = @fs.read_file_to_string(options.old_path, encoding="utf8")
  let new_source = @fs.read_file_to_string(options.new_path, encoding="utf8")
  let old_snapshot = @moonshim.parse_interface(old_source)
  let new_snapshot = @moonshim.parse_interface(new_source)
  let rules = load_rules(options.rules_path)
  let plan = @moonshim.plan_migration(old_snapshot, new_snapshot, rules)
  let markdown = @moonshim.render_markdown(
    plan,
    options.old_path,
    options.new_path,
  )
  let json = @moonshim.render_json(plan, options.old_path, options.new_path)
  print_plan_summary(plan)
  match options.markdown_path {
    Some(path) => @fs.write_string_to_file(path, markdown, encoding="utf8")
    None => println(markdown)
  }
  match options.json_path {
    Some(path) => @fs.write_string_to_file(path, json, encoding="utf8")
    None => ()
  }
  match options.shim_path {
    Some(path) => {
      let source = @moonshim.render_shim_source(plan)
      @fs.write_string_to_file(path, source, encoding="utf8")
    }
    None => ()
  }
  if options.fail_on_breaking && @moonshim.has_unresolved_breaking_changes(plan) {
    2
  } else {
    0
  }
}

///|
fn main {
  let code = run(@env.args()) catch {
    error => {
      eprintln("MoonShim error: \{error}")
      2
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
