import SwiftUI

struct WorkspaceFavorite: View {
    @EnvironmentObject var workspace: WorkspaceStore
    let target: WorkspaceTarget
    var body: some View { Button { workspace.toggle(target) } label: { Label(workspace.favorite(target) ? "Unfavorite" : "Favorite",systemImage:workspace.favorite(target) ? "star.fill" : "star") }.buttonStyle(.bordered).accessibilityIdentifier("workspace.favorite") }
}
struct WorkspaceQuickBar: View {
    @EnvironmentObject var workspace: WorkspaceStore
    @ObservedObject var clinic:ClinicStore
    @ObservedObject var cytology:ClinicStore
    @ObservedObject var medications:CustomMedicationStore
    @State private var showing=false
    @State private var query=""
    @State private var showRecent=false
    @State private var reference=false
    private var entries:[WorkspaceTarget] {
        (MedicationFormulations.organized+medications.definitions.map(\.asMedication)).map{WorkspaceTarget.medication($0)} + LabworkCatalog.tests.map(WorkspaceTarget.lab) + ClinicalData.breeds.map(WorkspaceTarget.breed) + clinic.items.map{WorkspaceTarget.clinic($0,kind:"My Clinic")} + cytology.items.map{WorkspaceTarget.clinic($0,kind:"Cytology")}
    }
    private func favorite(_ t:WorkspaceTarget)->Bool { if t.kind=="My Clinic" { return clinic.items.first{$0.id.uuidString.lowercased()==t.id}?.favorite ?? false };if t.kind=="Cytology" { return cytology.items.first{$0.id.uuidString.lowercased()==t.id}?.favorite ?? false };return workspace.favorite(t) }
    private func toggle(_ t:WorkspaceTarget) { if t.kind=="My Clinic",let id=UUID(uuidString:t.id){clinic.toggleFavorite(id)}else if t.kind=="Cytology",let id=UUID(uuidString:t.id){cytology.toggleFavorite(id)}else{workspace.toggle(t)} }
    private var favorites:[WorkspaceTarget] { entries.filter(favorite) }
    private var matches:[WorkspaceTarget] { let terms=query.lowercased().split(whereSeparator:\.isWhitespace);return Array(entries.filter{entry in terms.allSatisfy{(entry.title+" "+entry.detail+" "+entry.kind).lowercased().contains($0)}}.prefix(80)) }
    var body:some View {
        VStack(alignment:.leading,spacing:4){
            HStack{Button { showing=true } label:{Label("Search VetPilot",systemImage:"magnifyingglass")}.accessibilityIdentifier("workspace.search");Spacer();Button("Recent"){showRecent=true;showing=true}}
            if favorites.isEmpty { Text("Favorite items throughout VetPilot to pin them here.").font(.caption).foregroundStyle(.secondary) }
            else { ScrollView(.horizontal){HStack{ForEach(favorites,id:\.key){t in Button("★ "+t.title){workspace.open(t)}.buttonStyle(.bordered)}}} }
        }.padding(.horizontal,14).padding(.vertical,6)
        .sheet(isPresented:$showing){NavigationStack{List{
            Section { Toggle("Recently viewed",isOn:$showRecent);Button("Veterinary abbreviation reference"){reference=true} }
            if showRecent { Section("Recently viewed — up to 20"){ForEach(workspace.recent.filter{recent in entries.contains{$0.key==recent.key}},id:\.key){row($0)}} }
            else if query.isEmpty { Section("Favorites / Quick Access"){if favorites.isEmpty{Text("Use a Favorite button to pin an item.")};ForEach(favorites,id:\.key){row($0)}} }
            else { Section("Search results"){ForEach(matches,id:\.key){row($0)};if matches.isEmpty{Text("No matching items.")}} }
            Text(workspace.status).font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("VetPilot Search").searchable(text:$query,prompt:"Medication, CBC, breed, protocol…").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showing=false}}}.sheet(isPresented:$reference){NavigationStack{AbbreviationReference().toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){reference=false}}}}}} }
    private func row(_ t:WorkspaceTarget)->some View { HStack{Button { showing=false;workspace.open(t) } label:{VStack(alignment:.leading){Text(t.title);Text(t.kind).font(.caption).foregroundStyle(.secondary)}};Spacer();Button { toggle(t) } label:{Image(systemName:favorite(t) ? "star.fill":"star")}.buttonStyle(.borderless).accessibilityLabel("Favorite "+t.title)} }
}
struct AbbreviationReference:View {
    @State private var query=""
    static let entries=[("PO","By mouth (oral route)."),("IV","Intravenous: into a vein."),("IM","Intramuscular: into a muscle."),("SQ / SC","Subcutaneous: under the skin."),("q8h","Every 8 hours."),("q12h","Every 12 hours."),("q24h","Every 24 hours."),("PRN","As needed, within the veterinarian’s specified instructions.")]
    var body:some View{List{ForEach(Self.entries.filter{query.isEmpty || ($0.0+" "+$0.1).localizedCaseInsensitiveContains(query)},id:\.0){entry in VStack(alignment:.leading){Text(entry.0).bold();Text(entry.1)}};Text("Reference only. Follow the veterinarian’s complete instructions.").font(.footnote)}.navigationTitle("Abbreviations").searchable(text:$query)}
}
struct TabletAmountVisual:View {
    let quantity:Double
    static func parts(_ value:Double)->[Double]{guard value.isFinite,value>0,value<=8,abs(value*4-(value*4).rounded())<1e-8 else{return []};return (0..<Int(ceil(value))).map{min(1,value-Double($0))}}
    var body:some View{if !Self.parts(quantity).isEmpty { VStack(alignment:.leading){Text("Tablet amount visual: \(ClinicalData.format(quantity)) tablet(s)").font(.caption);HStack{ForEach(Array(Self.parts(quantity).enumerated()),id:\.offset){_,part in ZStack{Circle().stroke(AppTheme.blue,lineWidth:2);Circle().trim(from:0,to:part).stroke(AppTheme.blue,lineWidth:14).padding(8).rotationEffect(.degrees(-90))}.frame(width:34,height:34)}}.accessibilityHidden(true);Text("Display only. Confirm the product can be split as prescribed.").font(.caption).foregroundStyle(.secondary)}}}
}
struct LabTubeGuide:View {
    let tube:String
    private var colors:[(String,Color)]{let t=tube.lowercased();return [("Lavender / purple",Color.purple,t.contains("lavender") || t.contains("purple")),("Red",Color.red,t.range(of:"\\bred\\b",options:.regularExpression) != nil),("Green",Color.green,t.contains("green")),("Blue",Color.blue,t.contains("blue"))].filter{$0.2}.map{($0.0,$0.1)}}
    var body:some View{if !colors.isEmpty{HStack{ForEach(colors,id:\.0){name,color in VStack{VStack(spacing:0){Rectangle().fill(color).frame(width:20,height:10);RoundedRectangle(cornerRadius:6).stroke(Color.secondary).frame(width:18,height:32)}.accessibilityHidden(true);Text(name).font(.caption)}}}}}
}
