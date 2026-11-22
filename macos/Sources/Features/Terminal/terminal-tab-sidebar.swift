import AppKit
import SwiftUI

@MainActor
final class TerminalTabSidebar: ObservableObject {
    struct Tab: Identifiable, Equatable {
        let id: ObjectIdentifier
        let title: String
        let selected: Bool
    }

    struct Section: Identifiable, Equatable {
        let directory: String?
        var id: String? { directory }
        var title: String {
            directory.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "terminals"
        }
        var tabs: [Tab] = []
    }

    @Published private(set) var sections: [Section] = []
    @Published var collapsedSections: Set<String?> = []
    @Published var isCollapsed = false
    weak var window: NSWindow?
    var directoryForWindow: (NSWindow) -> String? = { _ in nil }
    private weak var group: NSWindowTabGroup?
    private var windowsObservation: NSKeyValueObservation?
    private var refreshScheduled = false

    var windows: [NSWindow] {
        guard let window else { return [] }
        let members = window.tabGroup?.windows ?? []
        return members.isEmpty ? [window] : members
    }

    func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            refreshScheduled = false
            refresh()
        }
    }

    func refresh() {
        let currentGroup = window?.tabGroup
        if currentGroup !== group {
            group = currentGroup
            windowsObservation = group?.observe(\.windows) { [weak self] _, _ in
                DispatchQueue.main.async { self?.scheduleRefresh() }
            }
        }
        var next: [Section] = []
        for member in windows {
            let directory = directoryForWindow(member)
            let tab = Tab(id: ObjectIdentifier(member), title: member.title.isEmpty ? "terminal" : member.title,
                          selected: member === window)
            if let index = next.firstIndex(where: { $0.directory == directory }) {
                next[index].tabs.append(tab)
            } else {
                next.append(Section(directory: directory, tabs: [tab]))
            }
        }
        if next != sections { sections = next }
    }

    func select(_ tab: Tab) {
        guard let target = windows.first(where: { ObjectIdentifier($0) == tab.id }), target !== window else { return }
        target.makeKeyAndOrderFront(nil)
    }
}

struct TerminalTabSidebarView: View {
    @ObservedObject var sidebar: TerminalTabSidebar
    let newTab: (String?) -> Void
    let newSection: () -> Void
    let toggleSection: (String?) -> Void
    let toggleSidebar: () -> Void
    let closeTab: (TerminalTabSidebar.Tab) -> Void
    let openGitChanges: () -> Void
    @State private var hoveredTab: TerminalTabSidebar.Tab.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                action("sidebar.left", sidebar.isCollapsed ? "show sidebar" : "hide sidebar", toggleSidebar)
                if !sidebar.isCollapsed {
                    Spacer()
                    action("folder.badge.plus", "new project section", newSection)
                }
            }
            if sidebar.isCollapsed {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(sidebar.sections) { section in
                            sectionView(section)
                        }
                    }
                }
            }
            action("arrow.triangle.branch", "git changes", openGitChanges)
        }
        .padding(8)
        .font(.system(size: 13))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.bar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1).allowsHitTesting(false)
        }
    }

    private func action(_ icon: String, _ title: String, _ handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            Image(systemName: icon).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func sectionView(_ section: TerminalTabSidebar.Section) -> some View {
        let collapsed = sidebar.collapsedSections.contains(section.directory)
        return VStack(spacing: 2) {
            HStack(spacing: 2) {
                Button {
                    toggleSection(section.directory)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.system(size: 9))
                        Text(verbatim: section.title).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(section.directory ?? section.title)
                action("plus", "new terminal in \(section.title)") { newTab(section.directory) }
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12, weight: .medium))
            if !collapsed {
                ForEach(section.tabs, content: tabRow)
            }
        }
    }

    private func tabRow(_ tab: TerminalTabSidebar.Tab) -> some View {
        HStack(spacing: 0) {
            Button {
                sidebar.select(tab)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "terminal")
                    Text(verbatim: tab.title).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tab.title)
            .accessibilityAddTraits(tab.selected ? .isSelected : [])

            if hoveredTab == tab.id {
                action("xmark", "close terminal: \(tab.title)") { closeTab(tab) }
            } else {
                Color.clear.frame(width: 24, height: 24)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .background {
            if tab.selected { Capsule().fill(Color.accentColor.opacity(0.22)) }
        }
        .onHover { isInside in
            if isInside {
                hoveredTab = tab.id
            } else if hoveredTab == tab.id {
                hoveredTab = nil
            }
        }
        .contextMenu { Button("close tab") { closeTab(tab) } }
    }
}
