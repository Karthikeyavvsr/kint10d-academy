import SwiftUI
@main struct KINT10dAcademyApp: App {
    @StateObject private var store=AcademyStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            AcademyRoot().environmentObject(store)
                .tint(Color.academyAccent)
                .task{await store.syncCloud()}
                .onChange(of:phase){_,value in if value == .active {store.syncFolder(); Task{await store.syncCloud()}} }
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
