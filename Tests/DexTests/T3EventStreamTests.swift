import Foundation
import Testing

@testable import Dex

@Suite("T3 live event stream")
struct T3EventStreamTests {
  @Test("encodes the official Effect RPC shell subscription envelope")
  func encodesShellSubscription() throws {
    let data = try T3RPCCodec.subscribeShell(id: 7, afterSequence: 42)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let payload = try #require(object["payload"] as? [String: Any])

    #expect(object["_tag"] as? String == "Request")
    #expect(object["id"] as? Int == 7)
    #expect(object["tag"] as? String == "orchestration.subscribeShell")
    #expect(payload["afterSequence"] as? Int == 42)
    #expect((object["headers"] as? [Any])?.isEmpty == true)
  }

  @Test("decodes shell updates from a streamed RPC chunk")
  func decodesShellUpdate() throws {
    let data = Data(
      #"{"_tag":"Chunk","requestId":1,"values":[{"kind":"thread-upserted","sequence":9,"thread":{"id":"thread-1","projectId":"project-1","title":"Build Dex","updatedAt":"2026-08-13T10:00:00.000Z"}}]}"#
        .utf8
    )

    let decoded = try T3RPCCodec.decode(data, subscriptions: [1: .shell])
    #expect(decoded.requestId == 1)
    guard case .shell(let item) = try #require(decoded.updates.first) else {
      Issue.record("Expected a shell update")
      return
    }
    #expect(item.kind == "thread-upserted")
    #expect(item.sequence == 9)
    #expect(item.thread?.id == "thread-1")
  }

  @Test("decodes context usage from a thread subscription")
  func decodesThreadUsage() throws {
    let data = Data(
      #"{"_tag":"Chunk","requestId":2,"values":[{"kind":"event","event":{"type":"thread.activity-appended","sequence":10,"payload":{"activity":{"kind":"context-window.updated","payload":{"usedTokens":82400,"maxTokens":128000}}}}}]}"#
        .utf8
    )

    let decoded = try T3RPCCodec.decode(data, subscriptions: [2: .thread("thread-1")])
    guard case .thread(let id, let item) = try #require(decoded.updates.first) else {
      Issue.record("Expected a thread update")
      return
    }
    #expect(id == "thread-1")
    #expect(item.event?.payload.activity?.kind == "context-window.updated")
    #expect(item.event?.payload.activity?.payload?.usedTokens == 82_400)
    #expect(item.event?.payload.activity?.payload?.maxTokens == 128_000)
  }

  @Test("ignores the terminal response for an interrupted subscription")
  func ignoresInterruptedSubscriptionExit() throws {
    let data = Data(
      #"{"_tag":"Exit","requestId":3,"exit":{"_tag":"Success","value":null}}"#.utf8
    )

    let decoded = try T3RPCCodec.decode(data, subscriptions: [1: .shell])
    #expect(decoded.requestId == nil)
    #expect(decoded.updates.isEmpty)
  }
}
