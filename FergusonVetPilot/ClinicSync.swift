import Foundation

struct ClinicSyncState: Codable {
    var items: [ClinicProtocol] = []
    var baseline: [ClinicProtocol] = []
    var version = 0
}

/// Three-way merge: absence represents deletion; concurrent edits preserve both copies.
enum ClinicMerge {
    static func merge(local: [ClinicProtocol], base: [ClinicProtocol], remote: [ClinicProtocol]) -> [ClinicProtocol] {
        let l = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let b = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        let r = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        var result: [ClinicProtocol] = []
        for id in Set(l.keys).union(b.keys).union(r.keys).sorted(by: { $0.uuidString < $1.uuidString }) {
            if l[id] == b[id] { if let item = r[id] { result.append(item) } }
            else if r[id] == b[id] || l[id] == r[id] { if let item = l[id] { result.append(item) } }
            else {
                if let item = r[id] { result.append(item) }
                if var copy = l[id] {
                    copy.id = UUID(); copy.sourceID = id
                    copy.title = String(copy.title.prefix(180)) + " (conflict copy)"
                    copy.reviewer = ""; copy.reviewedOn = ""
                    result.append(copy)
                }
            }
        }
        return result
    }
}
