-- GoRemitos v2.7 - verificación posterior
-- Ejecutar completo después de publicar la web y ejecutar
-- supabase-finalizar-v2.7.sql.
-- La primera tabla debe mostrar todos los controles en true.

with controles(nombre,ok,detalle) as (
  values
  ('columna_documento',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='documento_url'),
    'Referencia privada al remito externo'),
  ('columna_hash_documento',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='documento_sha256'),
    'Hash SHA-256 del remito externo'),
  ('columna_inicio_viaje',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='salida_at'),
    'Programado y en camino quedan diferenciados'),
  ('modalidad_piloto_free',
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='configuracion_plataforma' and column_name='piloto_free_aceptado')
    and to_regprocedure('public._plataforma_lista_v27()') is not null
    and position('piloto_free_aceptado' in pg_get_functiondef(to_regprocedure('public._plataforma_lista_v27()')))>0,
    'Free sólo se habilita mediante aceptación expresa y backups verificados'),
  ('documento_unico',
    exists(select 1 from pg_indexes where schemaname='public' and tablename='remitos' and indexname='remitos_documento_url_v27_uidx'),
    'Un archivo no puede vincularse a dos remitos'),
  ('metadata_documento_consistente',
    not exists(select 1 from public.remitos where
      (documento_url is null)<>(documento_sha256 is null)
      or (documento_url is null)<>(documento_nombre is null)
      or (documento_url is null)<>(documento_mime is null)
      or (documento_url is null)<>(documento_size is null)),
    'Las referencias existentes tienen metadata completa'),
  ('bucket_documentos_privado',
    coalesce((select not public from storage.buckets where id='documentos-remito'),false),
    'El remito original no es público'),
  ('bucket_documentos_limite',
    coalesce((select file_size_limit=10485760 from storage.buckets where id='documentos-remito'),false),
    'Límite de 10 MB aplicado en Storage'),
  ('bucket_documentos_formatos',
    coalesce((select allowed_mime_types @> array['application/pdf','image/jpeg','image/png','image/webp'] from storage.buckets where id='documentos-remito'),false),
    'Sólo PDF e imágenes admitidas'),
  ('politica_documentos_lectura',
    exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='documentos_remito_select_v27' and roles='{authenticated}'),
    'Lectura limitada por empresa, rol y asignación'),
  ('politica_documentos_subida',
    exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='documentos_remito_insert_v27' and roles='{authenticated}' and coalesce(with_check,'') ilike '%_subida_documento_valida_v27%'),
    'Subida limitada a administración y oficina'),
  ('politica_documentos_limpieza',
    exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='documentos_remito_cleanup_v27' and roles='{authenticated}' and coalesce(qual,'') ilike '%documento_url%'),
    'Sólo pueden borrarse documentos sin vínculo'),
  ('funcion_guardado_v27',
    to_regprocedure('public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)') is not null,
    'Alta y edición con documento obligatorio'),
  ('funcion_inicio_viaje_v27',
    to_regprocedure('public.marcar_en_camino_v27(uuid)') is not null,
    'Inicio de viaje explícito e idempotente'),
  ('inicio_revalida_documento',
    position('_documento_meta_v27' in pg_get_functiondef(to_regprocedure('public.marcar_en_camino_v27(uuid)')))>0
    and position('salida_at is not null' in pg_get_functiondef(to_regprocedure('public.marcar_en_camino_v27(uuid)')))>0,
    'El inicio es idempotente y comprueba nuevamente el documento'),
  ('funcion_cierre_v27',
    to_regprocedure('public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is not null,
    'Cierre vinculado al documento y al inicio'),
  ('cierre_exige_inicio_y_documento',
    position('salida_at is null' in pg_get_functiondef(to_regprocedure('public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)')))>0
    and position('_documento_meta_v27' in pg_get_functiondef(to_regprocedure('public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)')))>0,
    'No se cierra sin salida y el documento se revalida'),
  ('funcion_resumen_v27',
    to_regprocedure('public.resumen_remitos_v27()') is not null,
    'Resumen separa programados y en camino'),
  ('funciones_preparacion_v27',
    to_regprocedure('public.obtener_estado_operativo_v27()') is not null
    and to_regprocedure('public.actualizar_preparacion_plataforma_v27(boolean,boolean,boolean,boolean,boolean,boolean,boolean)') is not null
    and has_function_privilege('authenticated','public.obtener_estado_operativo_v27()','EXECUTE')
    and has_function_privilege('authenticated','public.actualizar_preparacion_plataforma_v27(boolean,boolean,boolean,boolean,boolean,boolean,boolean)','EXECUTE'),
    'La modalidad Pro o Free se administra con funciones controladas'),
  ('diagnostico_version_v27',
    to_regprocedure('public.registrar_error_cliente_v27(text,text,text,text,text)') is not null
    and has_function_privilege('authenticated','public.registrar_error_cliente_v27(text,text,text,text,text)','EXECUTE')
    and position('2.7.0' in pg_get_functiondef(to_regprocedure('public.registrar_error_cliente_v27(text,text,text,text,text)')))>0,
    'Los incidentes quedan asociados a la versión correcta'),
  ('funcion_seguimiento_v27',
    to_regprocedure('public.obtener_seguimiento_publico_v27(uuid)') is not null,
    'Seguimiento por token instalado'),
  ('funcion_borrado_v27',
    to_regprocedure('public.eliminar_remito_pendiente_v27(uuid)') is not null,
    'Borrado limitado a entregas aún no iniciadas'),
  ('chofer_en_camino_no_eliminable',
    position('salida_at is not null' in pg_get_functiondef(to_regprocedure('public.eliminar_usuario_empresa(uuid)')))>0
    and position('salida_at is not null' in pg_get_functiondef(to_regprocedure('public.cambiar_rol_usuario(uuid,text)')))>0
    and position('pg_advisory_xact_lock' in pg_get_functiondef(to_regprocedure('public.marcar_en_camino_v27(uuid)')))>0,
    'Una baja o cambio de rol no puede dejar un viaje sin chofer habilitado'),
  ('rpc_nuevos_habilitados',
    has_function_privilege('authenticated','public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)','EXECUTE')
    and has_function_privilege('authenticated','public.marcar_en_camino_v27(uuid)','EXECUTE')
    and has_function_privilege('authenticated','public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE')
    and has_function_privilege('authenticated','public.resumen_remitos_v27()','EXECUTE'),
    'La aplicación autenticada puede usar sólo el flujo nuevo'),
  ('rpc_v26_escritura_bloqueados',
    not has_function_privilege('authenticated','public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)','EXECUTE')
    and not has_function_privilege('authenticated','public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE')
    and not has_function_privilege('authenticated','public.eliminar_remito_pendiente(uuid)','EXECUTE'),
    'No se puede saltear documento ni inicio con RPC anteriores'),
  ('seguimiento_anonimo_controlado',
    has_function_privilege('anon','public.obtener_seguimiento_publico_v27(uuid)','EXECUTE')
    and not has_function_privilege('anon','public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)','EXECUTE')
    and not has_function_privilege('anon','public.marcar_en_camino_v27(uuid)','EXECUTE')
    and not has_function_privilege('anon','public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE'),
    'Anónimo sólo puede consultar un token válido'),
  ('seguimiento_sin_datos_sensibles',
    position('receptor_dni' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v27(uuid)')))=0
    and position('firma_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v27(uuid)')))=0
    and position('documento_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v27(uuid)')))=0
    and position('foto_entrega_url' in pg_get_functiondef(to_regprocedure('public.obtener_seguimiento_publico_v27(uuid)')))=0,
    'El RPC público no devuelve documento ni evidencias personales'),
  ('helpers_privados',
    not has_function_privilege('authenticated','public._documento_meta_v27(text,text,boolean)','EXECUTE')
    and not has_function_privilege('anon','public._documento_meta_v27(text,text,boolean)','EXECUTE'),
    'La validación interna no está expuesta'),
  ('security_definer_sin_public_search_path',not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE'))
      and coalesce(array_to_string(p.proconfig,','),'') ~ 'search_path=.*public'
  ),'RPC ejecutables sin public en search_path')
)
select nombre,ok,detalle from controles order by nombre;

-- Debe devolver cero filas. Si devuelve alguna, no habilites clientes.
select id,num,estado,salida_at,documento_url
from public.remitos
where (salida_at is not null and estado='Pendiente' and documento_url is null)
   or (salida_at is not null and estado='Pendiente' and not exists(
     select 1 from public.perfiles p
     where p.id=remitos.chofer_id and p.empresa_id=remitos.empresa_id
       and p.activo=true and p.rol='chofer'
   ))
   or (locked_at is not null and signed_snapshot is null)
   or (documento_url is not null and (
     documento_sha256 is null or documento_nombre is null or documento_mime is null or documento_size is null
   ));

-- Resumen informativo. No expone emails ni datos personales.
select
  count(*) filter(where estado='Pendiente' and salida_at is null) as programados,
  count(*) filter(where estado='Pendiente' and salida_at is not null) as en_camino,
  count(*) filter(where estado in ('Firmado','Disconforme','Rechazado')) as entregados,
  count(*) filter(where documento_url is not null) as con_documento_original,
  count(*) filter(where estado='Pendiente' and documento_url is null) as pendientes_anteriores_sin_documento
from public.remitos;
