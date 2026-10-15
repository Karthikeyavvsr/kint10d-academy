import Foundation
import Security
import AcademyCore

struct CloudCredentials:Codable { let endpoint:String; let token:String }
enum CloudVault {
    private static let service="org.kint10d.academy.sync"
    static func load() throws -> CloudCredentials? {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"owner",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        let status=SecItemCopyMatching(query as CFDictionary,&result)
        if status == errSecItemNotFound{return nil}
        guard status == errSecSuccess,let data=result as? Data else{throw failure(status)}
        return try JSONDecoder().decode(CloudCredentials.self,from:data)
    }
    static func save(_ credentials:CloudCredentials) throws {
        let data=try JSONEncoder().encode(credentials)
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"owner"]
        let update=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if update == errSecItemNotFound {
            var insert=query;insert[kSecValueData as String]=data;insert[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status=SecItemAdd(insert as CFDictionary,nil);guard status == errSecSuccess else{throw failure(status)}
        }else if update != errSecSuccess{throw failure(update)}
    }
    static func remove() throws {
        let status=SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"owner"] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else{throw failure(status)}
    }
    static func failure(_ code:OSStatus)->Error{NSError(domain:"Keychain",code:Int(code),userInfo:[NSLocalizedDescriptionKey:"Secure storage could not be accessed (\(code))."])}
}
struct CloudState:Codable {let revision:Int;let snapshot:Snapshot}
// Never forward the pairing secret to a redirect destination.
final class NoRedirect:NSObject,URLSessionTaskDelegate,@unchecked Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
enum CloudAPI {
    static func endpoint(_ text:String)throws->URL {
        guard let url=URL(string:text.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="https",url.host != nil,url.user==nil,url.password==nil,url.query==nil,url.fragment==nil,(url.path.isEmpty || url.path=="/") else{throw ProgressLogic.ValidationError.invalid("Enter an HTTPS server address without a path or credentials.")}
        return url.appendingPathComponent("v1/progress")
    }
    static func request(_ c:CloudCredentials,body:Data?=nil)async throws->(Data,Int){
        var request=URLRequest(url:try endpoint(c.endpoint));request.timeoutInterval=20
        request.httpMethod=body==nil ? "GET":"PUT";request.httpBody=body
        request.setValue("Bearer "+c.token,forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let config=URLSessionConfiguration.ephemeral;config.urlCache=nil
        let session=URLSession(configuration:config,delegate:NoRedirect(),delegateQueue:nil)
        defer{session.invalidateAndCancel()}
        let (bytes,response)=try await session.bytes(for:request)
        var data=Data();for try await byte in bytes{guard data.count<5_100_000 else{throw ProgressLogic.ValidationError.invalid("Server response is too large.")};data.append(byte)}
        guard let response=response as? HTTPURLResponse else{throw URLError(.badServerResponse)}
        return(data,response.statusCode)
    }
    static func fetch(_ c:CloudCredentials)async throws->CloudState {
        let (data,status)=try await request(c);guard status==200 else{throw error(status)}
        let remote=try JSONDecoder().decode(CloudState.self,from:data)
        guard remote.revision>=0 else{throw error(400)}
        _ = try ProgressLogic.decode(JSONEncoder().encode(remote.snapshot));return remote
    }
    static func push(_ c:CloudCredentials,snapshot:Snapshot,revision:Int)async throws->Bool {
        let (_,status)=try await request(c,body:JSONEncoder().encode(CloudState(revision:revision,snapshot:snapshot)))
        if status==409{return false};guard status==200 else{throw error(status)};return true
    }
    static func error(_ status:Int)->Error{ProgressLogic.ValidationError.invalid(status==401 ? "Pairing key rejected. Check the key in Settings." : "Sync server returned \(status). Local progress is retained.")}
}
