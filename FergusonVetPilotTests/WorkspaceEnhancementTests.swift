import XCTest
@testable import FergusonVetPilot

final class WorkspaceEnhancementTests:XCTestCase {
    func testMergePreservesConcurrentChangesAndConflictCopies() {
        let original=WorkspaceRecord(title:"Original",kind:"favorite",target:"Lab|cbc",value:["enabled":.bool(true)])
        var local=original;local.value["enabled"] = .bool(false)
        var remote=original;remote.title="Remote edit"
        let merged=WorkspaceMerge.merge([local],[original],[remote])
        XCTAssertEqual(merged.count,2)
        XCTAssertTrue(merged.contains{$0.id==original.id && $0.title=="Remote edit"})
        XCTAssertTrue(merged.contains{$0.id != original.id && $0.value["enabled"] == .bool(false)})
        XCTAssertTrue(WorkspaceMerge.merge([original],[original],[]).isEmpty)
    }
    @MainActor func testAccountIsolationPersistenceAndBoundedHistory() {
        let a=UUID(),b=UUID()
        defer { for owner in [a,b] { for suffix in ["",".recent"] { UserDefaults.standard.removeObject(forKey:"vetpilot."+owner.uuidString.lowercased()+".workspace.v1"+suffix) } } }
        let store=WorkspaceStore();store.switchAccount(a)
        let target=WorkspaceTarget(kind:"Lab",id:"fixture",title:"Fixture")
        store.toggle(target);XCTAssertTrue(store.favorite(target))
        for i in 0..<25 { store.viewed(WorkspaceTarget(kind:"Lab",id:String(i),title:String(i)));XCTAssertTrue(store.save(WorkspaceRecord(title:"Calculation",kind:"calculation",target:"Medication|fixture",value:["inputs":.object(["weight":.string(String(i))])])))}
        XCTAssertEqual(store.recent.count,20);XCTAssertEqual(store.records.filter{$0.kind=="calculation"}.count,20)
        store.switchAccount(b);XCTAssertFalse(store.favorite(target));XCTAssertTrue(store.recent.isEmpty);XCTAssertTrue(store.records.isEmpty)
        store.switchAccount(a);XCTAssertTrue(store.favorite(target));XCTAssertEqual(store.recent.count,20)
        let restored=WorkspaceStore();restored.switchAccount(a);XCTAssertTrue(restored.favorite(target));XCTAssertEqual(restored.records,store.records)
    }
    @MainActor func testInvalidAnnotationsPreserveSavedRecords() {
        let owner=UUID();defer {UserDefaults.standard.removeObject(forKey:"vetpilot."+owner.uuidString.lowercased()+".workspace.v1")}
        let store=WorkspaceStore();store.switchAccount(owner)
        let original=WorkspaceRecord(title:"Mark",kind:"annotation",target:"photo|fixture",value:["shape":.string("circle"),"label":.string(""),"x":.number(0),"y":.number(0),"x2":.number(1),"y2":.number(1)])
        XCTAssertTrue(store.save(original));var invalid=original;invalid.value["x"] = .number(-1)
        XCTAssertFalse(store.save(invalid));XCTAssertEqual(store.records,[original])
    }
    func testTabletVisualNeverRoundsQuantity() {for value in [0.25,0.5,0.75,1,1.5,2.75,8] {XCTAssertEqual(TabletAmountVisual.parts(value).reduce(0,+),value)};for value in [0,-1,Double.nan,Double.infinity,1.76,8.25]{XCTAssertTrue(TabletAmountVisual.parts(value).isEmpty)}}
    func testSourceKeysAreUniqueAcrossMedicationCatalog() {let keys=MedicationFormulations.organized.map{WorkspaceTarget.medication($0).key};XCTAssertEqual(keys.count,Set(keys).count)}
}
