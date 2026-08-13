import Foundation

struct T3RuntimeState: Decodable, Sendable {
  let version: Int
  let origin: URL
}

struct T3EnvironmentDescriptor: Decodable, Sendable {
  let label: String
  let serverVersion: String
}

struct T3ShellSnapshot: Decodable, Sendable {
  let snapshotSequence: Int
  let projects: [Project]
  let threads: [Thread]

  init(snapshotSequence: Int = 0, projects: [Project], threads: [Thread]) {
    self.snapshotSequence = snapshotSequence
    self.projects = projects
    self.threads = threads
  }

  private enum CodingKeys: String, CodingKey {
    case snapshotSequence
    case projects
    case threads
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    snapshotSequence = try container.decodeIfPresent(Int.self, forKey: .snapshotSequence) ?? 0
    projects = try container.decode([Project].self, forKey: .projects)
    threads = try container.decode([Thread].self, forKey: .threads)
  }

  struct Project: Decodable, Sendable {
    let id: String
    let title: String
  }

  struct Thread: Decodable, Sendable {
    let id: String
    let projectId: String
    let title: String
    let updatedAt: String
    let latestTurn: LatestTurn?
    let session: Session?
    let hasPendingApprovals: Bool?
    let hasPendingUserInput: Bool?
    let hasActionableProposedPlan: Bool?
    let backgroundLiveness: String?
    let planProgress: PlanProgress?
  }

  struct LatestTurn: Decodable, Sendable {
    let state: String
  }

  struct Session: Decodable, Sendable {
    let status: String
  }

  struct PlanProgress: Decodable, Sendable {
    let step: String
  }
}

struct T3ThreadSnapshot: Decodable, Sendable {
  let snapshotSequence: Int
  let thread: Thread

  private enum CodingKeys: String, CodingKey {
    case snapshotSequence
    case thread
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    snapshotSequence = try container.decodeIfPresent(Int.self, forKey: .snapshotSequence) ?? 0
    thread = try container.decode(Thread.self, forKey: .thread)
  }

  struct Thread: Decodable, Sendable {
    let activities: [Activity]
  }

  struct Activity: Decodable, Sendable {
    let kind: String
    let payload: UsagePayload?

    private enum CodingKeys: String, CodingKey {
      case kind
      case payload
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      kind = try container.decode(String.self, forKey: .kind)
      payload = try? container.decode(UsagePayload.self, forKey: .payload)
    }
  }

  struct UsagePayload: Decodable, Sendable {
    let usedTokens: Int?
    let maxTokens: Int?
  }
}

struct T3TokenExchangeResponse: Decodable, Sendable {
  let accessToken: String

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
  }
}

struct T3WebSocketTicketResponse: Decodable, Sendable {
  let ticket: String
}

struct T3ShellStreamItem: Decodable, Sendable {
  let kind: String
  let snapshot: T3ShellSnapshot?
  let sequence: Int?
  let project: T3ShellSnapshot.Project?
  let projectId: String?
  let thread: T3ShellSnapshot.Thread?
  let threadId: String?
}

struct T3ThreadStreamItem: Decodable, Sendable {
  let kind: String
  let snapshot: T3ThreadSnapshot?
  let event: Event?

  struct Event: Decodable, Sendable {
    let type: String
    let sequence: Int
    let payload: Payload
  }

  struct Payload: Decodable, Sendable {
    let activity: T3ThreadSnapshot.Activity?

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      activity = try? container.decode(T3ThreadSnapshot.Activity.self, forKey: .activity)
    }

    private enum CodingKeys: String, CodingKey {
      case activity
    }
  }
}
