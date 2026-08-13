import Foundation
import Testing

@testable import Dex

struct T3ClientTests {
  @Test @MainActor
  func invalidPairingLinkProducesPersistentConnectionFeedback() async {
    let model = DexModel()
    let controller = T3ConnectionController(model: model)

    controller.connect(pairingLink: "2")
    await controller.refresh()

    #expect(
      model.connectionState
        == .incompatible(T3ClientError.invalidPairingLink.localizedDescription)
    )
  }

  @Test
  func extractsCredentialFromSupportedPairingURLs() {
    #expect(
      T3Client.pairingCredential(from: "http://127.0.0.1:3773/pair#token=read%2Dtoken")
        == "read-token"
    )
    #expect(
      T3Client.pairingCredential(from: "http://127.0.0.1:3773/pair?token=query-token")
        == "query-token"
    )
    #expect(T3Client.pairingCredential(from: "http://127.0.0.1:3773/pair") == nil)
    #expect(T3Client.pairingCredential(from: "not-a-url#token=read-token") == nil)
    #expect(T3Client.pairingCredential(from: "ftp://127.0.0.1/pair#token=read-token") == nil)
  }

  @Test
  func decodesUsageWhileIgnoringUnrelatedActivityPayloads() throws {
    let data = Data(
      #"""
      {
        "thread": {
          "activities": [
            {"kind":"tool.completed","payload":"not a usage object"},
            {
              "kind":"context-window.updated",
              "payload":{"usedTokens":82400,"maxTokens":128000}
            }
          ]
        }
      }
      """#.utf8
    )

    let snapshot = try JSONDecoder().decode(T3ThreadSnapshot.self, from: data)
    #expect(snapshot.thread.activities[0].payload == nil)
    #expect(snapshot.thread.activities[1].payload?.usedTokens == 82_400)
    #expect(snapshot.thread.activities[1].payload?.maxTokens == 128_000)
  }
}
