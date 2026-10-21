import SwiftUI
@main struct KINT10dAcademyApp: App {
    @StateObject private var store=AcademyStore()
    @StateObject private var miko=MikoSession()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            AcademyRoot().environmentObject(store).environmentObject(miko)
                .tint(Color.academyAccent)
                .task{
                    miko.changePhase(.active)
                    #if DEBUG && os(iOS)
                    if ProcessInfo.processInfo.arguments.contains("--miko-preview-session") { miko.start() }
                    #endif
                    await store.syncCloud()
                }
                .onChange(of:phase){_,value in miko.changePhase(value); if value == .active {store.syncFolder(); Task{await store.syncCloud()}} }
                .alert("Academy",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){
                    Button("OK"){store.error=nil}
                } message: {Text(store.error ?? "")}
        }
        #if os(macOS)
        .defaultSize(width:1180,height:820)
        #endif
    }
}
extension Color {
    static let academyGreen=Color(red:0.10,green:0.29,blue:0.24)
    static let academyPaper=Color("AcademyPaper")
    static let academyCard=Color("AcademyCard")
    static let academyAccent=Color("AcademyAccent")
}
