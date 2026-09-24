import fs from 'node:fs';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';
const read=file=>fs.readFileSync(new URL('../'+file,import.meta.url),'utf8');
const db=new PGlite({extensions:{pgcrypto}});
try{
  await db.exec(read('tests/helpers/schema-fixture.sql'));
  for(const file of ['supabase-migration-v2.2.sql','supabase-migration-v2.5.sql','supabase-migration-v2.5.2.sql','supabase-migration-v2.6.sql','supabase-migration-v2.7.sql','supabase-finalizar-v2.7.sql','supabase-migration-v2.10.sql','supabase-migration-v2.11.sql']){
    try{await db.exec(read(file));}catch(error){throw new Error(`${file}: ${error.message}`);}
  }
  const verification=await db.exec(read('supabase-verificacion-v2.10.sql'));
  assert(verification[0].rows.every(r=>r.ok),JSON.stringify(verification[0].rows.filter(r=>!r.ok)));
  assert.equal(verification[1].rows.length,0);
  const checks211=await db.exec(read('supabase-verificacion-v2.11.sql'));
  assert(checks211[0].rows.every(r=>r.ok));assert.equal(checks211[1].rows.length,0);
  const company='00000000-0000-4000-8000-000000000001';
  const admin='10000000-0000-4000-8000-000000000001',office='10000000-0000-4000-8000-000000000002',driver='10000000-0000-4000-8000-000000000003',otherDriver='10000000-0000-4000-8000-000000000004',otherCompany='20000000-0000-4000-8000-000000000001';
  async function as(user,sql,args=[]){
    await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
    await db.exec('set role authenticated');
    try{return await db.query(sql,args);}finally{await db.exec('reset role');}
  }
  const denied=async(user,sql,args,pattern)=>assert.rejects(as(user,sql,args),pattern);
  await denied(office,'select actualizar_modo_prueba_empresa_v210(true)',[],/administrador/);
  await as(admin,'select actualizar_modo_prueba_empresa_v210(true)');
  const doc=`${company}/entradas/30000000-0000-4000-8000-000000000001.pdf`,sha='a'.repeat(64);
  const upload='insert into storage.objects(bucket_id,name,owner_id,metadata,user_metadata) values($1,$2,$3,$4,$5)';
  const docArgs=['documentos-remito',doc,office,JSON.stringify({size:128,mimetype:'application/pdf'}),JSON.stringify({sha256:sha,originalName:'prueba.pdf'})];
  await denied(driver,upload,docArgs,/row-level security/);
  await as(office,upload,docArgs);
  assert.equal((await as(otherCompany,'select name from storage.objects')).rows.length,0);
  const createSql='select guardar_remito_v211($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) as id';
  const params=[null,'PRUEBA-001','Cliente ficticio','Domicilio ficticio',null,null,driver,'2026-09-24',JSON.stringify([{cod:'FICTICIO',descripcion:'Mercadería ficticia',qty:10,orden:0}]),doc,sha,'prueba.pdf','application/pdf',128,true];
  await denied(office,createSql,[...params.slice(0,-1),false],/modo.*cambió/);
  await denied(driver,createSql,params,/permiso/);
  const remito=(await as(office,createSql,params)).rows[0].id;
  assert.equal((await db.query('select es_prueba from remitos where id=$1',[remito])).rows[0].es_prueba,true);
  assert.equal((await db.query('select public._plataforma_lista_v27() as lista')).rows[0].lista,false,'El bypass salió de su transacción');
  assert.equal((await as(otherCompany,'select id from remitos')).rows.length,0,'Otra empresa pudo leer remitos');
  assert.equal((await as(otherDriver,'select id from remitos')).rows.length,0,'Otro chofer pudo leer remitos');
  assert.equal((await as(office,'select id from remitos')).rows.length,1);
  await denied(office,'update remitos set num=$1 where id=$2',['MODIFICADO',remito],/permission denied/);
  await denied(otherDriver,'select marcar_en_camino_v210($1)',[remito],/no disponible/);
  await as(driver,'select marcar_en_camino_v210($1)',[remito]);
  const firstStart=(await db.query('select salida_at from remitos where id=$1',[remito])).rows[0].salida_at;
  await as(driver,'select marcar_en_camino_v210($1)',[remito]);
  assert.equal(String((await db.query('select salida_at from remitos where id=$1',[remito])).rows[0].salida_at),String(firstStart));
  await denied(office,'select eliminar_remito_pendiente_v27($1)',[remito],/administrador/);
  await denied(admin,'select eliminar_remito_pendiente_v27($1)',[remito],/camino/);
  await denied(admin,'select cambiar_rol_usuario($1,$2)',[driver,'oficina'],/camino/);
  await denied(admin,'select eliminar_usuario_empresa($1)',[driver],/camino/);
  await denied(admin,'select actualizar_modo_prueba_empresa_v210(false)',[],/pendientes/);
  const item=(await db.query('select id from items_remito where remito_id=$1',[remito])).rows[0].id;
  const signature=`${company}/${remito}/40000000-0000-4000-8000-000000000001/firma.png`;
  await as(driver,upload,['evidencias',signature,driver,JSON.stringify({size:128,mimetype:'image/png'}),JSON.stringify({sha256:sha})]);
  const closeSql='select confirmar_entrega_v210($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) as hash';
  const closeArgs=[remito,'ok','','Receptor ficticio','12345678',signature,sha,null,null,true,JSON.stringify([{id:item,estado:'ok',qty_recibida:10}])];
  await denied(office,closeSql,closeArgs,/chofer/);
  const inconsistent=[...closeArgs];inconsistent[10]=JSON.stringify([{id:item,estado:'miss',qty_recibida:2}]);
  await denied(driver,closeSql,inconsistent,/faltantes o daños/);
  assert.equal((await db.query('select estado from remitos where id=$1',[remito])).rows[0].estado,'Pendiente');
  const hash=(await as(driver,closeSql,closeArgs)).rows[0].hash;
  assert.match(hash,/^[a-f0-9]{64}$/);
  assert.equal((await db.query('select estado from remitos where id=$1',[remito])).rows[0].estado,'Firmado');
  await assert.rejects(db.query('update remitos set num=$1 where id=$2',['CAMBIO',remito]),/cerrada/);
  await as(driver,'delete from storage.objects where name=$1',[signature]);
  assert.equal((await db.query('select count(*) as n from storage.objects where name=$1',[signature])).rows[0].n,1,'Se borró evidencia cerrada');
  const token=(await db.query('select public_token from remitos where id=$1',[remito])).rows[0].public_token;
  await db.exec('set role anon');
  const publicTracking=(await db.query('select * from obtener_seguimiento_publico_v210($1)',[token])).rows[0];
  await db.exec('reset role');
  assert.deepEqual(Object.keys(publicTracking).sort(),['empresa','numero','fecha','estado','creado_at','salida_at','cierre_at','es_prueba'].sort());
  assert.equal(publicTracking.es_prueba,true);
  await as(admin,'select actualizar_modo_prueba_empresa_v210(false)');
  console.log('BASE v2.11 OK: migraciones, 13 controles, separación entre empresas/choferes, carga por Oficina, salida idempotente, baja bloqueada durante viaje, cierre, evidencia protegida y seguimiento mínimo.');
}finally{await db.close();}
