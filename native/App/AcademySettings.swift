import SwiftUI
import UniformTypeIdentifiers
struct AcademySettings:View {
    @EnvironmentObject var store:AcademyStore
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
            Section("Your plan"){
                Stepper("\(dailyMinutes) reading minutes per day",value:$dailyMinutes,in:10...120,step:5)
                Text("The planned estimate is separate from observed pace. No penalty for a missed day.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Study reminders on this device"){
                DatePicker("Time",selection:$reminder,displayedComponents:.hourAndMinute)
                Button("Enable daily reminder"){Task{await store.scheduleReminder(at:reminder)}}
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
                    TextField("HTTPS sync server",text:$cloudURL).textContentType(.URL)
                    SecureField("Private pairing key",text:$pairingKey)
                    Button(connecting ? "Connecting…":"Connect this device"){
                        connecting=true
                        Task{await store.connectCloud(endpoint:cloudURL,token:pairingKey);connecting=false;if store.cloudConnected{pairingKey=""}}
                    }.disabled(connecting)
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
                Text("Screen Time monitoring and Dynamic Island characters are deferred. This app does not inspect other-app activity.").font(.caption).foregroundStyle(.secondary)
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
