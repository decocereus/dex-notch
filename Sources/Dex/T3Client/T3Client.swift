import Foundation

enum T3ClientError: LocalizedError, Equatable {
  case notRunning
  case invalidRuntime
  case pairingLinkMissing
  case invalidPairingLink
  case unauthorized
  case incompatible
  case requestFailed(Int)
  case keychain(OSStatus)

  var errorDescription: String? {
    switch self {
    case .notRunning: "T3 Code is not running."
    case .invalidRuntime: "T3 Code published an invalid runtime descriptor."
    case .pairingLinkMissing: "Copy a T3 pairing link, then try again."
    case .invalidPairingLink: "The clipboard does not contain a valid T3 pairing link."
    case .unauthorized: "Dex needs a new read-only T3 pairing."
    case .incompatible: "This T3 Code build does not expose the required read API."
    case .requestFailed(let status): "T3 Code returned HTTP \(status)."
    case .keychain(let status): "Keychain returned status \(status)."
    }
  }
}

struct T3Client: Sendable {
  private let session: URLSession
  private let decoder = JSONDecoder()

  init(session: URLSession = .shared) {
    self.session = session
  }

  func discoverRuntime() throws -> T3RuntimeState {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let candidates = [
      home.appending(path: ".t3/userdata/server-runtime.json"),
      home.appending(path: ".t3/dev/server-runtime.json"),
    ]

    for url in candidates where FileManager.default.fileExists(atPath: url.path) {
      let runtime = try decoder.decode(T3RuntimeState.self, from: Data(contentsOf: url))
      guard runtime.version == 1 else { throw T3ClientError.invalidRuntime }
      return runtime
    }
    throw T3ClientError.notRunning
  }

  func probe(origin: URL) async throws -> T3EnvironmentDescriptor {
    try await get(origin.appending(path: ".well-known/t3/environment"), bearer: nil)
  }

  func exchange(pairingLink: String, origin: URL) async throws -> String {
    guard let credential = Self.pairingCredential(from: pairingLink) else {
      throw T3ClientError.invalidPairingLink
    }

    var request = URLRequest(url: origin.appending(path: "oauth/token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let fields = [
      "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
      "subject_token": credential,
      "subject_token_type": "urn:t3:params:oauth:token-type:environment-bootstrap",
      "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
      "scope": "orchestration:read",
      "client_label": "Dex",
      "client_device_type": "desktop",
      "client_os": "macOS",
    ]
    request.httpBody =
      fields
      .map { key, value in "\(Self.formEncode(key))=\(Self.formEncode(value))" }
      .sorted()
      .joined(separator: "&")
      .data(using: .utf8)

    let response: T3TokenExchangeResponse = try await execute(request)
    return response.accessToken
  }

  func shell(origin: URL, bearer: String) async throws -> T3ShellSnapshot {
    try await get(origin.appending(path: "api/orchestration/shell"), bearer: bearer)
  }

  func thread(origin: URL, id: String, bearer: String) async throws -> T3ThreadSnapshot {
    try await get(origin.appending(path: "api/orchestration/threads/\(id)"), bearer: bearer)
  }

  func webSocketURL(origin: URL, bearer: String) async throws -> URL {
    var request = URLRequest(url: origin.appending(path: "api/auth/websocket-ticket"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    let response: T3WebSocketTicketResponse = try await execute(request)

    guard var components = URLComponents(url: origin, resolvingAgainstBaseURL: false) else {
      throw T3ClientError.invalidRuntime
    }
    switch components.scheme?.lowercased() {
    case "http": components.scheme = "ws"
    case "https": components.scheme = "wss"
    default: throw T3ClientError.invalidRuntime
    }
    components.path = "/ws"
    components.queryItems = [URLQueryItem(name: "wsTicket", value: response.ticket)]
    guard let url = components.url else { throw T3ClientError.invalidRuntime }
    return url
  }

  static func pairingCredential(from value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let components = URLComponents(string: trimmed),
      let scheme = components.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      components.host != nil
    else { return nil }

    if let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
      !token.isEmpty
    {
      return token
    }

    guard let fragment = components.fragment,
      let fragmentComponents = URLComponents(string: "?\(fragment)"),
      let token = fragmentComponents.queryItems?.first(where: { $0.name == "token" })?.value,
      !token.isEmpty
    else { return nil }
    return token
  }

  private func get<Value: Decodable>(_ url: URL, bearer: String?) async throws -> Value {
    var request = URLRequest(url: url)
    if let bearer {
      request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    return try await execute(request)
  }

  private func execute<Value: Decodable>(_ request: URLRequest) async throws -> Value {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw T3ClientError.incompatible }
    if http.statusCode == 401 || http.statusCode == 403 { throw T3ClientError.unauthorized }
    guard (200..<300).contains(http.statusCode) else {
      throw T3ClientError.requestFailed(http.statusCode)
    }
    do {
      return try decoder.decode(Value.self, from: data)
    } catch {
      throw T3ClientError.incompatible
    }
  }

  private static func formEncode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
  }
}
