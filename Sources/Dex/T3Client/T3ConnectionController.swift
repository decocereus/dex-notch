import AppKit
import Foundation

@MainActor
final class T3ConnectionController {
  private let model: DexModel
  private let client: T3Client
  private let credentials: T3CredentialStore
  private var sessionCredential = T3SessionCredential()
  private var connectionTask: Task<Void, Never>?
  private var shellSnapshot: T3ShellSnapshot?
  private var usageByThread: [String: T3ThreadSnapshot.UsagePayload] = [:]
  private var activeOrigin: URL?
  private var activeBearer: String?

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
    connectionTask?.cancel()
    connectionTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await refresh()
        guard let origin = activeOrigin, let bearer = activeBearer else {
          try? await Task.sleep(for: .seconds(3))
          continue
        }

        do {
          try await runLiveStream(origin: origin, bearer: bearer)
        } catch T3ClientError.unauthorized {
          invalidateCredential()
        } catch {
          // A fresh HTTP snapshot on the next iteration covers connection loss
          // and older T3 builds that do not expose bearer-authenticated streams.
        }
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  func connectFromPasteboard() {
    connect(pairingLink: NSPasteboard.general.string(forType: .string))
  }

  func connect(pairingLink: String?) {
    guard let pairingLink else {
      model.updateConnection(
        .incompatible(T3ClientError.pairingLinkMissing.localizedDescription), threads: [])
      return
    }
    guard T3Client.pairingCredential(from: pairingLink) != nil else {
      model.updateConnection(
        .incompatible(T3ClientError.invalidPairingLink.localizedDescription), threads: [])
      return
    }

    model.updateConnection(.connecting, threads: [])
    Task {
      do {
        let runtime = try client.discoverRuntime()
        _ = try await client.probe(origin: runtime.origin)
        let bearer = try await client.exchange(pairingLink: pairingLink, origin: runtime.origin)
        try credentials.save(bearer)
        sessionCredential.replace(with: bearer)
        await refresh(preservingConnectionFeedback: false)
      } catch {
        model.updateConnection(.incompatible(error.localizedDescription), threads: [])
      }
    }
  }

  func refresh(preservingConnectionFeedback: Bool = true) async {
    if preservingConnectionFeedback, model.connectionState.isConnectionFeedback {
      return
    }

    do {
      let runtime = try client.discoverRuntime()
      _ = try await client.probe(origin: runtime.origin)
      guard let bearer = sessionCredential.value(load: credentials.load) else {
        clearLiveState()
        model.updateConnection(.disconnected, threads: [])
        return
      }

      let shell = try await client.shell(origin: runtime.origin, bearer: bearer)
      let visible = Self.relevantThreads(from: shell)
      var usage: [String: T3ThreadSnapshot.UsagePayload] = [:]
      for thread in visible {
        let snapshot = try? await client.thread(
          origin: runtime.origin,
          id: thread.id,
          bearer: bearer
        )
        if let context = Self.contextUsage(from: snapshot) {
          usage[thread.id] = context
        }
      }
      shellSnapshot = shell
      usageByThread = usage
      activeOrigin = runtime.origin
      activeBearer = bearer
      updateModel()
    } catch T3ClientError.unauthorized {
      invalidateCredential()
    } catch T3ClientError.notRunning {
      clearLiveState()
      model.updateConnection(.disconnected, threads: [])
    } catch {
      model.updateConnection(.incompatible(error.localizedDescription), threads: [])
    }
  }

  private func runLiveStream(origin: URL, bearer: String) async throws {
    let url = try await client.webSocketURL(origin: origin, bearer: bearer)
    let streamClient = T3EventStream(url: url)
    let updates = try await streamClient.connect(afterSequence: shellSnapshot?.snapshotSequence)

    do {
      try await updateSubscriptions(on: streamClient)
      for try await update in updates {
        switch update {
        case .shell(let item):
          apply(item)
          try await updateSubscriptions(on: streamClient)
        case .thread(let id, let item):
          apply(item, to: id)
        }
        updateModel()
      }
      await streamClient.close()
    } catch {
      await streamClient.close()
      throw error
    }
  }

  private func updateSubscriptions(on client: T3EventStream) async throws {
    guard let shellSnapshot else { return }
    let ids = Set(Self.relevantThreads(from: shellSnapshot).map(\.id))
    try await client.subscribe(to: ids)
  }

  private func apply(_ item: T3ShellStreamItem) {
    if item.kind == "snapshot", let snapshot = item.snapshot {
      shellSnapshot = snapshot
      return
    }
    guard let current = shellSnapshot, let sequence = item.sequence,
      sequence > current.snapshotSequence
    else { return }

    var projects = current.projects
    var threads = current.threads
    switch item.kind {
    case "project-upserted":
      guard let project = item.project else { return }
      if let index = projects.firstIndex(where: { $0.id == project.id }) {
        projects[index] = project
      } else {
        projects.append(project)
      }
    case "project-removed":
      guard let projectId = item.projectId else { return }
      projects.removeAll { $0.id == projectId }
    case "thread-upserted":
      guard let thread = item.thread else { return }
      if let index = threads.firstIndex(where: { $0.id == thread.id }) {
        threads[index] = thread
      } else {
        threads.append(thread)
      }
    case "thread-removed":
      guard let threadId = item.threadId else { return }
      threads.removeAll { $0.id == threadId }
      usageByThread.removeValue(forKey: threadId)
    default:
      return
    }
    shellSnapshot = T3ShellSnapshot(
      snapshotSequence: sequence,
      projects: projects,
      threads: threads
    )
  }

