import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createService,digest} from './server.mjs';

test('authentication, conflict protection, validation and durable recovery',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'academy-sync-'));
 const file=join(dir,'state.sqlite');const token='test-only-not-a-deployment-key';
 let server;
 const start=async()=>{server=createService({file,tokenHash:digest(token)});await new Promise(r=>server.listen(0,'127.0.0.1',r));return `http://127.0.0.1:${server.address().port}`;};
 let base=await start();
 const headers={Authorization:`Bearer ${token}`,'Content-Type':'application/json'};
 try{
  assert.equal((await fetch(base+'/health')).status,200);
  assert.equal((await fetch(base+'/v1/progress')).status,401);
  assert.equal((await fetch(base+'/v1/progress',{headers:{Authorization:'Bearer wrong'}})).status,401);
  const initial=await (await fetch(base+'/v1/progress',{headers})).json();assert.equal(initial.revision,0);
  const snapshot={exported:new Date().toISOString(),records:{'lesson:test':{key:'lesson:test',value:'read',revision:1,updated:new Date().toISOString()}}};
  const put=body=>fetch(base+'/v1/progress',{method:'PUT',headers,body:JSON.stringify(body)});
  assert.equal((await put({revision:0,snapshot})).status,200);
  assert.equal((await put({revision:0,snapshot:{...snapshot,records:{}}})).status,409);
  assert.equal((await put({revision:1,snapshot:{...snapshot,records:{bad:{}}}})).status,400);
  await new Promise(r=>server.close(r));base=await start();
  const recovered=await (await fetch(base+'/v1/progress',{headers})).json();
  assert.equal(recovered.revision,1);assert.deepEqual(recovered.snapshot,snapshot);
 }finally{await new Promise(r=>server.close(r));rmSync(dir,{recursive:true,force:true});}
});
