//
//  Collector.swift
//  PerchHelper
//
//  Gathers Git status, dev servers and GitHub activity and writes them to
//  ~/Library/Application Support/Perch/dev.json for the Dev tab.
//

import Foundation
import PerchDevCore

final class Collector {
    /// Git and dev servers are local and cheap: every few seconds.
    private static let localInterval: TimeInterval = 6
    /// GitHub goes over the network: every few minutes.
    private static let githubInterval: TimeInterval = 180
    /// How many recent projects to show.
    private static let projectLimit = 6
    /// How many repositories to ask GitHub Actions about.
    private static let actionsRepoLimit = 4

    let folder: URL
    /// Called on the main queue with every snapshot written, for the desktop widgets.
    var onUpdate: ((DevSnapshot) -> Void)?
    private let home: String
    private let queue = DispatchQueue(label: "perch.helper.collector")
    private var localTimer: DispatchSourceTimer?
    private var githubTimer: DispatchSourceTimer?

    private var projects: [GitProject] = []
    private var servers: [DevServer] = []
    private var github: GitHubSummary?
    private var githubStatus: GitHubStatus = .ok
    private var codex: CodexLimits?
    private var lastCodexCheck = Date.distantPast
    /// Codex's session files change with each reply; a look every 30 seconds is plenty.
    private static let codexInterval: TimeInterval = 30
    /// Project folders and when they were last seen, newest first; kept across launches.
    private var recentRoots: [String: Date] = [:]
    /// The projects' paths, readable from any thread without waiting on a slow GitHub call.
    private var knownPaths: Set<String> = []
    private let knownLock = NSLock()
    /// Each directory's Git top level, or "" when it isn't in a repository.
    private var gitRoots: [String: String] = [:]

    init(home: String = NSHomeDirectory()) {
        self.home = home
        folder = URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/Perch", isDirectory: true)
    }

    func start() {
        queue.async { self.loadState() }
        localTimer = schedule(every: Self.localInterval) { [weak self] in self?.collectLocal() }
        githubTimer = schedule(every: Self.githubInterval) { [weak self] in self?.collectGitHub() }
    }

    /// Whether a folder is one of the projects shown in the Dev tab. Only those may be
    /// opened in the terminal by URL, so no other app can point the terminal anywhere else.
    func isKnownProject(_ path: String) -> Bool {
        knownLock.lock()
        defer { knownLock.unlock() }
        return knownPaths.contains(path)
    }

    /// Refreshes everything now, GitHub included.
    func refreshNow() {
        queue.async {
            self.collectLocal()
            self.collectGitHub()
        }
    }