  private func apply(_ item: T3ThreadStreamItem, to threadId: String) {
    if let snapshot = item.snapshot, let usage = Self.contextUsage(from: snapshot) {
      usageByThread[threadId] = usage
      return
    }
    guard item.kind == "event", item.event?.type == "thread.activity-appended",
      let activity = item.event?.payload.activity,
      activity.kind == "context-window.updated",
      let usage = activity.payload
    else { return }
    usageByThread[threadId] = usage
  }

  private func updateModel() {
    guard let shellSnapshot else {
      model.updateConnection(.disconnected, threads: [])
      return
    }
    let mapped = Self.relevantThreads(from: shellSnapshot).map {
      Self.map($0, shell: shellSnapshot, usage: usageByThread[$0.id])
    }
    model.updateConnection(.connected, threads: mapped)
  }

  private func invalidateCredential() {
    sessionCredential.replace(with: nil)
    credentials.remove()
    clearLiveState()
    model.updateConnection(.disconnected, threads: [])
  }

  private func clearLiveState() {
    activeOrigin = nil
    activeBearer = nil
    shellSnapshot = nil
    usageByThread = [:]
  }

  static func relevantThreads(from shell: T3ShellSnapshot) -> [T3ShellSnapshot.Thread] {
    shell.threads
      .filter(isUnresolvedWork)
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
    if thread.hasActionableProposedPlan == true { return 2 }
    if thread.latestTurn?.state == "error" { return 3 }
    if thread.session?.status == "running" || thread.session?.status == "starting" { return 4 }
    if thread.backgroundLiveness == "working" { return 4 }
    if thread.backgroundLiveness == "monitoring" { return 5 }
    return 6
  }

  private static func isUnresolvedWork(_ thread: T3ShellSnapshot.Thread) -> Bool {
    guard thread.archivedAt == nil else { return false }

    // T3's settled resolver treats human blockers and a live session as
    // authoritative activity, even across an explicit settle boundary.
    if thread.hasPendingApprovals == true || thread.hasPendingUserInput == true {
      return true
    }
    if thread.session?.status == "running" || thread.session?.status == "starting" {
      return true
    }
    guard thread.settledOverride != "settled" else { return false }

    return thread.hasActionableProposedPlan == true
      || thread.backgroundLiveness == "working"
      || thread.backgroundLiveness == "monitoring"
      || thread.latestTurn?.state == "error"
      || thread.settledOverride == "active"
  }

  static func map(
    _ thread: T3ShellSnapshot.Thread,
    shell: T3ShellSnapshot,
    usage: T3ThreadSnapshot.UsagePayload?
  ) -> DexThread {
    let activity: ThreadActivity
    let detail: String
    if thread.hasPendingApprovals == true {
      activity = .needsApproval
      detail = "Waiting for approval"
    } else if thread.hasPendingUserInput == true {
      activity = .needsInput
      detail = "Waiting for input"
    } else if thread.hasActionableProposedPlan == true {
      activity = .needsInput
      detail = "Plan ready"
    } else if thread.latestTurn?.state == "error" {
      activity = .failed
      detail = "Failed"
    } else if thread.session?.status == "running" || thread.session?.status == "starting" {
      activity = .working
      detail = thread.planProgress?.step ?? "Working"
    } else if thread.backgroundLiveness == "working" {
      activity = .working
      detail = thread.planProgress?.step ?? "Background work"
    } else if thread.backgroundLiveness == "monitoring" {
      activity = .monitoring
      detail = "Monitoring"
    } else {
      activity = .monitoring
      detail = "Kept active"
    }

    let projectSnapshot = shell.projects.first { $0.id == thread.projectId }
    let project = projectSnapshot?.title ?? "T3 Code"
    let identity = projectSnapshot?.repositoryIdentity
    let repository = identity?.displayName
      ?? [identity?.owner, identity?.name].compactMap { $0 }.joined(separator: "/").nonEmpty
      ?? identity?.name
      ?? project
    return DexThread(
      id: thread.id,
      title: thread.title,
      project: project,
      repository: repository,
      branch: thread.branch,
      worktreePath: thread.worktreePath ?? projectSnapshot?.workspaceRoot,
      detail: detail,
      activity: activity,
      usedTokens: usage?.usedTokens ?? 0,
      maximumTokens: usage?.maxTokens
    )
  }

  private static func contextUsage(
    from snapshot: T3ThreadSnapshot?
  ) -> T3ThreadSnapshot.UsagePayload? {
    snapshot?.thread.activities.reversed().first { $0.kind == "context-window.updated" }?.payload
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}

extension DexModel.ConnectionState {
  fileprivate var isConnectionFeedback: Bool {
    switch self {
    case .connecting, .incompatible:
      true
    case .disconnected, .connected:
      false
    }
  }
}
