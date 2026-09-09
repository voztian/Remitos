import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(msg);};

const requeridos=[
  'index.html','privacidad.html','manifest.json','vercel.json','_headers','.vercelignore','sw.js',
  'supabase-migration-v2.7.sql','supabase-finalizar-v2.7.sql',
  'supabase-reversion-emergencia-v2.7.sql','supabase-verificacion-v2.7.sql','README.md',
  'PRUEBAS-PILOTO-v2.7.md','OPERACION-Y-BACKUPS-v2.7.md','PRIVACIDAD-Y-CONTRATOS-v2.7.md',
  'CAMBIOS-v2.7.md','RESULTADO-VALIDACION-v2.7.md','CHECKSUMS-SHA256.txt',
  'CAMBIOS-v2.8.md','PRUEBAS-ESCRITORIO-v2.8.md',
  'VERSION.txt','tests/verificar-logica-v2.7.mjs'
];
for(const file of requeridos)assert(fs.existsSync(path.join(root,file)),`Falta ${file}`);

const checksums=read('CHECKSUMS-SHA256.txt').trim().split(/\r?\n/);
assert(checksums.length>=10,'La lista de integridad está incompleta');
for(const linea of checksums){
  const partes=linea.match(/^([a-f0-9]{64})  (.+)$/);
  assert(partes,`Línea inválida en CHECKSUMS-SHA256.txt: ${linea}`);
  const [,esperado,file]=partes;
  const destino=path.join(root,file);
  assert(fs.existsSync(destino),`El checksum referencia un archivo inexistente: ${file}`);
  const obtenido=crypto.createHash('sha256').update(fs.readFileSync(destino)).digest('hex');
  assert(obtenido===esperado,`Checksum incorrecto: ${file}`);
}

const manifest=JSON.parse(read('manifest.json'));
JSON.parse(read('vercel.json'));
assert(manifest.orientation==='any','La aplicación instalada todavía fuerza orientación vertical');
for(const icono of manifest.icons||[]){
  assert(/^\/[A-Za-z0-9._-]+$/.test(icono.src),`Ruta de ícono inválida: ${icono.src}`);
  assert(fs.existsSync(path.join(root,icono.src.slice(1))),`Falta el ícono ${icono.src}`);
}