    private func schedule(every interval: TimeInterval, _ work: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .seconds(1))
        timer.setEventHandler(handler: work)
        timer.resume()
        return timer
    }

    // MARK: - Local

    private func collectLocal() {
        if Date().timeIntervalSince(lastCodexCheck) >= Self.codexInterval {
            lastCodexCheck = Date()
            codex = collectCodex()
        }
        servers = collectServers()
        let roots = recentProjectRoots(adding: claudeSessionFolders() + servers.map(\.directory))
        projects = roots.compactMap(gitProject)
        knownLock.lock()
        knownPaths = Set(projects.map(\.path))
        knownLock.unlock()
        write()
    }

    private func collectServers() -> [DevServer] {
        guard let listening = Shell.run("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]) else { return [] }
        let listeners = ListeningPortsParser.parseListeners(listening.output)
            .filter { $0.pid != Int(ProcessInfo.processInfo.processIdentifier) }
        guard !listeners.isEmpty else { return [] }
        let pids = Set(listeners.map(\.pid)).map(String.init).joined(separator: ",")
        let cwd = Shell.run("lsof", ["-a", "-d", "cwd", "-p", pids, "-Fpn"])?.output ?? ""
        var servers = ListeningPortsParser.devServers(
            listeners: listeners, directories: ListeningPortsParser.parseWorkingDirectories(cwd), home: home)
        guard !servers.isEmpty else { return [] }

        // What each one runs, so a card can say "next dev" rather than "node".
        let serverPids = Set(servers.map(\.pid)).map(String.init).joined(separator: ",")
        var arguments: [Int: String] = [:]
        for line in (Shell.run("ps", ["-o", "pid=,args=", "-p", serverPids])?.output ?? "").split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            if parts.count == 2, let pid = Int(parts[0]) { arguments[pid] = String(parts[1]) }
        }
        for index in servers.indices {
            servers[index].summary = arguments[servers[index].pid].map(ProcessSummary.summarize)
        }
        return servers
    }

    /// The newest limit reading in Codex's session files, if you use Codex on this Mac.
    private func collectCodex() -> CodexLimits? {
        let codexFolder = URL(fileURLWithPath: home).appendingPathComponent(".codex", isDirectory: true)
        var files: [(url: URL, modified: Date)] = []
        for folder in ["sessions", "archived_sessions"] {
            let root = codexFolder.appendingPathComponent(folder, isDirectory: true)
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in walker where url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                files.append((url, modified))
            }
        }
        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(3) {
            // The newest reading is near the end; read only the last part of a long file.
            guard let handle = try? FileHandle(forReadingFrom: file.url) else { continue }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            try? handle.seek(toOffset: size > 512_000 ? size - 512_000 : 0)
            let tail = String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
            if let limits = CodexUsageParser.latest(in: tail) { return limits }
        }
        return nil
    }

    /// The folders Claude Code sessions ran in, from the perch-bridge mod's files.
    private func claudeSessionFolders() -> [String] {
        let sessions = folder.appendingPathComponent("sessions", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { file in
            guard file.pathExtension == "json", let data = try? Data(contentsOf: file),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return object["cwd"] as? String
        }
    }

    private func recentProjectRoots(adding directories: [String]) -> [String] {
        let now = Date()
        var changed = false
        for directory in Set(directories) {
            guard let root = gitRoot(of: directory) else { continue }
            if recentRoots[root] == nil { changed = true }
            recentRoots[root] = now
        }
        // Drop folders that no longer exist, and anything beyond twice the limit.
        let kept = recentRoots
            .filter { FileManager.default.fileExists(atPath: $0.key) }
            .sorted { $0.value > $1.value }
            .prefix(Self.projectLimit * 2)
        if kept.count != recentRoots.count { changed = true }
        recentRoots = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        if changed { saveState() }
        return kept.prefix(Self.projectLimit).map(\.key)
    }

    private func gitRoot(of directory: String) -> String? {
        if let cached = gitRoots[directory] { return cached.isEmpty ? nil : cached }
        let result = Shell.run("git", ["-C", directory, "rev-parse", "--show-toplevel"], timeout: 5)
        let root = result?.succeeded == true ? result!.output.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        gitRoots[directory] = root
        return root.isEmpty ? nil : root
    }

    private func gitProject(at root: String) -> GitProject? {
        guard let status = Shell.run("git", ["-C", root, "status", "--porcelain=v2", "--branch"], timeout: 8),
              status.succeeded else { return nil }
        let parsed = GitStatusParser.parse(status.output)

        var lastCommit: String?
        var lastCommitDate: Date?
        if let log = Shell.run("git", ["-C", root, "log", "-1", "--format=%s%x1f%cI"], timeout: 5), log.succeeded {
            let parts = log.output.trimmingCharacters(in: .newlines).components(separatedBy: "\u{1f}")
            lastCommit = parts.first.flatMap { $0.isEmpty ? nil : $0 }
            lastCommitDate = parts.count > 1 ? ISO8601DateFormatter().date(from: parts[1]) : nil
        }
        let remote = Shell.run("git", ["-C", root, "remote", "get-url", "origin"], timeout: 5)
        let githubRepo = remote?.succeeded == true ? GitStatusParser.githubRepo(fromRemote: remote!.output) : nil

        return GitProject(path: root, branch: parsed.branch, ahead: parsed.ahead, behind: parsed.behind,
                          changed: parsed.changed, untracked: parsed.untracked,
                          lastCommit: lastCommit, lastCommitDate: lastCommitDate, githubRepo: githubRepo)
    }

    // MARK: - GitHub

    private func collectGitHub() {
        guard Shell.find("gh") != nil else {
            githubStatus = .notInstalled
            github = nil
            write()
            return
        }
        guard Shell.run("gh", ["auth", "status", "--hostname", "github.com"], timeout: 10)?.succeeded == true else {
            githubStatus = .signedOut
            github = nil
            write()
            return
        }
        guard let viewer = Shell.run("gh", ["api", "graphql", "-f", "query=\(GitHubParser.viewerQuery)"], timeout: 30),
              viewer.succeeded else {
            githubStatus = .failed
            write()
            return
        }

        let repos = Array(NSOrderedSet(array: projects.compactMap(\.githubRepo)).array as! [String]).prefix(Self.actionsRepoLimit)
        var runs: [WorkflowRun] = []
        for repo in repos {
            guard let list = Shell.run("gh", ["run", "list", "-R", repo, "-L", "2", "--json", GitHubParser.runFields], timeout: 20),
                  list.succeeded,
                  let parsed = try? GitHubParser.parseRuns(Data(list.output.utf8), repo: repo) else { continue }
            runs += parsed
        }
        runs.sort { $0.createdAt > $1.createdAt }

        do {
            github = try GitHubParser.parseViewer(Data(viewer.output.utf8), runs: Array(runs.prefix(6)))
            githubStatus = .ok
        } catch {
            githubStatus = .failed
        }
        write()
    }

    // MARK: - Files

    private func write() {
        let snapshot = DevSnapshot(updatedAt: Date(), projects: projects, servers: servers,
                                   github: github, githubStatus: githubStatus, codex: codex)
        if let onUpdate { DispatchQueue.main.async { onUpdate(snapshot) } }
        guard let data = try? DevSnapshot.encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(DevSnapshot.fileName), options: .atomic)
    }

    private var stateFile: URL { folder.appendingPathComponent("helper-state.json") }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? DevSnapshot.decoder.decode([String: Date].self, from: data) else { return }
        recentRoots = state
    }

    private func saveState() {
        guard let data = try? DevSnapshot.encoder.encode(recentRoots) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: stateFile, options: .atomic)
    }
}
