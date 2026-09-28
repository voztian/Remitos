import assert from 'node:assert/strict';
import {appContext,fakeQuery} from './helpers/app-context.mjs';

const app=appContext(),{run,ctx,document}=app;
run("cu={id:'office',rol:'oficina',empresaId:'company',empresa:'Empresa de prueba',modoPruebaInterna:true,modoPruebaDisponible:true,modoPruebaEstado:'ok'}; showView('view-app'); goTab('nuevo');");
run("applyTheme('light');applyTheme('dark');");
assert(document.body.classList.contains('app-shell-visible'),'El cambio de tema perdió el escritorio');
run("document.getElementById('f-cli').value='CLIENTE FICTICIO';formularioEditado=true;documentoNuevo=new Blob(['documento']);");
ctx.networkOk=false;
ctx.mockRpc=async name=>name==='obtener_mi_acceso'?{data:[{empresa_id:'company',rol:'oficina',activo:true}],error:null}:ctx.networkOk?{data:[{modo_prueba_interna:true,plataforma_real_lista:false,empresa_real_lista:false}],error:null}:{data:null,error:{message:'temporary connection error'}};
run('sb={rpc:mockRpc}');
await run('verificarAccesoVigente()');
assert.equal(run('cu.modoPruebaInterna'),true,'Un error de conexión cambió el modo');
assert.equal(run('cu.modoPruebaEstado'),'error');
assert.equal(document.getElementById('f-cli').value,'CLIENTE FICTICIO','Se borró el formulario');
assert.equal(run('documentoNuevo.size'),9,'Se perdió el documento seleccionado');
assert(document.getElementById('btn-guardar-remito').disabled,'Se permitió escribir sin confirmar modo');
ctx.networkOk=true;await run('verificarAccesoVigente()');
assert.equal(document.getElementById('f-cli').value,'CLIENTE FICTICIO');
assert(!document.getElementById('btn-guardar-remito').disabled);
run("goTab('remitos')");assert.equal(run('tabActual'),'nuevo','Cancelar salida no conservó el formulario');
assert.equal(await run('doLogout()'),false,'Cancelar salida no conservó la sesión');
assert.equal(run('cu.id'),'office');
run("limpiarEstadoFormulario();goTab('remitos')");assert.equal(run('tabActual'),'remitos');

const driver=appContext(),log=[];
const rows=[...Array.from({length:100},(_,i)=>({id:`closed-${i}`,created_at:`2026-09-24T10:00:${String(i).padStart(2,'0')}Z`,fecha:'2026-09-24',estado:'Firmado',chofer_id:'driver',items_remito:[]})),{id:'old-pending',num:'PENDIENTE-ANTIGUO',cliente:'Destino ficticio',dir:'Dirección de prueba',created_at:'2026-01-01',fecha:'2026-09-20',estado:'Pendiente',chofer_id:'driver',items_remito:[]}];
driver.ctx.query=()=>fakeQuery(rows,log);
driver.run("cu={id:'driver',rol:'chofer',empresaId:'company',modoPruebaEstado:'ok',modoPruebaInterna:true};sb={from:query}");
await driver.run('cargarRemitos()');await driver.run('cargarPendientesChofer()');
assert.equal(driver.run('remitosPaginados.length'),100);
assert.equal(driver.run('entregasPendientes[0].id'),'old-pending');
assert(driver.run('renderEntrega()').includes('PENDIENTE-ANTIGUO'),'Se ocultó la entrega anterior al historial cargado');
assert(log.some(x=>x[0]==='eq'&&x[1]==='estado'&&x[2]==='Pendiente'));
assert.equal(driver.run('hayMasRemitos'),true,'El cache adicional alteró la paginación');

const search=appContext(),queries=[];
search.ctx.query=()=>fakeQuery(rows,queries);
search.run("cu={id:'office',rol:'oficina',modoPruebaEstado:'ok'};sb={from:query};busquedaRemitos='cliente, a(1) \"test\"';");
await search.run('buscarRemitos()');
assert(queries.some(x=>x[0]==='or'&&x[1].includes('\\"test\\"')),'La búsqueda no escapa comillas');
assert.equal(search.run('totalBusqueda'),101);
assert.equal(search.run('resultadosBusqueda.length'),100);
await search.run('buscarRemitos(false)');assert.equal(search.run('resultadosBusqueda.length'),101);
search.run("remitoObjetivo={id:'closed-0',estado:'Pendiente'};resultadosBusqueda=[{id:'closed-0',estado:'Pendiente'}];integrarRemitosActualizados([{id:'closed-0',estado:'Firmado'}]);reunirRemitos();");
assert.equal(search.run("remitos.find(r=>r.id==='closed-0').estado"),'Firmado','Una copia vieja tapó la actualización');

