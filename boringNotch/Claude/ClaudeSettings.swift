//
//  ClaudeSettings.swift
//  boringNotch
//
//  The Claude page in Settings.
//

import AppKit
import Defaults
import SwiftUI

struct ClaudeSettings: View {
    @ObservedObject var store = ClaudeSessionStore.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .claudeLiveActivity) {
                    Text("Show Claude activity on the closed notch")
                }
                Defaults.Toggle(key: .claudeOpenWhenNeeded) {
                    Text("Open the notch when Claude needs you")
                }
            } header: {
                Text("Notch")
            } footer: {
                Text("While a session works, the closed notch shows the Claude spinner and your five-hour usage. When a session waits for your approval it shows an amber hand, even over music.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.isConnected ? TerminalColors.green : Color.secondary)
                            .frame(width: 7, height: 7)
                        Text(store.isConnected ? "Connected" : "Not connected")
                    }
                }
                LabeledContent("Active sessions") {
                    Text("\(store.sessions.count)")
                }
                if let cachedAt = store.usage?.cachedAt {
                    LabeledContent("Limits updated") {
                        Text(ClaudeFormatting.ageText(cachedAt))
                    }
                }
                Button("Show Data Folder in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ClaudeSessionStore.folder])
                }
                .disabled(!store.isConnected)
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Claude Code sends session status and plan limits through the notch-bridge mod, which writes small files to this folder on your Mac. Nothing is sent over the network. To install the mod, run `claude plugin marketplace add ./claude-mod`, then `claude plugin install notch-bridge@boring-notch-claude`, from this project's folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Claude")
    }
}
