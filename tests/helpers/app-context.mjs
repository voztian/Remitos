import fs from 'node:fs';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
import {parseHTML} from 'linkedom';

export const source=fs.readFileSync(new URL('../../index.html',import.meta.url),'utf8');
export function appContext(){
  const {window,document}=parseHTML(source);
  const messages=[],timers=[];
  const storage=()=>{const m=new Map();return {getItem:k=>m.get(k)??null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k)};};
  const location=new URL('https://goremitos.example/');
  Object.assign(window,{location,scrollTo(){},matchMedia:()=>({matches:false}),confirm:()=>false,alert:message=>messages.push(message)});
  const ctx={window,document,location,navigator:{onLine:true,userAgent:'GoRemitos isolated test'},localStorage:storage(),sessionStorage:storage(),URL,URLSearchParams,Blob,File,Uint8Array,Response,Request,crypto:webcrypto,console:{error(){},warn(){},log(){}},alert:message=>messages.push(message),confirm:()=>false,setTimeout:fn=>{timers.push(fn);return timers.length;},clearTimeout(){},setInterval:()=>1,clearInterval(){},fetch:()=>{throw new Error('Network forbidden in isolated tests');}};
  vm.createContext(ctx);
  for(const [,script] of source.matchAll(/<script>([\s\S]*?)<\/script>/g))vm.runInContext(script,ctx);
  return {ctx,document,messages,run:code=>vm.runInContext(code,ctx),timers};
}

export function fakeQuery(rows,log=[]){
  let filtered=[...rows],orders=[],from=0,to=999999,single=false;
  const q={
    select(){return q;},
    eq(k,v){log.push(['eq',k,v]);filtered=filtered.filter(r=>r[k]===v);return q;},
    in(k,v){filtered=filtered.filter(r=>v.includes(r[k]));return q;},
    is(k,v){filtered=filtered.filter(r=>(r[k]??null)===v);return q;},
    not(k,op,v){filtered=filtered.filter(r=>(r[k]??null)!==v);return q;},
    or(expr){log.push(['or',expr]);return q;},
    order(k,o={}){orders.push([k,o.ascending!==false]);return q;},
    range(a,b){from=a;to=b;return q;},
    maybeSingle(){single=true;return q;},
    then(resolve,reject){
      filtered.sort((a,b)=>{for(const [k,asc] of orders){const c=String(a[k]??'').localeCompare(String(b[k]??''));if(c)return asc?c:-c;}return 0;});
      const data=filtered.slice(from,to+1);
      return Promise.resolve({data:single?(data[0]||null):data,count:filtered.length,error:null}).then(resolve,reject);
    }
  };return q;
}
