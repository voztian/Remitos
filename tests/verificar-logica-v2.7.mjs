import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=fs.readFileSync(path.join(root,'index.html'),'utf8');

function extraerFuncion(nombre){
  // `js` contiene expresiones regulares con comillas; al estar completa en una
  // sola línea es más seguro extraerla literalmente que intentar interpretar JS.
  if(nombre==='js'){
    const linea=source.match(/^function js\(v\)\{[^\r\n]+\}$/m)?.[0];
    assert(linea,'No se encontró js');
    return linea;
  }
  const candidatos=[`function ${nombre}(`,`async function ${nombre}(`];
  const inicios=candidatos.map(x=>source.indexOf(x)).filter(x=>x>=0);
  assert(inicios.length,`No se encontró ${nombre}`);
  const inicio=Math.min(...inicios),llave=source.indexOf('{',inicio);
  let nivel=0,comilla='',escape=false;
  for(let i=llave;i<source.length;i++){
    const c=source[i];
    if(comilla){
      if(escape)escape=false;
      else if(c==='\\')escape=true;
      else if(c===comilla)comilla='';
      continue;
    }
    if(c==='"'||c==="'"||c==='`'){comilla=c;continue;}
    if(c==='{')nivel++;
    else if(c==='}'&&--nivel===0)return source.slice(inicio,i+1);
  }
  throw new Error(`La función ${nombre} no cierra`);
}

const nombres=[
  'documentoMime','documentoNombre','validarDocumento','verificarContenidoDocumento',
  'js','telWA','claveEstadoVisual','nivelSeguimiento','fechaPublica'
];
const contexto={Blob,Uint8Array,Error,MAX_DOCUMENTO_BYTES:10*1024*1024};
vm.createContext(contexto);
vm.runInContext(nombres.map(extraerFuncion).join('\n')+'\nthis.api={'+nombres.join(',')+'};',contexto);
const f=contexto.api;

assert(f.validarDocumento({name:'remito.PDF',type:'application/pdf',size:120}).mime==='application/pdf','PDF válido rechazado');
assert(f.validarDocumento({name:'foto.jpeg',type:'image/jpeg',size:120}).mime==='image/jpeg','JPEG válido rechazado');
assert(f.validarDocumento({name:'captura.png',type:'image/png',size:120}).mime==='image/png','PNG válido rechazado');
assert(f.validarDocumento({name:'captura.webp',type:'image/webp',size:120}).mime==='image/webp','WebP válido rechazado');
assert.throws(()=>f.validarDocumento({name:'malware.pdf',type:'application/x-msdownload',size:120}),/PDF|extensión/i);
assert.throws(()=>f.validarDocumento({name:'remito.txt',type:'application/pdf',size:120}),/extensión/i);
assert.throws(()=>f.validarDocumento({name:'grande.pdf',type:'application/pdf',size:10*1024*1024+1}),/10 MB/i);
const nombreLargo=f.documentoNombre('a'.repeat(240)+'.pdf');
assert(nombreLargo.length===180&&nombreLargo.endsWith('.pdf'),'El nombre largo no conserva una extensión válida');
assert(!/[\u0000-\u001f\u007f]/.test(f.documentoNombre('remito\nmal.pdf')),'El nombre conserva caracteres de control');

const archivos=[
  ['PDF',new Blob([Buffer.from('%PDF-1.7\n')]),'application/pdf',true],
  ['ejecutable renombrado',new Blob([Buffer.from('MZ................')]),'application/pdf',false],
  ['JPEG',new Blob([Buffer.from([0xff,0xd8,0xff,0xe0])]),'image/jpeg',true],
  ['PNG',new Blob([Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])]),'image/png',true],
  ['WebP',new Blob([Buffer.from('RIFF0000WEBP')]),'image/webp',true]
];
for(const [nombre,blob,mime,esperado] of archivos){
  let valido=true;
  try{await f.verificarContenidoDocumento(blob,mime);}catch{valido=false;}
  assert(valido===esperado,`${nombre}: validación de contenido incorrecta`);
}

const evento=f.js("O'Brien & <script>");
assert(!/[&'<>]/.test(evento),'El escape de eventos deja delimitadores HTML');
assert(f.telWA('011 15-1234-5678')==='549111512345678','Normalización telefónica inesperada');
assert(f.claveEstadoVisual({estado:'Pendiente',salidaAt:null})==='Programado','Pendiente sin salida no es Programado');
assert(f.claveEstadoVisual({estado:'Pendiente',salidaAt:'2026-09-02T10:00:00Z'})==='EnCamino','Pendiente con salida no es EnCamino');
assert(f.nivelSeguimiento('Programado')===1&&f.nivelSeguimiento('En camino')===2&&f.nivelSeguimiento('Entregado')===3,'Progreso público incorrecto');
assert(f.fechaPublica('2026-09-02')==='02/09/2026','Fecha pública incorrecta');

console.log('LÓGICA v2.7 OK: archivos, escape, estados, seguimiento y utilidades');
