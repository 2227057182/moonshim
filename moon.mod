// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "2227057182/moonshim"

version = "0.1.1"

readme = "README.md"

repository = "https://github.com/2227057182/moonshim"

license = "Apache-2.0"

keywords = [
  "moonbit",
  "api-compatibility",
  "migration",
  "developer-tools",
  "codegen",
]

preferred_target = "js"

description = "Conservative, compile-tested compatibility shims for evolving MoonBit public APIs."

import {
  "moonbitlang/x@0.5.6",
}
