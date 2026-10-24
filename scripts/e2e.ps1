$ErrorActionPreference = "Stop"
$env:Path = "$HOME\.moon\bin;$env:Path"

moon run cmd/main -- `
  diff fixtures/old.mbti fixtures/new.mbti `
  --rules fixtures/renames.json `
  --markdown examples/migration-report.md `
  --json examples/migration-report.json `
  --shim compat_fixture/compat_generated.mbt `
  --fail-on-breaking

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

moon run cmd/main -- `
  diff fixtures/old.mbti fixtures/new.mbti `
  --rules fixtures/renames.json `
  --shim examples/generated-shim.mbt `
  --fail-on-breaking

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

moon fmt
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

moon fmt --check
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

git diff --exit-code -- `
  compat_fixture/compat_generated.mbt `
  examples/generated-shim.mbt `
  examples/migration-report.md `
  examples/migration-report.json
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

moon check --deny-warn
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

moon test --deny-warn
exit $LASTEXITCODE
