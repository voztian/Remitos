-- GoRemitos v2.6 - verificacion posterior a la migracion
-- Ejecutar completo. La primera tabla debe mostrar todos los controles en true.

with controles(nombre,ok,detalle) as (
  values
  ('funcion_onboarding_cerrado',
    to_regprocedure('public.completar_onboarding_interactivo(text,text,text,text,text)') is not null,
    'Onboarding controlado instalado'),
  ('funcion_confirmacion_v26',
    to_regprocedure('public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is not null,
    'Cierre con evidencia verificada instalado'),
  ('funcion_guardado_v26',
    to_regprocedure('public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)') is not null,
    'Alta y edición sujetas al control operativo'),
  ('funcion_manual_v26',
    to_regprocedure('public.guardar_remito_manual_v26(text,date,text,text,text)') is not null,
    'Respaldo manual verificado instalado'),
  ('reuso_manual_serializado',
    coalesce(position('pg_advisory_xact_lock' in pg_get_functiondef(to_regprocedure('public.guardar_remito_manual_v26(text,date,text,text,text)')))>0,false),
    'Dos cierres simultáneos no pueden reutilizar la misma evidencia'),
  ('funcion_resumen',
    to_regprocedure('public.resumen_remitos_v26()') is not null,
    'Resumen paginado instalado'),
  ('tabla_configuracion',to_regclass('public.configuracion_plataforma') is not null,'Configuración central creada'),
  ('tabla_admins_plataforma',to_regclass('public.plataforma_admins') is not null,'Administradores de plataforma creados'),
  ('tabla_altas_empresa',to_regclass('public.autorizaciones_empresa') is not null,'Altas controladas creadas'),
  ('rls_configuracion',coalesce((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='configuracion_plataforma'),false),'RLS en configuración'),
  ('rls_altas_empresa',coalesce((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='autorizaciones_empresa'),false),'RLS en altas'),
  ('bucket_privado',coalesce((select not public from storage.buckets where id='evidencias'),false),'Bucket de evidencias privado'),
  ('limite_storage',coalesce((select file_size_limit=5242880 from storage.buckets where id='evidencias'),false),'Límite de 5 MB por evidencia'),
  ('politica_subida_v26',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='evidencias_empresa_insert' and coalesce(with_check,'') ilike '%user_metadata%'),'Subida con hash y cuota'),
  ('politica_cleanup_v26',exists(
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='evidencias_chofer_cleanup_v26'
      and coalesce(qual,'') ilike '%owner_id%'
  ),'Limpieza limitada al archivo del propio chofer'),
  ('hash_firma',exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='firma_sha256'),'Hash de firma'),
  ('hash_foto_entrega',exists(select 1 from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='foto_entrega_sha256'),'Hash de foto'),
  ('hash_items',exists(select 1 from information_schema.columns where table_schema='public' and table_name='items_remito' and column_name='foto_sha256'),'Hash de ítems'),
  ('politica_retencion_empresa',exists(select 1 from information_schema.columns where table_schema='public' and table_name='empresas' and column_name='politica_retencion'),'Conservación definida por cliente'),
  ('captcha_site_key_configurable',exists(select 1 from information_schema.columns where table_schema='public' and table_name='configuracion_plataforma' and column_name='captcha_site_key'),'Site Key pública de Turnstile configurable'),
  ('preparacion_operativa',to_regprocedure('public.obtener_estado_operativo_v26()') is not null,'Lista de salida a piloto instalada'),
  ('admin_plataforma_existente',exists(select 1 from public.plataforma_admins),'Existe responsable de plataforma'),
  ('cada_empresa_con_admin',not exists(
    select 1 from public.empresas e
    where exists(select 1 from public.perfiles p where p.empresa_id=e.id and p.activo=true)
      and not exists(select 1 from public.perfiles p where p.empresa_id=e.id and p.activo=true and p.rol='admin')
  ),'Ninguna empresa activa quedó sin administrador'),
  ('registro_email_inicialmente_cerrado',coalesce((select not registro_email_habilitado from public.configuracion_plataforma where id=true),false),'No habilitar hasta configurar Confirm Email y SMTP'),
  ('rpc_antiguo_confirmar_bloqueado',
    not has_function_privilege('authenticated','public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb)','EXECUTE'),
    'No se puede saltear la verificación v2.6'),
  ('rpc_antiguo_guardar_bloqueado',
    not has_function_privilege('authenticated','public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb)','EXECUTE'),
    'No se puede saltear la preparación operativa'),
  ('rpc_antiguo_manual_bloqueado',
    not has_function_privilege('authenticated','public.guardar_remito_manual(text,date,text,text)','EXECUTE'),
    'No se puede saltear la verificación manual v2.6'),
  ('codigo_anterior_bloqueado',
    not has_function_privilege('authenticated','public.obtener_codigo_invitacion()','EXECUTE')
    and not has_function_privilege('authenticated','public.rotar_codigo_invitacion()','EXECUTE'),
    'Códigos de invitación fuera de uso'),
  ('tablas_privadas_sin_acceso_directo',
    not has_table_privilege('anon','public.configuracion_plataforma','SELECT')
    and not has_table_privilege('authenticated','public.configuracion_plataforma','SELECT')
    and not has_table_privilege('anon','public.autorizaciones_empresa','SELECT')
    and not has_table_privilege('authenticated','public.autorizaciones_empresa','SELECT')
    and not has_table_privilege('authenticated','public.client_error_events','SELECT'),
    'Datos administrativos sólo mediante RPC'),
  ('security_definer_sin_public_search_path',not exists(
    select 1
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and has_function_privilege('authenticated',p.oid,'EXECUTE')
      and coalesce(array_to_string(p.proconfig,','),'') ~ 'search_path=.*public'
  ),'RPC ejecutables sin public en search_path')
)
select nombre,ok,detalle from controles order by nombre;

