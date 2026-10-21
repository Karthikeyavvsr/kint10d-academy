const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(require('node:path').join(__dirname,'../App/ResourceReader.swift'),'utf8');
const script=source.split('private static let tracker = #"""')[1].split('"""#')[0];
function fixture({state=2,time=130,index=0,queue=['aaaaaaaaaaa','bbbbbbbbbbb'],saved={}}={}) {
 const messages=[];let seek=null,ready;
 const player={getPlayerState:()=>state,getCurrentTime:()=>time,getVideoData:()=>({video_id:queue[index]}),getPlaylistIndex:()=>index,getVideoUrl:()=>`https://www.youtube.com/watch?v=${queue[index]}&list=PLtest`,getPlaylist:()=>queue,seekTo:t=>{seek=t},pauseVideo:()=>{}};
 const document={querySelectorAll:()=>[],addEventListener(){},head:{appendChild(){}},createElement:()=>({})};
 const window={academyResume:saved,academyPlayerConfig:{playerVars:{list:'PLtest'}},webkit:{messageHandlers:{study:{postMessage:m=>messages.push(m)}}},addEventListener(){},scrollY:120,scrollTo(){}};
 const YT={Player:function(id,config){ready=config.events.onReady;return player}};
 window.YT=YT;
 vm.runInNewContext(script,{window,document,YT,location:{href:'https://org.kint10d.academy.mobile/'},URL,setInterval:()=>1,clearInterval(){},setTimeout:f=>f()});
 ready({target:player});window.academyCapture(true);
 return {message:messages.at(-1),seek};
}
assert.equal(fixture({saved:{video:'aaaaaaaaaaa',seconds:95}}).seek,95);
assert.equal(fixture().message.seconds,130);
const completed=fixture({state:0,time:600}).message;
assert.equal(completed.video,'bbbbbbbbbbb');assert.equal(completed.index,1);assert.equal(completed.seconds,0);
assert.equal(fixture({state:0,index:1}).message.ended,true);
assert.equal(fixture({state:-1,time:0}).message.video,undefined);
console.log('5 resource tracker checks passed (mock player; not live YouTube validation).');
