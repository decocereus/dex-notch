import Darwin
import Foundation

struct CodexExecutableLocator: Sendable {
  private let candidates: [String]

  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    var paths: [String] = []

    if let override = environment["DEX_CODEX_EXECUTABLE"], !override.isEmpty {
      paths.append(override)
    }

    if let path = environment["PATH"] {
      paths.append(
        contentsOf: path.split(separator: ":").map {
          URL(fileURLWithPath: String($0)).appendingPathComponent("codex").path
        }
      )
    }

    paths.append(contentsOf: [
      homeDirectory.appendingPathComponent(".bun/bin/codex").path,
      homeDirectory.appendingPathComponent(".local/bin/codex").path,
      homeDirectory.appendingPathComponent(".npm-global/bin/codex").path,
      "/opt/homebrew/bin/codex",
      "/usr/local/bin/codex",
    ])

    self.candidates = paths
  }

  init(candidates: [String]) {
    self.candidates = candidates
  }

  func locate() -> URL? {
    var visited = Set<String>()
    for path in candidates where visited.insert(path).inserted {
      if FileManager.default.isExecutableFile(atPath: path) {
        return URL(fileURLWithPath: path)
      }
    }
    return nil
  }
}

struct CodexUsageClient: CodexUsageReading {
  private static let weeklyWindowMinutes = 7 * 24 * 60

  private let locator: CodexExecutableLocator
  private let timeout: Duration
  private let observedAt: @Sendable () -> Date

  init(
    locator: CodexExecutableLocator = CodexExecutableLocator(),
    timeout: Duration = .seconds(5),
    observedAt: @escaping @Sendable () -> Date = Date.init
  ) {
    self.locator = locator
    self.timeout = timeout
    self.observedAt = observedAt
  }

  func readWeeklyUsage() async throws -> CodexUsageSnapshot {
    guard let executableURL = locator.locate() else {
      throw CodexUsageError.executableNotFound
    }

    return try await withThrowingTaskGroup(of: CodexUsageSnapshot.self) { group in
      group.addTask {
        try await readWeeklyUsage(from: executableURL)
      }
      group.addTask {
        try await Task.sleep(for: timeout)
        throw CodexUsageError.timedOut
      }

      defer { group.cancelAll() }
      guard let snapshot = try await group.next() else {
        throw CodexUsageError.protocolFailure
      }
      return snapshot
    }
  }

  private func readWeeklyUsage(from executableURL: URL) async throws -> CodexUsageSnapshot {
    let session = CodexAppServerProcess(executableURL: executableURL)
    do {
      try session.run()
    } catch {
      throw CodexUsageError.couldNotLaunch
    }

    defer { session.stop() }
    return try await withTaskCancellationHandler {
      try write(
        [
          "method": "initialize",
          "id": 0,
          "params": [
            "clientInfo": [
              "name": "dex_notch",
              "title": "Dex",
              "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? "development",
            ]
          ],
        ],
        to: session.input
      )

      var sentRateLimitRequest = false
      for try await line in session.output.bytes.lines {
        try Task.checkCancellation()
        guard let data = line.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = (object["id"] as? NSNumber)?.intValue
        else { continue }

        if id == 0, !sentRateLimitRequest {
          guard object["error"] == nil else { throw CodexUsageError.protocolFailure }
          try write(
            ["method": "initialized", "params": [:]],
            to: session.input
          )
          try write(
            ["method": "account/rateLimits/read", "id": 6, "params": [:]],
            to: session.input
          )
          sentRateLimitRequest = true
          continue
        }

        if id == 6 {
          guard object["error"] == nil, let result = object["result"] else {
            throw CodexUsageError.rateLimitsUnavailable
          }
          let resultData = try JSONSerialization.data(withJSONObject: result)
          return try Self.decodeWeeklyUsage(resultData, observedAt: observedAt())
        }
      }

      throw CodexUsageError.serverExited
    } onCancel: {
      session.stop()
    }
  }

  private func write(_ object: [String: Any], to handle: FileHandle) throws {
    var data = try JSONSerialization.data(withJSONObject: object)
    data.append(0x0A)
    try handle.write(contentsOf: data)
  }

  static func decodeWeeklyUsage(_ data: Data, observedAt: Date) throws -> CodexUsageSnapshot {
    let response: RateLimitResponse
    do {
      response = try JSONDecoder().decode(RateLimitResponse.self, from: data)
    } catch {
      throw CodexUsageError.protocolFailure
    }

    let mainBucket = response.rateLimitsByLimitId?["codex"]
      ?? response.rateLimitsByLimitId?.values.first(where: { $0.limitId == "codex" })
      ?? response.rateLimits.flatMap { bucket in
        bucket.limitId == nil || bucket.limitId == "codex" ? bucket : nil
      }

    guard let mainBucket else { throw CodexUsageError.weeklyWindowUnavailable }
    guard let weeklyWindow = [mainBucket.primary, mainBucket.secondary]
      .compactMap({ $0 })
      .first(where: { $0.windowDurationMins == weeklyWindowMinutes })
    else {
      throw CodexUsageError.weeklyWindowUnavailable
    }

    let used = min(max(weeklyWindow.usedPercent, 0), 100)
    return CodexUsageSnapshot(
      remainingPercentage: Int((100 - used).rounded()),
      usedPercentage: Int(used.rounded()),
      resetsAt: weeklyWindow.resetsAt.map(Date.init(timeIntervalSince1970:)),
      observedAt: observedAt
    )
  }
}

private final class CodexAppServerProcess: @unchecked Sendable {
  let input: FileHandle
  let output: FileHandle

  private let process: Process
  private let inputPipe: Pipe
  private let outputPipe: Pipe
  private let lock = NSLock()
  private var stopped = false

  init(executableURL: URL) {
    let process = Process()
    let inputPipe = Pipe()
    let outputPipe = Pipe()

    process.executableURL = executableURL
    process.arguments = ["app-server"]
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice

    self.process = process
    self.inputPipe = inputPipe
    self.outputPipe = outputPipe
    self.input = inputPipe.fileHandleForWriting
    self.output = outputPipe.fileHandleForReading
    _ = fcntl(self.input.fileDescriptor, F_SETNOSIGPIPE, 1)
  }

  func run() throws {
    try process.run()
  }

  func stop() {
    lock.lock()
    guard !stopped else {
      lock.unlock()
      return
    }
    stopped = true
    lock.unlock()

    try? input.close()
    try? output.close()
    if process.isRunning {
      process.terminate()
    }
  }
}

enum CodexUsageError: Error, Equatable, Sendable {
  case executableNotFound
  case couldNotLaunch
  case timedOut
  case protocolFailure
  case rateLimitsUnavailable
  case weeklyWindowUnavailable
  case serverExited
}

private struct RateLimitResponse: Decodable {
  let rateLimits: RateLimitBucket?
  let rateLimitsByLimitId: [String: RateLimitBucket]?
}

private struct RateLimitBucket: Decodable {
  let limitId: String?
  let primary: RateLimitWindow?
  let secondary: RateLimitWindow?
}

private struct RateLimitWindow: Decodable {
  let usedPercent: Double
  let windowDurationMins: Int?
  let resetsAt: Double?
}
