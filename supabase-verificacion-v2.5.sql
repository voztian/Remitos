-- GoRemitos v2.5 - verificacion posterior a la migracion
-- Ejecutar en Supabase > SQL Editor DESPUES de supabase-migration-v2.5.sql.
-- La primera consulta debe devolver todos los controles en true.

with controles(nombre,ok) as (
  values
    ('tabla_autorizaciones',to_regclass('public.autorizaciones_acceso') is not null),
    ('tabla_eventos_acceso',to_regclass('public.acceso_eventos') is not null),
    ('perfil_tiene_email',exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='perfiles' and column_name='email'
    )),
    ('perfil_tiene_eliminado_at',exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='perfiles' and column_name='eliminado_at'
    )),
    ('rls_autorizaciones',coalesce((
      select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='autorizaciones_acceso'
    ),false)),
    ('rls_eventos_acceso',coalesce((
      select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='acceso_eventos'
    ),false)),
    ('indice_email_autorizado_unico',to_regclass('public.autorizaciones_email_activa_uidx') is not null),
    ('indice_email_perfil_unico',to_regclass('public.perfiles_email_activo_uidx') is not null),
    ('rpc_autorizar',to_regprocedure('public.autorizar_usuario(text,text,text)') is not null),
    ('rpc_cancelar',to_regprocedure('public.cancelar_autorizacion(uuid)') is not null),
    ('rpc_cambiar_rol',to_regprocedure('public.cambiar_rol_usuario(uuid,text)') is not null),
    ('rpc_eliminar',to_regprocedure('public.eliminar_usuario_empresa(uuid)') is not null),
    ('rpc_listar',to_regprocedure('public.listar_accesos_empresa()') is not null),
    ('rpc_mi_acceso',to_regprocedure('public.obtener_mi_acceso()') is not null),
    ('authenticated_puede_autorizar',coalesce(has_function_privilege(
      'authenticated',to_regprocedure('public.autorizar_usuario(text,text,text)'),'EXECUTE'
    ),false)),
    ('authenticated_puede_eliminar',coalesce(has_function_privilege(
      'authenticated',to_regprocedure('public.eliminar_usuario_empresa(uuid)'),'EXECUTE'
    ),false)),
    ('codigo_anterior_bloqueado',not coalesce(has_function_privilege(
      'authenticated',to_regprocedure('public.obtener_codigo_invitacion()'),'EXECUTE'
    ),false)),
    ('administracion_anterior_bloqueada',not coalesce(has_function_privilege(
      'authenticated',to_regprocedure('public.administrar_usuario(uuid,text,boolean)'),'EXECUTE'
    ),false)),
    ('email_perfiles_no_expuesto',not has_column_privilege(
      'authenticated','public.perfiles','email','SELECT'
    )),
    ('autorizaciones_sin_acceso_directo',
      not has_table_privilege('authenticated','public.autorizaciones_acceso','SELECT')
      and not has_table_privilege('authenticated','public.autorizaciones_acceso','INSERT')
      and not has_table_privilege('authenticated','public.autorizaciones_acceso','UPDATE')
      and not has_table_privilege('authenticated','public.autorizaciones_acceso','DELETE')
    ),
    ('perfiles_activos_con_email',not exists(
      select 1 from public.perfiles where activo=true and email is null
    )),
    ('emails_activos_sin_duplicados',not exists(
      select 1 from public.autorizaciones_acceso where activa=true
      group by email having count(*)>1
    )),
    ('roles_sin_desacople',not exists(
      select 1
      from public.autorizaciones_acceso a
      join public.perfiles p on p.id=a.usuario_id
      where a.activa=true and p.activo=true
        and (a.empresa_id<>p.empresa_id or a.rol<>p.rol or a.email<>p.email)
    )),
    ('cada_empresa_con_admin',not exists(
      select 1
      from public.empresas e
      where exists(
        select 1 from public.perfiles p
        where p.empresa_id=e.id and p.activo=true
      )
      and not exists(
        select 1 from public.perfiles p
        where p.empresa_id=e.id and p.activo=true and p.rol='admin'
      )
    ))
)
select nombre,ok from controles order by nombre;

-- Debe devolver cero filas. Si aparece algo, no publiques todavía.
select grantee,table_schema,table_name,privilege_type
from information_schema.role_table_grants
where table_schema='public'
  and table_name='autorizaciones_acceso'
  and grantee in ('anon','authenticated')
order by grantee,privilege_type;

-- Resumen informativo. No expone emails en el resultado.
select
  count(*) filter(where activa=true and usuario_id is null) as autorizaciones_pendientes,
  count(*) filter(where activa=true and usuario_id is not null) as accesos_vinculados,
  count(*) filter(where activa=false) as autorizaciones_revocadas
from public.autorizaciones_acceso;