const tracking=appContext('https://goremitos.example/#seguimiento=00000000-0000-4000-8000-000000000001');
tracking.ctx.mockRpc=async()=>({data:[{numero:'FICTICIO',empresa:'QA',estado:'Programado',fecha:'2026-09-24'}],error:null});
tracking.run('sb={rpc:mockRpc}');await tracking.run('cargarSeguimientoPublico()');
assert(tracking.document.getElementById('tracking-card').textContent.includes('Programado'));
tracking.ctx.mockRpc=async()=>{throw new Error('network failure');};
tracking.run('sb={rpc:mockRpc}');await tracking.run('cargarSeguimientoPublico(true)');
assert(tracking.document.getElementById('tracking-card').textContent.includes('Programado'),'Se perdió el último estado');
assert(!tracking.document.getElementById('tracking-connection').hidden,'El seguimiento ocultó la pérdida de conexión');

// Un cierre confirmado sigue siendo un éxito aunque se corte la consulta posterior.
// No debe ofrecer otra confirmación ni eliminar evidencia ya vinculada.
const closed=appContext();
closed.run(`cu={id:'driver',rol:'chofer',empresaId:'company',modoPruebaEstado:'ok',modoPruebaInterna:true};
  showView('view-app');tabActual='entrega';
  remitoActual={id:'delivery',estado:'Pendiente',salidaAt:'2026-09-28T12:00:00Z',items:[{id:'item',desc:'Mercadería ficticia',qty:1}]};
  document.getElementById('main-content').innerHTML=renderEntregaDetalle(remitoActual);
  prepararOperacion=async()=>true;rpcVersionado=async()=>({error:null});
  refrescarDatos=async()=>{throw new Error('Connection lost after commit');};
  registrarError=()=>{};limpiarEvidenciasHuerfanas=async()=>{throw new Error('Must not delete committed evidence');};
  confActual='rech';itemsEstado=[{id:'item',qty:1,qtyRecibida:0,estado:'miss'}];
  document.getElementById('f-rxn').value='Receptor ficticio';document.getElementById('f-rxd').value='12345678';
  document.getElementById('f-consent').checked=true;document.getElementById('f-obs').value='Rechazo de prueba';`);
await closed.run('confirmarEntrega()');
assert.equal(closed.run('tabActual'),'historial');
assert.equal(closed.run('operacionEnCurso'),false);
assert(closed.messages.some(message=>message.includes('ya quedó guardada')));
assert(!closed.document.getElementById('firma-sec'),'El cierre guardado volvió a ofrecer confirmación');

const starting=appContext();
starting.run(`cu={id:'driver',rol:'chofer',empresaId:'company'};showView('view-app');tabActual='entrega';
  remitos=[{id:'delivery',num:'FICTICIO',estado:'Pendiente',documentoUrl:'private/document.pdf'}];
  document.getElementById('main-content').innerHTML='<button id="btn-iniciar-entrega">Iniciar viaje</button>';
  prepararOperacion=async()=>true;confirm=()=>true;registrarError=()=>{};
  rpcVersionado=async()=>{goTab('historial');throw new Error('Network interrupted');};`);
await starting.run("iniciarEntrega('delivery')");
assert.equal(starting.run('tabActual'),'entrega','Se permitió abandonar la pantalla durante el inicio');
assert.equal(starting.run('operacionEnCurso'),false);
assert(!starting.document.getElementById('btn-iniciar-entrega').disabled,'No se recuperó el botón tras el fallo');

assert.equal(run("telWA('011 15-1234-5678')"),'5491112345678');
assert.equal(run("telWA('+54 9 11 1234-5678')"),'5491112345678');
assert.equal(run("telWA('123')"),'');
assert.equal(run("telWA('+598 99 123 456')"),'59899123456');

console.log('EXPERIENCIA v2.11 OK: tema, conservación de formulario, reconexión, permisos de guardado, pendientes antiguos, búsqueda paginada, inicio, cierre confirmado y teléfonos.');
