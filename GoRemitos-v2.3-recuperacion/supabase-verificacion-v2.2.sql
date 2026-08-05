-- GoRemitos v2.2 - diagnostico de solo lectura para ejecutar despues de la migracion

select 'RLS empresas' as control, c.relrowsecurity as ok
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='empresas'
union all
select 'RLS perfiles',c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='perfiles'
union all
select 'RLS remitos',c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='remitos'
union all
select 'RLS items_remito',c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='items_remito'
union all
select 'RLS remito_eventos',c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='remito_eventos'
union all
select 'Bucket evidencias privado',not b.public from storage.buckets b where b.id='evidencias'
union all
select 'Funcion guardar_remito',to_regprocedure('public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb)') is not null
union all
select 'Funcion confirmar_entrega',to_regprocedure('public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb)') is not null
union all
select 'Funcion onboarding',to_regprocedure('public.completar_onboarding()') is not null
union all
select 'Funcion onboarding Google',to_regprocedure('public.completar_onboarding_interactivo(text,text,text,text,text)') is not null
union all
select 'Funcion codigo solo admin',to_regprocedure('public.obtener_codigo_invitacion()') is not null
union all
select 'Codigo no visible directamente',not has_column_privilege('authenticated','public.empresas','codigo_invitacion','SELECT')
union all
select 'Numero de remito unico',to_regclass('public.remitos_empresa_num_operativo_uidx') is not null
union all
select 'Codigo de invitacion unico',to_regclass('public.empresas_codigo_invitacion_uidx') is not null;

-- Debe devolver cero filas. Si aparece INSERT, UPDATE o DELETE para
-- authenticated/anon, no publiques hasta revisar ese permiso.
select grantee,table_schema,table_name,privilege_type
from information_schema.role_table_grants
where table_schema='public'
  and table_name in ('empresas','perfiles','remitos','items_remito','remito_eventos')
  and grantee in ('PUBLIC','anon','authenticated')
  and privilege_type in ('INSERT','UPDATE','DELETE')
order by table_name,grantee,privilege_type;

-- Inventario final de políticas para revisión visual.
select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies
where (schemaname='public' and tablename in ('empresas','perfiles','remitos','items_remito','remito_eventos'))
   or (schemaname='storage' and tablename='objects')
order by schemaname,tablename,policyname;
