import XCTest
@testable import FergusonVetPilot

@MainActor
private final class AnnotationCloud: WorkspaceSyncAccount {
    var userID: UUID?
    var items: [WorkspaceRecord] = []
    var version = 0
    var offline = false
    var requests = 0
    var uploads = 0
    var lastPayload: [[String: Any]] = []
    var beforeSave: (() async -> Void)?

    init(owner: UUID) { userID = owner }

    func request(path: String, method: String, body: [String: Any]?, authenticated: Bool) async throws -> Data {
        requests += 1
        XCTAssertTrue(authenticated)
        if offline { throw URLError(.notConnectedToInternet) }
        if method == "GET" {
            XCTAssertEqual(path, "rest/v1/workspace_collections?select=version,items")
            struct Row: Encodable { var version: Int; var items: [WorkspaceRecord] }
            return try JSONEncoder().encode(version == 0 ? [] : [Row(version: version, items: items)])
        }
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(path, "rest/v1/rpc/save_workspace_collection")
        let expected = try XCTUnwrap(body?["expected_version"] as? Int)
        let payload = try XCTUnwrap(body?["collection_items"] as? [[String: Any]])
        if let hook = beforeSave { beforeSave = nil; await hook() }
        guard expected == version else { throw URLError(.badServerResponse) }
        items = try JSONDecoder().decode([WorkspaceRecord].self, from: JSONSerialization.data(withJSONObject: payload))
        lastPayload = payload
        uploads += 1; version += 1
        return try JSONEncoder().encode(version)
    }
}

@MainActor
final class AnnotationSyncTests: XCTestCase {
    private func key(_ owner: UUID) -> String { "vetpilot." + owner.uuidString.lowercased() + ".workspace.v1" }
    private func mark(_ shape: String, photo: UUID) -> WorkspaceRecord {
        WorkspaceRecord(title: "Test image", kind: "annotation", target: "photo|" + photo.uuidString.lowercased(),
            value: ["shape": .string(shape), "label": .string(shape == "label" ? "Test label" : ""),
                    "x": .number(0.15), "y": .number(0.25), "x2": .number(0.65), "y2": .number(0.75)])
    }

    func testArrowCircleAndLabelUploadWithWebsitePhotoKeysAndReload() async throws {
        let owner = UUID(), photo = UUID(), cloud = AnnotationCloud(owner: owner)
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        let marks = ["arrow", "circle", "label"].map { mark($0, photo: photo) }
        for value in marks { XCTAssertTrue(app.save(value)) }
        await app.sync(account: cloud)
        XCTAssertEqual(Set(cloud.items.map(\.id)), Set(marks.map(\.id)))
        XCTAssertEqual(app.state.items, app.state.baseline)
        for wire in cloud.lastPayload {
            XCTAssertEqual(wire["kind"] as? String, "annotation")
            XCTAssertEqual(wire["target"] as? String, "photo|" + photo.uuidString.lowercased())
            let value = try XCTUnwrap(wire["value"] as? [String: Any])
            XCTAssertEqual(value["x"] as? Double, 0.15)
            XCTAssertEqual(value["y2"] as? Double, 0.75)
        }
        let reopened = WorkspaceStore(); reopened.switchAccount(owner)
        XCTAssertEqual(reopened.records, app.records)
        // An empty second client receives the same editable marks from the cloud.
        UserDefaults.standard.removeObject(forKey: key(owner))
        let second = WorkspaceStore(); second.switchAccount(owner)
        await second.sync(account: cloud)
        XCTAssertEqual(second.records, app.records)
        XCTAssertEqual(cloud.uploads, 1)
    }

    func testOfflineAnnotationsSurviveRestartAndRetry() async {
        let owner = UUID(), cloud = AnnotationCloud(owner: owner)
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        let arrow = mark("arrow", photo: UUID())
        XCTAssertTrue(app.save(arrow)); cloud.offline = true
        await app.sync(account: cloud)
        XCTAssertEqual(app.records, [arrow])
        XCTAssertTrue(app.status.contains("sync pending"))
        XCTAssertTrue(cloud.items.isEmpty)
        let reopened = WorkspaceStore(); reopened.switchAccount(owner)
        cloud.offline = false
        await reopened.sync(account: cloud)
        XCTAssertEqual(cloud.items, [arrow])
        XCTAssertEqual(reopened.state.items, reopened.state.baseline)
    }

