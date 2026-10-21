import SwiftUI
import WebKit
import CryptoKit

struct ResourceResume: Codable, Equatable {
    var source: String
    var title: String
    var url: String
    var scroll: Double = 0
    var video: String? = nil
    var seconds: Double = 0
    var playlist: String? = nil
    var index: Int = 0
    var ended: Bool = false
    var positionDescription: String {
        if video != nil { return ended ? "Video ended · reopen to continue" : "Video saved at \(Int(seconds)/60):\(String(format: "%02d", Int(seconds)%60))" }
        return "Last page saved · video progress may be unavailable"
    }
    static func key(_ source: String) -> String {
        "bookmark:resource_" + SHA256.hash(data:Data(source.utf8)).map{String(format:"%02x",$0)}.joined()
    }
}
extension AcademyStore {
    var resourceResume: ResourceResume? { decoded(ResourceResume.self,key:"bookmark:resource_last") }
    func resourceResume(for source:String) -> ResourceResume? { decoded(ResourceResume.self,key:ResourceResume.key(source)) }
    func saveResource(_ resume:ResourceResume) {
        set(ResourceResume.key(resume.source),object:resume)
        set("bookmark:resource_last",object:resume)
    }
}
struct ResourceLink: View {
    @EnvironmentObject private var store:AcademyStore
    var title:String
    var address:String
    var resourceTitle:String? = nil
    @State private var showing=false
    var body:some View {
        Button {
            if let resource=store.resources.first(where:{$0.url==address}),store.value("resource:"+resource.id).isEmpty {store.set("resource:"+resource.id,"opened")}
            if let paper=store.papers.first(where:{$0.url==address}),store.value("paper:"+paper.id).isEmpty {store.set("paper:"+paper.id,"opened")}
            showing=true
        } label: { Label(title,systemImage:"book.pages") }
            .sheet(isPresented:$showing) {
                ResourceReader(source:address,title:resourceTitle ?? title).environmentObject(store)
            }
    }
}
struct ResourceReader: View {
    @EnvironmentObject var store:AcademyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    let source:String
    let title:String
    @StateObject private var browser=StudyBrowser()
    var body:some View {
        VStack(spacing:0) {
            HStack {
                Button("Back") { browser.web.goBack() }.disabled(!browser.canGoBack)
                Spacer()
                Button("Open externally") { if let url=URL(string:browser.current?.url ?? source) { openURL(url) } }
                Button("Done") { browser.capture(); dismiss() }.buttonStyle(.borderedProminent)
            }.padding()
            Text(title).font(.headline).lineLimit(2).padding(.horizontal)
            Text(browser.message).font(.caption).foregroundStyle(.secondary).padding(8)
            StudyWebView(browser:browser)
            Text("Resume is saved only while using this reader. Separate browser/YouTube app activity is not tracked. Playback position is not proof of learning.")
                .font(.caption2).foregroundStyle(.secondary).padding(10)
        }.frame(minWidth:300,minHeight:420)
            .onAppear { browser.start(source:source,title:title,resume:store.resourceResume(for:source)) { store.saveResource($0) } }
            .onChange(of:phase) { _, value in if value != .active { browser.capture() } }
            .onDisappear { browser.capture(); browser.stop() }
    }
}
@MainActor final class StudyBrowser: NSObject,ObservableObject,WKNavigationDelegate,WKScriptMessageHandler {
    @Published var message="Opening resource…"
    @Published var canGoBack=false
    var current:ResourceResume?
    private var save:((ResourceResume)->Void)?
    private var lastSave=Date.distantPast
    private var started=false
    private var lastCheckpoint:ResourceResume?
    lazy var web:WKWebView = {
        let configuration=WKWebViewConfiguration()
        #if os(iOS)
        configuration.allowsInlineMediaPlayback=true
        #endif
        let view=WKWebView(frame:.zero,configuration:configuration)
        view.navigationDelegate=self
        return view
    }()
    func start(source:String,title:String,resume:ResourceResume?,save:@escaping(ResourceResume)->Void) {
        guard !started,let url=URL(string:resume?.url ?? source),["https","http"].contains(url.scheme ?? "") else{return}
        started=true;self.save=save
        current=resume ?? ResourceResume(source:source,title:title,url:source)
        web.configuration.userContentController.add(self,name:"study")
        let encoded=(try? JSONEncoder().encode(current)) ?? Data("null".utf8)
        let snapshot=String(decoding:encoded,as:UTF8.self).replacingOccurrences(of:"</",with:"<\\/")
        web.configuration.userContentController.addUserScript(WKUserScript(source:"window.academyResume = \(snapshot);\n"+Self.tracker,injectionTime:.atDocumentEnd,forMainFrameOnly:true))
        load(url)
    }
    private func load(_ url:URL) {
        let host=url.host?.lowercased() ?? ""
        if ["youtube.com","www.youtube.com","m.youtube.com","youtu.be"].contains(host) {
            let query=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems ?? []
            let video=host=="youtu.be" ? url.lastPathComponent : query.first{$0.name=="v"}?.value
            let playlist=query.first{$0.name=="list"}?.value
            let config:[String:Any]=["videoId":current?.video ?? video ?? "", "playerVars":["playsinline":1,"listType":"playlist","list":current?.playlist ?? playlist ?? "","index":current?.index ?? 0,"start":Int(current?.seconds ?? 0)]]
            let json=String(decoding:(try? JSONSerialization.data(withJSONObject:config)) ?? Data("{}".utf8),as:UTF8.self).replacingOccurrences(of:"</",with:"<\\/")
            web.loadHTMLString("<html><meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0;background:#111;color:white'><div id='player' style='width:100%;min-height:240px'></div><script>window.academyPlayerConfig=\(json);</script></body></html>",baseURL:URL(string:"https://"+(Bundle.main.bundleIdentifier ?? "org.kint10d.academy.mobile")))
        } else { web.load(URLRequest(url:url)) }
    }
    func capture() { web.evaluateJavaScript("window.academyCapture && window.academyCapture(true)",completionHandler:nil) }
    func stop() {
        // Persist the last received checkpoint even when the sheet is dismissed before JS replies.
        if let current { save?(current) }
        web.evaluateJavaScript("window.academyStop && window.academyStop()",completionHandler:nil)
        web.configuration.userContentController.removeScriptMessageHandler(forName:"study")
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        canGoBack=webView.canGoBack
        message="Page opened · position saves automatically"
    }
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) { message="Could not load this page. Try Open externally. Saved progress is kept." }
    func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=action.request.url else{decisionHandler(.cancel);return}
        guard ["https","http","about"].contains(url.scheme ?? "") else { decisionHandler(.cancel); return }
        if action.targetFrame == nil { decisionHandler(.cancel);load(url);return }
        if action.targetFrame?.isMainFrame == true,action.navigationType == .linkActivated,["youtube.com","www.youtube.com","m.youtube.com","youtu.be"].contains(url.host ?? "") {
            current?.video=nil;current?.seconds=0;current?.playlist=nil;current?.index=0;current?.url=url.absoluteString
            decisionHandler(.cancel);load(url);return
        }
        decisionHandler(.allow)
    }
    func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.frameInfo.isMainFrame,let data=message.body as? [String:Any],var checkpoint=current else{return}
        if let error=data["error"] as? String { self.message=error;return }
        guard let raw=data["url"] as? String,let observedURL=URL(string:raw) else{return}
        let ownPlayer=observedURL.host == Bundle.main.bundleIdentifier
        guard ownPlayer || observedURL.host==URL(string:checkpoint.source)?.host else {
            self.message="Outside this course · automatic checkpoints paused";return
        }
        if let url=URL(string:raw),url.host==URL(string:checkpoint.source)?.host {
            // Do not persist arbitrary query strings, authentication URLs or form content.
            guard !["login","signin","oauth","auth"].contains(where:{url.path.lowercased().contains($0)}) else { self.message="Sign-in page · automatic checkpoints paused"; return }
            do {
                var clean=URLComponents(url:url,resolvingAgainstBaseURL:false);clean?.query=nil
                let newURL=clean?.url?.absoluteString ?? checkpoint.url
                if checkpoint.url != newURL { checkpoint.video=nil;checkpoint.seconds=0;checkpoint.playlist=nil;checkpoint.index=0;checkpoint.ended=false }
                checkpoint.url=newURL
            }
        }
        if let scroll=data["scroll"] as? Double,scroll.isFinite { checkpoint.scroll=max(0,min(scroll,10_000_000)) }
        if let video=data["video"] as? String,video.range(of:"^[a-zA-Z0-9_-]{11}$",options:.regularExpression) != nil,
           let seconds=data["seconds"] as? Double,seconds.isFinite,seconds>=0,seconds<604800 {
            checkpoint.video=video;checkpoint.seconds=seconds;checkpoint.ended=data["ended"] as? Bool ?? false
            if let list=data["playlist"] as? String,list.range(of:"^[a-zA-Z0-9_-]{1,100}$",options:.regularExpression) != nil { checkpoint.playlist=list }
            checkpoint.index=max(0,min(data["index"] as? Int ?? 0,10000))
        }
        current=checkpoint
        let force=data["force"] as? Bool ?? false
        if force || Date().timeIntervalSince(lastSave)>=5 {
            if checkpoint != lastCheckpoint { save?(checkpoint);lastCheckpoint=checkpoint }
            lastSave=Date();self.message=checkpoint.positionDescription
        }
    }
    private static let tracker = #"""
    (() => {
      const saved=window.academyResume||{}; let player=null, timer=null;
      const post=o=>window.webkit.messageHandlers.study.postMessage(o);
      window.academyCapture=(force=false)=>{
        const d={url:location.href,scroll:window.scrollY,force};
        try { if(player && player.getVideoData) {
          const state=player.getPlayerState(),time=player.getCurrentTime();
          if(time>0 || state===0) {
            d.video=player.getVideoData().video_id;d.seconds=time;d.ended=state===0;
            d.index=player.getPlaylistIndex()||0;
            const list=new URL(player.getVideoUrl()).searchParams.get('list') || window.academyPlayerConfig?.playerVars?.list || window.academyEmbeddedPlaylist;if(list)d.playlist=list;
            const queue=player.getPlaylist();
            if(state===0 && queue && d.index+1<queue.length) {d.video=queue[d.index+1];d.index++;d.seconds=0;d.ended=false;}
          }
        }}catch(e){} post(d);
      };
      const events={onReady:e=>{try{if(saved.playlist && location.href===saved.url && saved.video!==e.target.getVideoData().video_id){e.target.cuePlaylist({list:saved.playlist,index:saved.index||0,startSeconds:saved.seconds||0});}else if(saved.video===e.target.getVideoData().video_id && saved.seconds>0)e.target.seekTo(saved.seconds,true);}catch(_){}},onStateChange:()=>window.academyCapture(true),onError:()=>post({error:'Video resume unavailable for this player. Page position is still saved; try Open externally.'})};
      const connect=()=>{
        if(window.academyPlayerConfig){ const c=window.academyPlayerConfig;c.width='100%';c.height=280;c.events=events;player=new YT.Player('player',c);return; }
        const frame=[...document.querySelectorAll('iframe')].find(f=>/^(https:)?\/\/(www\.)?(youtube\.com|youtube-nocookie\.com)\/embed\//.test(f.src));
        if(frame){const u=new URL(frame.src);window.academyEmbeddedPlaylist=u.searchParams.get('list');u.searchParams.set('enablejsapi','1');frame.src=u.href;player=new YT.Player(frame,{events});}
      };
      if(window.academyPlayerConfig || [...document.querySelectorAll('iframe')].some(f=>/youtube(-nocookie)?\.com\/embed\//.test(f.src))) {
        if(window.YT&&YT.Player)connect();else{window.onYouTubeIframeAPIReady=connect;const s=document.createElement('script');s.src='https://www.youtube.com/iframe_api';document.head.appendChild(s);}
      }
      if(location.href===saved.url && saved.scroll>0){setTimeout(()=>window.scrollTo(0,saved.scroll),800);}
      timer=setInterval(()=>window.academyCapture(),5000);
      window.addEventListener('pagehide',()=>window.academyCapture(true));
      document.addEventListener('visibilitychange',()=>{if(document.hidden)window.academyCapture(true);});
      window.academyStop=()=>{clearInterval(timer);try{player?.pauseVideo();}catch(_){};};
    })();
    """#
}
#if os(iOS)
struct StudyWebView:UIViewRepresentable {
    let browser:StudyBrowser
    func makeUIView(context:Context)->WKWebView{browser.web}
    func updateUIView(_ view:WKWebView,context:Context){}
}
#else
struct StudyWebView:NSViewRepresentable {
    let browser:StudyBrowser
    func makeNSView(context:Context)->WKWebView{browser.web}
    func updateNSView(_ view:WKWebView,context:Context){}
}
#endif
