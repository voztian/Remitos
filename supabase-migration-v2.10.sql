-- GoRemitos v2.10 - modo de prueba interna persistente y claramente separado
-- Requiere v2.7. Ejecutar completo en Supabase > SQL Editor.
-- No elimina empresas, usuarios, remitos, documentos ni evidencias existentes.

begin;

do $$
begin
  if to_regprocedure('public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)') is null
     or to_regprocedure('public.marcar_en_camino_v27(uuid)') is null
     or to_regprocedure('public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is null then
    raise exception 'PRECHECK v2.10: primero ejecuta la migracion v2.7';
  end if;
end
$$;

alter table public.empresas
  add column if not exists modo_prueba_interna boolean not null default false,
  add column if not exists modo_prueba_activado_en timestamptz,
  add column if not exists modo_prueba_activado_por uuid;

alter table public.remitos
  add column if not exists es_prueba boolean not null default false;

create index if not exists remitos_prueba_pendiente_v210_idx
  on public.remitos(empresa_id,es_prueba,estado)
  where es_prueba=true and estado='Pendiente';

-- Estos helpers mantienen separada la preparación real del bypass temporal que
-- sólo pueden abrir los RPC v2.10 dentro de su propia transacción.
create or replace function public._plataforma_real_lista_v210()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((
    select
      (c.plan_pro_verificado <> c.piloto_free_aceptado)
      and c.smtp_verificado
      and c.backup_db_verificado
      and c.backup_storage_verificado
      and c.oauth_produccion_verificado
      and c.captcha_verificado
      and length(btrim(coalesce(c.captcha_site_key,''))) between 10 and 200
      and length(btrim(coalesce(c.responsable_nombre,'')))>=2
      and length(btrim(coalesce(c.responsable_domicilio,'')))>=5
      and coalesce(c.privacidad_email,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      and coalesce(c.soporte_email,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    from public.configuracion_plataforma c
    where c.id=true
  ),false)
$$;

create or replace function public._empresa_real_lista_v210(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((
    select
      length(btrim(coalesce(e.razon_social,'')))>=2
      and regexp_replace(coalesce(e.cuit,''),'[^0-9]','','g') ~ '^[0-9]{11}$'
      and length(btrim(coalesce(e.domicilio_privacidad,'')))>=5
      and coalesce(e.email_privacidad,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
      and length(btrim(coalesce(e.politica_retencion,'')))>=10
    from public.empresas e
    where e.id=p_empresa
  ),false)
$$;

create or replace function public._modo_prueba_empresa_v210(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((
    select e.modo_prueba_interna
    from public.empresas e
    where e.id=p_empresa
  ),false)
$$;

create or replace function public._bypass_prueba_v210(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select auth.uid() is not null
    and p_empresa is not null
    and p_empresa=public.current_empresa_id()
    and coalesce(current_setting('goremitos.empresa_prueba',true),'')=p_empresa::text
    and public._modo_prueba_empresa_v210(p_empresa)
$$;

revoke all on function public._plataforma_real_lista_v210() from public,anon,authenticated;
revoke all on function public._empresa_real_lista_v210(uuid) from public,anon,authenticated;
revoke all on function public._modo_prueba_empresa_v210(uuid) from public,anon,authenticated;
revoke all on function public._bypass_prueba_v210(uuid) from public,anon,authenticated;

-- Las funciones v2.6/v2.7 siguen viendo la preparación real salvo cuando un
-- wrapper v2.10 habilitó explícitamente el bypass para esta empresa y sólo por
-- la duración de esa transacción.
create or replace function public._plataforma_lista_v27()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select public._plataforma_real_lista_v210()
    or public._bypass_prueba_v210(public.current_empresa_id())
$$;

create or replace function public._plataforma_lista_v26()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select public._plataforma_lista_v27()
$$;

create or replace function public._empresa_lista_v26(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select public._empresa_real_lista_v210(p_empresa)
    or public._bypass_prueba_v210(p_empresa)
$$;

revoke all on function public._plataforma_lista_v27() from public,anon,authenticated;
revoke all on function public._plataforma_lista_v26() from public,anon,authenticated;
revoke all on function public._empresa_lista_v26(uuid) from public,anon,authenticated;

-- El indicador se decide en el servidor al insertar y después es inmutable.
-- Esto también cubre pestañas viejas y evita que el navegador pueda elegir si
-- un registro es real o de prueba.
create or replace function public._marcar_remito_prueba_v210()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op='INSERT' then
    new.es_prueba:=public._modo_prueba_empresa_v210(new.empresa_id);
  elsif new.es_prueba is distinct from old.es_prueba then
    raise exception 'La clasificación real/prueba de un remito es inmutable';
  end if;
  return new;
end
$$;

revoke all on function public._marcar_remito_prueba_v210() from public,anon,authenticated;
drop trigger if exists remitos_marcar_prueba_v210 on public.remitos;
drop trigger if exists remitos_prueba_inmutable_v210 on public.remitos;
create trigger remitos_marcar_prueba_v210
before insert on public.remitos
for each row execute function public._marcar_remito_prueba_v210();
create trigger remitos_prueba_inmutable_v210
before update of es_prueba on public.remitos
for each row execute function public._marcar_remito_prueba_v210();

create or replace function public.obtener_modo_prueba_empresa_v210()
returns table(
  modo_prueba_interna boolean,
  activado_en timestamptz,
  activado_por uuid,
  remitos_prueba_pendientes bigint,
  remitos_prueba_total bigint,
  plataforma_real_lista boolean,
  empresa_real_lista boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null then raise exception 'Sesion requerida'; end if;
  return query
  select e.modo_prueba_interna,e.modo_prueba_activado_en,e.modo_prueba_activado_por,
    (select count(*) from public.remitos r where r.empresa_id=v_empresa and r.es_prueba=true and r.estado='Pendiente'),
    (select count(*) from public.remitos r where r.empresa_id=v_empresa and r.es_prueba=true),
    public._plataforma_real_lista_v210(),public._empresa_real_lista_v210(v_empresa)
  from public.empresas e
  where e.id=v_empresa;
end
$$;

revoke all on function public.obtener_modo_prueba_empresa_v210() from public,anon,authenticated;
grant execute on function public.obtener_modo_prueba_empresa_v210() to authenticated;

create or replace function public.actualizar_modo_prueba_empresa_v210(p_activo boolean)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador de la empresa puede cambiar el modo de prueba';
  end if;
  if p_activo is null then raise exception 'Indicá si querés activar o desactivar el modo de prueba'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public.current_empresa_id() is distinct from v_empresa
     or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Tu acceso de administrador ya no está vigente';
  end if;

  if p_activo then
    if exists(
      select 1 from public.remitos r
      where r.empresa_id=v_empresa and r.estado='Pendiente' and r.es_prueba=false
    ) then
      raise exception 'No se puede activar: hay entregas reales pendientes. Cerrálas o eliminálas primero';
    end if;
    update public.empresas set
      modo_prueba_interna=true,
      modo_prueba_activado_en=case when modo_prueba_interna then modo_prueba_activado_en else now() end,
      modo_prueba_activado_por=case when modo_prueba_interna then modo_prueba_activado_por else auth.uid() end,
      updated_at=now()
    where id=v_empresa;
  else
    if exists(
      select 1 from public.remitos r
      where r.empresa_id=v_empresa and r.estado='Pendiente' and r.es_prueba=true
    ) then
      raise exception 'No se puede desactivar: todavía hay entregas de prueba pendientes';
    end if;
    update public.empresas set modo_prueba_interna=false,updated_at=now()
    where id=v_empresa;
  end if;
  return p_activo;
end
$$;

revoke all on function public.actualizar_modo_prueba_empresa_v210(boolean) from public,anon,authenticated;
grant execute on function public.actualizar_modo_prueba_empresa_v210(boolean) to authenticated;

-- Wrapper de alta/edición. El bypass nunca queda disponible para otras
-- operaciones ni para otros RPC de la sesión.
create or replace function public.guardar_remito_v210(
  p_remito_id uuid,
  p_num text,
  p_cliente text,
  p_dir text,
  p_contacto text,
  p_tel text,
  p_chofer_id uuid,
  p_fecha date,
  p_items jsonb,
  p_documento_url text,
  p_documento_sha256 text,
  p_documento_nombre text,
  p_documento_mime text,
  p_documento_size bigint
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'') not in ('admin','oficina') then
    raise exception 'Sin permiso para guardar remitos';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public._modo_prueba_empresa_v210(v_empresa) then
    perform set_config('goremitos.empresa_prueba',v_empresa::text,true);
  elsif not public._plataforma_real_lista_v210() or not public._empresa_real_lista_v210(v_empresa) then
    raise exception 'La operación real todavía no está habilitada. Un administrador puede activar el modo de prueba interna';
  end if;
  return public.guardar_remito_v27(
    p_remito_id,p_num,p_cliente,p_dir,p_contacto,p_tel,p_chofer_id,p_fecha,p_items,
    p_documento_url,p_documento_sha256,p_documento_nombre,p_documento_mime,p_documento_size
  );
end
$$;

revoke all on function public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)
  from public,anon,authenticated;
grant execute on function public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)
  to authenticated;

create or replace function public.marcar_en_camino_v210(p_remito_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_prueba boolean;
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Solo el chofer asignado puede iniciar la entrega';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  select r.es_prueba into v_prueba
  from public.remitos r
  where r.id=p_remito_id and r.empresa_id=v_empresa and r.chofer_id=auth.uid() and r.estado='Pendiente';
  if not found then raise exception 'Entrega no disponible'; end if;
  if v_prueba then
    if not public._modo_prueba_empresa_v210(v_empresa) then
      raise exception 'El modo de prueba debe seguir activo para iniciar esta entrega';
    end if;
    perform set_config('goremitos.empresa_prueba',v_empresa::text,true);
  end if;
  return public.marcar_en_camino_v27(p_remito_id);
end
$$;

revoke all on function public.marcar_en_camino_v210(uuid) from public,anon,authenticated;
grant execute on function public.marcar_en_camino_v210(uuid) to authenticated;

create or replace function public.confirmar_entrega_v210(
  p_remito_id uuid,
  p_conformidad text,
  p_obs text,
  p_receptor_nombre text,
  p_receptor_dni text,
  p_firma_url text,
  p_firma_sha256 text,
  p_foto_entrega_url text,
  p_foto_entrega_sha256 text,
  p_consent boolean,
  p_items jsonb
)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_prueba boolean;
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Solo el chofer asignado puede confirmar';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  select r.es_prueba into v_prueba
  from public.remitos r
  where r.id=p_remito_id and r.empresa_id=v_empresa and r.chofer_id=auth.uid() and r.estado='Pendiente';
  if not found then raise exception 'Entrega no disponible'; end if;
  if v_prueba then
    if not public._modo_prueba_empresa_v210(v_empresa) then
      raise exception 'El modo de prueba debe seguir activo para cerrar esta entrega';
    end if;
    perform set_config('goremitos.empresa_prueba',v_empresa::text,true);
  end if;
  return public.confirmar_entrega_v27(
    p_remito_id,p_conformidad,p_obs,p_receptor_nombre,p_receptor_dni,
    p_firma_url,p_firma_sha256,p_foto_entrega_url,p_foto_entrega_sha256,p_consent,p_items
  );
end
$$;

revoke all on function public.confirmar_entrega_v210(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
grant execute on function public.confirmar_entrega_v210(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  to authenticated;

create or replace function public.guardar_remito_manual_v210(
  p_num text,p_fecha date,p_nota text,p_foto_url text,p_foto_sha256 text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Operacion no permitida';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public._modo_prueba_empresa_v210(v_empresa) then
    perform set_config('goremitos.empresa_prueba',v_empresa::text,true);
  elsif not public._plataforma_real_lista_v210() or not public._empresa_real_lista_v210(v_empresa) then
    raise exception 'La operación real todavía no está habilitada';
  end if;
  return public.guardar_remito_manual_v26(p_num,p_fecha,p_nota,p_foto_url,p_foto_sha256);
end
$$;

revoke all on function public.guardar_remito_manual_v210(text,date,text,text,text)
  from public,anon,authenticated;
grant execute on function public.guardar_remito_manual_v210(text,date,text,text,text)
  to authenticated;

-- Storage se evalúa antes de llamar al RPC de guardado; por eso autoriza de
-- forma explícita la empresa en prueba, manteniendo rutas, roles y límites.
create or replace function public._subida_documento_valida_v27(p_name text,p_user_metadata jsonb)
returns boolean
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_partes text[]:=storage.foldername(p_name);
  v_recientes bigint;
  v_real boolean;
begin
  if auth.uid() is null or v_empresa is null or public.current_rol() not in ('admin','oficina') then return false; end if;
  v_real:=public._plataforma_real_lista_v210() and public._empresa_real_lista_v210(v_empresa);
  if not v_real and not public._modo_prueba_empresa_v210(v_empresa) then return false; end if;
  if array_length(v_partes,1)<>2 or v_partes[1]<>v_empresa::text or v_partes[2]<>'entradas' then return false; end if;
  if p_name !~ ('^'||v_empresa::text||'/entradas/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](pdf|jpg|png|webp)$') then return false; end if;

  select count(*) into v_recientes
  from storage.objects o
  where o.bucket_id='documentos-remito' and o.owner_id::text=auth.uid()::text
    and o.created_at>now()-interval '1 hour';
  return v_recientes<60;
end
$$;

revoke all on function public._subida_documento_valida_v27(text,jsonb) from public,anon,authenticated;
grant execute on function public._subida_documento_valida_v27(text,jsonb) to authenticated;

create or replace function public._subida_evidencia_valida_v26(p_name text,p_user_metadata jsonb)
returns boolean
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_sha text:=lower(coalesce(p_user_metadata->>'sha256',''));
  v_partes text[]:=storage.foldername(p_name);
  v_recientes bigint;
  v_real boolean;
begin
  if auth.uid() is null or v_empresa is null or public.current_rol()<>'chofer' then return false; end if;
  v_real:=public._plataforma_real_lista_v210() and public._empresa_real_lista_v210(v_empresa);
  if not v_real and not public._modo_prueba_empresa_v210(v_empresa) then return false; end if;
  if v_sha !~ '^[0-9a-f]{64}$' then return false; end if;
  if array_length(v_partes,1)<2 or v_partes[1]<>v_empresa::text then return false; end if;

  if v_partes[2]='manual' then
    if array_length(v_partes,1)<>2
       or p_name !~ ('^'||v_empresa::text||'/manual/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$') then
      return false;
    end if;
  else
    if array_length(v_partes,1)<>3
       or v_partes[2] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or v_partes[3] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or p_name !~ ('^'||v_empresa::text||'/'||v_partes[2]||'/'||v_partes[3]||'/(firma[.]png|entrega[.]jpg|item-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg)$') then
      return false;
    end if;
  end if;

  select count(*) into v_recientes
  from storage.objects o
  where o.bucket_id='evidencias' and o.owner_id::text=auth.uid()::text
    and o.created_at>now()-interval '1 hour';
  return v_recientes<150;
end
$$;

revoke all on function public._subida_evidencia_valida_v26(text,jsonb) from public,anon,authenticated;
grant execute on function public._subida_evidencia_valida_v26(text,jsonb) to authenticated;

create or replace function public.obtener_seguimiento_publico_v210(p_token uuid)
returns table(
  empresa text,numero text,fecha date,estado text,
  creado_at timestamptz,salida_at timestamptz,cierre_at timestamptz,
  es_prueba boolean
)
language sql
stable
security definer
set search_path=''
as $$
  select e.nombre,r.num,r.fecha,
    case
      when r.estado='Pendiente' and r.salida_at is null then 'Programado'
      when r.estado='Pendiente' and r.salida_at is not null then 'En camino'
      when r.estado='Firmado' then 'Entregado'
      when r.estado='Disconforme' then 'Entregado con observaciones'
      when r.estado='Rechazado' then 'Rechazado'
      when r.estado='Manual' then 'Registrado manualmente'
      else 'En proceso'
    end,
    r.created_at,r.salida_at,r.ts_firma,r.es_prueba
  from public.remitos r
  join public.empresas e on e.id=r.empresa_id
  where r.public_token=p_token
  limit 1
$$;

revoke all on function public.obtener_seguimiento_publico_v210(uuid) from public,anon,authenticated;
grant execute on function public.obtener_seguimiento_publico_v210(uuid) to anon,authenticated;

commit;
