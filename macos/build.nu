#!/usr/bin/env nu

# Build the macOS Ghostty app using xcodebuild with a clean environment
# to avoid Nix shell interference (NIX_LDFLAGS, NIX_CFLAGS_COMPILE, etc.).

def main [
    --scheme: string = "Ghostty"       # Xcode scheme (Ghostty, DockTilePlugin)
    --configuration: string = "Debug"  # Build configuration (Debug, Release, ReleaseLocal)
    --action: string = "build"         # xcodebuild action (build, test, clean, etc.)
] {
    let project = ($env.FILE_PWD | path join "Ghostty.xcodeproj")
    let build_dir = ($env.FILE_PWD | path join "build")

    if $scheme == "Ghostty" and ($action in ["build" "test" "archive"]) {
        cd ($env.FILE_PWD | path join "senterm-editor")
        let lock_hash = (open --raw package-lock.json | hash sha256)
        let installed_hash = if ("node_modules/.senterm-lock" | path exists) {
            open --raw node_modules/.senterm-lock
        } else { "" }
        if $lock_hash != $installed_hash {
            ^npm ci --ignore-scripts --no-audit --no-fund
            $lock_hash | save --force node_modules/.senterm-lock
        }
        ^node build.mjs
    }

    # Skip UI tests for CLI-based invocations because it requires
    # special permissions.
    let skip_testing = if $action == "test" {
        [-skip-testing GhosttyUITests]
    } else {
        []
    }

    # Keep an explicit Xcode selection without inheriting other toolchain flags.
    let developer_dir = if "DEVELOPER_DIR" in $env {
        [$"DEVELOPER_DIR=($env.DEVELOPER_DIR)"]
    } else {
        []
    }

    (^env -i
        $"HOME=($env.HOME)"
        "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
        ...$developer_dir
        xcodebuild
        -project $project
        -scheme $scheme
        -configuration $configuration
        $"SYMROOT=($build_dir)"
        ...$skip_testing
        $action)
}
