/* Sólo se publica en preview. Simula el límite de Supabase para pruebas de UI. */
(()=>{
  const company='00000000-0000-4000-8000-000000000001',role=new URLSearchParams(location.search).get('role')||'oficina';
  const users=[['admin','10000000-0000-4000-8000-000000000001','Admin ficticio'],['oficina','10000000-0000-4000-8000-000000000002','Oficina ficticia'],['chofer','10000000-0000-4000-8000-000000000003','Chofer ficticio']].map(([rol,id,nombre])=>({rol,id,nombre,empresa_id:company,activo:true,email:rol+'@example.invalid'}));
  const actor=users.find(u=>u.rol===role)||users[1];
  const key='goremitos-preview-ficticio-v211';
  const data=JSON.parse(sessionStorage.getItem(key)||'null')||{mode:true,rows:[],files:{},events:[]};
  let network=true;
  const save=()=>sessionStorage.setItem(key,JSON.stringify(data));
  const permitted=()=>data.rows.filter(r=>actor.rol!=='chofer'||r.chofer_id===actor.id);
  const nativeFetch=window.fetch.bind(window);
  window.fetch=async(url,options)=>{
    if(String(url).includes('/auth/v1/settings'))return new Response(JSON.stringify({mailer_autoconfirm:false,external:{google:true}}),{headers:{'content-type':'application/json'}});
    if(/^(blob:|data:)/.test(String(url)))return nativeFetch(url,options);
    throw new Error('Las pruebas aisladas no pueden hacer solicitudes a servicios reales.');
  };
  const access=()=>({usuario_id:actor.id,nombre:actor.nombre,email:actor.email,rol:actor.rol,empresa_id:company,empresa_nombre:'Empresa ficticia · QA',empresa_cuit:'20123456786',empresa_razon_social:'Empresa ficticia de prueba',empresa_domicilio_privacidad:'Domicilio ficticio',empresa_email_privacidad:'privacidad@example.invalid',empresa_politica_retencion:'Sólo datos ficticios de prueba',activo:true,admin_plataforma:actor.rol==='admin',plataforma_lista_piloto:false});
  function query(table){
    let rows=table==='perfiles'?users:table==='remito_eventos'?data.events:permitted(),orders=[],from=0,to=999999,single=false;
    const q={select(){return q;},eq(k,v){rows=rows.filter(r=>r[k]===v);return q;},in(k,vs){rows=rows.filter(r=>vs.includes(r[k]));return q;},is(k,v){rows=rows.filter(r=>(r[k]??null)===v);return q;},not(k,op,v){rows=rows.filter(r=>(r[k]??null)!==v);return q;},or(exp){const term=(exp.match(/ilike\."%([^%]*)%"/)?.[1]||'').toLowerCase();rows=rows.filter(r=>[r.num,r.cliente,r.chofer_nombre].join(' ').toLowerCase().includes(term));return q;},order(k,o={}){orders.push([k,o.ascending!==false]);return q;},range(a,b){from=a;to=b;return q;},limit(n){to=n-1;return q;},maybeSingle(){single=true;return q;},then(resolve,reject){rows=[...rows].sort((a,b)=>{for(const [k,asc] of orders){const c=String(a[k]??'').localeCompare(String(b[k]??''));if(c)return asc?c:-c;}return 0;});const found=rows.slice(from,to+1);return Promise.resolve({data:single?(found[0]||null):structuredClone(found),count:rows.length,error:null}).then(resolve,reject);}};return q;
  }
  async function rpc(name,p={}){
    const ok=d=>({data:d,error:null}),fail=m=>({data:null,error:{message:m,code:'QA_ERROR'}});
    if(name==='obtener_estado_registro')return ok([{registro_email_habilitado:false}]);
    if(name==='obtener_configuracion_publica')return ok([{responsable_nombre:'Empresa ficticia QA',responsable_domicilio:'Domicilio ficticio',privacidad_email:'privacidad@example.invalid',soporte_email:'soporte@example.invalid'}]);
    if(name==='obtener_mi_acceso')return ok([access()]);
    if(name==='obtener_modo_prueba_empresa_v210')return network?ok([{modo_prueba_interna:data.mode,remitos_prueba_pendientes:data.rows.filter(r=>r.estado==='Pendiente').length,remitos_prueba_total:data.rows.length,plataforma_real_lista:false,empresa_real_lista:true}]):fail('Fallo temporal simulado');
    if(name==='actualizar_modo_prueba_empresa_v210'){if(actor.rol!=='admin')return fail('Solo administrador');if(!p.p_activo&&data.rows.some(r=>r.estado==='Pendiente'))return fail('Quedan pruebas pendientes');data.mode=p.p_activo;save();return ok(data.mode);}
    if(name==='guardar_remito_v211'){
      if(!['oficina','admin'].includes(actor.rol)||!data.mode||p.p_modo_prueba!==data.mode)return fail('Modo o rol inválido');
      let r=p.p_remito_id?data.rows.find(x=>x.id===p.p_remito_id):null;
      if(data.rows.some(x=>x.id!==r?.id&&x.num===p.p_num))return fail('Ya existe un remito con ese número');
      if(!r){r={id:crypto.randomUUID(),public_token:crypto.randomUUID(),estado:'Pendiente',salida_at:null,es_prueba:true,created_at:new Date().toISOString()};data.rows.push(r);}
      for(const k of ['num','cliente','dir','contacto','tel','chofer_id','fecha','documento_url','documento_sha256','documento_nombre','documento_mime','documento_size'])r[k]=p['p_'+k];
      r.empresa_id=company;r.chofer_nombre=users.find(u=>u.id===r.chofer_id)?.nombre;r.items_remito=p.p_items.map(i=>({...i,id:crypto.randomUUID(),qty_recibida:null,estado:null}));save();return ok(r.id);
    }
    if(name==='marcar_en_camino_v210'){const r=permitted().find(r=>r.id===p.p_remito_id);if(!r||actor.rol!=='chofer')return fail('Entrega no disponible');r.salida_at||=new Date().toISOString();save();return ok(r.salida_at);}
    if(name==='confirmar_entrega_v210'){
      const r=permitted().find(r=>r.id===p.p_remito_id);if(!r||!r.salida_at||actor.rol!=='chofer')return fail('Entrega no disponible');
      r.estado={ok:'Firmado',disc:'Disconforme',rech:'Rechazado'}[p.p_conformidad];
      for(const k of ['conformidad','obs','receptor_nombre','receptor_dni','firma_url','firma_sha256','foto_entrega_url','foto_entrega_sha256'])r[k]=p['p_'+k];
      r.items_remito=r.items_remito.map(i=>({...i,...p.p_items.find(x=>x.id===i.id)}));r.ts_firma=r.locked_at=new Date().toISOString();r.signed_snapshot={empresa:{nombre:'Empresa ficticia QA'},es_prueba:true};r.evidence_hash='a'.repeat(64);save();return ok(r.evidence_hash);
    }
    if(name==='obtener_seguimiento_publico_v210'){const r=data.rows.find(x=>x.public_token===p.p_token);return ok(r?[{empresa:'Empresa ficticia QA',numero:r.num,fecha:r.fecha,estado:r.estado==='Pendiente'?(r.salida_at?'En camino':'Programado'):r.estado==='Firmado'?'Entregado':'Entregado con observaciones',creado_at:r.created_at,salida_at:r.salida_at,cierre_at:r.ts_firma,es_prueba:true}]:[]);}
    if(name==='listar_accesos_empresa')return ok(users.map(u=>({tipo:'usuario',registro_id:u.id,usuario_id:u.id,...u,estado:'activo',es_actual:u.id===actor.id})));
    if(name==='resumen_remitos_v27')return ok([{total:permitted().length,entregados:permitted().filter(r=>r.estado!=='Pendiente').length,programados:permitted().filter(r=>r.estado==='Pendiente'&&!r.salida_at).length,en_camino:permitted().filter(r=>r.estado==='Pendiente'&&r.salida_at).length,con_problemas:0,manuales:0}]);
    if(name==='eliminar_remito_pendiente_v27'){const index=data.rows.findIndex(r=>r.id===p.p_remito_id&&!r.salida_at);if(index<0)return fail('No se puede eliminar');const r=data.rows.splice(index,1)[0];save();return ok(r.documento_url);}
    if(name==='registrar_error_cliente_v27'){console.warn('Diagnóstico de prueba',p.p_contexto,p.p_mensaje);return ok(null);}
    return ok([]);
  }
  const mock={rpc,from:query,auth:{getSession:async()=>({data:{session:{user:{id:actor.id,email:actor.email}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},channel:()=>({on(){return this;},subscribe(fn){fn('SUBSCRIBED');return this;}}),removeChannel:async()=>{},storage:{from:bucket=>({upload:async(path,file,options)=>{const value=await new Promise(resolve=>{const f=new FileReader();f.onload=()=>resolve(f.result);f.readAsDataURL(file);});data.files[bucket+'/'+path]={value,metadata:options.metadata};save();return {data:{path},error:null};},createSignedUrl:async path=>({data:{signedUrl:data.files[bucket+'/'+path]?.value},error:null}),remove:async paths=>{paths.forEach(p=>delete data.files[bucket+'/'+p]);save();return {error:null};}})}};
  window.supabase={createClient:()=>mock};
  window.addEventListener('message',async event=>{
    if(event.origin!==location.origin||!event.data?.goremitosQA)return;
    if(event.data.type==='network'){network=event.data.value;await verificarAccesoVigente();}
    if(event.data.type==='document'){
      await cargarJsPDF();const pdf=new window.jspdf.jsPDF();pdf.text('REMITO FICTICIO - SOLO PRUEBA GoRemitos',15,20);
      const file=new File([pdf.output('arraybuffer')],'remito-ficticio.pdf',{type:'application/pdf'});
      await handleDocumentoNuevo({files:[file],value:''});marcarFormularioEditado();
    }
  });
})();
