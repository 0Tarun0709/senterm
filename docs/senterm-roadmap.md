# senterm roadmap

senterm is the macos ghostty fork. keep ghostty's terminal engine, renderer, pty lifecycle, and native behavior. port the workflows that made senterm legacy useful; don't port swiftterm or rebuild features ghostty already provides. `senterm-legacy` stays a reference, not a dependency.

## checkpoints and pushes

- develop on local `senterm` and push to `origin/senterm` on `0Tarun0709/senterm`. leave `origin/main`, upstream ghostty, and senterm legacy alone. use normal pushes, never force-push.
- each numbered item is sized for one focused commit when practical. include its id in the commit body so progress is searchable in git. split it if that makes testing or rollback clearer; don't create empty commits to hit a count.
- before committing, inspect the staged diff, run `git diff --cached --check` and the relevant tests, and record what passed and what could not run. use conventional commit messages with a body, lines of at most 85 characters, and the configured github identity.
- after committing, push the branch and verify its remote tip matches the local commit. report the checkpoint id, short hash, checks, and any remaining blocker. if the push fails, retain the local commit and report it as unpushed.
- the fork is public. keep local paths, credentials, session exports, private diffs, review notes, and benchmark captures with personal data out of git. use disposable fixtures. new senterm files and folders are lowercase unless a tool requires a specific name; don't rename unrelated upstream paths.
- a standalone backend or docs checkpoint can ship before the full app builds. app integration checkpoints require the macos build and the relevant smoke checks. current machine has command line tools only; use a full toolchain on this mac or an approved build machine before calling the app milestones done.

## a. foundation

baseline: ghostty `v1.4.0`, commit `83fb95624`. see [the upstream build guide](../HACKING.md) and [macos build instructions](../macos/AGENTS.md). run the unmodified baseline from a separate checkout of that commit, not by reverting senterm's branch.

| id | checkpoint | acceptance check |
|---|---|---|
| a01 | pin and document the upstream baseline | fork commit, local build commands, and development branch are recorded |
| a02 | provision a supported macos build toolchain | full xcode, metal tools, pinned zig, nushell, and swiftlint versions are verified; no tools installed without approval |
| a03 | build the unmodified baseline | ghostty's documented macos build and unit tests pass on the pinned source |
| a04 | smoke-test the baseline app | disposable shell supports typing, resize, splits, and sibling survival after exit |
| a05 | capture baseline performance | record hardware, grid, build mode, workloads, and raw-result format before measuring fork changes |
| a06 | give senterm its own app identity | separate bundle id and state paths let senterm and stock ghostty run alongside each other |
| a07 | add repeatable fork build checks | approved runner or documented local build runs the baseline checks without publishing artifacts |

## b. git diff and review — first feature milestone

| id | checkpoint | acceptance check |
|---|---|---|
| b01 | port the diff and note backend | standalone tests pass with swift 5 warnings-as-errors, including linked worktrees and legacy note format |
| b02 | add a manual review-window action | an active pane opens a distinct resizable window for its worktree; non-repo state is clear |
| b03 | list changed files and totals | staged, unstaged, and untracked fixtures show correct counts; binary files aren't counted as text |
| b04 | render side-by-side hunks | old/new lines align, changed spans are emphasized, and large diffs have bounded work |
| b05 | identify every review window | multiple windows show folder plus branch or detached commit without sharing selection |
| b06 | add inline notes | add control appears on hover or keyboard focus; old/new anchors and original line survive reopening |
| b07 | edit and delete notes | footer lists notes for the right worktree and revision; deletion cannot affect another worktree |
| b08 | support resolved notes | resolve and reopen preserve history; active view and default agent lookup exclude resolved notes |
| b09 | connect interactive `git diff` | plain, staged, and cached forms open the viewer from the correct local pane; the bridge carries no arbitrary command execution |
| b10 | preserve git's normal output | pipes, redirection, `--no-pager`, unsupported arguments, and noninteractive shells work without the viewer |
| b11 | port the read-only review cli | listing from a subfolder finds current worktree notes and does not mutate git or note storage |
| b12 | port the pi handoff | a disposable worktree can add notes, reload pi, and ask for notes without copying a prompt; explicit skill fallback works |
| b13 | verify the complete review loop | test annotate → retrieve → address → resolve in staged and unstaged views; legacy notes still load |

## c. project workspace and pane behavior

