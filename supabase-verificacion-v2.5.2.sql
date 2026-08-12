-- GoRemitos v2.5.2 - verificacion posterior
-- Ejecutar despues de supabase-migration-v2.5.2.sql.
-- Todos los controles deben devolver true.

with controles(nombre,ok) as (
  values
    ('rpc_actualizar_nombre',to_regprocedure('public.actualizar_mi_nombre(text)') is not null),
    ('rpc_security_definer',coalesce((
      select p.prosecdef
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='actualizar_mi_nombre'
        and pg_get_function_identity_arguments(p.oid)='p_nombre text'
    ),false)),
    ('rpc_search_path_restringido',coalesce((
      select p.proconfig @> array['search_path=""']::text[]
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='actualizar_mi_nombre'
        and pg_get_function_identity_arguments(p.oid)='p_nombre text'
    ),false)),
    ('authenticated_puede_actualizar_nombre',coalesce(has_function_privilege(
      'authenticated',to_regprocedure('public.actualizar_mi_nombre(text)'),'EXECUTE'
    ),false)),
    ('anon_no_puede_actualizar_nombre',not coalesce(has_function_privilege(
      'anon',to_regprocedure('public.actualizar_mi_nombre(text)'),'EXECUTE'
    ),false)),
    ('sin_update_directo_perfiles',not has_column_privilege(
      'authenticated','public.perfiles','nombre','UPDATE'
    )),
    ('sin_update_directo_autorizaciones',not has_table_privilege(
      'authenticated','public.autorizaciones_acceso','UPDATE'
    ))
)
select nombre,ok from controles order by nombre;
