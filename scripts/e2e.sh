#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.moon/bin:$PATH"

moon run cmd/main -- \
  diff fixtures/old.mbti fixtures/new.mbti \
  --rules fixtures/renames.json \
  --markdown examples/migration-report.md \
  --json examples/migration-report.json \
  --shim compat_fixture/compat_generated.mbt \
  --fail-on-breaking

moon run cmd/main -- \
  diff fixtures/old.mbti fixtures/new.mbti \
  --rules fixtures/renames.json \
  --shim examples/generated-shim.mbt \
  --fail-on-breaking

moon fmt
moon fmt --check
git diff --exit-code -- \
  compat_fixture/compat_generated.mbt \
  examples/generated-shim.mbt \
  examples/migration-report.md \
  examples/migration-report.json
moon check --deny-warn
moon test --deny-warn