| id | checkpoint | acceptance check |
|---|---|---|
| c01 | map project tabs to ghostty surfaces | create, select, and detach views without creating a second shell or breaking native session ownership |
| c02 | add the project sidebar behind a setting | users can fall back to stock layout; keyboard focus and toolbar hit targets work |
| c03 | open a folder as a project | each new project opens exactly one shell named `terminal`; reopened folders don't duplicate projects |
| c04 | add per-project tab creation | new tabs start at the project root and can be renamed |
| c05 | collapse and reorder groups | collapse, ordering, and names survive relaunch; invalid folders have a recoverable state |
| c06 | persist workspace metadata | folders and layout restore without pretending old processes or scrollback survived app quit |
| c07 | switch tabs without disturbing jobs | a live server and agent survive repeated switches; each tab restores the last focused pane |
| c08 | add hover close and selection fallback | close control works by mouse and keyboard; the nearest valid tab is selected after close |
| c09 | confirm intentional close before teardown | cancel preserves shell and window; confirms close/quit before destroying sessions |
| c10 | verify natural exit and cleanup | either split can exit while its sibling stays visible and accepts typing; document detached-job limits |
| c11 | verify split behavior against ghostty | split cwd inheritance, directional focus, drag resize, equalize, and dim/outline preferences stay native |
| c12 | add zoomed-pane tabs | active zoom control is blue; top tabs switch the zoom target with no shell restart |
| c13 | verify window and keyboard actions | no wasted title row, toolbar is clickable, macos zoom preference works, and shortcuts route correctly |
| c14 | exercise six real projects | disposable workload includes a server, agent-style process, logs, multiple splits, and clean teardown |

## d. process visibility

| id | checkpoint | acceptance check |
|---|---|---|
| d01 | associate each surface with its local processes | foreground and background children map to the right pane, including across tabs and splits |
| d02 | detect foreground agent harnesses | fixtures cover supported harnesses, wrappers, and ordinary commands without false badges |
| d03 | map process badges | supported agents, go, ngrok, and servers get approved icons or generic fallbacks |
| d04 | add the running-process sidebar mode | waveform toggles modes, lists the right project and pane, and links back to the terminal |
| d05 | show cpu, memory, and elapsed time | detail rows handle processes that exit between samples without misattribution |
| d06 | show listening tcp ports | disposable ipv4 and ipv6 listeners verify ownership; remote and detached jobs aren't misrepresented |
| d07 | suspend unnecessary sampling | inspector polls only when useful; idle and six-project cpu are measured before and after |

## e. daily-use feature parity

| id | checkpoint | acceptance check |
|---|---|---|
| e01 | map shortcuts to native ghostty actions | pane cycling, find, quick terminal, and senterm actions work without duplicate bindings |
| e02 | match shell editing and quiet defaults | command-delete, option-delete, cursor blink, and bell defaults are verified; completion alerts are separate |
| e03 | verify multiline paste and scrollback settings | native protection, limits, and export meet the legacy workflow or the missing piece is added |
| e04 | make zsh integration coexist with ghostty's | syntax highlighting and prompt/cwd reporting work without editing dotfiles or overriding user settings |
| e05 | add opt-in command completion alerts | inactive-pane alerts work, active panes stay quiet, and users can opt out |
| e06 | add whole-window themes | high contrast stays stable; ocean, paper, and imported palettes cover sidebar, chrome, settings, and review |
| e07 | wire settings and action affordances | gear opens a separate window; tooltips, keyboard focus, and native menus work |
| e08 | review portability and migration | document differences in settings, licenses for bundled assets, and what can transfer from legacy |

## f. performance, compatibility, and release

| id | checkpoint | acceptance check |
|---|---|---|
| f01 | port repeatable throughput tests | same-grid release runs compare plain, colored, unicode, and escape-heavy pty workloads |
| f02 | measure visible updates and resource use | compare median and p95 with and without scrolling logs; record idle and loaded cpu and rss |
| f03 | measure responsiveness under sibling load | compare typing and switching on disposable panes; label model, captured-frame, and physical-input measures separately |
| f04 | find and fix measured regressions | profile extra sampling, view updates, and git work before optimizing; publish before/after evidence |
| f05 | verify terminal compatibility | smoke-test vim, tmux, and vttest; report exactly which checks ran, not blanket conformance |
| f06 | run stability and data-safety checks | repeat close/reopen, sleep/wake, concurrent review windows, and large diffs without lost notes or live-session regressions |
| f07 | assemble a local release candidate | versioned bundle coexists with stock ghostty and legacy; install, launch, rollback, and migration are documented |
| f08 | publish only after release approval | tag and distribute a verified build only with explicit approval; retain known limitations in the release notes |

## milestone gates

- **first usable feature:** a03–a04 and b01–b13 pass; users can run `git diff` and hand off notes end to end.
- **daily driver:** workspace, process, and daily-use tests pass on the six-project scenario without disrupting native ghostty behavior.
- **release candidate:** run the benchmark suite against the same ghostty baseline, document regressions and skipped checks, and pass the install/rollback smoke test. don't claim ghostty speed parity without comparable results.

start with b01, which is testable now. the next parallelizable path is a02–a04; do not present the review window as working until the macos app checks run.
