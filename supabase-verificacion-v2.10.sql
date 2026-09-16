-- GoRemitos v2.10 - verificación posterior
-- Ejecutar después de supabase-migration-v2.10.sql.
-- La primera tabla debe mostrar todos los controles en true.

with controles(nombre,ok,detalle) as (
  values
  ('columna_modo_empresa',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='empresas' and column_name='modo_prueba_interna' and is_nullable='NO'),
    'Cada empresa controla explícitamente su modo de prueba'),
  ('columna_remito_prueba',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='es_prueba' and is_nullable='NO'),
    'Los registros de prueba quedan identificados permanentemente'),
  ('triggers_clasificacion',
    exists(select 1 from pg_trigger where tgrelid='public.remitos'::regclass and tgname='remitos_marcar_prueba_v210' and not tgisinternal)
    and exists(select 1 from pg_trigger where tgrelid='public.remitos'::regclass and tgname='remitos_prueba_inmutable_v210' and not tgisinternal),
    'El servidor clasifica las altas y vuelve inmutable la marca'),
  ('rpc_estado_prueba',
    to_regprocedure('public.obtener_modo_prueba_empresa_v210()') is not null
    and has_function_privilege('authenticated','public.obtener_modo_prueba_empresa_v210()','EXECUTE'),
    'Todos los roles de la empresa pueden consultar el estado'),
  ('rpc_toggle_admin',
    to_regprocedure('public.actualizar_modo_prueba_empresa_v210(boolean)') is not null
    and has_function_privilege('authenticated','public.actualizar_modo_prueba_empresa_v210(boolean)','EXECUTE')
    and position('current_rol' in pg_get_functiondef(to_regprocedure('public.actualizar_modo_prueba_empresa_v210(boolean)')))>0,
    'Sólo un administrador puede activar o desactivar'),
  ('rpc_guardado_v210',
    to_regprocedure('public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)') is not null
    and has_function_privilege('authenticated','public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)','EXECUTE'),
    'Oficina y administración usan el guardado controlado'),
  ('rpc_viaje_v210',
    to_regprocedure('public.marcar_en_camino_v210(uuid)') is not null
    and to_regprocedure('public.confirmar_entrega_v210(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is not null
    and has_function_privilege('authenticated','public.marcar_en_camino_v210(uuid)','EXECUTE')
    and has_function_privilege('authenticated','public.confirmar_entrega_v210(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE'),
    'El chofer puede iniciar y cerrar exclusivamente mediante wrappers v2.10'),
  ('bypass_transaccional',
    position('set_config' in pg_get_functiondef(to_regprocedure('public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)')))>0
    and position('current_setting' in pg_get_functiondef(to_regprocedure('public._bypass_prueba_v210(uuid)')))>0,
    'La excepción existe sólo dentro de cada operación de prueba'),
  ('storage_prueba_controlado',
    position('_modo_prueba_empresa_v210' in pg_get_functiondef(to_regprocedure('public._subida_documento_valida_v27(text,jsonb)')))>0
    and position('_modo_prueba_empresa_v210' in pg_get_functiondef(to_regprocedure('public._subida_evidencia_valida_v26(text,jsonb)')))>0,
    'Documentos y evidencias mantienen rol, ruta y límites'),
  ('seguimiento_v210',
    to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)') is not null
    and has_function_privilege('anon','public.obtener_seguimiento_publico_v210(uuid)','EXECUTE')
    and position('es_prueba' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)')))>0,
    'El seguimiento público advierte si es una prueba'),
  ('seguimiento_sin_datos_sensibles',
    position('receptor_dni' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)')))=0
    and position('firma_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)')))=0
    and position('documento_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)')))=0
    and position('foto_entrega_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v210(uuid)')))=0,
    'El enlace no expone documento, identidad ni evidencias'),
  ('helpers_privados',
    not has_function_privilege('authenticated','public._plataforma_real_lista_v210()','EXECUTE')
    and not has_function_privilege('authenticated','public._empresa_real_lista_v210(uuid)','EXECUTE')
    and not has_function_privilege('authenticated','public._bypass_prueba_v210(uuid)','EXECUTE'),
    'El cliente no puede invocar directamente los helpers'),
  ('sin_mezcla_pendiente',
    not exists(
      select 1 from public.empresas e
      join public.remitos r on r.empresa_id=e.id
      where e.modo_prueba_interna=true and r.estado='Pendiente' and r.es_prueba=false
    ),
    'Una empresa en prueba no tiene entregas reales pendientes')
)
select nombre,ok,detalle from controles order by nombre;

-- Debe devolver cero filas. Nunca modifica ni elimina datos.
select r.id,r.empresa_id,r.num,r.estado,r.es_prueba,e.modo_prueba_interna,
  case
    when e.modo_prueba_interna and r.estado='Pendiente' and not r.es_prueba
      then 'pendiente real dentro de una empresa en modo prueba'
    when not e.modo_prueba_interna and r.estado='Pendiente' and r.es_prueba
      then 'prueba pendiente con el modo desactivado'
  end as anomalia
from public.remitos r
join public.empresas e on e.id=r.empresa_id
where (e.modo_prueba_interna and r.estado='Pendiente' and not r.es_prueba)
   or (not e.modo_prueba_interna and r.estado='Pendiente' and r.es_prueba);
