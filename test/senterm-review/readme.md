# senterm review backend

run from the fork root with the macos command line tools. this check does not need zig or full xcode:

```sh
(
  set -e
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  swiftc -swift-version 5 -warnings-as-errors \
    macos/Sources/Features/senterm-review/git-changes.swift \
    macos/Sources/Features/senterm-review/diff-review.swift \
    test/senterm-review/git-changes-tests.swift \
    -o "$tmp/git-changes-tests"
  "$tmp/git-changes-tests"
)
```

this tests the git diff parser, change totals, and inline note storage against a disposable repository and linked worktree. the note format matches senterm legacy. it does not test the ghostty ui or shell integration.
