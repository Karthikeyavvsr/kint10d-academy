import http from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { createHash, timingSafeEqual } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const MAX = 5_000_000;
export const digest = token => createHash('sha256').update(token).digest('hex');
export function validate(snapshot) {
  if (!snapshot || typeof snapshot.exported !== 'string' || !Number.isFinite(Date.parse(snapshot.exported)) ||
      !snapshot.records || Array.isArray(snapshot.records) || typeof snapshot.records !== 'object') throw Error('Invalid snapshot');
  const entries = Object.entries(snapshot.records);
  if (entries.length > 5000) throw Error('Too many records');
  for (const [key, r] of entries) {
    if (!/^(lesson|paper|resource|note|review|quiz|bookmark|setting|capstone):[a-zA-Z0-9_-]{1,100}$/.test(key) ||
        !r || r.key !== key || typeof r.value !== 'string' || Buffer.byteLength(r.value) > 20000 ||
        !Number.isSafeInteger(r.revision) || r.revision < 0 || typeof r.updated !== 'string' || !Number.isFinite(Date.parse(r.updated))) throw Error('Invalid record');
  }
  return {records: Object.fromEntries(entries.map(([k,r]) => [k,{key:k,value:r.value,revision:r.revision,updated:r.updated}])), exported:snapshot.exported};
}
export function createService({file,tokenHash}) {
  if (!/^[a-f0-9]{64}$/.test(tokenHash ?? '')) throw Error('ACADEMY_TOKEN_SHA256 must be a SHA-256 hex digest');
  mkdirSync(dirname(file), {recursive:true});
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, snapshot TEXT NOT NULL);');
  db.prepare('INSERT OR IGNORE INTO state VALUES (1,0,?)').run(JSON.stringify({records:{},exported:new Date().toISOString()}));
  const expected=Buffer.from(tokenHash,'hex');
  // One owner, one instance. Rate limit bounds accidental client loops; no IP tracking.
  let windowStart=Date.now(), requests=0;
  const server=http.createServer(async(req,res)=>{
    const send=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));};
    if(req.url==='/health' && req.method==='GET') return send(200,{ok:true});
    const token=(req.headers.authorization ?? '').replace(/^Bearer /,'');
    if(!token || token.length>512 || !timingSafeEqual(Buffer.from(digest(token),'hex'),expected)) return send(401,{error:'Unauthorized'});
    if(Date.now()-windowStart>60000){windowStart=Date.now();requests=0;}
    if(++requests>120){res.setHeader('Retry-After','60');return send(429,{error:'Try again later'});}
    if(req.url!=='/v1/progress') return send(404,{error:'Not found'});
    if(req.method==='GET') {
      const row=db.prepare('SELECT revision,snapshot FROM state WHERE id=1').get();
      return send(200,{revision:row.revision,snapshot:JSON.parse(row.snapshot)});
    }
    if(req.method!=='PUT') return send(405,{error:'Method not allowed'});
    if(!req.headers['content-type']?.startsWith('application/json')) return send(415,{error:'JSON required'});
    if(Number(req.headers['content-length'])>MAX) return send(413,{error:'Too large'});
    try {
      let size=0;const chunks=[];
      for await (const chunk of req){size+=chunk.length;if(size>MAX){send(413,{error:'Too large'});return;}chunks.push(chunk);}
      const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(!Number.isSafeInteger(body.revision)||body.revision<0) return send(400,{error:'Invalid revision'});
      const snapshot=validate(body.snapshot);
      // A stale device must fetch and merge; it cannot overwrite an intervening write.
      const result=db.prepare('UPDATE state SET revision=revision+1,snapshot=? WHERE id=1 AND revision=?').run(JSON.stringify(snapshot),body.revision);
      if(!result.changes) return send(409,{error:'Fetch and merge before retrying'});
      return send(200,{revision:body.revision+1});
    } catch { return send(400,{error:'Invalid request'}); }
  });
  server.requestTimeout=15000;server.headersTimeout=10000;
  server.on('close',()=>db.close());
  return server;
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  const server=createService({file:process.env.DATABASE_PATH || '/data/academy.sqlite',tokenHash:process.env.ACADEMY_TOKEN_SHA256});
  server.listen(Number(process.env.PORT || 8080),'0.0.0.0',()=>console.log('Academy sync ready'));
  for(const signal of ['SIGTERM','SIGINT']) process.on(signal,()=>server.close(()=>process.exit(0)));
}
