import Foundation
import Combine

indirect enum WorkspaceValue: Codable, Equatable {
    case string(String), number(Double), bool(Bool), object([String:WorkspaceValue]), array([WorkspaceValue]), null
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); if c.decodeNil() { self = .null } else if let v = try? c.decode(Bool.self) { self = .bool(v) } else if let v = try? c.decode(Double.self) { self = .number(v) } else if let v = try? c.decode(String.self) { self = .string(v) } else if let v = try? c.decode([String:WorkspaceValue].self) { self = .object(v) } else { self = .array(try c.decode([WorkspaceValue].self)) } }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); switch self { case .string(let v):try c.encode(v); case .number(let v):try c.encode(v); case .bool(let v):try c.encode(v); case .object(let v):try c.encode(v); case .array(let v):try c.encode(v); case .null:try c.encodeNil() } }
    var text: String { if case .string(let v) = self { return v }; return "" }
    var number: Double { if case .number(let v) = self { return v }; return 0 }
    var object: [String:WorkspaceValue] { if case .object(let v) = self { return v }; return [:] }
}
struct WorkspaceTarget: Codable, Equatable, Identifiable {
    var kind: String; var id: String; var title: String; var detail = ""; var species: String? = nil
    var key: String { kind + "|" + id }
    static func medication(_ m: Medication, species: Species? = nil) -> Self { Self(kind:"Medication",id:[m.generic,m.form.rawValue,m.formulation?.label ?? "",m.indication].joined(separator:"|"),title:m.displayName,detail:m.brand + " " + m.indication,species:species?.rawValue ?? m.species.sorted(by:{$0.rawValue<$1.rawValue}).first?.rawValue) }
    static func lab(_ l: LabTestEntry) -> Self { Self(kind:"Lab",id:l.id,title:l.name,detail:[l.code,l.purpose,l.specimen,l.provider].joined(separator:" ")) }
    static func breed(_ b: BreedEntry) -> Self { Self(kind:"Breed",id:b.species.rawValue+"|"+b.name,title:b.name,detail:b.conditions,species:b.species.rawValue) }
    static func clinic(_ i: ClinicProtocol, kind: String) -> Self { Self(kind:kind,id:i.id.uuidString.lowercased(),title:i.title,detail:([i.category,i.summary,i.notes] + i.equipment.map(\.name) + i.steps.map(\.text) + i.photos.map(\.caption)).joined(separator:" ")) }
}
struct WorkspaceRecord: Codable, Equatable, Identifiable {
    var id = UUID().uuidString.lowercased(); var title: String; var kind: String; var target: String; var updatedAt = Date().timeIntervalSince1970 * 1000; var value: [String:WorkspaceValue]
}
struct WorkspaceState: Codable { var items: [WorkspaceRecord] = []; var baseline: [WorkspaceRecord] = []; var version = 0 }
struct WorkspaceRequest: Identifiable { let id = UUID(); var target: WorkspaceTarget; var inputs: [String:WorkspaceValue]? = nil }
enum WorkspaceMerge {
    static func merge(_ local: [WorkspaceRecord], _ base: [WorkspaceRecord], _ remote: [WorkspaceRecord]) -> [WorkspaceRecord] {
        let l=Dictionary(uniqueKeysWithValues:local.map{($0.id,$0)}),b=Dictionary(uniqueKeysWithValues:base.map{($0.id,$0)}),r=Dictionary(uniqueKeysWithValues:remote.map{($0.id,$0)})
        var result:[WorkspaceRecord]=[]
        for id in Set(l.keys).union(b.keys).union(r.keys).sorted() { if l[id] == b[id] { if let v=r[id] { result.append(v) } } else if r[id] == b[id] || l[id] == r[id] { if let v=l[id] { result.append(v) } } else { if let v=r[id] { result.append(v) }; if var v=l[id] { v.id=UUID().uuidString.lowercased();v.title += " (conflict copy)";result.append(v) } } }
        return result
    }
}
@MainActor final class WorkspaceStore: ObservableObject {
    @Published private(set) var state=WorkspaceState()
    @Published private(set) var recent:[WorkspaceTarget]=[]
    @Published var request:WorkspaceRequest?
    @Published var status=""
    private var owner:UUID?; private var loaded=false; private var busy=false; private var generation=0
    private var key:String { "vetpilot."+(owner?.uuidString.lowercased() ?? "guest")+".workspace.v1" }
    var records:[WorkspaceRecord] { state.items }
    init() { load() }
    func switchAccount(_ id:UUID?) { guard id != owner else{return};generation += 1;owner=id;busy=false;request=nil;load() }
    private func load() { loaded=false;state=WorkspaceState();recent=[];do { if let data=UserDefaults.standard.data(forKey:key) { state=try JSONDecoder().decode(WorkspaceState.self,from:data);try validate(state) };if let data=UserDefaults.standard.data(forKey:key+".recent") { recent=Array((try JSONDecoder().decode([WorkspaceTarget].self,from:data)).prefix(20)) };loaded=true;status=owner == nil ? "Quick access saved on this device" : "Quick access sync pending" } catch { status="Saved quick access needs recovery; original data has not been overwritten." } }
    private func validate(_ value:WorkspaceState) throws {
        func invalid() -> ClinicFileError { .invalid("Invalid quick access data. Existing data is preserved.") }
        guard value.version>=0,value.items.count<=3000,value.baseline.count<=3000,Set(value.items.map(\.id)).count==value.items.count,Set(value.baseline.map(\.id)).count==value.baseline.count,try JSONEncoder().encode(value).count<=4_000_000 else { throw invalid() }
        for record in value.items + value.baseline {
            guard UUID(uuidString:record.id) != nil,["favorite","calculation","annotation"].contains(record.kind),record.target.count<=3000,record.title.count<=20000,record.updatedAt.isFinite,record.updatedAt>=0,record.updatedAt<=8_640_000_000_000_000 else { throw invalid() }
            if record.kind=="favorite" { guard case .bool? = record.value["enabled"] else { throw invalid() } }
            if record.kind=="calculation" { guard case .object? = record.value["inputs"] else { throw invalid() } }
            if record.kind=="annotation" {
                guard ["arrow","circle","label"].contains(record.value["shape"]?.text ?? ""),case .string(let label)?=record.value["label"],label.count<=100 else { throw invalid() }
                for key in ["x","y","x2","y2"] { guard case .number(let n)?=record.value[key],n.isFinite,n>=0,n<=1 else { throw invalid() } }
            }
        }
    }
    private func persist(_ next:WorkspaceState) throws { try validate(next);let data=try JSONEncoder().encode(next);UserDefaults.standard.set(data,forKey:key);state=next }
    @discardableResult func save(_ value:WorkspaceRecord) -> Bool { guard loaded else{return false};do { var next=state;next.items.removeAll{$0.id==value.id};next.items.append(value);if value.kind=="calculation" { let keep=Set(next.items.filter{$0.kind=="calculation"}.sorted{$0.updatedAt == $1.updatedAt ? $0.id>$1.id : $0.updatedAt>$1.updatedAt}.prefix(20).map(\.id));next.items.removeAll{$0.kind=="calculation" && !keep.contains($0.id)} };try persist(next);status="Saved locally";return true } catch { status=error.localizedDescription;return false } }
    func remove(_ id:String) { guard loaded else{return};do { var next=state;next.items.removeAll{$0.id==id};try persist(next) } catch { status=error.localizedDescription } }
    func favorite(_ target:WorkspaceTarget) -> Bool { state.items.filter{$0.kind=="favorite" && $0.target==target.key}.sorted{$0.updatedAt == $1.updatedAt ? $0.id>$1.id : $0.updatedAt>$1.updatedAt}.first?.value["enabled"] == .bool(true) }
    func toggle(_ target:WorkspaceTarget) { let existing=state.items.first{$0.kind=="favorite" && $0.target==target.key};save(WorkspaceRecord(id:existing?.id ?? UUID().uuidString.lowercased(),title:target.title,kind:"favorite",target:target.key,value:["enabled":.bool(!favorite(target))])) }
    func viewed(_ target:WorkspaceTarget) { recent=Array(([target]+recent.filter{$0.key != target.key}).prefix(20));if let data=try? JSONEncoder().encode(recent) { UserDefaults.standard.set(data,forKey:key+".recent") } }
    func open(_ target:WorkspaceTarget, inputs:[String:WorkspaceValue]?=nil) { viewed(target);request=WorkspaceRequest(target:target,inputs:inputs) }
    func sync(account:VetPilotAccount) async { guard loaded,!busy,let owner,account.userID==owner else{return};busy=true;let epoch=generation;defer{if epoch==generation{busy=false}}
        do { struct Row:Decodable{var version:Int;var items:[WorkspaceRecord]};let data=try await account.request(path:"rest/v1/workspace_collections?select=version,items");let rows=try JSONDecoder().decode([Row].self,from:data);guard epoch==generation,account.userID==owner else{return};let remote=rows.first?.items ?? [];let version=rows.first?.version ?? 0;try validate(WorkspaceState(items:remote,baseline:[],version:version));let merged=WorkspaceMerge.merge(state.items,state.baseline,remote);try persist(WorkspaceState(items:merged,baseline:remote,version:version));if merged != remote { let payload=try JSONSerialization.jsonObject(with:JSONEncoder().encode(merged));let response=try await account.request(path:"rest/v1/rpc/save_workspace_collection",method:"POST",body:["expected_version":version,"collection_items":payload]);guard epoch==generation,account.userID==owner else{return};let acknowledged=try JSONDecoder().decode(Int.self,from:response);try persist(WorkspaceState(items:state.items,baseline:merged,version:acknowledged)) };status="Quick access synced" } catch { if epoch==generation { status="Quick access sync pending; local data is preserved. "+error.localizedDescription } }
    }
}
