import Foundation

enum T3StreamUpdate: Sendable {
  case shell(T3ShellStreamItem)
  case thread(id: String, item: T3ThreadStreamItem)
}

enum T3EventStreamError: LocalizedError, Equatable {
  case malformedFrame
  case streamEnded
  case serverFailure

  var errorDescription: String? {
    switch self {
    case .malformedFrame: "T3 Code sent an unreadable live-update frame."
    case .streamEnded: "The T3 Code live-update stream ended."
    case .serverFailure: "T3 Code rejected the live-update subscription."
    }
  }
}

enum T3RPCSubscription: Equatable, Sendable {
  case shell
  case thread(String)
}

enum T3RPCCodec {
  private struct Request<Payload: Encodable>: Encodable {
    let tag = "Request"
    let id: Int
    let method: String
    let payload: Payload
    let headers: [[String]] = []

    enum CodingKeys: String, CodingKey {
      case tag = "_tag"
      case id
      case method = "tag"
      case payload
      case headers
    }
  }

  private struct ShellPayload: Encodable {
    let afterSequence: Int?
  }

  private struct ThreadPayload: Encodable {
    let threadId: String
  }

  private struct RequestReference: Encodable {
    let tag: String
    let requestId: Int?

    enum CodingKeys: String, CodingKey {
      case tag = "_tag"
      case requestId
    }
  }

  private struct Header: Decodable {
    let tag: String
    let requestId: Int?

    enum CodingKeys: String, CodingKey {
      case tag = "_tag"
      case requestId
    }
  }

  private struct Chunk<Value: Decodable>: Decodable {
    let values: [Value]
  }

  static func subscribeShell(id: Int, afterSequence: Int?) throws -> Data {
    try JSONEncoder().encode(
      Request(
        id: id,
        method: "orchestration.subscribeShell",
        payload: ShellPayload(afterSequence: afterSequence)
      ))
  }

  static func subscribeThread(id: Int, threadId: String) throws -> Data {
    try JSONEncoder().encode(
      Request(
        id: id,
        method: "orchestration.subscribeThread",
        payload: ThreadPayload(threadId: threadId)
      ))
  }

  static func acknowledge(requestId: Int) throws -> Data {
    try JSONEncoder().encode(RequestReference(tag: "Ack", requestId: requestId))
  }

  static func interrupt(requestId: Int) throws -> Data {
    try JSONEncoder().encode(RequestReference(tag: "Interrupt", requestId: requestId))
  }

  static func ping() throws -> Data {
    try JSONEncoder().encode(RequestReference(tag: "Ping", requestId: nil))
  }

  static func decode(
    _ data: Data,
    subscriptions: [Int: T3RPCSubscription]
  ) throws -> (requestId: Int?, updates: [T3StreamUpdate]) {
    let decoder = JSONDecoder()
    let header = try decoder.decode(Header.self, from: data)
    switch header.tag {
    case "Pong":
      return (nil, [])
    case "Chunk":
      guard let requestId = header.requestId else {
        throw T3EventStreamError.malformedFrame
      }
      // An interrupted subscription can still have a buffered final chunk.
      // Acknowledge it without decoding after its routing entry is removed.
      guard let subscription = subscriptions[requestId] else {
        return (requestId, [])
      }
      switch subscription {
      case .shell:
        let chunk = try decoder.decode(Chunk<T3ShellStreamItem>.self, from: data)
        return (requestId, chunk.values.map(T3StreamUpdate.shell))
      case .thread(let id):
        let chunk = try decoder.decode(Chunk<T3ThreadStreamItem>.self, from: data)
        return (requestId, chunk.values.map { .thread(id: id, item: $0) })
      }
    case "Exit":
      if let requestId = header.requestId, subscriptions[requestId] == nil {
        return (nil, [])
      }
      throw T3EventStreamError.streamEnded
    case "Defect", "ClientProtocolError":
      throw T3EventStreamError.serverFailure
    default:
      throw T3EventStreamError.malformedFrame
    }
  }
}

actor T3EventStream {
  private let socket: URLSessionWebSocketTask
  private var receiveTask: Task<Void, Never>?
  private var pingTask: Task<Void, Never>?
  private var subscriptions: [Int: T3RPCSubscription] = [:]
  private var threadRequests: [String: Int] = [:]
  private var nextRequestId = 1

  init(url: URL, session: URLSession = .shared) {
    socket = session.webSocketTask(with: url)
  }

  func connect(afterSequence: Int?) async throws -> AsyncThrowingStream<T3StreamUpdate, Error> {
    socket.resume()
    let shellRequestId = allocateRequest(for: .shell)
    try await send(T3RPCCodec.subscribeShell(id: shellRequestId, afterSequence: afterSequence))

    let (stream, continuation) = AsyncThrowingStream<T3StreamUpdate, Error>.makeStream()
    receiveTask = Task { [weak self] in
      await self?.receive(into: continuation)
    }
    pingTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        try? await self?.send(T3RPCCodec.ping())
      }
    }
    continuation.onTermination = { @Sendable [weak self] _ in
      Task { await self?.close() }
    }
    return stream
  }

  func subscribe(to threadIds: Set<String>) async throws {
    let removed = Set(threadRequests.keys).subtracting(threadIds)
    for id in removed {
      guard let requestId = threadRequests.removeValue(forKey: id) else { continue }
      subscriptions.removeValue(forKey: requestId)
      try await send(T3RPCCodec.interrupt(requestId: requestId))
    }

    let added = threadIds.subtracting(threadRequests.keys)
    for id in added.sorted() {
      let requestId = allocateRequest(for: .thread(id))
      threadRequests[id] = requestId
      try await send(T3RPCCodec.subscribeThread(id: requestId, threadId: id))
    }
  }

  func close() {
    receiveTask?.cancel()
    pingTask?.cancel()
    receiveTask = nil
    pingTask = nil
    socket.cancel(with: .goingAway, reason: nil)
  }

  private func allocateRequest(for subscription: T3RPCSubscription) -> Int {
    defer { nextRequestId += 1 }
    subscriptions[nextRequestId] = subscription
    return nextRequestId
  }

  private func send(_ data: Data) async throws {
    try await socket.send(.data(data))
  }

  private func receive(
    into continuation: AsyncThrowingStream<T3StreamUpdate, Error>.Continuation
  ) async {
    do {
      while !Task.isCancelled {
        let message = try await socket.receive()
        let data: Data
        switch message {
        case .data(let value): data = value
        case .string(let value): data = Data(value.utf8)
        @unknown default: throw T3EventStreamError.malformedFrame
        }
        let decoded = try T3RPCCodec.decode(data, subscriptions: subscriptions)
        if let requestId = decoded.requestId {
          try await send(T3RPCCodec.acknowledge(requestId: requestId))
        }
        for update in decoded.updates {
          continuation.yield(update)
        }
      }
      continuation.finish()
    } catch is CancellationError {
      continuation.finish()
    } catch {
      continuation.finish(throwing: error)
    }
  }
}
