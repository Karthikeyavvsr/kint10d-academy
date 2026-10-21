import SwiftUI
import UniformTypeIdentifiers
import AcademyCore

enum AcademyScreen:String,CaseIterable,Identifiable {
    case today="Today", curriculum="Curriculum", papers="Paper library", labs="Visual labs", interview="Interview room", resources="Resources", notebook="My notebook", settings="Settings"
    var id:String{rawValue}
    var icon:String {
        switch self {case .today:return "sun.horizon";case .curriculum:return "books.vertical";case .papers:return "doc.text.magnifyingglass";case .labs:return "slider.horizontal.3";case .interview:return "bubble.left.and.bubble.right";case .resources:return "arrow.up.right.square";case .notebook:return "note.text";case .settings:return "gearshape"}
    }
}
struct AcademyRoot:View {
    @EnvironmentObject var store:AcademyStore
    @State var screen:AcademyScreen? = .today
    @State var path:[Lesson]=[]
    @AppStorage("academy.appearance") var appearance="system"
    var body:some View {
        Group {
        #if os(iOS)
        NativeTabs()
        #else
        NavigationSplitView {
            List(selection:$screen) {
                Section {
                    VStack(alignment:.leading,spacing:6) {
                        Text("K10").font(.system(size:40,weight:.medium,design:.serif))
                        Text("ACADEMY").font(.caption.weight(.bold)).tracking(4)
                        Text("Learn. Build. Explain.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical,18)
                }
                Section("Your learning space"){
                    ForEach(AcademyScreen.allCases){item in Label(item.rawValue,systemImage:item.icon).tag(item)}
                }
                Section{
                    ProgressView(value:Double(store.readCount),total:Double(max(1,store.lessons.count)))
                    Text("\(store.readCount) / \(store.lessons.count) lessons read").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Academy")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min:220,ideal:245,max:300)
            #endif
        } detail: {
            NavigationStack(path:$path) {
                Group {
                    switch screen ?? .today {
                    case .today: TodayView{path.append($0)}
                    case .curriculum: CurriculumView()
                    case .papers: PaperShelf()
                    case .labs: NativeLabs()
                    case .interview: InterviewView()
                    case .resources: ResourcesView()
                    case .notebook: NotebookView()
                    case .settings: AcademySettings()
                    }
                }
                .navigationTitle((screen ?? .today).rawValue)
                .navigationDestination(for:Lesson.self){LessonReader(lesson:$0)}
                .safeAreaInset(edge:.bottom){
                    Text(store.status).font(.caption2).foregroundStyle(.secondary).frame(maxWidth:.infinity).padding(8).background(.regularMaterial)
                }
            }
        }
        .onChange(of:screen){_,_ in path=[]}
        #endif
        }.preferredColorScheme(appearance=="light" ? .light : appearance=="dark" ? .dark : nil)
    }
}
struct PageTitle:View {
    let eyebrow:String,title:String,subtitle:String
    var body:some View {
        VStack(alignment:.leading,spacing:15) {
            Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            Text(title).font(.system(.largeTitle,design:.serif)).fontWeight(.medium)
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,12)
    }
}
struct AcademyCard<Content:View>:View {
    @ViewBuilder let content:Content
    var body:some View {VStack(alignment:.leading,spacing:14){content}.frame(maxWidth:.infinity,alignment:.leading).padding(22).background(Color.academyCard,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(.gray.opacity(0.15)))}
}
struct TodayView:View {
    @EnvironmentObject var store:AcademyStore
    let open:(Lesson)->Void
    var next:Lesson? {store.continueLesson}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                PageTitle(eyebrow:"A personal school for builders",title:"Build understanding.\nThen build the system.",subtitle:"Engineering, intelligence and markets—connected through deliberate practice.")
                if let next {
                    VStack(alignment:.leading,spacing:16) {
                        Text("YOUR NEXT STUDY SESSION").font(.caption2.weight(.bold)).tracking(2)
                        Text(next.title).font(.system(.title2,design:.serif))
                        Text("Read the mechanism. Work the example. Explain it without notes.").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        Button{open(next)}label:{Label("Continue learning",systemImage:"arrow.right")}.buttonStyle(.borderedProminent).tint(Color(red:0.80,green:0.90,blue:0.65)).foregroundStyle(Color.academyGreen)
                    }.padding(28).frame(maxWidth:.infinity,alignment:.leading).background(Color.academyGreen,in:RoundedRectangle(cornerRadius:18)).foregroundStyle(.white)
                }
                if next == nil && !store.lessons.isEmpty {
                    AcademyCard {
                        Label("First reading pass complete",systemImage:"checkmark.seal").font(.headline)
                        Text("Keep building and use the reviews below to check what you can recall.")
                    }
                }
                if let resume = store.resourceResume {
                    AcademyCard {
                        Text("Continue your resource").font(.headline)
                        Text(resume.title)
                        Text(resume.positionDescription).font(.caption).foregroundStyle(.secondary)
                        ResourceLink(title: "Resume resource", address: resume.source, resourceTitle: resume.title)
                    }
                }
                AcademyCard {
                    Text("One small step today").font(.headline)
                    Text("Choose one section. After reading, look away and explain one idea in your own words. Stop there if that is enough for today.")
                    Text("Returning matters more than keeping a streak.").font(.caption).foregroundStyle(.secondary)
                }
                LearningProgressCard()
                LazyVGrid(columns:[GridItem(.adaptive(minimum:130))],alignment:.leading,spacing:16){
                    metric(String(store.lessons.count),"Deep-dive lessons")
                    metric(String(store.papers.count),"Guided papers")
                    metric(String(store.dueLessons.count),"Reviews due")
                }
                AcademyCard {
                    Text("A rhythm that builds skill").font(.title3.weight(.semibold))
                    Label("Recall yesterday before rereading.",systemImage:"1.circle")
                    Label("Study one mechanism and work its example.",systemImage:"2.circle")
                    Label("Explain it, then solve something new.",systemImage:"3.circle")
                }
                if !store.dueLessons.isEmpty {
                    AcademyCard {
                        Text("Ready for review").font(.title2)
                        ForEach(store.dueLessons){l in Button(l.title){open(l)}.buttonStyle(.plain)}
                    }
                }
                AcademyCard {
                    Text("Evidence before confidence.").font(.system(.title2,design:.serif))
                    Text("Reading, self-reported recall and a quiz are different evidence. None certifies mastery. Use the linked courses, build projects and invite someone to challenge your reasoning.").foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth:1000)
        }.frame(maxWidth:.infinity).background(Color.academyPaper)
    }
    func metric(_ count:String,_ label:String)->some View {VStack(alignment:.leading){Text(count).font(.system(size:38,design:.serif));Text(label).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)}
}
struct CurriculumView:View {
    @EnvironmentObject var store:AcademyStore
    @State var query=""
    @State var track="All subjects"
    let tracks=["All subjects","Engineering & research","AI & intelligence","Quant & markets"]
    var filtered:[Lesson]{store.lessons.filter{(track=="All subjects" || $0.track==track) && (query.isEmpty || ($0.title+" "+$0.summary+" "+$0.sections.map(\.body).joined(separator:" ")).localizedCaseInsensitiveContains(query))}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                PageTitle(eyebrow:"Foundations → mechanisms → practice",title:"The curriculum",subtitle:"Study the machinery, work the examples, and test your understanding.")
                Picker("Subject",selection:$track){ForEach(tracks,id:\.self){Text($0)}}.pickerStyle(.menu)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:280),spacing:18)],spacing:18){
                    ForEach(filtered){lesson in
                        NavigationLink(value:lesson){
                            AcademyCard {
                                HStack{Text(lesson.level).font(.caption.weight(.semibold));Spacer();Text("\(lesson.minutes) min").font(.caption).foregroundStyle(.secondary)}
                                Text(lesson.title).font(.system(.title3,design:.serif)).multilineTextAlignment(.leading)
                                Text(lesson.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                                Label(store.value("lesson:"+lesson.id)=="read" ? "Read" : "Start lesson",systemImage:store.value("lesson:"+lesson.id)=="read" ? "checkmark.circle" : "arrow.right").font(.caption)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                if filtered.isEmpty{ContentUnavailableView.search(text:query)}
                Text("Reading estimates exclude exercises and full linked courses. Complete the original field guide and capstone work as well.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth:1100)
        }.frame(maxWidth:.infinity).background(Color.academyPaper).searchable(text:$query,prompt:"Search concepts and failure modes")
    }
}
struct LessonReader:View {
    @EnvironmentObject var store:AcademyStore
    let lesson:Lesson
    @State private var note=""
    @State private var originalNote=""
    @Environment(\.scenePhase) private var phase
    @State private var choice:Int?
    @State private var loaded=false
    @State private var savedSection: Int?
    @State private var showNext=false
    @State private var recallMessage=""
    private var nextLesson: Lesson? { guard let index=store.lessons.firstIndex(where:{$0.id==lesson.id}), index+1<store.lessons.count else{return nil};return store.lessons[index+1] }
    @ScaledMetric(relativeTo:.body) private var baseSize=19.0
    @AppStorage("academy.readerScale") private var readerScale=1.0
    var body:some View {
        ScrollViewReader{reader in
            ScrollView {
                VStack(alignment:.leading,spacing:28) {
                    PageTitle(eyebrow:lesson.track+" / "+lesson.level,title:lesson.title,subtitle:lesson.summary)
                    HStack {
                        Button(store.value("lesson:"+lesson.id)=="read" ? "✓ Marked read" : "Mark read"){
                            store.set("lesson:"+lesson.id,store.value("lesson:"+lesson.id)=="read" ? "reading" : "read")
                        }.buttonStyle(.bordered)
                        Spacer()
                        Button("A−"){readerScale=max(0.85,readerScale-0.1)}.accessibilityLabel("Smaller reading text")
                        Button("A+"){readerScale=min(1.5,readerScale+0.1)}.accessibilityLabel("Larger reading text")
                    }
                    DisclosureGroup("In this lesson"){
                        ForEach(Array(lesson.sections.enumerated()),id:\.offset){i,s in Button(s.title){reader.scrollTo(i,anchor:.top)}.padding(.vertical,4)}
                    }
                    ForEach(Array(lesson.sections.enumerated()),id:\.offset){i,section in
                        VStack(alignment:.leading,spacing:16){
                            Text(section.title).font(.system(.title2,design:.serif))
                            Button {
                                let before=store.records["bookmark:last"]?.revision
                                store.set("bookmark:last",object:Bookmark(lesson:lesson.id,section:i))
                                if store.records["bookmark:last"]?.revision != before { savedSection=i }
                            } label: {
                                Label(store.bookmark?.lesson==lesson.id && store.bookmark?.section==i ? "Place saved · resume here" : "Save my place", systemImage:store.bookmark?.lesson==lesson.id && store.bookmark?.section==i ? "bookmark.fill" : "bookmark")
                            }.font(.caption).buttonStyle(.bordered)
                            if savedSection==i { Text("Saved on this device. Continue learning returns to this section until you mark the chapter read.").font(.caption).foregroundStyle(.secondary) }
                            Text(section.body).font(.system(size:baseSize*readerScale,design:.serif)).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                        }.id(i)
                    }
                    if let lab=lesson.lab{NavigationLink{NativeLabs(initial:lab)}label:{Label("Explore the "+lab+" lab",systemImage:"slider.horizontal.3")}.buttonStyle(.bordered)}
                    AcademyCard {
                        Text("Apply it before revealing the answer").font(.title3.weight(.semibold))
                        Text(lesson.exercise.prompt).textSelection(.enabled)
                        DisclosureGroup("Worked solution"){Text(lesson.exercise.solution).padding(.top,10).textSelection(.enabled)}
                        Divider()
                        Text("Explain it in an interview").font(.headline)
                        Text(lesson.interview.question)
                        DisclosureGroup("Compare with a strong answer"){Text(lesson.interview.answer).padding(.top,10).textSelection(.enabled)}
                    }
                    AcademyCard {
                        Text("Check one key idea").font(.title3.weight(.semibold))
                        Text(lesson.quiz.question)
                        ForEach(Array(lesson.quiz.options.enumerated()),id:\.offset){i,option in
                            Button{
                                choice=i
                                struct Attempt:Codable{let correct:Bool;let choice:Int;let at:Double}
                                store.set("quiz:"+lesson.id,object:Attempt(correct:i==lesson.quiz.correct,choice:i,at:Date().timeIntervalSince1970*1000))
                            }label:{HStack{Image(systemName:choice==i ? "largecircle.fill.circle" : "circle");Text(option).multilineTextAlignment(.leading);Spacer()}}.buttonStyle(.bordered)
                        }
                        if let choice{Text(choice==lesson.quiz.correct ? "Correct." : "Revisit the reasoning.").font(.headline);Text(lesson.quiz.explanation)}
                        Text("One concept check is not mastery.").font(.caption).foregroundStyle(.secondary)
                    }
                    AcademyCard {
                        Text("Could you explain it without notes?").font(.headline)
                        Text("Close the answers. Speak for two minutes and solve a fresh example.").foregroundStyle(.secondary)
                        Button("Not yet · review tomorrow"){store.recall(lesson,success:false);recallMessage="Review scheduled for tomorrow."}.buttonStyle(.bordered)
                        Button("Yes · schedule spaced review"){store.recall(lesson,success:true);recallMessage="Your next spaced review is scheduled."}.buttonStyle(.borderedProminent)
                    }
                    if !recallMessage.isEmpty { Text(recallMessage).font(.caption).foregroundStyle(.secondary) }
                    AcademyCard {
                        Text("Your working notes").font(.title3)
                        TextEditor(text:$note).frame(minHeight:180).font(.body).overlay(RoundedRectangle(cornerRadius:4).stroke(.gray.opacity(0.2))).accessibilityLabel("Lesson notes")
                        Button("Save notes"){saveNote()}.buttonStyle(.borderedProminent)
                        Text("Notes also save on leaving this lesson. Any save error appears in an alert.").font(.caption).foregroundStyle(.secondary)
                    }
                    AcademyCard {
                        Text("Go deeper at the source").font(.title3)
                        ForEach(lesson.sources,id:\.url){s in ResourceLink(title:s.title,address:s.url)}
                    }
                    AcademyCard {
                        Text("Finish this chapter").font(.title2)
                        Text("Take a moment to recall one idea and one way you could use it. Linked courses can take longer; chapter progress and resource progress are separate.").foregroundStyle(.secondary)
                        if let nextLesson {
                            Text("Up next: "+nextLesson.title).font(.headline)
                            Button("Mark chapter read & continue") {
                                saveNote()
                                store.set("lesson:"+lesson.id,"read")
                                if store.value("lesson:"+lesson.id)=="read" { showNext=true }
                            }.buttonStyle(.borderedProminent)
                            NavigationLink("Next chapter without marking read") { LessonReader(lesson:nextLesson) }
                        } else {
                            Button("Mark final chapter read") { store.set("lesson:"+lesson.id,"read") }.buttonStyle(.borderedProminent)
                            if store.value("lesson:"+lesson.id)=="read" { Text("Reading pass complete. Your projects and spaced reviews are the next step.") }
                        }
                    }
                }.padding(24).frame(maxWidth:780)
            }.frame(maxWidth:.infinity).background(Color.academyPaper)
            .onAppear {
                guard !loaded else{return};loaded=true;note=store.value("note:"+lesson.id);originalNote=note
                if let bookmark=store.bookmark,bookmark.lesson==lesson.id {
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.2){reader.scrollTo(bookmark.section,anchor:.top)}
                }
            }
            .onDisappear{saveNote()}
            .onChange(of:phase){_,phase in if phase != .active{saveNote()}}
        }.navigationTitle(lesson.title).preference(key: MikoReadingKey.self, value: true)
            .navigationDestination(isPresented:$showNext) { if let nextLesson { LessonReader(lesson:nextLesson) } }
    }
    private func saveNote(){
        guard loaded,note != originalNote else{return}
        store.set("note:"+lesson.id,note)
        if store.value("note:"+lesson.id)==note{originalNote=note}
    }
}
struct PaperShelf:View {
    @EnvironmentObject var store:AcademyStore
    @Environment(\.openURL) var openURL
    @State var search=""
    var body:some View {
        List {
            Section{Text("Read with a question. These guides describe what to investigate; they do not claim independent reproduction.").foregroundStyle(.secondary)}
            ForEach(store.papers.filter{search.isEmpty || ($0.title+" "+$0.area+" "+$0.authors).localizedCaseInsensitiveContains(search)}){p in
                VStack(alignment:.leading,spacing:12) {
                    Text("\(p.year.description) · \(p.area)").font(.caption).foregroundStyle(.secondary)
                    Text(p.title).font(.system(.title3,design:.serif))
                    Text(p.authors).font(.caption).foregroundStyle(.secondary)
                    Text(p.why)
                    DisclosureGroup("Reading guide"){
                        VStack(alignment:.leading,spacing:12){
                            Text("Prerequisites: "+p.prerequisites.description)
                            Text("Read for: "+p.readFor)
                            Text("Limits: "+p.limits)
                            Text("Try: "+p.exercise)
                        }.padding(.top,12)
                    }
                    HStack{
                        ResourceLink(title:"Open / resume paper",address:p.url,resourceTitle:p.title).buttonStyle(.bordered)
                        Button(store.value("paper:"+p.id)=="read" ? "✓ Read · undo" : "I finished reading"){store.set("paper:"+p.id,store.value("paper:"+p.id)=="read" ? "opened" : "read")}.buttonStyle(.bordered)
                    }
                    Text(store.value("paper:"+p.id).isEmpty ? "Not opened" : store.value("paper:"+p.id).capitalized).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical,14)
            }
        }.searchable(text:$search,prompt:"Search papers, authors or fields")
    }
}
struct ResourcesView:View {
    @EnvironmentObject var store:AcademyStore
    @Environment(\.openURL) var openURL
    @State var search=""
    var body:some View {
        List(store.resources.filter{search.isEmpty || ($0.title+" "+$0.format+" "+$0.study_focus).localizedCaseInsensitiveContains(search)}){r in
            VStack(alignment:.leading,spacing:12) {
                Text(r.title).font(.title3)
                Text(r.format+" · "+r.level).font(.caption).foregroundStyle(.secondary)
                Text(r.study_focus)
                Text(r.access).font(.caption)
                HStack {
                    ResourceLink(title:"Open / resume resource",address:r.url,resourceTitle:r.title)
                    Button(store.value("resource:"+r.id)=="read" ? "✓ Read · undo" : "Mark read"){store.set("resource:"+r.id,store.value("resource:"+r.id)=="read" ? "opened" : "read")}.buttonStyle(.bordered)
                }
            }.padding(.vertical,10)
        }.searchable(text:$search,prompt:"Search courses, videos and books")
    }
}
struct InterviewView:View {
    @EnvironmentObject var store:AcademyStore
    @State var index=0
    @State var reveal=false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24){
                PageTitle(eyebrow:"Recall before recognition",title:"Explain your thinking.",subtitle:"State assumptions, derive the mechanism, give an example and name a failure mode.")
                if !store.lessons.isEmpty {
                    let l=store.lessons[index % store.lessons.count]
                    AcademyCard{
                        Text(l.track).font(.caption).foregroundStyle(.secondary)
                        Text(l.interview.question).font(.system(.title2,design:.serif))
                        Button(reveal ? "Hide answer" : "Reveal a strong answer"){reveal.toggle()}.buttonStyle(.bordered)
                        if reveal{Text(l.interview.answer).font(.system(.body,design:.serif)).lineSpacing(5).textSelection(.enabled)}
                        HStack{Button("Previous"){index=max(0,index-1);reveal=false};Spacer();Button("Next question"){index+=1;reveal=false}}.buttonStyle(.bordered)
                        NavigationLink("Study this lesson",value:l)
                    }
                }
                AcademyCard{Text("A better self-assessment").font(.headline);Text("Can you recognize the term, explain the mechanism, derive it, implement it, and diagnose a new failure? Ask a reviewer to test you with an unseen problem.")}
            }.padding(24).frame(maxWidth:850)
        }.frame(maxWidth:.infinity).background(Color.academyPaper)
    }
}
struct NotebookView:View {
    @EnvironmentObject var store:AcademyStore
    var notes:[Lesson]{store.lessons.filter{!store.value("note:"+$0.id).isEmpty}}
    var body:some View {
        List{
            if notes.isEmpty{ContentUnavailableView("Your explanations belong here",systemImage:"note.text",description:Text("Open a lesson and write your first working note."))}
            ForEach(notes){l in NavigationLink(value:l){VStack(alignment:.leading,spacing:8){Text(l.title).font(.headline);Text(store.value("note:"+l.id)).lineLimit(6).foregroundStyle(.secondary)}}}
        }
    }
}
