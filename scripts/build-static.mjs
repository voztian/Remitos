import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'dist');
// La lista explícita es la barrera de publicación. No depende de archivos ocultos.
export const publicFiles=[
  'index.html','privacidad.html','manifest.json','sw.js',
  'apple-touch-icon.png','favicon-16.png','favicon-32.png','icon-192.png','icon-512.png',
  'supabase-2.110.6.min.js','jspdf-4.2.1.umd.min.js','qrcode-1.0.0.min.js',
  'tabler-icons-3.44.0.min.css','tabler-icons.woff2'
];
for(const file of publicFiles){
  if(!fs.existsSync(path.join(root,file)))throw new Error(`Falta el archivo público ${file}`);
}
fs.rmSync(out,{recursive:true,force:true});
fs.mkdirSync(out,{recursive:true});
for(const file of publicFiles)fs.copyFileSync(path.join(root,file),path.join(out,file));
fs.copyFileSync(path.join(root,'THIRD-PARTY-NOTICES.md'),path.join(out,'third-party-notices.txt'));
// Banco visual con datos ficticios: solamente en deployments de vista previa.
// El build de producción no copia ni enlaza estos archivos.
if(process.env.VERCEL_ENV==='preview'){
  const app=fs.readFileSync(path.join(root,'index.html'),'utf8');
  fs.writeFileSync(path.join(out,'qa-app.html'),app.replace('<script>','<script src="/qa-fixture.js"></script>\n<script>'));
  fs.copyFileSync(path.join(root,'scripts/qa-fixture.js'),path.join(out,'qa-fixture.js'));
  fs.copyFileSync(path.join(root,'scripts/qa.html'),path.join(out,'qa.html'));
}
console.log(`Publicación preparada: ${publicFiles.length+1} archivos. SQL, pruebas y versiones anteriores quedan fuera.`);
