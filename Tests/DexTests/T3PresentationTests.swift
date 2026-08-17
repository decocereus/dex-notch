import Foundation
import Testing

@testable import Dex

@Suite("T3 live-work projection")
@MainActor
struct T3PresentationTests {
  @Test("filters settled history while preserving authoritative blockers")
  func filtersSettledHistory() throws {
    let shell = try decodeShell()

    let visible = T3ConnectionController.relevantThreads(from: shell)

    #expect(visible.map(\.id) == ["blocked", "failed", "kept-active"])
    #expect(!visible.map(\.id).contains("settled-failure"))
    #expect(!visible.map(\.id).contains("completed"))
    #expect(!visible.map(\.id).contains("archived"))
  }

  @Test("maps repository branch and worktree without inventing PR data")
  func mapsCheckoutIdentity() throws {
    let shell = try decodeShell()
    let source = try #require(shell.threads.first { $0.id == "failed" })

    let thread = T3ConnectionController.map(source, shell: shell, usage: nil)

    #expect(thread.repository == "avail/nightshade")
    #expect(thread.branch == "agent/recovery")
    #expect(thread.checkoutLabel == "avail/nightshade  ·  agent/recovery  ·  worktrees/recovery")
  }

  private func decodeShell() throws -> T3ShellSnapshot {
    let json = #"""
    {
      "snapshotSequence": 7,
      "projects": [{
        "id": "nightshade",
        "title": "Nightshade",
        "workspaceRoot": "/Users/example/nightshade",
        "repositoryIdentity": {
          "canonicalKey": "github.com/avail/nightshade",
          "displayName": "avail/nightshade",
          "owner": "avail",
          "name": "nightshade"
        }
      }],
      "threads": [
        {
          "id": "completed", "projectId": "nightshade", "title": "Done",
          "updatedAt": "2026-08-17T08:00:00Z", "latestTurn": {"state": "completed"}
        },
        {
          "id": "settled-failure", "projectId": "nightshade", "title": "Old failure",
          "updatedAt": "2026-08-17T09:00:00Z", "latestTurn": {"state": "error"},
          "settledOverride": "settled"
        },
        {
          "id": "blocked", "projectId": "nightshade", "title": "Needs approval",
          "updatedAt": "2026-08-17T10:00:00Z", "hasPendingApprovals": true,
          "settledOverride": "settled"
        },
        {
          "id": "failed", "projectId": "nightshade", "title": "Recovery",
          "updatedAt": "2026-08-17T09:30:00Z", "latestTurn": {"state": "error"},
          "branch": "agent/recovery", "worktreePath": "/Users/example/worktrees/recovery"
        },
        {
          "id": "kept-active", "projectId": "nightshade", "title": "Review",
          "updatedAt": "2026-08-17T09:15:00Z", "settledOverride": "active"
        },
        {
          "id": "archived", "projectId": "nightshade", "title": "Archived",
          "updatedAt": "2026-08-17T11:00:00Z", "session": {"status": "running"},
          "archivedAt": "2026-08-17T11:01:00Z"
        }
      ]
    }
    """#.data(using: .utf8)!

    return try JSONDecoder().decode(T3ShellSnapshot.self, from: json)
  }
}
