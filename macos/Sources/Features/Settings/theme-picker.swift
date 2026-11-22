import GhosttyKit
import SwiftUI

/// Keep picker choices separate from hand-edited configuration files.
enum ThemeSelection {
    static var overrideFile: URL? {
        guard let identifier = Bundle.main.bundleIdentifier else { return nil }
        return URL.applicationSupportDirectory.appendingPathComponent(identifier)
            .appendingPathComponent("selected-theme.conf")
    }

    static func save(_ file: URL?, to destination: URL) throws {
        if let file {
            let name = file.lastPathComponent
            guard !name.isEmpty, !name.contains(where: { $0.isNewline || ",:=".contains($0) }) else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            // Store the name, not the bundle path, so the choice survives app updates and moves.
            try "theme = \(name)\n".write(to: destination, atomically: true, encoding: .utf8)
        } else if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    static func savedName(in destination: URL?) -> String? {
        guard let destination, let value = try? String(contentsOf: destination, encoding: .utf8),
              value.hasPrefix("theme = ") else { return nil }
        return String(value.dropFirst("theme = ".count)).trimmingCharacters(in: .newlines)
    }
}

@MainActor
enum ThemePickerWindow {
    private static var window: NSWindow?

    static func open(_ ghostty: Ghostty.App) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let directory = Bundle.main.resourceURL?.appendingPathComponent("ghostty/themes", isDirectory: true)
        let view = ThemePicker(ghostty: ghostty, directory: directory)
        let panel = NSWindow(contentViewController: NSHostingController(rootView: view))
        panel.title = "terminal themes"
        panel.styleMask = [.titled, .closable, .resizable]
        panel.contentMinSize = NSSize(width: 560, height: 350)
        panel.setContentSize(NSSize(width: 660, height: 430))
        panel.isReleasedWhenClosed = false
        panel.center()
        window = panel
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct ThemePicker: View {
    let ghostty: Ghostty.App
    let files: [URL]
    @State private var query = ""
    @State private var selection: URL?
    @State private var applied: String?
    @State private var error: String?

    init(ghostty: Ghostty.App, directory: URL?) {
        self.ghostty = ghostty
        let files = directory.flatMap {
            try? FileManager.default.contentsOfDirectory(
                at: $0, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles
            )
        } ?? []
        self.files = files.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let saved = ThemeSelection.savedName(in: ThemeSelection.overrideFile)
        _applied = State(initialValue: saved)
        _selection = State(initialValue: self.files.first { $0.lastPathComponent == (saved ?? "abyssal-trench") })
    }

    private var filtered: [URL] {
        query.isEmpty ? files : files.filter { name($0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    TextField("search themes", text: $query)
                        .padding([.top, .horizontal], 12)
                    if filtered.isEmpty {
                        Text(files.isEmpty ? "no bundled themes found" : "no matching themes")
                            .foregroundStyle(.secondary)
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollViewReader { scroll in
                            List(filtered, id: \.self, selection: $selection) { file in
                                HStack {
                                    Text(verbatim: name(file))
                                    Spacer()
                                    if file.lastPathComponent == applied {
                                        Image(systemName: "checkmark").accessibilityLabel("applied")
                                    }
                                }
                                .tag(file)
                            }
                            .listStyle(.sidebar)
                            .onAppear { if let selection { scroll.scrollTo(selection, anchor: .center) } }
                        }
                    }
                }
                .frame(width: 220)
                Divider()
                if let selection, filtered.contains(selection) {
                    ThemePreview(title: name(selection), file: selection).id(selection)
                } else {
                    Text("select a theme to preview it")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                Button("use config theme") { apply(nil) }.disabled(applied == nil)
                Spacer()
                Button("apply theme") { apply(selection) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil || !filtered.contains { $0 == selection } ||
                              selection?.lastPathComponent == applied)
            }
            .padding(12)
        }
        .alert("couldn’t save theme", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("ok") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func name(_ file: URL) -> String {
        if file.lastPathComponent == "abyssal-trench" { return "abyssal trench" }
        if file.lastPathComponent == "senterm-original" { return "senterm original" }
        return file.lastPathComponent
    }

    private func apply(_ file: URL?) {
        do {
            guard let destination = ThemeSelection.overrideFile else { throw CocoaError(.fileWriteUnknown) }
            try ThemeSelection.save(file, to: destination)
            applied = file?.lastPathComponent
            ghostty.reloadConfig()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ThemePreview: View {
    let title: String
    let config: Ghostty.Config
    let colors: [Color]

    init(title: String, file: URL) {
        self.title = title
        let config = Ghostty.Config(config: ghostty_config_new())
        var palette = ghostty_config_palette_s()
        if let pointer = config.config {
            ghostty_config_load_file(pointer, file.path)
            _ = ghostty_config_get(pointer, &palette, "palette", 7)
        }
        self.config = config
        colors = withUnsafeBytes(of: &palette.colors) { bytes in
            bytes.bindMemory(to: ghostty_config_color_s.self).prefix(16).map {
                Color(nsColor: NSColor(ghostty: $0))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: title).font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("~/projects/app % git status").foregroundStyle(config.foregroundColor)
                Text("modified: readme.md").foregroundStyle(colors[1])
                Text("new file: theme.conf").foregroundStyle(colors[2])
                HStack(spacing: 2) {
                    ForEach(colors.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2).fill(colors[index]).frame(height: 15)
                    }
                }
                .accessibilityHidden(true)
                .padding(.top, 8)
            }
            .font(.system(size: 13, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(config.backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            Text("individual color settings in your config still take precedence.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}
