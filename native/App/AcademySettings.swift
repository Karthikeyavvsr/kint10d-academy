import SwiftUI
import UniformTypeIdentifiers
struct AcademySettings:View {
    @EnvironmentObject var store:AcademyStore
    @EnvironmentObject var miko:MikoSession
    @AppStorage("academy.miko.visible") private var mikoVisible = true
    @AppStorage("academy.appearance") var appearance="system"
    @AppStorage("academy.dailyMinutes") var dailyMinutes=30
    @State var cloudURL=""
    @State var pairingKey=""
    @State var connecting=false
    @State var reminder=Date()
    @State var importing=false
    @State var choosingFolder=false
    @State var exporting=false
    @State var document=ProgressDocument(data:Data())
    var body:some View {
        Form {
            Section("Reading comfort"){
                Picker("Appearance",selection:$appearance){Text("System").tag("system");Text("Light").tag("light");Text("Dark").tag("dark")}.pickerStyle(.segmented)
                Text("Text follows system Dynamic Type. Reader A− / A+ adds a personal adjustment. VoiceOver, Bold Text and Reduce Motion use native controls.").font(.caption).foregroundStyle(.secondary)
                Text("Opaque reading surfaces keep glass away from long paragraphs. System navigation uses the material appropriate to your OS.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Connection") { Text(store.status).font(.caption).foregroundStyle(.secondary) }
            Section("Miko, your companion") {
                Toggle("Show tiny Miko", isOn: $mikoVisible)
                Text("Miko explores the floating navigation bar, pauses to look around, and wears glasses during lessons. Tap Miko to say hello. Reduce Motion keeps Miko still.").font(.caption).foregroundStyle(.secondary)
                #if os(iOS)
                if miko.running {
                    Button("End companion session") { miko.stop() }
                } else {
                    Button("Start companion session") { miko.start() }
                }
                Text(miko.message).font(.caption).foregroundStyle(.secondary)
                Text("On supported iPhones, Miko appears in the Dynamic Island; on iPad, on the Lock Screen. Sessions become stale after one hour. iOS controls visibility and may retain the card after force-quitting; end the session here to dismiss it. No other-app activity is monitored.").font(.caption).foregroundStyle(.secondary)
                #endif
            }
            Section("Your plan"){
                Stepper("\(dailyMinutes) reading minutes per day",value:$dailyMinutes,in:10...120,step:5)
                Text("The planned estimate is separate from observed pace. No penalty for a missed day.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Study reminders on this device"){
                DatePicker("Time",selection:$reminder,displayedComponents:.hourAndMinute)
                Button("Enable daily reminder"){Task{await store.scheduleReminder(at:reminder)}}.buttonStyle(.borderedProminent)
                Button("Turn off daily reminder"){Task{await store.disableReminder()}}
                Text(store.notificationStatus).font(.caption).foregroundStyle(.secondary)
                Text("Nothing is scheduled until you enable it and allow notifications. Focus and system settings can silence alerts. Configure each device separately.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Progress and backups"){
                Button("Export progress"){do{document=ProgressDocument(data:try store.export());exporting=true}catch{store.error=error.localizedDescription}}
                Button("Import progress file"){importing=true}
                Text("Import saved records from the website’s JSON export or another native device. Newer timestamps win. Unsaved web drafts are not imported. A local pre-import backup is retained.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Shared progress"){
                if store.cloudConnected {
                    Button("Sync now"){Task{await store.syncCloud()}}
                    Button("Disconnect this device"){store.disconnectCloud()}
                }else{
                    VStack(alignment:.leading,spacing:8) {
                        Label("Sync server address",systemImage:"network").font(.headline)
                        TextField("https://your-server",text:$cloudURL).textContentType(.URL)
                            .textFieldStyle(.plain).padding(12).background(Color.academyPaper,in:RoundedRectangle(cornerRadius:10))
                            .overlay(RoundedRectangle(cornerRadius:10).stroke(Color.academyAccent.opacity(0.6)))
                        Text("Enter the server address used on your other device.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical,6)
                    VStack(alignment:.leading,spacing:8) {
                        Label("Private pairing key",systemImage:"key").font(.headline)
                        SecureField("Paste your private key",text:$pairingKey)
                            .textFieldStyle(.plain).padding(12).background(Color.academyPaper,in:RoundedRectangle(cornerRadius:10))
                            .overlay(RoundedRectangle(cornerRadius:10).stroke(Color.academyAccent.opacity(0.6)))
                        Text("Stored securely in this device’s Keychain.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical,6)
                    Button(connecting ? "Connecting…":"Connect this device"){
                        connecting=true
                        Task{await store.connectCloud(endpoint:cloudURL,token:pairingKey);connecting=false;if store.cloudConnected{pairingKey=""}}
                    }.buttonStyle(.borderedProminent).disabled(connecting || cloudURL.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || pairingKey.isEmpty)
                }
                Text(store.cloudStatus).font(.caption).foregroundStyle(.secondary)
                Text("Use the same private server and pairing key on your devices. The key stays in this device’s Keychain. Newer record timestamps win; keep device clocks automatic. Sync runs on edits and when you return to the app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Optional shared folder"){
                if let name=store.folderName{
                    LabeledContent("Folder",value:name)
                    Button("Sync now"){store.syncFolder()}
                    Button("Disconnect folder"){store.disconnectFolder()}
                }else{Button("Choose a shared progress folder"){choosingFolder=true}}
                Text("Choose the same dedicated iCloud Drive folder on each device. Updates run while the app is active; delivery is asynchronous. Device clocks affect timestamp conflict resolution.").font(.caption).foregroundStyle(.secondary)
            }
            Section("About"){
                Text("Native SwiftUI · iPhone, iPad and Mac")
                Text("Bundled lessons and labs work offline; external papers and videos need a connection. Website account sync is not connected to this native build.").font(.caption).foregroundStyle(.secondary)
                Text("Miko does not inspect other-app activity or Screen Time.").font(.caption).foregroundStyle(.secondary)
                Link("Public source",destination:URL(string:"https://github.com/Karthikeyavvsr/kint10d-academy")!)
            }
        }.formStyle(.grouped).task{await store.reminderStatus()}
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json],allowsMultipleSelection:false){result in
            switch result{case .success(let urls):if let url=urls.first{store.importProgress(url)};case .failure(let error):store.error=error.localizedDescription}
        }
        .fileImporter(isPresented:$choosingFolder,allowedContentTypes:[.folder],allowsMultipleSelection:false){result in
            switch result{case .success(let urls):if let url=urls.first{store.selectFolder(url)};case .failure(let error):store.error=error.localizedDescription}
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"KINT10d-progress"){result in
            if case .failure(let error)=result{store.error=error.localizedDescription}
        }
    }
}