    func testEditDuringUploadIsUploadedBeforeSyncFinishes() async {
        let owner = UUID(), cloud = AnnotationCloud(owner: owner)
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        var arrow = mark("arrow", photo: UUID())
        XCTAssertTrue(app.save(arrow))
        arrow.value["x2"] = .number(0.9); arrow.updatedAt += 1
        let edited = arrow
        cloud.beforeSave = {
            XCTAssertTrue(app.save(edited))
            await app.sync(account: cloud) // A concurrent save request must not be lost.
        }
        await app.sync(account: cloud)
        XCTAssertEqual(cloud.items, [edited])
        XCTAssertEqual(app.records, [edited])
        XCTAssertEqual(app.state.baseline, [edited])
        XCTAssertEqual(cloud.uploads, 2)
    }

    func testRemovalDuringUploadAndRemoteEditBothSync() async {
        let owner = UUID(), cloud = AnnotationCloud(owner: owner)
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        let arrow = mark("arrow", photo: UUID())
        XCTAssertTrue(app.save(arrow))
        cloud.beforeSave = { app.remove(arrow.id) }
        await app.sync(account: cloud)
        XCTAssertTrue(cloud.items.isEmpty)
        XCTAssertTrue(app.records.isEmpty)
        XCTAssertEqual(cloud.uploads, 2)
        // A website-created mark is downloaded, then a local removal reaches it.
        let circle = mark("circle", photo: UUID())
        cloud.items = [circle]; cloud.version += 1
        await app.sync(account: cloud)
        XCTAssertEqual(app.records, [circle])
        app.remove(circle.id)
        await app.sync(account: cloud)
        XCTAssertTrue(cloud.items.isEmpty)
    }

    func testAccountSwitchDoesNotApplyAnOldAcknowledgementToNewOwner() async {
        let owner = UUID(), other = UUID(), cloud = AnnotationCloud(owner: owner)
        defer {
            UserDefaults.standard.removeObject(forKey: key(owner))
            UserDefaults.standard.removeObject(forKey: key(other))
        }
        let app = WorkspaceStore(); app.switchAccount(owner)
        let arrow = mark("arrow", photo: UUID()), circle = mark("circle", photo: UUID())
        XCTAssertTrue(app.save(arrow))
        cloud.beforeSave = {
            cloud.userID = other; app.switchAccount(other)
            XCTAssertTrue(app.save(circle))
        }
        await app.sync(account: cloud)
        XCTAssertEqual(app.records, [circle])
        XCTAssertTrue(app.state.baseline.isEmpty)
        XCTAssertEqual(app.state.version, 0)
        app.switchAccount(owner)
        XCTAssertEqual(app.records, [arrow])
    }

    func testOnlyLocalAnnotationChangesRequestImmediateSync() async {
        let owner = UUID(), cloud = AnnotationCloud(owner: owner)
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        var changes = 0
        app.onAnnotationChange = { changes += 1 }
        var arrow = mark("arrow", photo: UUID())
        XCTAssertTrue(app.save(arrow))
        arrow.value["label"] = .string("Edited")
        XCTAssertTrue(app.save(arrow))
        XCTAssertEqual(changes, 2)
        await app.sync(account: cloud)
        XCTAssertEqual(changes, 2) // Applying a cloud snapshot must not create a sync loop.
        app.remove(arrow.id)
        XCTAssertEqual(changes, 3)
        app.remove(arrow.id)
        XCTAssertEqual(changes, 3)
        XCTAssertTrue(app.save(WorkspaceRecord(title: "Favorite", kind: "favorite", target: "test", value: ["enabled": .bool(true)])))
        XCTAssertEqual(changes, 3)
    }

    func testMismatchedAccountCannotUploadLocalMarks() async {
        let owner = UUID(), cloud = AnnotationCloud(owner: UUID())
        defer { UserDefaults.standard.removeObject(forKey: key(owner)) }
        let app = WorkspaceStore(); app.switchAccount(owner)
        let circle = mark("circle", photo: UUID())
        XCTAssertTrue(app.save(circle))
        await app.sync(account: cloud)
        XCTAssertEqual(cloud.requests, 0)
        XCTAssertEqual(app.records, [circle])
    }
}
