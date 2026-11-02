//
//  Shell.swift
//  PerchHelper
//
//  Runs git, lsof and gh with a time limit and no prompts.
//

import Foundation

enum Shell {
    struct Result {
        let status: Int32
        let output: String
        var succeeded: Bool { status == 0 }
    }

    /// Where Homebrew and the system keep the tools Perch Helper calls.
    static let searchPath = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static func find(_ name: String) -> String? {
        searchPath.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Runs a tool and returns its exit status and standard output; nil if it couldn't start.
    /// Anything still running after `timeout` seconds is stopped.
    static func run(_ tool: String, _ arguments: [String], timeout: TimeInterval = 15) -> Result? {
        guard let path = tool.contains("/") ? tool : find(tool) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchPath.joined(separator: ":")
        environment["GIT_TERMINAL_PROMPT"] = "0"   // never wait for a password
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["NO_COLOR"] = "1"
        process.environment = environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do { try process.run() } catch { return nil }

        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
