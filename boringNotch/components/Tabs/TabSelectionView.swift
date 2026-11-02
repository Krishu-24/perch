//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
    /// A tab that does something instead of showing a view, like the terminal.
    var action: (@MainActor () -> Void)? = nil
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Terminal", icon: "apple.terminal.fill", view: .home, action: { DevStore.shared.toggleTerminal() }),
    TabModel(label: "Limits", icon: "gauge.with.dots.needle.33percent", view: .limits),
    TabModel(label: "Claude", icon: "sparkles", view: .claude),
    TabModel(label: "Dev", icon: "chart.bar.xaxis", view: .dev)
]

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    let isSelected = tab.action == nil && coordinator.currentView == tab.view
                    TabButton(label: tab.label, icon: tab.icon, selected: isSelected) {
                        if let action = tab.action {
                            action()
                        } else {
                            withAnimation(.smooth) {
                                coordinator.currentView = tab.view
                            }
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(isSelected ? .white : .gray)
                    .help(tab.label)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
