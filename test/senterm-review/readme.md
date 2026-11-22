# senterm review backend

run from the fork root with the macos command line tools. this check does not need zig or full xcode:

```sh
bash test/senterm-review/run.sh
```

this tests the git diff parser, change totals, and inline note storage against a disposable repository and linked worktree. the note format matches senterm legacy. it does not test the ghostty ui or shell integration.
