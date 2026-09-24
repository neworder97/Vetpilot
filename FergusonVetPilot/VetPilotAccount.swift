import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Security
import UIKit

struct VetPilotCloudConfiguration: Decodable {
    var url: String
    var publishableKey: String
    static let current: Self? = {
        guard let file = Bundle.main.url(forResource: "VetPilotCloud", withExtension: "json"),
              let data = try? Data(contentsOf: file), var value = try? JSONDecoder().decode(Self.self, from: data),
              let url = URL(string: value.url), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, ["", "/"].contains(url.path),
              !value.publishableKey.isEmpty else { return nil }
        guard !value.publishableKey.hasPrefix("sb_secret_") else { return nil }
        value.url = value.url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return value
    }()
}

private enum AccountKeychain {
    static let service = "com.ferguson.vetpilot.account"
    static func read() -> Data? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: "session", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
    static func save(_ data: Data?) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        guard let data else { SecItemDelete(query as CFDictionary); return }
        let values: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if updated == errSecItemNotFound {
            guard SecItemAdd(query.merging(values, uniquingKeysWith: { _, rhs in rhs }) as CFDictionary, nil) == errSecSuccess else {
                throw ScribeError.invalid("The account session could not be stored securely.")
            }
        } else if updated != errSecSuccess { throw ScribeError.invalid("The account session could not be updated securely.") }
    }
}

struct VetPilotSession: Codable {
    struct User: Codable { var id: UUID; var email: String? }
    var access_token: String
    var refresh_token: String
    var expires_in: Double
    var expires_at: Double?
    var user: User
    var receivedAt: Date?
    var origin: String?
    var expiry: Date { expires_at.map(Date.init(timeIntervalSince1970:)) ?? (receivedAt ?? .distantPast).addingTimeInterval(expires_in) }
}

