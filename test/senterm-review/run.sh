#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

swiftc -swift-version 5 -warnings-as-errors \
  macos/Sources/Features/senterm-review/git-changes.swift \
  macos/Sources/Features/senterm-review/diff-review.swift \
  test/senterm-review/git-changes-tests.swift \
  -o "$tmp/git-changes-tests"
"$tmp/git-changes-tests"
