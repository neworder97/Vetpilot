import SwiftUI
import UIKit

struct CytologyImageTools:View {
    @ObservedObject var store:ClinicStore
    @State private var showing=false
    var body:some View { VStack(alignment:.leading){Button("Compare / annotate images"){showing=true}.buttonStyle(.bordered).accessibilityIdentifier("cytology.imageTools");DisclosureGroup("Microscope photography tips"){Text("Clean the eyepiece and camera lens. Focus the microscope first, center and steady the camera, and adjust illumination/exposure to avoid glare. Capture an overview and a closer view; record specimen, stain and magnification. Keep originals and avoid filters that change cell appearance.").font(.footnote)}}.sheet(isPresented:$showing){NavigationStack{CytologyImageToolsSheet(store:store).toolbar{ToolbarItem(placement:.confirmationAction){Button("Return to Cytology"){showing=false}}}}} }
}
private struct CytologyPhotoChoice:Identifiable { var item:ClinicProtocol;var photo:ClinicPhoto;var id:String{item.id.uuidString+"|"+photo.id.uuidString} }
private struct CytologyImageToolsSheet:View {
    @EnvironmentObject var workspace:WorkspaceStore
    @ObservedObject var store:ClinicStore
    @State private var mode="Compare"
    @State private var first=""
    @State private var second=""
    @State private var shape="arrow"
    @State private var label=""
    @State private var message=""
    @State private var editing:WorkspaceRecord?
    private var choices:[CytologyPhotoChoice]{store.items.flatMap{item in item.photos.map{CytologyPhotoChoice(item:item,photo:$0)}}}
    private var a:CytologyPhotoChoice?{choices.first{$0.id==first}}
    private var b:CytologyPhotoChoice?{choices.first{$0.id==second}}
    private var marks:[WorkspaceRecord]{guard let a else{return []};return workspace.records.filter{$0.kind=="annotation" && $0.target=="photo|"+a.photo.id.uuidString.lowercased()}}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:12){
        Picker("Image tools",selection:$mode){Text("Compare").tag("Compare");Text("Annotate").tag("Annotate")}.pickerStyle(.segmented)
        picker("First image",selection:$first)
        if mode=="Compare" { picker("Second image",selection:$second);if let a,let b,a.id != b.id { HStack(alignment:.top){pane(a);pane(b)};Text("Pinch to zoom and drag to pan each image independently.").font(.caption) } else { Text("Choose two different images.") } }
        else if let a,let image=UIImage(data:a.photo.jpeg) {
            Picker("Annotation tool",selection:$shape){Text("Arrow").tag("arrow");Text("Circle").tag("circle");Text("Label").tag("label")}.pickerStyle(.segmented)
            TextField("Label text",text:$label).textFieldStyle(.roundedBorder)
            Text("Drag to place a mark. Edit or remove marks below. The original image is unchanged.").font(.caption)
            Image(uiImage:image).resizable().scaledToFit().overlay{GeometryReader{g in
                Canvas{context,size in for record in marks { draw(record,in:&context,size:size) }}
                    .contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onEnded{v in
                        guard marks.count<100 else{message="Limit of 100 annotations per image.";return}
                        if shape=="label" && label.trimmingCharacters(in:.whitespaces).isEmpty{message="Enter label text first.";return}
                        func unit(_ value:CGFloat,_ extent:CGFloat)->Double{max(0,min(1,Double(value/max(1,extent))))}
                        workspace.save(WorkspaceRecord(title:a.photo.caption,kind:"annotation",target:"photo|"+a.photo.id.uuidString.lowercased(),value:["shape":.string(shape),"label":.string(String(label.prefix(100))),"x":.number(unit(v.startLocation.x,g.size.width)),"y":.number(unit(v.startLocation.y,g.size.height)),"x2":.number(unit(v.location.x,g.size.width)),"y2":.number(unit(v.location.y,g.size.height))]))
                    })
            }}
            ForEach(marks){record in HStack{Text(record.value["shape"]?.text ?? "Mark");Text(record.value["label"]?.text ?? "");Spacer();Button("Edit"){editing=record};Button("Remove"){workspace.remove(record.id)}}}
            Button("Save annotated copy for sharing"){saveCopy(a,image:image)}.buttonStyle(.borderedProminent).disabled(marks.isEmpty)
            Text("Annotations sync separately with your account. Save an annotated copy to include markings in existing PDF, file, or QR sharing; the original remains available.").font(.caption)
        }
        if !message.isEmpty{Text(message).font(.footnote)}
    }.padding()}.navigationTitle("Cytology image tools").sheet(item:$editing){record in AnnotationEditor(record:record){workspace.save($0);editing=nil}} }
    private func picker(_ title:String,selection:Binding<String>)->some View{Picker(title,selection:selection){Text("Choose an image").tag("");ForEach(choices){p in Text(p.item.title+" — "+p.photo.caption).tag(p.id)}}}
    private func pane(_ p:CytologyPhotoChoice)->some View{VStack{Text(p.item.title).font(.headline);Text(p.photo.caption).font(.caption);if let image=UIImage(data:p.photo.jpeg){WorkspaceZoomImage(image:image).id(p.id).frame(height:320)}}.frame(maxWidth:.infinity)}
    private func draw(_ record:WorkspaceRecord,in context:inout GraphicsContext,size:CGSize){let v=record.value;let x=(v["x"]?.number ?? 0)*size.width,y=(v["y"]?.number ?? 0)*size.height,x2=(v["x2"]?.number ?? 0)*size.width,y2=(v["y2"]?.number ?? 0)*size.height;let shape=v["shape"]?.text ?? "arrow";if shape=="label" {context.draw(Text(v["label"]?.text ?? "").font(.system(size:max(12,size.width/35))).foregroundColor(.yellow),at:CGPoint(x:x,y:y),anchor:.leading);return};var path=Path();if shape=="circle"{path.addEllipse(in:CGRect(x:min(x,x2),y:min(y,y2),width:max(2,abs(x2-x)),height:max(2,abs(y2-y))))}else{path.move(to:CGPoint(x:x,y:y));path.addLine(to:CGPoint(x:x2,y:y2));let angle=atan2(y2-y,x2-x),length=size.width/25;path.move(to:CGPoint(x:x2-length*cos(angle-0.5),y:y2-length*sin(angle-0.5)));path.addLine(to:CGPoint(x:x2,y:y2));path.addLine(to:CGPoint(x:x2-length*cos(angle+0.5),y:y2-length*sin(angle+0.5)))};context.stroke(path,with:.color(.yellow),lineWidth:2)}
    private func saveCopy(_ choice:CytologyPhotoChoice,image:UIImage){do{guard choice.item.photos.count<8 else{throw ClinicFileError.invalid("This entry already has eight photos. Original images were preserved.")};let renderer=UIGraphicsImageRenderer(size:image.size);let output=renderer.image{context in image.draw(at:.zero);let c=context.cgContext;c.setStrokeColor(UIColor.yellow.cgColor);c.setLineWidth(max(3,image.size.width/220));for record in marks{let v=record.value,x=(v["x"]?.number ?? 0)*image.size.width,y=(v["y"]?.number ?? 0)*image.size.height,x2=(v["x2"]?.number ?? 0)*image.size.width,y2=(v["y2"]?.number ?? 0)*image.size.height;switch v["shape"]?.text{case "label":((v["label"]?.text ?? "") as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.foregroundColor:UIColor.yellow,.font:UIFont.systemFont(ofSize:max(18,image.size.width/35))]);case "circle":c.strokeEllipse(in:CGRect(x:min(x,x2),y:min(y,y2),width:max(2,abs(x2-x)),height:max(2,abs(y2-y))));default:c.move(to:CGPoint(x:x,y:y));c.addLine(to:CGPoint(x:x2,y:y2));let angle=atan2(y2-y,x2-x),length=image.size.width/40;c.move(to:CGPoint(x:x2-length*cos(angle-0.5),y:y2-length*sin(angle-0.5)));c.addLine(to:CGPoint(x:x2,y:y2));c.addLine(to:CGPoint(x:x2-length*cos(angle+0.5),y:y2-length*sin(angle+0.5)));c.strokePath()}}};guard let jpeg=output.jpegData(compressionQuality:0.85),jpeg.count<=2_000_000 else{throw ClinicFileError.invalid("Annotated copy is too large. Original unchanged.")};var item=choice.item;item.photos.append(ClinicPhoto(caption:String((choice.photo.caption+" — annotated copy").prefix(20000)),jpeg:jpeg));try store.save(item,basedOn:choice.item);message="Annotated copy saved. Original unchanged; use existing sharing controls."}catch{message=error.localizedDescription}}
}
private struct AnnotationEditor:View{
    @State var record:WorkspaceRecord
    let save:(WorkspaceRecord)->Void
    @Environment(\.dismiss) private var dismiss
    var body:some View{NavigationStack{Form{TextField("Label",text:Binding(get:{record.value["label"]?.text ?? ""},set:{record.value["label"] = .string(String($0.prefix(100)))}));ForEach(["x","y","x2","y2"],id:\.self){key in VStack{Text(key);Slider(value:Binding(get:{record.value[key]?.number ?? 0},set:{record.value[key] = .number($0)}),in:0...1)}};Button("Save annotation"){record.updatedAt=Date().timeIntervalSince1970*1000;save(record)}}.navigationTitle("Edit annotation").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}}}}
}
private struct WorkspaceZoomImage:UIViewRepresentable{
    let image:UIImage
    func makeCoordinator()->Coordinator{Coordinator()}
    func makeUIView(context:Context)->UIScrollView{let scroll=UIScrollView();scroll.minimumZoomScale=1;scroll.maximumZoomScale=6;scroll.delegate=context.coordinator;let view=UIImageView(image:image);view.contentMode = .scaleAspectFit;view.frame=CGRect(x:0,y:0,width:300,height:320);scroll.addSubview(view);scroll.contentSize=view.bounds.size;context.coordinator.image=view;return scroll}
    func updateUIView(_ scroll:UIScrollView,context:Context){context.coordinator.image?.image=image}
    class Coordinator:NSObject,UIScrollViewDelegate{var image:UIImageView?;func viewForZooming(in scrollView:UIScrollView)->UIView?{image}}
}
