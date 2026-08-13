import AppKit
import Foundation

@MainActor
final class T3ConnectionController {
  private let model: DexModel
  private let client: T3Client
  private let credentials: T3CredentialStore
  private var refreshTask: Task<Void, Never>?

  init(
    model: DexModel,
    client: T3Client = T3Client(),
    credentials: T3CredentialStore = T3CredentialStore()
  ) {
    self.model = model
    self.client = client
    self.credentials = credentials
  }

  func start() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await refresh()
        try? await Task.sleep(for: .seconds(3))
      }
    }
  }

  func connectFromPasteboard() {
    guard let pairingLink = NSPasteboard.general.string(forType: .string) else {
      model.updateConnection(.incompatible(T3ClientError.pairingLinkMissing.localizedDescription), threads: [])
      return
    }

    model.updateConnection(.connecting, threads: [])
    Task {
      do {
        let runtime = try client.discoverRuntime()
        _ = try await client.probe(origin: runtime.origin)
        let bearer = try await client.exchange(pairingLink: pairingLink, origin: runtime.origin)
        try credentials.save(bearer)
        await refresh()
      } catch {
        model.updateConnection(.incompatible(error.localizedDescription), threads: [])
      }
    }
  }

  private func refresh() async {
    do {
      let runtime = try client.discoverRuntime()
      _ = try await client.probe(origin: runtime.origin)
      guard let bearer = credentials.load() else {
        model.updateConnection(.disconnected, threads: [])
        return
      }

      let shell = try await client.shell(origin: runtime.origin, bearer: bearer)
      let visible = Self.relevantThreads(from: shell)
      var mapped: [DexThread] = []
      for thread in visible {
        let usage = try? await client.thread(
          origin: runtime.origin,
          id: thread.id,
          bearer: bearer
        )
        mapped.append(Self.map(thread, shell: shell, usage: usage))
      }
      let order = Dictionary(uniqueKeysWithValues: visible.enumerated().map { ($1.id, $0) })
      model.updateConnection(
        .connected,
        threads: mapped.sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
      )
    } catch T3ClientError.unauthorized {
      credentials.remove()
      model.updateConnection(.disconnected, threads: [])
    } catch T3ClientError.notRunning {
      model.updateConnection(.disconnected, threads: [])
    } catch {
      model.updateConnection(.incompatible(error.localizedDescription), threads: [])
    }
  }

  private static func relevantThreads(from shell: T3ShellSnapshot) -> [T3ShellSnapshot.Thread] {
    shell.threads
      .sorted {
        let lhs = activityPriority($0)
        let rhs = activityPriority($1)
        return lhs == rhs ? $0.updatedAt > $1.updatedAt : lhs < rhs
      }
      .prefix(4)
      .map { $0 }
  }

  private static func activityPriority(_ thread: T3ShellSnapshot.Thread) -> Int {
    if thread.hasPendingApprovals == true { return 0 }
    if thread.hasPendingUserInput == true { return 1 }
    if thread.session?.status == "running" || thread.session?.status == "starting" { return 2 }
    if thread.hasActionableProposedPlan == true { return 3 }
    if thread.backgroundLiveness == "working" { return 4 }
    if thread.backgroundLiveness == "monitoring" { return 5 }
    if thread.latestTurn?.state == "error" { return 6 }
    return 7
  }

  private static func map(
    _ thread: T3ShellSnapshot.Thread,
    shell: T3ShellSnapshot,
    usage: T3ThreadSnapshot?
  ) -> DexThread {
    let activity: ThreadActivity
    let detail: String
    if thread.hasPendingApprovals == true {
      activity = .needsApproval
      detail = "Waiting for approval"
    } else if thread.hasPendingUserInput == true {
      activity = .needsInput
      detail = "Waiting for input"
    } else if thread.session?.status == "running" || thread.session?.status == "starting" {
      activity = .working
      detail = thread.planProgress?.step ?? "Working"
    } else if thread.hasActionableProposedPlan == true {
      activity = .needsInput
      detail = "Plan ready"
    } else if thread.backgroundLiveness == "working" {
      activity = .working
      detail = thread.planProgress?.step ?? "Background work"
    } else if thread.backgroundLiveness == "monitoring" {
      activity = .monitoring
      detail = "Monitoring"
    } else if thread.latestTurn?.state == "error" {
      activity = .failed
      detail = "Failed"
    } else {
      activity = .completed
      detail = "Done"
    }

    let context = usage?.thread.activities.reversed().first { $0.kind == "context-window.updated" }?.payload
    let project = shell.projects.first { $0.id == thread.projectId }?.title ?? "T3 Code"
    return DexThread(
      id: thread.id,
      title: thread.title,
      project: project,
      detail: detail,
      activity: activity,
      usedTokens: context?.usedTokens ?? 0,
      maximumTokens: context?.maxTokens
    )
  }
}
