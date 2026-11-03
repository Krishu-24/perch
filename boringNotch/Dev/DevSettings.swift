//
//  DevSettings.swift
//  Perch
//
//  Settings → Widgets: when Perch Helper draws the widgets on the desktop, and in
//  which corner. Saved to settings.json in Perch's folder, which the helper reads.
//

import SwiftUI

struct DevSettings: View {
    @ObservedObject var store = DevStore.shared

    private var visibility: Binding<WidgetVisibility> {
        Binding(get: { store.widgetSettings.visibility },
                set: { store.saveWidgetSettings(WidgetSettings(visibility: $0, position: store.widgetSettings.position)) })
    }

    private var position: Binding<WidgetPosition> {
        Binding(get: { store.widgetSettings.position },
                set: { store.saveWidgetSettings(WidgetSettings(visibility: store.widgetSettings.visibility, position: $0)) })
    }

    static func name(_ visibility: WidgetVisibility) -> String {
        switch visibility {
        case .onDesktop: "On the desktop"
        case .always: "Always"
        case .off: "No, drop-down only"
        }
    }

    static func name(_ position: WidgetPosition) -> String {
        switch position {
        case .topRight: "Top right"
        case .topLeft: "Top left"
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Also on the desktop", selection: visibility) {
                    ForEach(WidgetVisibility.allCases, id: \.self) { Text(Self.name($0)).tag($0) }
                }
                Picker("Corner", selection: position) {
                    ForEach(WidgetPosition.allCases, id: \.self) { Text(Self.name($0)).tag($0) }
                }
                .disabled(store.widgetSettings.visibility == .off)
            } header: {
                Text("Desktop widgets")
            } footer: {
                Text("The widgets always live in the drop-down: press Control-` and pick Widgets. They can also sit on your desktop, beneath your windows. *On the desktop* shows them only while you're looking at the desktop (after clicking the wallpaper, or with Finder in front) and fades them when you go back to an app; *Always* keeps them there.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("Perch Helper") {
                    HStack(spacing: 6) {
                        Circle().fill(store.isHelperRunning ? TerminalColors.green : Color.secondary).frame(width: 7, height: 7)
                        Text(store.isHelperRunning ? "Running" : "Not running")
                    }
                }
                LabeledContent("GitHub") {
                    Text(Self.githubText(store.snapshot?.githubStatus))
                }
                Button("Refresh Now", action: store.refresh)
            } header: {
                Text("Data")
            } footer: {
                Text("Perch Helper reads your Git repositories, the ports your dev servers listen on, and GitHub through the GitHub CLI (gh). Run `gh auth login` once in the terminal (Control-`) to connect GitHub.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Widgets")
        .onAppear { store.reload() }
    }

    static func githubText(_ status: GitHubStatus?) -> String {
        switch status {
        case .ok: "Connected"
        case .signedOut: "Not signed in"
        case .notInstalled: "gh not installed"
        case .failed: "Can't reach GitHub"
        case nil: "Waiting for Perch Helper"
        }
    }
}