@MainActor
final class VetPilotAccount: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var session: VetPilotSession?
    @Published var busy = false
    @Published var error: String?
    private var authentication: ASWebAuthenticationSession?
    private var authContinuation: CheckedContinuation<URL, Error>?
    private var refreshTask: Task<VetPilotSession, Error>?
    let configuration: VetPilotCloudConfiguration?
    var configured: Bool { configuration != nil }
    var userID: UUID? { session?.user.id }
    var email: String { session?.user.email ?? "Signed-in account" }
    init(configuration: VetPilotCloudConfiguration? = .current) {
        #if DEBUG
        let configuration = ProcessInfo.processInfo.arguments.contains("ui-no-cloud") ? nil : configuration
        #endif
        self.configuration = configuration
        super.init()
        if let configuration, let data = AccountKeychain.read(), let stored = try? JSONDecoder().decode(VetPilotSession.self, from: data), stored.origin == configuration.url { session = stored }
    }
    private func accept(_ value: VetPilotSession) throws {
        var value = value; value.receivedAt = Date(); value.origin = configuration?.url
        try AccountKeychain.save(JSONEncoder().encode(value)); session = value
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    private func randomVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw ScribeError.invalid("Secure sign-in could not start.") }
        return Self.base64url(Data(bytes))
    }
    private static func base64url(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    private func finishAuthentication(_ result: Result<URL, Error>) {
        guard let continuation = authContinuation else { return }; authContinuation = nil; continuation.resume(with: result)
    }
    func signIn(provider: String) async {
        guard !busy else { return }
        guard let configuration, ["google", "apple"].contains(provider) else { error = "Account service is not connected in this build."; return }
        busy = true; defer { busy = false; authentication = nil }
        do {
            let verifier = try randomVerifier()
            let challenge = Self.base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
            var components = URLComponents(string: configuration.url + "/auth/v1/authorize")!
            components.queryItems = [.init(name: "provider", value: provider), .init(name: "redirect_to", value: "vetpilot://auth/callback"),
                                     .init(name: "code_challenge", value: challenge), .init(name: "code_challenge_method", value: "s256")]
            let callback: URL = try await withCheckedThrowingContinuation { continuation in
                authContinuation = continuation
                let flow = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "vetpilot") { url, error in
                    Task { @MainActor in
                        if let url { self.finishAuthentication(.success(url)) }
                        else { self.finishAuthentication(.failure(error ?? ScribeError.invalid("Sign-in was cancelled."))) }
                    }
                }
                authentication = flow; flow.presentationContextProvider = self; flow.prefersEphemeralWebBrowserSession = true
                if !flow.start() { finishAuthentication(.failure(ScribeError.invalid("Sign-in could not open. Try again."))) }
            }
            guard callback.scheme == "vetpilot", callback.host == "auth", callback.path == "/callback",
                  let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
                throw ScribeError.invalid("Sign-in did not return a valid authorization code.")
            }
            let data = try await request(path: "auth/v1/token?grant_type=pkce", method: "POST", body: ["auth_code": code, "code_verifier": verifier], authenticated: false)
            try accept(JSONDecoder().decode(VetPilotSession.self, from: data))
        } catch { self.error = error.localizedDescription }
    }
    @Published var notice: String?
    func authenticate(email: String, password: String, create: Bool) async {
        guard !busy else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.count <= 254, !password.isEmpty,
              password.utf8.count <= 1024, !create || password.count >= 12 else {
            error = "Enter your email and password. New passwords need at least 12 characters."; return
        }
        busy = true; error = nil; notice = nil; defer { busy = false }
        do {
            let data = try await request(path: create ? "auth/v1/signup" : "auth/v1/token?grant_type=password",
                                         method: "POST", body: ["email": email, "password": password], authenticated: false)
            if let value = try? JSONDecoder().decode(VetPilotSession.self, from: data) { try accept(value) }
            else if create { notice = "Check your email to confirm your account, then sign in here or on the website." }
            else { throw ScribeError.invalid("Sign-in did not return a valid session.") }
        } catch { self.error = error.localizedDescription }
    }
    func token() async throws -> String {
        guard let session else { throw ScribeError.invalid("Sign in before using cloud services.") }
        if session.expiry.timeIntervalSinceNow > 60 { return session.access_token }
        if let refreshTask { return try await refreshTask.value.access_token }
        let task = Task { @MainActor in
            let data = try await self.request(path: "auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": session.refresh_token], authenticated: false)
            return try JSONDecoder().decode(VetPilotSession.self, from: data)
        }
        refreshTask = task; defer { refreshTask = nil }
        let updated = try await task.value; try accept(updated); return updated.access_token
    }
    func signOut() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        if configured, session != nil { _ = try? await request(path: "auth/v1/logout?scope=local", method: "POST") }
        do { try AccountKeychain.save(nil); session = nil } catch { self.error = error.localizedDescription }
    }
    func deleteAccount() async throws {
        guard !busy else { throw ScribeError.invalid("Wait for the current account operation.") }
        busy = true; defer { busy = false }
        _ = try await request(path: "functions/v1/vetpilot-account", method: "POST", body: ["action": "delete"])
        try AccountKeychain.save(nil); session = nil
    }
    func request(path: String, method: String = "GET", body: [String: Any]? = nil, authenticated: Bool = true) async throws -> Data {
        guard let configuration, let url = URL(string: configuration.url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else {
            throw ScribeError.invalid("Cloud services are not connected in this build. Local recording and editing remain available.")
        }
        var request = URLRequest(url: url); request.httpMethod = method; request.timeoutInterval = 180
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        if authenticated { request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 409 { throw ScribeError.invalid("A newer cloud copy exists. Download it as a separate copy before syncing again.") }
            if !authenticated && (status == 400 || status == 422) { throw ScribeError.invalid("Check your email, password and email confirmation, then try again.") }
            if status == 401 { throw ScribeError.invalid("Your sign-in has expired. Sign in again; local notes are preserved.") }
            if status == 429 { throw ScribeError.invalid("The service usage limit was reached. Try again later; the recording is preserved.") }
            throw ScribeError.invalid("The cloud service could not complete this request (\(status)). Your local data is preserved.")
        }
        guard data.count <= 20_000_000 else { throw ScribeError.invalid("The cloud response is too large.") }
        return data
    }
}
