# senterm git review editor

run the normal macos build with `nu macos/build.nu`. it needs node.js 22 or
newer and npm to install the locked editor dependencies and bundle assets.
there is no node.js runtime or network requirement in the review window.

the read-only editor uses monaco for side-by-side diffs and shiki for
textmate highlighting. the 2026 dark palette and token rules come from
[microsoft/vscode at 6904719](https://github.com/microsoft/vscode/blob/69047191fc427f2f92828279aae1d90d8eeda7ab/extensions/theme-defaults/themes/2026-dark.json)
under the included mit license. this viewer does not run vscode extensions
or language servers.
