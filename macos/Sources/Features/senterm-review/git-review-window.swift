import AppKit
import SwiftUI

@MainActor
final class GitReviewWindow: NSWindowController, NSWindowDelegate {
    private static var openWindows: Set<GitReviewWindow> = []

    static func open(directory: String) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: GitReviewView(directory: directory)))
        window.title = "git changes"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.center()
        let controller = GitReviewWindow(window: window)
        window.delegate = controller
        openWindows.insert(controller)
        controller.showWindow(nil)
    }

    func windowWillClose(_ notification: Notification) {
        Self.openWindows.remove(self)
    }
}

private struct GitReviewView: View {
    let directory: String
    @State private var files: GitChanges.Files?
    @State private var failure: String?

    var body: some View {
        Group {
            if let files {
                if files.paths.isEmpty {
                    Text("no unstaged changes")
                } else {
                    List(files.paths, id: \.self) { path in
                        Text(verbatim: path)
                    }
                    .accessibilityLabel("unstaged changes")
                }
            } else if let failure {
                Text(verbatim: failure)
                    .padding()
            } else {
                ProgressView("reading git changes…")
            }
        }
        .frame(minWidth: 360, minHeight: 240)
        .task {
            do {
                files = try await Task.detached(priority: .userInitiated) {
                    try GitChanges.files(in: directory, scope: .unstaged)
                }.value
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}