-- Debe devolver cero filas. Si devuelve algo, no publiques todavía.
select n.nspname as esquema,p.proname as funcion,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       p.proconfig as configuracion
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef
  and has_function_privilege('authenticated',p.oid,'EXECUTE')
  and coalesce(array_to_string(p.proconfig,','),'') ~ 'search_path=.*public'
order by p.proname;

-- Resumen operativo. No expone emails.
select
  (select count(*) from public.empresas) as empresas,
  (select count(*) from public.perfiles where activo=true) as usuarios_activos,
  (select count(*) from public.autorizaciones_acceso where activa=true and usuario_id is null) as accesos_pendientes,
  (select count(*) from public.autorizaciones_empresa where activa=true and usuario_id is null) as empresas_pendientes,
  (select count(*) from public.empresas where razon_social is null or domicilio_privacidad is null or email_privacidad is null) as empresas_sin_datos_legales,
  (select count(*) from public.empresas where politica_retencion is null) as empresas_sin_politica_retencion,
  public._plataforma_lista_v26() as plataforma_lista_piloto,
  (select count(*) from public.remitos where locked_at is not null and signed_snapshot is null) as constancias_cerradas_sin_snapshot;

-- Control de privilegios críticos. Las columnas peligrosas deben ser false.
select
  has_function_privilege('authenticated','public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE') as authenticated_puede_confirmar_v26,
  has_function_privilege('authenticated','public.guardar_remito_manual_v26(text,date,text,text,text)','EXECUTE') as authenticated_puede_manual_v26,
  has_function_privilege('authenticated','public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)','EXECUTE') as authenticated_puede_guardar_v26,
  has_function_privilege('anon','public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)','EXECUTE') as anon_puede_confirmar_v26,
  has_function_privilege('anon','public.autorizar_nueva_empresa(text,text,text,text)','EXECUTE') as anon_puede_autorizar_empresa;
