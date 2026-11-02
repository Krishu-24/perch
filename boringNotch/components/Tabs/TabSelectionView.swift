//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//  Modified for Perch: tabs switch on hover, with the menu-aim rule in TabAim.swift.
//

import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
    /// A tab that does something instead of showing a view, like the terminal. The notch
    /// closes after it, since what it opens takes the notch's place.
    var action: (@MainActor () -> Void)? = nil
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Terminal", icon: "apple.terminal.fill", view: .home, action: { DevStore.shared.showTerminal() }),
    TabModel(label: "Limits", icon: "gauge.with.dots.needle.33percent", view: .limits),
    TabModel(label: "Claude", icon: "sparkles", view: .claude),
    TabModel(label: "Dev", icon: "chart.bar.xaxis", view: .dev)
]

/// Each tab's frame in the row, by index.
private struct TabFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct TabSelectionView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation

    private static let rowHeight: CGFloat = 26
    private static let space = "perch.tabRow"

    @State private var frames: [Int: CGRect] = [:]
    @State private var hovered: Int?
    @State private var pending: (index: Int, task: Task<Void, Never>)?
    /// The content starts just below the row and spans the open notch.
    @State private var aim = TabAim(contentTop: TabSelectionView.rowHeight + 8, contentMinX: -8, contentMaxX: openNotchSize.width - 60)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let isSelected = tab.action == nil && coordinator.currentView == tab.view
                TabButton(label: tab.label, icon: tab.icon, selected: isSelected) {
                    activate(tab)
                }
                .frame(height: Self.rowHeight)
                .foregroundStyle(isSelected || hovered == index ? .white : .gray)
                .help(tab.label)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: TabFramesKey.self, value: [index: geometry.frame(in: .named(Self.space))])
                    }
                }
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    } else {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .matchedGeometryEffect(id: "capsule", in: animation)
                            .hidden()
                    }
                }
            }
        }
        .contentShape(Rectangle())
        // The row's own space, so hover locations and tab frames share an origin.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                hover(at: location)
            case .ended:
                aim.reset()
                hovered = nil
                cancelPending()
            }
        }
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(TabFramesKey.self) { frames = $0 }
        .onChange(of: vm.notchState) { _, state in
            if state == .closed { cancelPending() }
        }
        .clipShape(Capsule())
    }

    // MARK: - Hover

    private func hover(at location: CGPoint) {
        let headingForContent = aim.move(to: location)
        let index = frames.first { $0.value.contains(location) }?.key
        if index != hovered { hovered = index }

        guard let index, !isShowing(tabs[index]) else {
            cancelPending()
            return
        }
        // Already waiting on this tab and just moving along it: let the wait run out. Heading
        // down toward the content restarts it, so a tab crossed on the way isn't picked.
        if pending?.index == index && !headingForContent { return }

        cancelPending()
        let tab = tabs[index]
        let delay = TabAim.delay(isAction: tab.action != nil, headingForContent: headingForContent)
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, hovered == index, vm.notchState == .open else { return }
            pending = nil
            activate(tab)
        }
        pending = (index, task)
    }

    private func cancelPending() {
        pending?.task.cancel()
        pending = nil
    }

    /// Whether the tab is already what the notch shows.
    private func isShowing(_ tab: TabModel) -> Bool {
        tab.action == nil && coordinator.currentView == tab.view
    }

    /// Switches to a tab, or does what it does; for hover and click alike.
    private func activate(_ tab: TabModel) {
        cancelPending()
        if let action = tab.action {
            action()
            withAnimation(.smooth) { vm.close() }
        } else if coordinator.currentView != tab.view {
            withAnimation(.smooth) {
                coordinator.currentView = tab.view
            }
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
