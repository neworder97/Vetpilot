import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCollection: String, Codable { case clinic, cytology
    var title: String { self == .clinic ? "My Clinic" : "Cytology" }
}
struct QRSharingLink: Equatable {
    let collection: QRCollection
    let token: String
    static func parse(_ text: String, expected: QRCollection? = nil) throws -> QRSharingLink {
        guard let c = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), c.scheme == "https", c.host == "vetpilotapp.org", c.port == nil || c.port == 443, c.user == nil, c.password == nil, c.query == nil, c.path == "/transfer", let fragment = c.fragment else { throw ClinicFileError.invalid("Scan or paste a valid VetPilot QR sharing link.") }
        let parts = fragment.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "v1", let collection = QRCollection(rawValue: String(parts[1])), parts[2].count == 43, parts[2].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { throw ClinicFileError.invalid("This is not a valid VetPilot QR sharing link.") }
        if let expected, expected != collection { throw ClinicFileError.invalid("Open this link in \(collection.title).") }
        return QRSharingLink(collection: collection, token: String(parts[2]))
    }
    static func image(_ link: String) throws -> UIImage {
        _ = try parse(link)
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(link.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage else { throw ClinicFileError.invalid("Unable to create QR image.") }
        let white = CIImage(color: CIColor.white).cropped(to: output.extent.insetBy(dx: -4, dy: -4))
        let padded = output.composited(over: white).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(padded, from: padded.extent) else { throw ClinicFileError.invalid("Unable to create QR image.") }
        return UIImage(cgImage: cg)
    }
}
struct QRSharedTransfer: Decodable, Identifiable {
    let id: UUID
    let collection: QRCollection
    let expiresAt: String
    let itemCount: Int
    let title: String
    var url: String?
    var expirationText: String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (f.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt))?.formatted(date: .abbreviated, time: .shortened) ?? expiresAt
    }
}
@MainActor enum QRTransferService {
    static func request(account: VetPilotAccount, action: String, collection: QRCollection, values: [String: Any] = [:]) async throws -> Data {
        guard let owner = account.userID, let c = account.configuration, let url = URL(string: c.url + "/functions/v1/vetpilot-transfer") else { throw ClinicFileError.invalid("Sign in to use QR sharing.") }
        var body = values; body["owner"] = owner.uuidString.lowercased(); body["action"] = action; body["collection"] = collection.rawValue
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue(c.publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(try await account.token())", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        guard (request.httpBody?.count ?? 0) <= 15_100_000 else { throw ClinicFileError.invalid("Transfer exceeds 15 MB. Select fewer items.") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard account.userID == owner else { throw ClinicFileError.invalid("Account changed. Reopen QR sharing.") }
        guard data.count <= 16_000_000 else { throw ClinicFileError.invalid("The sharing file is too large.") }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let details = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw ClinicFileError.invalid(details?["error"] as? String ?? "QR sharing unavailable. Reconnect and try again.")
        }
        return data
    }
    static func create(account: VetPilotAccount, collection: QRCollection, items: [ClinicProtocol]) async throws -> QRSharedTransfer {
        let data = try ClinicPackage(items: items).encoded(); try ClinicTransfer.validatePhotos(items)
        let object = try JSONSerialization.jsonObject(with: data)
        let response = try await request(account: account, action: "create", collection: collection, values: ["package": object])
        let share = try JSONDecoder().decode(QRSharedTransfer.self, from: response)
        guard share.collection == collection, let url = share.url else { throw ClinicFileError.invalid("Invalid sharing response.") }
        _ = try QRSharingLink.parse(url, expected: collection); return share
    }
    static func receive(account: VetPilotAccount, collection: QRCollection, link: String) async throws -> ClinicPackage {
        let parsed = try QRSharingLink.parse(link, expected: collection)
        let data = try await request(account: account, action: "resolve", collection: collection, values: ["token": parsed.token])
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["collection"] as? String == collection.rawValue, let package = object["package"] else { throw ClinicFileError.invalid("Invalid sharing file.") }
        let result = try ClinicPackage.decode(JSONSerialization.data(withJSONObject: package)); try ClinicTransfer.validatePhotos(result.items); return result
    }
    static func list(account: VetPilotAccount, collection: QRCollection) async throws -> [QRSharedTransfer] {
        struct Result: Decodable { let transfers: [QRSharedTransfer] }
        let data = try await request(account: account, action: "list", collection: collection)
        return try JSONDecoder().decode(Result.self, from: data).transfers
    }
    static func revoke(account: VetPilotAccount, collection: QRCollection, id: UUID) async throws { _ = try await request(account: account, action: "revoke", collection: collection, values: ["id": id.uuidString.lowercased()]) }
}
