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

assert.equal(run("telWA('011 15-1234-5678')"),'5491112345678');
assert.equal(run("telWA('+54 9 11 1234-5678')"),'5491112345678');
assert.equal(run("telWA('123')"),'');
assert.equal(run("telWA('+598 99 123 456')"),'59899123456');

console.log('EXPERIENCIA v2.11 OK: tema, conservación de formulario, reconexión, permisos de guardado, pendientes antiguos, búsqueda paginada y teléfonos.');
