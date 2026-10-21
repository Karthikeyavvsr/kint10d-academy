import SwiftUI
import AcademyCore

struct LearningProgressCard:View {
    @EnvironmentObject var store:AcademyStore
    @AppStorage("academy.dailyMinutes") var dailyMinutes=30
    var remaining:Int{store.lessons.filter{store.value("lesson:"+$0.id) != "read"}.reduce(0){$0+$1.minutes}}
    var total:Int{store.lessons.reduce(0){$0+$1.minutes}}
    var pace:PaceEstimate {
        let completed=store.lessons.compactMap{lesson->CompletedReading? in
            guard let record=store.records["lesson:"+lesson.id],record.value=="read",let date=ProgressLogic.date(record.updated) else{return nil}
            return CompletedReading(minutes:lesson.minutes,date:date)
        }
        let started=ProgressLogic.date(store.value("setting:started")) ?? Date()
        return PaceEstimate.calculate(remainingMinutes:remaining,completions:completed,started:started)
    }
    var body:some View {
        AcademyCard {
            HStack{Text("Your learning journey").font(.headline);Spacer();Text("\(store.readCount)/\(store.lessons.count)").font(.subheadline.monospacedDigit())}
            ProgressView(value:Double(total-remaining),total:Double(max(1,total))).accessibilityLabel("Reading progress").accessibilityValue("\(Int(Double(total-remaining)/Double(max(1,total))*100)) percent")
            Text("\(Int(Double(total-remaining)/Double(max(1,total))*100))% of estimated lesson reading completed").font(.caption).foregroundStyle(.secondary)
            if remaining==0{Text("First reading pass complete. Keep practicing and reviewing.").font(.title3)}
            else {
                Text("About \(Int(ceil(Double(remaining)/60))) reading hours remain.").font(.system(.title3,design:.serif))
                if let days=pace.daysRemaining,let rate=pace.readingMinutesPerDay {
                    Text("At your recent pace: about \(Int(ceil(days))) more days.").font(.headline)
                    Text("Based on \(Int(rate.rounded())) estimated reading minutes completed per calendar day across the last \(pace.sampleDays) days. Days off count too.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Your pace is warming up.").font(.headline)
                    Text("An estimate needs at least 3 days of history and 3 completed lessons in the recent window.").font(.caption).foregroundStyle(.secondary)
                }
                Text("At your plan of \(dailyMinutes) min/day: roughly \(Int(ceil(Double(remaining)/Double(max(1,dailyMinutes))))) days.").font(.subheadline)
            }
            Text("These are reading estimates, not measured attention or a mastery deadline. Exercises, full courses, papers and projects take additional time.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
#if os(iOS)
struct NativeTabs:View {
    @State private var selected = 0
    @State private var reading = false
    var body:some View {
        TabView(selection: $selected) {
            NativeTab(screen:.today).tabItem{Label("Today",systemImage:"sun.horizon")}.tag(0)
            NativeTab(screen:.curriculum).tabItem{Label("Learn",systemImage:"books.vertical")}.tag(1)
            NavigationStack{ExploreView().navigationTitle("Explore")}.toolbar(.hidden, for: .tabBar).tabItem{Label("Explore",systemImage:"sparkle.magnifyingglass")}.tag(2)
            NativeTab(screen:.notebook).tabItem{Label("Notes",systemImage:"note.text")}.tag(3)
            NativeTab(screen:.settings).tabItem{Label("Settings",systemImage:"gearshape")}.tag(4)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { AcademyFloatingDock(selected: $selected, reading: reading) }
        .onPreferenceChange(MikoReadingKey.self) { reading = $0 }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--miko-preview-settings") { selected = 4 }
            #endif
        }.onOpenURL { url in
            guard url.scheme == "academy", url.host == "resume" else { return }
            selected = 0
            NotificationCenter.default.post(name: .init("academy.resume"), object: nil)
        }
    }
}
/// One shared floating dock: the companion's feet meet the capsule edge.
struct AcademyFloatingDock: View {
    @Binding var selected: Int
    var reading: Bool
    @EnvironmentObject var store: AcademyStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let titles = ["Today", "Learn", "Explore", "Notes", "Settings"]
    private let icons = ["sun.horizon", "books.vertical", "sparkle.magnifyingglass", "note.text", "gearshape"]
    var body: some View {
        VStack(spacing: 0) {
            MikoLedge(reading: reading).padding(.horizontal, 20)
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Button { selected = index } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icons[index]).font(.system(size: 20, weight: .medium))
                            Text(titles[index]).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth: .infinity).frame(minHeight: 52)
                            .foregroundStyle(selected == index ? Color.academyAccent : Color.primary)
                            .background { if selected == index { Capsule().fill(Color.primary.opacity(0.08)) } }
                            .contentShape(Capsule())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(selected == index ? .isSelected : [])
                }
            }.padding(6)
                .background { if reduceTransparency { Capsule().fill(Color.academyPaper) } else { Capsule().fill(.regularMaterial) } }
                .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }.frame(maxWidth: 560).padding(.horizontal, 18).padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(stops: [.init(color: Color.academyPaper.opacity(0), location: 0), .init(color: Color.academyPaper, location: 0.22), .init(color: Color.academyPaper, location: 1)], startPoint: .top, endPoint: .bottom)
                    .padding(.top, -14).ignoresSafeArea(edges: .bottom)
            }
    }
}
struct NativeTab:View {
    let screen:AcademyScreen
    @EnvironmentObject var store:AcademyStore
    @State var path:[Lesson]=[]
    var body:some View {
        NavigationStack(path:$path) {
            Group{
                switch screen {
                case .today: TodayView{path.append($0)}
                case .curriculum: CurriculumView()
                case .notebook: NotebookView()
                default: AcademySettings()
                }
            }.navigationTitle(screen.rawValue)
                .navigationDestination(for:Lesson.self){LessonReader(lesson:$0)}
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            #if DEBUG
            if screen == .today, ProcessInfo.processInfo.arguments.contains("--miko-preview-reading"), path.isEmpty, let first = store.lessons.first { path = [first] }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("academy.resume"))) { _ in
            guard screen == .today, let lesson = store.continueLesson else { return }
            path = [lesson]
        }
    }
}
#endif
struct ExploreView:View {
    var body:some View {
        List {
            NavigationLink{PaperShelf().navigationTitle("Paper library")}label:{Label("Research papers",systemImage:"doc.text.magnifyingglass")}
            NavigationLink{NativeLabs().navigationTitle("Visual labs")}label:{Label("Interactive visual labs",systemImage:"slider.horizontal.3")}
            NavigationLink{InterviewView().navigationTitle("Interview room")}label:{Label("Interview practice",systemImage:"bubble.left.and.bubble.right")}
            NavigationLink{ResourcesView().navigationTitle("Resources")}label:{Label("Courses, videos and books",systemImage:"arrow.up.right.square")}
        }.navigationDestination(for:Lesson.self){LessonReader(lesson:$0)}
    }
}
