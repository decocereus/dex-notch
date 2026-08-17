import Foundation
import Testing

@testable import Dex

@Suite("Codex weekly usage")
struct CodexUsageClientTests {
  @Test("selects the main seven-day window instead of a model-specific limit")
  func decodesMainWeeklyWindow() throws {
    let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let result = Data(
      #"""
      {
        "futureField": {"ignored": true},
        "rateLimitsByLimitId": {
          "codex_spark": {
            "limitId": "codex_spark",
            "limitName": "GPT-5.3-Codex-Spark",
            "primary": {
              "usedPercent": 0,
              "windowDurationMins": 10080,
              "resetsAt": 1800000000
            }
          },
          "main": {
            "limitId": "codex",
            "primary": {
              "usedPercent": 4,
              "windowDurationMins": 300,
              "resetsAt": 1750000000
            },
            "secondary": {
              "usedPercent": 28.6,
              "windowDurationMins": 10080,
              "resetsAt": 1760000000,
              "unknown": "safe to ignore"
            }
          }
        }
      }
      """#.utf8
    )

    let snapshot = try CodexUsageClient.decodeWeeklyUsage(result, observedAt: observedAt)

    #expect(snapshot.remainingPercentage == 71)
    #expect(snapshot.usedPercentage == 29)
    #expect(snapshot.resetsAt == Date(timeIntervalSince1970: 1_760_000_000))
    #expect(snapshot.observedAt == observedAt)
  }

  @Test("rejects responses without a main weekly window")
  func rejectsMissingWeeklyWindow() {
    let result = Data(
      #"""
      {
        "rateLimitsByLimitId": {
          "codex_spark": {
            "limitId": "codex_spark",
            "primary": {"usedPercent": 10, "windowDurationMins": 10080}
          }
        }
      }
      """#.utf8
    )

    #expect(throws: CodexUsageError.weeklyWindowUnavailable) {
      try CodexUsageClient.decodeWeeklyUsage(result, observedAt: Date())
    }
  }

  @Test("rejects malformed rate-limit payloads")
  func rejectsMalformedPayload() {
    let result = Data(#"{"rateLimits":{"limitId":"codex","secondary":"unexpected"}}"#.utf8)

    #expect(throws: CodexUsageError.protocolFailure) {
      try CodexUsageClient.decodeWeeklyUsage(result, observedAt: Date())
    }
  }

  @Test("reports a missing executable without launching a shell")
  func reportsMissingExecutable() async {
    let client = CodexUsageClient(locator: CodexExecutableLocator(candidates: []))

    await #expect(throws: CodexUsageError.executableNotFound) {
      try await client.readWeeklyUsage()
    }
  }

  @Test("performs the app-server handshake and reads usage")
  func readsFromAppServer() async throws {
    let response = #"""
      {"rateLimits":{"limitId":"codex","secondary":{"usedPercent":29,"windowDurationMins":10080,"resetsAt":1760000000}}}
      """#
    let script = "#!/bin/sh\nprintf '%s\\n' '{\"id\":0,\"result\":{\"userAgent\":\"fake\"}}'\nprintf '%s\\n' '{\"id\":6,\"result\":RESPONSE}'\nexec sleep 2\n"
      .replacingOccurrences(of: "RESPONSE", with: response)

    try await withFakeExecutable(script: script) { executable in
      let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
      let client = CodexUsageClient(
        locator: CodexExecutableLocator(candidates: [executable.path]),
        timeout: .seconds(3),
        observedAt: { observedAt }
      )

      let snapshot = try await client.readWeeklyUsage()
      #expect(snapshot.remainingPercentage == 71)
      #expect(snapshot.resetsAt == Date(timeIntervalSince1970: 1_760_000_000))
    }
  }

  @Test("treats a signed-out app-server response as unavailable")
  func handlesUnavailableAccount() async throws {
    let script = "#!/bin/sh\nprintf '%s\\n' '{\"id\":0,\"result\":{}}'\nprintf '%s\\n' '{\"id\":6,\"error\":{\"code\":-32000,\"message\":\"account unavailable\"}}'\nexec sleep 2\n"

    try await withFakeExecutable(script: script) { executable in
      let client = CodexUsageClient(
        locator: CodexExecutableLocator(candidates: [executable.path]),
        timeout: .seconds(3)
      )

      await #expect(throws: CodexUsageError.rateLimitsUnavailable) {
        try await client.readWeeklyUsage()
      }
    }
  }

  @Test("times out quietly when app-server never initializes")
  func timesOut() async throws {
    try await withFakeExecutable(script: "#!/bin/sh\nexec sleep 2\n") { executable in
      let client = CodexUsageClient(
        locator: CodexExecutableLocator(candidates: [executable.path]),
        timeout: .milliseconds(50)
      )

      await #expect(throws: CodexUsageError.timedOut) {
        try await client.readWeeklyUsage()
      }
    }
  }

  private func withFakeExecutable(
    script: String,
    operation: (URL) async throws -> Void
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("dex-codex-usage-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let executable = directory.appendingPathComponent("codex")
    try Data(script.utf8).write(to: executable)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executable.path
    )
    try await operation(executable)
  }
}

@Suite("Codex usage cache")
@MainActor
struct CodexUsageControllerTests {
  @Test("keeps the last successful reading when a later refresh fails")
  func preservesLastGoodReading() async {
    let expected = CodexUsageSnapshot(
      remainingPercentage: 71,
      usedPercentage: 29,
      resetsAt: nil,
      observedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let model = DexModel()
    let successful = CodexUsageController(
      model: model,
      reader: StubUsageReader(result: .success(expected))
    )
    await successful.refresh()

    let failed = CodexUsageController(
      model: model,
      reader: StubUsageReader(result: .failure(.rateLimitsUnavailable))
    )
    await failed.refresh()

    #expect(model.codexUsage == expected)
  }
}

private struct StubUsageReader: CodexUsageReading {
  let result: Result<CodexUsageSnapshot, CodexUsageError>

  func readWeeklyUsage() async throws -> CodexUsageSnapshot {
    try result.get()
  }
}
