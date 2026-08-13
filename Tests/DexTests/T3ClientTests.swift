import Foundation
import Testing

@testable import Dex

struct T3ClientTests {
  @Test
  func extractsCredentialFromPairingFragment() {
    #expect(
      T3Client.pairingCredential(from: "http://127.0.0.1:3773/pair#token=read%2Dtoken")
        == "read-token"
    )
    #expect(T3Client.pairingCredential(from: "http://127.0.0.1:3773/pair") == nil)
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