for(const file of ['index.html','privacidad.html']){
  const html=read(file);
  for(const [,src] of html.matchAll(/(?:src|href)="(\/[^"?#]*)(?:[?#][^"]*)?"/g)){
    if(src==='/'||src==='/privacidad.html')continue;
    assert(fs.existsSync(path.join(root,src.slice(1))),`${file} referencia un archivo inexistente: ${src}`);
  }
  for(const [,script] of html.matchAll(/<script>([\s\S]*?)<\/script>/g))new Function(script);
  assert(!/cdn\.jsdelivr|cdnjs|unpkg\.com/i.test(html),`${file} todavía depende de un CDN`);
  assert(!/\/vendor\//.test(html),`${file} conserva una ruta vendor antigua`);
}

const index=read('index.html');
const htmlEstatico=index.slice(0,index.indexOf('<script>'));
const ids=[...htmlEstatico.matchAll(/\sid="([^"]+)"/g)].map(x=>x[1]);
assert(new Set(ids).size===ids.length,'Hay IDs HTML estáticos duplicados');
for(const imagen of htmlEstatico.matchAll(/<img\b[^>]*>/g))assert(/\salt="[^"]*"/.test(imagen[0]),'Hay una imagen estática sin texto alternativo');
assert(index.includes("const APP_VERSION='2.8.0'"),'Versión web incorrecta');
assert(index.includes('@media(min-width:900px)'),'Falta el diseño adaptable de escritorio');
assert(index.includes('grid-template-columns:244px minmax(0,1fr)'),'Falta la estructura principal con menú lateral');
assert(index.includes('class="desktop-nav-menu"'),'Falta el menú lateral de escritorio');
assert(index.includes('class="dashboard-main-grid"'),'Falta la distribución de escritorio del dashboard');
assert(index.includes('class="users-grid"'),'Falta la distribución de escritorio de usuarios');
assert(index.includes("document.body.classList.toggle('app-shell-visible',id==='view-app')"),'La vista de aplicación no activa su estructura responsive');
assert(index.includes('const contextoVersionado=`v${APP_VERSION}:'),'Los errores no identifican la versión de interfaz');
assert(index.includes("const BUCKET_DOCUMENTOS='documentos-remito'"),'Falta el bucket privado de documentos');
assert(index.includes('MAX_DOCUMENTO_BYTES=10*1024*1024'),'Falta el límite de 10 MB del documento');
assert(index.includes('async function verificarContenidoDocumento'),'Falta verificar la firma interna del documento');
assert(index.includes("const extensiones={'application/pdf':['pdf']"),'Falta comprobar que nombre, extensión y tipo coincidan');
assert(index.includes("extension=punto>0?final.slice(punto).slice(0,12):''"),'Los nombres largos pueden perder la extensión');
for(const firma of ['0x25,0x50,0x44,0x46,0x2d','0xff,0xd8,0xff','0x89,0x50,0x4e,0x47','0x52,0x49,0x46,0x46'])assert(index.includes(firma),`Falta validar la firma ${firma}`);
assert((index.match(/await verificarContenidoDocumento\(/g)||[]).length>=2,'La validación real debe ejecutarse al elegir y al subir');
assert((index.match(/await documentoBlob\(rem\)/g)||[]).length>=3,'Vista, descarga y constancia deben comprobar el hash del remito externo');
assert(index.includes("rpc('guardar_remito_v27'"),'La web no exige guardado v2.7');
assert(index.includes("rpc('marcar_en_camino_v27'"),'La web no registra el inicio del viaje');
assert(index.includes("rpc('confirmar_entrega_v27'"),'La web no usa el cierre v2.7');
assert(index.includes("rpc('resumen_remitos_v27'"),'La web no usa el resumen v2.7');
assert(index.includes("rpc('obtener_estado_operativo_v27'"),'La web no muestra la modalidad de infraestructura v2.7');
assert(index.includes("rpc('actualizar_preparacion_plataforma_v27'"),'La web no guarda la modalidad de infraestructura v2.7');
assert(index.includes("rpc('registrar_error_cliente_v27'"),'Los diagnósticos todavía se atribuyen a una versión anterior');
assert(index.includes('id="op-free"'),'Falta la opción explícita de piloto controlado en Free');
assert(index.includes("rpc('obtener_seguimiento_publico_v27'"),'Falta el seguimiento público');
assert(index.includes("rpc('eliminar_remito_pendiente_v27'"),'Falta el borrado seguro v2.7');
assert(index.includes('este usuario tiene una entrega en camino'),'La interfaz no explica por qué una baja en viaje queda bloqueada');
assert(!index.includes("rpc('guardar_remito_v26'"),'La web todavía guarda con v2.6');
assert(!index.includes("rpc('confirmar_entrega_v26'"),'La web todavía cierra con v2.6');
assert(index.includes('#seguimiento='),'El enlace nuevo de seguimiento debe usar fragmento para no registrar el token en el hosting');
assert(index.includes("get('seguimiento')||new URLSearchParams(window.location.search).get('seguimiento')"),'Falta compatibilidad con enlaces de seguimiento anteriores');
assert(index.includes('no muestra datos personales'),'Falta advertencia de privacidad del seguimiento');
assert(index.includes('GoRemitos no emite el remito original'),'Falta aclaración de alcance documental');
assert(index.includes('Confirmo que el receptor fue informado'),'Falta registrar la información al receptor');
assert(!index.includes('acepta el registro de sus datos'),'La interfaz no debe presentar una casilla operativa como consentimiento legal completo');
assert(index.includes('<meta name="referrer" content="no-referrer">'),'Falta protección de referencia fuera de Vercel');
assert(index.includes("replace(/&/g,'\\\\u0026').replace(/'/g,'\\\\u0027')"),'Los argumentos de eventos HTML no escapan caracteres delimitadores');
assert(index.includes('sb_publishable_'),'La web no contiene la clave pública esperada');
assert(!/eyJ[A-Za-z0-9_-]{20,}\./.test(index),'Posible JWT incluido en la web');
assert(!/service_role\s*[:=]\s*['"]/i.test(index),'Posible service_role incluido en la web');
assert(index.includes("localStorage.getItem('grm_recovery_pending')"),'La recuperación no persiste entre pestañas');
assert(!index.includes("sessionStorage.getItem('grm_recovery_pending')"),'La recuperación todavía depende de una sola pestaña');
assert(index.includes('https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'),'Falta Turnstile');
assert((index.match(/captchaToken/g)||[]).length>=3,'Turnstile no protege ingreso, alta y recuperación');
assert((index.match(/id="m-nota"/g)||[]).length===1,'El formulario manual tiene IDs duplicados');

const migration=read('supabase-migration-v2.7.sql');
for(const token of [
  'documentos-remito','documento_sha256','salida_at','guardar_remito_v27',
  'marcar_en_camino_v27','confirmar_entrega_v27','resumen_remitos_v27',
  'obtener_seguimiento_publico_v27','eliminar_remito_pendiente_v27',
  '_plataforma_lista_v27','piloto_free_aceptado','obtener_estado_operativo_v27',
  'actualizar_preparacion_plataforma_v27',
  'c.plan_pro_verificado <> c.piloto_free_aceptado',
  'registrar_error_cliente_v27',"'2.7.0'",
  '_documento_meta_v27','10485760','pg_advisory_xact_lock','documento_asociado_v27',
  'entrega_iniciada_v27','entrega_cerrada_v27','El formato declarado no coincide',
  'perform public._documento_meta_v27(v_rem.documento_url,v_rem.documento_sha256,false)',
  "v_meta->>'nombre_original'",'La extensión del nombre original no coincide',
  'informacion_receptor_confirmada',"documento_nombre !~ '[[:cntrl:]]'",
  'No se puede eliminar el acceso: el usuario tiene una entrega en camino',
  'No se puede cambiar el rol: el chofer tiene una entrega en camino',
  'public.current_empresa_id() is distinct from v_empresa',
  'Identificador de item invalido'
])assert(migration.includes(token),`La migración no contiene ${token}`);
for(const funcion of ['cambiar_rol_usuario','eliminar_usuario_empresa']){
  const bloque=migration.match(new RegExp(`create or replace function public\\.${funcion}\\([\\s\\S]*?revoke all on function public\\.${funcion}`))?.[0]||'';
  assert(bloque.includes("estado='Pendiente' and r.salida_at is not null"),`${funcion} no protege viajes en camino`);
  assert(bloque.includes("estado='Pendiente' and r.salida_at is null"),`${funcion} no limita la desasignación a programados`);
}
assert(/^begin;[\s\S]*commit;\s*$/m.test(migration),'La migración v2.7 no está delimitada por una transacción');
assert(migration.includes('grant execute on function public.obtener_seguimiento_publico_v27(uuid) to anon,authenticated'),'El seguimiento no está habilitado de forma controlada');
assert(!migration.includes('revoke all on function public.confirmar_entrega_v26'),'La migración inicial cortaría la web v2.6 antes del deployment');

const finalizacion=read('supabase-finalizar-v2.7.sql');
assert(/^begin;[\s\S]*commit;\s*$/m.test(finalizacion),'La finalización v2.7 no está delimitada por una transacción');
for(const anterior of ['guardar_remito_v26','confirmar_entrega_v26','eliminar_remito_pendiente(uuid)']){
  assert(finalizacion.includes(`revoke all on function public.${anterior}`),`La finalización no bloquea ${anterior}`);
}
const reversion=read('supabase-reversion-emergencia-v2.7.sql');
assert(reversion.includes("estado='Pendiente' and salida_at is not null"),'La reversión no bloquea viajes en curso');
assert(reversion.includes('grant execute on function public.guardar_remito_v26'),'La reversión no reactiva el guardado seguro v2.6');
assert(reversion.includes('revoke all on function public.confirmar_entrega_v27'),'La reversión deja pestañas v2.7 escribiendo');

const seguimiento=migration.match(/create or replace function public\.obtener_seguimiento_publico_v27[\s\S]*?revoke all on function public\.obtener_seguimiento_publico_v27/)?.[0]||'';
for(const sensible of ['receptor_dni','firma_url','foto_entrega_url','documento_url','telefono','tel,','dir,','items_remito']){
  assert(!seguimiento.includes(sensible),`El RPC público podría exponer ${sensible}`);
}

const vercel=read('vercel.json');
assert(vercel.includes('https://challenges.cloudflare.com'),'La CSP de Vercel bloquea Turnstile');
assert(vercel.includes('"Referrer-Policy", "value": "no-referrer"'),'El navegador podría reenviar tokens o rutas sensibles como referencia');
assert(vercel.includes("object-src 'none'"),'La CSP no bloquea objetos embebidos');
assert(vercel.includes("frame-ancestors 'none'"),'La CSP no bloquea framing');
assert(!/default-src[^;]*\*/.test(vercel),'La CSP contiene un wildcard peligroso');
const vercelIgnore=read('.vercelignore');
for(const privado of ['*.sql','*.md','tests/','CHECKSUMS-SHA256.txt'])assert(vercelIgnore.includes(privado),`.vercelignore no excluye ${privado}`);
assert(!read('sw.js').includes("addEventListener('fetch'"),'El service worker no debe cachear datos del piloto');

const privacidad=read('privacidad.html');
assert(privacidad.includes('2026-09-09-v2.7'),'La política de privacidad no corresponde a v2.7');
assert(privacidad.includes('no emite ni reemplaza el remito original'),'La política no delimita el rol de GoRemitos');
const terceros=read('THIRD-PARTY-NOTICES.md');
for(const aviso of ['Supabase','Tabler Icons','jsPDF','qrcodejs','Permission is hereby granted']){
  assert(terceros.includes(aviso),`Falta el aviso de licencia de ${aviso}`);
}

await import('./verificar-logica-v2.7.mjs');
console.log('PAQUETE v2.8 OK: escritorio, sintaxis, archivos, flujo, privacidad, seguridad y secretos públicos');
