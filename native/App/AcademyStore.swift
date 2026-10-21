import SwiftUI
import Combine
import UserNotifications
import UniformTypeIdentifiers
import AcademyCore

struct ProgressDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor final class AcademyStore: ObservableObject {
    @Published var lessons: [Lesson] = []
    @Published var papers: [Paper] = []
    @Published var resources: [Resource] = []
    @Published var records: [String:ProgressRecord] = [:]
    @Published var status = "Offline reading · progress on this device"
    @Published var error: String?
    @Published var folderName: String?
    @Published var notificationStatus = "Reminders are off on this device."
    @Published var cloudConnected = false
    @Published var cloudStatus = "Cloud sync is not connected."
    private var cloudTask: Task<Void,Never>?
    private var cloudBusy = false
    private var cloudGeneration = UUID()
    private var folder: URL?
    private var syncTask: Task<Void,Never>?
    private var canWrite = true
    private let file: URL
    private let deviceID: String

    init() {
        let base = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!
            .appendingPathComponent("KINT10dAcademy",isDirectory:true)
        file = base.appendingPathComponent("progress.json")
        let d = UserDefaults.standard.string(forKey:"academy.deviceID") ?? UUID().uuidString
        deviceID=d; UserDefaults.standard.set(d,forKey:"academy.deviceID")
        do {
            try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true)
            lessons = try Self.load("curriculum")
            papers = try Self.load("papers")
            resources = try Self.load("resources")
            if FileManager.default.fileExists(atPath:file.path) { records = try ProgressLogic.decode(Data(contentsOf:file)).records }
        } catch { self.error="Could not load saved content: \(error.localizedDescription). Existing data is preserved."; canWrite=false }
        if canWrite && records["setting:started"] == nil { set("setting:started",ProgressLogic.timestamp()) }
        restoreFolder()
        do { cloudConnected = try CloudVault.load() != nil }
        catch { cloudStatus = error.localizedDescription }
    }

    private static func load<T:Decodable>(_ name:String) throws -> T {
        guard let url=Bundle.main.url(forResource:name,withExtension:"json") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(T.self,from:Data(contentsOf:url))
    }
    func value(_ key:String) -> String { records[key]?.value ?? "" }
    func decoded<T:Decodable>(_ type:T.Type,key:String) -> T? { try? JSONDecoder().decode(type,from:Data(value(key).utf8)) }
    var continueLesson: Lesson? {
        let id=LearningNavigation.continueID(orderedIDs:lessons.map(\.id),completed:Set(lessons.filter{value("lesson:"+$0.id)=="read"}.map(\.id)),bookmark:bookmark?.lesson)
        return lessons.first{$0.id==id}
    }
    var readCount: Int { lessons.filter{value("lesson:"+$0.id)=="read"}.count }
    var dueLessons: [Lesson] { lessons.filter { (decoded(Recall.self,key:"review:"+$0.id)?.due ?? .infinity) <= Date().timeIntervalSince1970*1000 } }
    var bookmark: Bookmark? { decoded(Bookmark.self,key:"bookmark:last") }
    func set<T:Encodable>(_ key:String,object:T) {
        do { let data=try JSONEncoder().encode(object); set(key,String(decoding:data,as:UTF8.self)) }
        catch { self.error=error.localizedDescription }
    }
    func set(_ key:String,_ value:String) {
        guard canWrite else { error="Stored progress could not be loaded safely. Export a backup and resolve the load error before saving."; return }
        guard value.utf8.count<=20000 else { error="This note is too large (20 KB maximum)."; return }
        var next=records
        let previousDate=records[key].flatMap{ProgressLogic.date($0.updated)} ?? .distantPast
        let now=max(Date(),previousDate.addingTimeInterval(0.001))
        next[key]=ProgressRecord(key:key,value:value,revision:(records[key]?.revision ?? 0)+1,updated:ProgressLogic.timestamp(now))
        do { try persist(next); status="Saved on this device"; scheduleFolderSync(); scheduleCloudSync() }
        catch { self.error="Save failed: "+error.localizedDescription }
    }
    private func persist(_ next:[String:ProgressRecord]) throws {
        let data=try export(next)
        _ = try ProgressLogic.decode(data)
        try data.write(to:file,options:.atomic)
        records=next
    }
    func export(_ data:[String:ProgressRecord]?=nil) throws -> Data {
        let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        return try encoder.encode(Snapshot(records:data ?? records))
    }
    func importProgress(_ url:URL) {
        let access=url.startAccessingSecurityScopedResource(); defer{if access{url.stopAccessingSecurityScopedResource()}}
        do {
            let incoming=try ProgressLogic.decode(Data(contentsOf:url))
            let backup=file.deletingLastPathComponent().appendingPathComponent("before-import-"+UUID().uuidString+".json")
            try export().write(to:backup,options:.atomic)
            try persist(ProgressLogic.merge(records,incoming.records))
            status="Imported newer records; backup retained on this device"
            scheduleFolderSync(); scheduleCloudSync()
        } catch { self.error="Import failed: "+error.localizedDescription }
    }
    func recall(_ lesson:Lesson,success:Bool) {
        let previous=decoded(Recall.self,key:"review:"+lesson.id)
        set("review:"+lesson.id,object:Recall(success:success,previousDays:previous?.days ?? 1))
    }
    func selectFolder(_ url:URL) {
        let access=url.startAccessingSecurityScopedResource()
        defer{if access{url.stopAccessingSecurityScopedResource()}}
        do {
            #if os(macOS)
            let bookmark=try url.bookmarkData(options:[.withSecurityScope],includingResourceValuesForKeys:nil,relativeTo:nil)
            #else
            let bookmark=try url.bookmarkData(options:[.minimalBookmark],includingResourceValuesForKeys:nil,relativeTo:nil)
            #endif
            UserDefaults.standard.set(bookmark,forKey:"academy.folderBookmark")
            folder=url; folderName=url.lastPathComponent; syncFolder()
        } catch { self.error="Folder access failed: "+error.localizedDescription }
    }
    private func restoreFolder() {
        guard let data=UserDefaults.standard.data(forKey:"academy.folderBookmark") else{return}
        do {
            var stale=false
            #if os(macOS)
            let url=try URL(resolvingBookmarkData:data,options:[.withSecurityScope],relativeTo:nil,bookmarkDataIsStale:&stale)
            #else
            let url=try URL(resolvingBookmarkData:data,options:[],relativeTo:nil,bookmarkDataIsStale:&stale)
            #endif
            if stale { status="Choose your shared folder again to renew access"; return }
            folder=url; folderName=url.lastPathComponent
        } catch { status="Shared folder unavailable; choose it again in Settings" }
    }
    func disconnectFolder() {
        syncTask?.cancel(); folder=nil; folderName=nil
        UserDefaults.standard.removeObject(forKey:"academy.folderBookmark")
        status="Folder disconnected; local progress retained"
    }
    private func scheduleFolderSync() {
        guard folder != nil else{return}
        syncTask?.cancel()
        syncTask=Task { try? await Task.sleep(for:.seconds(1)); if !Task.isCancelled { syncFolder() } }
    }
    func syncFolder() {
        guard let folder,canWrite else{return}
        let access=folder.startAccessingSecurityScopedResource()
        defer{if access{folder.stopAccessingSecurityScopedResource()}}
        do {
            let urls=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:[.ubiquitousItemDownloadingStatusKey],options:.skipsHiddenFiles)
                .filter{$0.lastPathComponent.hasPrefix("k10-progress-") && $0.pathExtension=="json"}
            guard urls.count<=100 else{throw ProgressLogic.ValidationError.invalid("Too many progress files in this folder.")}
            var merged=records
            for url in urls {
                let values=try url.resourceValues(forKeys:[.ubiquitousItemDownloadingStatusKey])
                if let state=values.ubiquitousItemDownloadingStatus,state != .current {
                    try FileManager.default.startDownloadingUbiquitousItem(at:url)
                    throw ProgressLogic.ValidationError.invalid("iCloud is downloading progress. Try Sync again shortly.")
                }
                let data=try coordinatedRead(url)
                merged=ProgressLogic.merge(merged,try ProgressLogic.decode(data).records)
            }
            try persist(merged)
            let destination=folder.appendingPathComponent("k10-progress-"+deviceID+".json")
            try coordinatedWrite(export(),to:destination)
            status="Shared-folder file updated · iCloud delivery may still be pending"
        } catch { status="Folder sync incomplete; local progress retained"; self.error=error.localizedDescription }
    }
    private func coordinatedRead(_ url:URL) throws -> Data {
        var coordinationError:NSError?, result:Result<Data,Error>?
        NSFileCoordinator().coordinate(readingItemAt:url,options:[],error:&coordinationError){ location in result=Result{try Data(contentsOf:location)} }
        if let coordinationError {throw coordinationError}
        guard let result else {throw CocoaError(.fileReadUnknown)}
        return try result.get()
    }
    private func coordinatedWrite(_ data:Data,to url:URL) throws {
        var coordinationError:NSError?, writeError:Error?
        NSFileCoordinator().coordinate(writingItemAt:url,options:.forReplacing,error:&coordinationError){ location in
            do{try data.write(to:location,options:.atomic)}catch{writeError=error}
        }
        if let coordinationError{throw coordinationError};if let writeError{throw writeError}
    }
    func connectCloud(endpoint:String,token:String) async {
        do {
            _ = try CloudAPI.endpoint(endpoint)
            guard token.count>=32,token.count<=256,!token.contains(where:{$0.isWhitespace}) else {throw ProgressLogic.ValidationError.invalid("Enter the complete private pairing key.")}
            let credentials=CloudCredentials(endpoint:endpoint.trimmingCharacters(in:.whitespacesAndNewlines),token:token)
            _ = try await CloudAPI.fetch(credentials)
            try CloudVault.save(credentials)
            cloudGeneration=UUID();cloudConnected=true
            await syncCloud()
        }catch{cloudStatus=error.localizedDescription}
    }
    func disconnectCloud() {
        do{try CloudVault.remove();cloudTask?.cancel();cloudGeneration=UUID();cloudConnected=false;cloudStatus="Disconnected. Local progress is retained."}
        catch{cloudStatus=error.localizedDescription}
    }
    private func scheduleCloudSync() {
        guard cloudConnected else{return}
        cloudTask?.cancel()
        cloudTask=Task{try? await Task.sleep(for:.seconds(2));if !Task.isCancelled{await syncCloud()}}
    }
    func syncCloud() async {
        guard cloudConnected,canWrite,!cloudBusy else{return}
        cloudBusy=true;defer{cloudBusy=false}
        let generation=cloudGeneration
        cloudStatus="Syncing…"
        do {
            guard let credentials=try CloudVault.load() else{throw ProgressLogic.ValidationError.invalid("Pair this device again.")}
            for _ in 0..<3 {
                let remote=try await CloudAPI.fetch(credentials)
                guard generation==cloudGeneration,!Task.isCancelled else{return}
                // Re-read current local records after awaiting the network, preserving edits made during sync.
                let merged=ProgressLogic.merge(records,remote.snapshot.records)
                if merged != records {try persist(merged)}
                let sent=records
                let accepted=try await CloudAPI.push(credentials,snapshot:Snapshot(records:sent),revision:remote.revision)
                guard generation==cloudGeneration,!Task.isCancelled else{return}
                if accepted {
                    cloudStatus="Synced at \(Date().formatted(date:.omitted,time:.shortened))"
                    if records != sent {scheduleCloudSync()}
                    return
                }
            }
            cloudStatus="Another device is updating. Local progress is safe; tap Sync again."
        }catch{cloudStatus="Sync pending: "+error.localizedDescription}
    }
    func reminderStatus() async {
        let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        let requests=await center.pendingNotificationRequests()
        if settings.authorizationStatus == .denied { notificationStatus="Notifications are denied. Change permission in system Settings." }
        else if let r=requests.first(where:{$0.identifier=="academy.daily"}),let trigger=r.trigger as? UNCalendarNotificationTrigger {
            notificationStatus=String(format:"Daily reminder scheduled on this device at %02d:%02d. Delivery follows system settings.",trigger.dateComponents.hour ?? 0,trigger.dateComponents.minute ?? 0)
        } else { notificationStatus="No daily reminder is scheduled on this device." }
    }
    func scheduleReminder(at date:Date) async {
        do {
            let center=UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options:[.alert,.sound,.badge]) else { await reminderStatus(); return }
            let parts=Calendar.current.dateComponents([.hour,.minute],from:date)
            let content=UNMutableNotificationContent()
            content.title="A little learning, deliberately."
            content.body="Recall yesterday’s idea, study one mechanism, and solve a fresh example."
            content.sound = .default
            let request=UNNotificationRequest(identifier:"academy.daily",content:content,trigger:UNCalendarNotificationTrigger(dateMatching:parts,repeats:true))
            try await center.add(request); await reminderStatus()
        }catch{self.error="Could not schedule reminder: "+error.localizedDescription}
    }
    func disableReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["academy.daily"])
        await reminderStatus()
    }
}
