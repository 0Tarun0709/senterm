import AppKit
import SwiftUI

@MainActor
final class TerminalTabSidebar: ObservableObject {
    struct Tab: Identifiable, Equatable {
        let id: ObjectIdentifier
        let title: String
        let selected: Bool
    }

    @Published private(set) var tabs: [Tab] = []
    weak var window: NSWindow?
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
        let next = windows.map {
            Tab(id: ObjectIdentifier($0), title: $0.title.isEmpty ? "terminal" : $0.title, selected: $0 === window)
        }
        if next != tabs { tabs = next }
    }

    func select(_ tab: Tab) {
        guard let target = windows.first(where: { ObjectIdentifier($0) == tab.id }), target !== window else { return }
        target.makeKeyAndOrderFront(nil)
    }
}

struct TerminalTabSidebarView: View {
    @ObservedObject var sidebar: TerminalTabSidebar
    let newTab: () -> Void
    let closeTab: (TerminalTabSidebar.Tab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("tabs")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button(action: newTab) {
                    Image(systemName: "plus").frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("new tab")
                .accessibilityLabel("new tab")
            }
            .padding(.horizontal, 8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sidebar.tabs) { tab in
                        Button {
                            sidebar.select(tab)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "terminal")
                                Text(verbatim: tab.title).lineLimit(1).truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .contentShape(Rectangle())
                            .background {
                                if tab.selected {
                                    Capsule().fill(Color.accentColor.opacity(0.22))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(tab.title)
                        .accessibilityAddTraits(tab.selected ? .isSelected : [])
                        .contextMenu {
                            Button("close tab") { closeTab(tab) }
                        }
                    }
                }
            }
        }
        .padding(8)
        .font(.system(size: 13))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.bar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1).allowsHitTesting(false)
        }
    }
}
