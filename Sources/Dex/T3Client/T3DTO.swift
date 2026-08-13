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
  let projects: [Project]
  let threads: [Thread]

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
  let thread: Thread

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
