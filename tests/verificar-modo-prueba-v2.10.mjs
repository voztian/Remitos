import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const index=read('index.html');
const migration=read('supabase-migration-v2.10.sql');
const verification=read('supabase-verificacion-v2.10.sql');

for(const token of [
  "const APP_VERSION='2.10.0'",
  "rpc('obtener_modo_prueba_empresa_v210'",
  "rpc('actualizar_modo_prueba_empresa_v210'",
  "rpcVersionado('guardar_remito_v210','guardar_remito_v27'",
  "rpcVersionado('marcar_en_camino_v210','marcar_en_camino_v27'",
  "rpcVersionado('confirmar_entrega_v210','confirmar_entrega_v27'",
  "rpcVersionado('guardar_remito_manual_v210','guardar_remito_manual_v26'",
  "rpcVersionado('obtener_seguimiento_publico_v210','obtener_seguimiento_publico_v27'",
  'Modo de prueba interna activo',
  'Usá solamente datos ficticios',
  'DOCUMENTO DE PRUEBA · NO CORRESPONDE A UNA ENTREGA REAL',
  "rem?.esPrueba?'<span class=\"test-badge\""
])assert(index.includes(token),`La interfaz v2.10 no contiene: ${token}`);

assert(index.includes("if(r.esPrueba){alert('Las entregas de prueba no envían avisos"),'Una prueba podría iniciar un aviso real por WhatsApp');
assert(index.includes("wa.style.display=r.tel&&!r.esPrueba"),'El alta de prueba todavía muestra el aviso al destinatario');
assert(index.includes("${rem.tel&&!rem.esPrueba?"),'El viaje de prueba todavía muestra el aviso al destinatario');
assert(index.includes("if(cu?.modoPruebaInterna)return true"),'La interfaz no habilita el circuito interno');
assert(index.includes("if(cu.modoPruebaInterna)return []"),'Los bloqueos visuales no distinguen el modo interno');

for(const token of [
  'modo_prueba_interna boolean not null default false',
  'es_prueba boolean not null default false',
  'remitos_marcar_prueba_v210',
  'remitos_prueba_inmutable_v210',
  '_plataforma_real_lista_v210',
  '_empresa_real_lista_v210',
  '_bypass_prueba_v210',
  "set_config('goremitos.empresa_prueba',v_empresa::text,true)",
  "current_setting('goremitos.empresa_prueba',true)",
  'actualizar_modo_prueba_empresa_v210',
  'guardar_remito_v210',
  'marcar_en_camino_v210',
  'confirmar_entrega_v210',
  'guardar_remito_manual_v210',
  'obtener_seguimiento_publico_v210',
  '_subida_documento_valida_v27',
  '_subida_evidencia_valida_v26'
])assert(migration.includes(token),`La migración v2.10 no contiene: ${token}`);

assert(/^begin;[\s\S]*commit;\s*$/m.test(migration),'La migración v2.10 no está delimitada por una transacción');
assert(migration.includes("coalesce(public.current_rol(),'')<>'admin'"),'El cambio de modo no está limitado al administrador');
assert(migration.includes("r.estado='Pendiente' and r.es_prueba=false"),'La activación no bloquea pendientes reales');
assert(migration.includes("r.estado='Pendiente' and r.es_prueba=true"),'La desactivación no protege pruebas pendientes');
assert(migration.includes("new.es_prueba:=public._modo_prueba_empresa_v210(new.empresa_id)"),'La marca de prueba depende del servidor');
assert(migration.includes("new.es_prueba is distinct from old.es_prueba"),'La marca de prueba podría modificarse después');

const toggle=migration.match(/create or replace function public\.actualizar_modo_prueba_empresa_v210[\s\S]*?revoke all on function public\.actualizar_modo_prueba_empresa_v210/)?.[0]||'';
assert(toggle.includes('pg_advisory_xact_lock'),'El cambio de modo no serializa operaciones simultáneas');
const wrappers=['guardar_remito_v210','marcar_en_camino_v210','confirmar_entrega_v210','guardar_remito_manual_v210'];
for(const nombre of wrappers){
  const bloque=migration.match(new RegExp(`create or replace function public\\.${nombre}[\\s\\S]*?revoke all on function public\\.${nombre}`))?.[0]||'';
  assert(bloque.includes('pg_advisory_xact_lock'),`${nombre} no se coordina con el cambio de modo`);
  assert(bloque.includes('set_config'),`${nombre} no limita el bypass a su transacción`);
}

const seguimiento=migration.match(/create or replace function public\.obtener_seguimiento_publico_v210[\s\S]*?revoke all on function public\.obtener_seguimiento_publico_v210/)?.[0]||'';
assert(seguimiento.includes('es_prueba'),'El seguimiento no informa que es una prueba');
for(const sensible of ['receptor_dni','firma_url','foto_entrega_url','documento_url','telefono','items_remito']){
  assert(!seguimiento.includes(sensible),`El seguimiento v2.10 podría exponer ${sensible}`);
}

for(const token of ['columna_modo_empresa','triggers_clasificacion','bypass_transaccional','storage_prueba_controlado','sin_mezcla_pendiente']){
  assert(verification.includes(token),`La verificación v2.10 no controla ${token}`);
}

console.log('MODO PRUEBA v2.10 OK: separación, permisos, Storage, seguimiento y etiquetas');
