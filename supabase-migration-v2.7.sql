-- GoRemitos v2.7 - etapa 1: remito externo, seguimiento y constancia digital
-- Requiere v2.6. Ejecutar completo en Supabase > SQL Editor.
-- No elimina empresas, usuarios, remitos ni evidencias existentes.

begin;

do $$
begin
  if to_regprocedure('public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)') is null
     or to_regprocedure('public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is null then
    raise exception 'PRECHECK v2.7: primero ejecuta la migracion v2.6';
  end if;
end
$$;

-- El plan comercial no define la validez del circuito. Para una prueba
-- controlada se permite Free únicamente si el responsable acepta de forma
-- expresa el riesgo de pausa y verifica backups externos de DB y Storage.
alter table public.configuracion_plataforma
  add column if not exists piloto_free_aceptado boolean not null default false;

create or replace function public._plataforma_lista_v27()
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

revoke all on function public._plataforma_lista_v27() from public,anon,authenticated;

-- Mantiene compatibles las funciones seguras de v2.6 que consultan este
-- helper, pero aplica la decisión explícita Pro/Free de v2.7.
create or replace function public._plataforma_lista_v26()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select public._plataforma_lista_v27()
$$;

revoke all on function public._plataforma_lista_v26() from public,anon,authenticated;

create or replace function public.obtener_estado_operativo_v27()
returns table(
  plan_pro_verificado boolean,
  piloto_free_aceptado boolean,
  smtp_verificado boolean,
  backup_db_verificado boolean,
  backup_storage_verificado boolean,
  oauth_produccion_verificado boolean,
  captcha_verificado boolean,
  plataforma_lista boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then
    raise exception 'Operacion reservada al administrador de GoRemitos';
  end if;
  return query
  select c.plan_pro_verificado,c.piloto_free_aceptado,c.smtp_verificado,
         c.backup_db_verificado,c.backup_storage_verificado,
         c.oauth_produccion_verificado,c.captcha_verificado,
         public._plataforma_lista_v27()
  from public.configuracion_plataforma c
  where c.id=true;
end
$$;

revoke all on function public.obtener_estado_operativo_v27() from public,anon,authenticated;
grant execute on function public.obtener_estado_operativo_v27() to authenticated;

create or replace function public.actualizar_preparacion_plataforma_v27(
  p_plan_pro boolean,
  p_piloto_free boolean,
  p_smtp boolean,
  p_backup_db boolean,
  p_backup_storage boolean,
  p_oauth_produccion boolean,
  p_captcha boolean
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then
    raise exception 'Operacion reservada al administrador de GoRemitos';
  end if;
  if coalesce(p_plan_pro,false)=coalesce(p_piloto_free,false) then
    raise exception 'Elegí una sola modalidad: Supabase Pro o piloto controlado en Free';
  end if;
  if coalesce(p_captcha,false) and length(btrim(coalesce(
    (select c.captcha_site_key from public.configuracion_plataforma c where c.id=true),''
  ))) not between 10 and 200 then
    raise exception 'Configurá la Site Key de Cloudflare Turnstile antes de marcar CAPTCHA';
  end if;
  update public.configuracion_plataforma set
    plan_pro_verificado=coalesce(p_plan_pro,false),
    piloto_free_aceptado=coalesce(p_piloto_free,false),
    smtp_verificado=coalesce(p_smtp,false),
    backup_db_verificado=coalesce(p_backup_db,false),
    backup_storage_verificado=coalesce(p_backup_storage,false),
    oauth_produccion_verificado=coalesce(p_oauth_produccion,false),
    captcha_verificado=coalesce(p_captcha,false),
    updated_at=now(),updated_by=auth.uid()
  where id=true;
  return public._plataforma_lista_v27();
end
$$;

revoke all on function public.actualizar_preparacion_plataforma_v27(boolean,boolean,boolean,boolean,boolean,boolean,boolean)
  from public,anon,authenticated;
grant execute on function public.actualizar_preparacion_plataforma_v27(boolean,boolean,boolean,boolean,boolean,boolean,boolean)
  to authenticated;

-- Diagnóstico acotado de esta versión. Conserva la retención y el límite de
-- frecuencia de v2.6, pero registra correctamente la versión que produjo el
-- error para no mezclar incidentes durante el piloto.
create or replace function public.registrar_error_cliente_v27(
  p_contexto text,p_mensaje text,p_stack text,p_path text,p_user_agent text
)
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_id bigint;
begin
  if v_uid is null then return null; end if;
  delete from public.client_error_events
  where created_at<now()-interval '30 days';
  if (select count(*) from public.client_error_events e
      where e.user_id=v_uid and e.created_at>now()-interval '1 minute')>=20 then
    return null;
  end if;
  insert into public.client_error_events(
    user_id,empresa_id,app_version,contexto,mensaje,stack,url_path,user_agent
  ) values(
    v_uid,public.current_empresa_id(),'2.7.0',
    left(coalesce(p_contexto,'desconocido'),80),
    left(coalesce(p_mensaje,'Error sin mensaje'),1000),
    left(coalesce(p_stack,''),4000),left(coalesce(p_path,''),500),
    left(coalesce(p_user_agent,''),500)
  ) returning id into v_id;
  return v_id;
end
$$;

revoke all on function public.registrar_error_cliente_v27(text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.registrar_error_cliente_v27(text,text,text,text,text)
  to authenticated;

-- Protege la continuidad de un viaje ante cambios de usuarios. En v2.5 un
-- administrador podía quitar el rol o el acceso de un chofer cuyo remito ya
-- estaba en camino, dejando la entrega sin una identidad habilitada para
-- cerrarla. Las operaciones sobre usuarios y las transiciones v2.7 comparten
-- un bloqueo por empresa; una baja sigue permitida, pero recién después de
-- cerrar cualquier viaje activo del usuario.
create or replace function public.cambiar_rol_usuario(p_usuario_id uuid,p_rol text)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_empresa uuid:=public.current_empresa_id();
  v_rol text:=lower(btrim(coalesce(p_rol,'')));
  v_anterior text;
  v_email text;
  v_desasignados integer:=0;
begin
  if v_actor is null or v_empresa is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede cambiar roles';
  end if;
  if p_usuario_id=v_actor then raise exception 'No podes modificar tu propio rol'; end if;
  if v_rol not in ('admin','oficina','chofer') then raise exception 'Rol invalido'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Tu acceso de administrador ya no esta vigente';
  end if;

  select p.rol,p.email into v_anterior,v_email
  from public.perfiles p
  where p.id=p_usuario_id and p.empresa_id=v_empresa and p.activo=true
  for update;
  if not found then raise exception 'Usuario no encontrado'; end if;

  if v_anterior='admin' and v_rol<>'admin'
     and (select count(*) from public.perfiles p where p.empresa_id=v_empresa and p.activo=true and p.rol='admin')<=1 then
    raise exception 'La empresa debe conservar al menos un administrador';
  end if;

  if v_anterior='chofer' and v_rol<>'chofer' and exists(
    select 1 from public.remitos r
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
      and r.estado='Pendiente' and r.salida_at is not null
  ) then
    raise exception 'No se puede cambiar el rol: el chofer tiene una entrega en camino. Cerrala antes de continuar';
  end if;

  if v_anterior='chofer' and v_rol<>'chofer' then
    insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    select r.id,v_empresa,v_actor,'chofer_desasignado',
           jsonb_build_object('usuario_id',p_usuario_id,'motivo','cambio_de_rol')
    from public.remitos r
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
      and r.estado='Pendiente' and r.salida_at is null;

    update public.remitos r
    set chofer_id=null,chofer_nombre='Sin asignar'
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
      and r.estado='Pendiente' and r.salida_at is null;
    get diagnostics v_desasignados=row_count;
  end if;

  update public.perfiles set rol=v_rol where id=p_usuario_id and empresa_id=v_empresa;
  update public.autorizaciones_acceso
  set rol=v_rol,updated_at=now()
  where empresa_id=v_empresa and usuario_id=p_usuario_id and activa=true;

  insert into public.acceso_eventos(
    empresa_id,actor_id,usuario_id,email,evento,detalle
  ) values(
    v_empresa,v_actor,p_usuario_id,v_email,'rol_cambiado',
    jsonb_build_object('anterior',v_anterior,'nuevo',v_rol,'remitos_desasignados',v_desasignados)
  );
  return v_desasignados;
end
$$;

revoke all on function public.cambiar_rol_usuario(uuid,text) from public,anon,authenticated;
grant execute on function public.cambiar_rol_usuario(uuid,text) to authenticated;

create or replace function public.eliminar_usuario_empresa(p_usuario_id uuid)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_empresa uuid:=public.current_empresa_id();
  v_rol text;
  v_email text;
  v_desasignados integer:=0;
begin
  if v_actor is null or v_empresa is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede eliminar usuarios';
  end if;
  if p_usuario_id=v_actor then raise exception 'No podes eliminar tu propio acceso'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Tu acceso de administrador ya no esta vigente';
  end if;

  select p.rol,p.email into v_rol,v_email
  from public.perfiles p
  where p.id=p_usuario_id and p.empresa_id=v_empresa and p.activo=true
  for update;
  if not found then raise exception 'Usuario no encontrado'; end if;

  if v_rol='admin'
     and (select count(*) from public.perfiles p where p.empresa_id=v_empresa and p.activo=true and p.rol='admin')<=1 then
    raise exception 'La empresa debe conservar al menos un administrador';
  end if;

  if exists(
    select 1 from public.remitos r
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
      and r.estado='Pendiente' and r.salida_at is not null
  ) then
    raise exception 'No se puede eliminar el acceso: el usuario tiene una entrega en camino. Cerrala antes de continuar';
  end if;

  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  select r.id,v_empresa,v_actor,'chofer_desasignado',
         jsonb_build_object('usuario_id',p_usuario_id,'motivo','usuario_eliminado')
  from public.remitos r
  where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
    and r.estado='Pendiente' and r.salida_at is null;

  update public.remitos r
  set chofer_id=null,chofer_nombre='Sin asignar'
  where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id
    and r.estado='Pendiente' and r.salida_at is null;
  get diagnostics v_desasignados=row_count;

  update public.perfiles
  set activo=false,eliminado_at=now(),eliminado_por=v_actor
  where id=p_usuario_id and empresa_id=v_empresa;

  update public.autorizaciones_acceso
  set activa=false,revocada_por=v_actor,revocada_at=now(),updated_at=now()
  where empresa_id=v_empresa and usuario_id=p_usuario_id and activa=true;

  insert into public.acceso_eventos(
    empresa_id,actor_id,usuario_id,email,evento,detalle
  ) values(
    v_empresa,v_actor,p_usuario_id,v_email,'usuario_eliminado',
    jsonb_build_object('rol',v_rol,'remitos_desasignados',v_desasignados)
  );
  return v_desasignados;
end
$$;

revoke all on function public.eliminar_usuario_empresa(uuid) from public,anon,authenticated;
grant execute on function public.eliminar_usuario_empresa(uuid) to authenticated;

-- El documento es el remito emitido por el sistema del cliente. GoRemitos no
-- lo numera ni lo convierte en comprobante fiscal: lo custodia y lo vincula a
-- la trazabilidad de la entrega.
alter table public.remitos
  add column if not exists documento_url text,
  add column if not exists documento_sha256 text,
  add column if not exists documento_nombre text,
  add column if not exists documento_mime text,
  add column if not exists documento_size bigint,
  add column if not exists salida_at timestamptz,
  add column if not exists salida_por uuid references auth.users(id) on delete set null;

do $$ begin
  alter table public.remitos add constraint remitos_documento_sha256_v27_ck
    check(documento_sha256 is null or documento_sha256 ~ '^[0-9a-f]{64}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_documento_nombre_v27_ck
    check(documento_nombre is null or (
      length(btrim(documento_nombre)) between 1 and 180
      and documento_nombre !~ '[[:cntrl:]]'
    ));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_documento_mime_v27_ck
    check(documento_mime is null or documento_mime in ('application/pdf','image/jpeg','image/png','image/webp'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_documento_size_v27_ck
    check(documento_size is null or documento_size between 1 and 10485760);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_documento_completo_v27_ck
    check(
      (documento_url is null and documento_sha256 is null and documento_nombre is null and documento_mime is null and documento_size is null)
      or
      (documento_url is not null and documento_sha256 is not null and documento_nombre is not null and documento_mime is not null and documento_size is not null)
    );
exception when duplicate_object then null; end $$;

create unique index if not exists remitos_documento_url_v27_uidx
  on public.remitos(documento_url) where documento_url is not null;
create index if not exists remitos_empresa_salida_v27_idx
  on public.remitos(empresa_id,estado,salida_at);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'documentos-remito','documentos-remito',false,10485760,
  array['application/pdf','image/jpeg','image/png','image/webp']
)
on conflict(id) do update set
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

-- Valida la ruta y limita la cantidad de documentos que un usuario puede
-- cargar por hora. Algunas versiones de Storage incorporan user_metadata
-- después del INSERT inicial; por compatibilidad, la política no depende de
-- esos datos. guardar_remito_v27 comprueba hash, nombre, tipo y tamaño contra
-- el objeto ya terminado antes de permitir que quede asociado a un remito.
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
begin
  if auth.uid() is null or v_empresa is null or public.current_rol() not in ('admin','oficina') then return false; end if;
  if not public._plataforma_lista_v27() or not public._empresa_lista_v26(v_empresa) then return false; end if;
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

drop policy if exists documentos_remito_select_v27 on storage.objects;
create policy documentos_remito_select_v27
on storage.objects for select to authenticated using(
  bucket_id='documentos-remito'
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and (
    public.current_rol() in ('admin','oficina')
    or (
      public.current_rol()='chofer'
      and exists(
        select 1 from public.remitos r
        where r.empresa_id=public.current_empresa_id()
          and r.chofer_id=auth.uid()
          and r.documento_url=name
      )
    )
  )
);

drop policy if exists documentos_remito_insert_v27 on storage.objects;
create policy documentos_remito_insert_v27
on storage.objects for insert to authenticated with check(
  bucket_id='documentos-remito'
  and public._subida_documento_valida_v27(name,user_metadata)
);

-- Sólo se borran objetos que ya no estén vinculados. Un administrador puede
-- limpiar el documento de un pendiente eliminado aunque lo haya subido oficina.
drop policy if exists documentos_remito_cleanup_v27 on storage.objects;
create policy documentos_remito_cleanup_v27
on storage.objects for delete to authenticated using(
  bucket_id='documentos-remito'
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and public.current_rol() in ('admin','oficina')
  and not exists(select 1 from public.remitos r where r.documento_url=name)
);

-- Devuelve metadata verificada del objeto. No se expone como RPC. Para un
-- documento nuevo exige que el objeto pertenezca al usuario que lo acaba de
-- subir; para uno ya vinculado permite conservarlo al editar o cerrar.
create or replace function public._documento_meta_v27(
  p_path text,p_sha256 text,p_exigir_propietario boolean default true
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_obj jsonb;
  v_meta jsonb;
  v_sha text:=lower(btrim(coalesce(p_sha256,'')));
  v_guardado text;
  v_mime text;
  v_size bigint;
begin
  if p_path is null or v_sha !~ '^[0-9a-f]{64}$' then raise exception 'Hash del documento invalido'; end if;

  select to_jsonb(o) into v_obj
  from storage.objects o
  where o.bucket_id='documentos-remito' and o.name=p_path
  limit 1;
  if v_obj is null then raise exception 'El documento original no existe en Storage'; end if;
  if p_exigir_propietario and coalesce(v_obj->>'owner_id','')<>auth.uid()::text then
    raise exception 'El documento original no pertenece al usuario actual';
  end if;

  v_meta:=coalesce(v_obj->'metadata','{}'::jsonb);
  v_guardado:=lower(coalesce(
    v_obj->'user_metadata'->>'sha256',
    v_meta->'userMetadata'->>'sha256',
    v_meta->>'sha256',''
  ));
  v_mime:=coalesce(v_meta->>'mimetype',v_meta->>'contentType','');
  v_size:=coalesce(nullif(v_meta->>'size','')::bigint,0);

  if v_guardado='' or v_guardado<>v_sha then raise exception 'El documento no coincide con su hash'; end if;
  if v_size not between 1 and 10485760
     or v_mime not in ('application/pdf','image/jpeg','image/png','image/webp') then
    raise exception 'El documento tiene tamaño o formato invalido';
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'path',p_path,'sha256',v_sha,'size',v_size,'mimetype',v_mime,
    'nombre_original',coalesce(
      v_obj->'user_metadata'->>'originalName',
      v_meta->'userMetadata'->>'originalName'
    ),
    'etag',coalesce(v_meta->>'eTag',v_meta->>'etag'),
    'created_at',v_obj->>'created_at'
  ));
end
$$;

revoke all on function public._documento_meta_v27(text,text,boolean) from public,anon,authenticated;

create or replace function public.guardar_remito_v27(
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
  v_actual public.remitos%rowtype;
  v_id uuid;
  v_meta jsonb;
  v_nuevo_documento boolean:=true;
begin
  if auth.uid() is null or v_empresa is null or public.current_rol() not in ('admin','oficina') then
    raise exception 'Sin permiso para guardar remitos';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public.current_empresa_id() is distinct from v_empresa
     or coalesce(public.current_rol(),'') not in ('admin','oficina') then
    raise exception 'Tu acceso ya no esta vigente';
  end if;
  if p_documento_url is null or p_documento_sha256 is null or p_documento_nombre is null
     or p_documento_mime is null or p_documento_size is null then
    raise exception 'Adjuntá el remito original en PDF o imagen';
  end if;
  if length(btrim(p_documento_nombre)) not between 1 and 180
     or p_documento_nombre ~ '[[:cntrl:]]'
     or p_documento_mime not in ('application/pdf','image/jpeg','image/png','image/webp')
     or p_documento_size not between 1 and 10485760 then
    raise exception 'Los datos del documento original son invalidos';
  end if;
  if (p_documento_mime='application/pdf' and p_documento_url !~ '[.]pdf$')
     or (p_documento_mime='image/jpeg' and p_documento_url !~ '[.]jpg$')
     or (p_documento_mime='image/png' and p_documento_url !~ '[.]png$')
     or (p_documento_mime='image/webp' and p_documento_url !~ '[.]webp$') then
    raise exception 'El formato declarado no coincide con la referencia del documento';
  end if;
  if (p_documento_mime='application/pdf' and lower(btrim(p_documento_nombre)) !~ '[.]pdf$')
     or (p_documento_mime='image/jpeg' and lower(btrim(p_documento_nombre)) !~ '[.](jpg|jpeg)$')
     or (p_documento_mime='image/png' and lower(btrim(p_documento_nombre)) !~ '[.]png$')
     or (p_documento_mime='image/webp' and lower(btrim(p_documento_nombre)) !~ '[.]webp$') then
    raise exception 'La extensión del nombre original no coincide con el formato declarado';
  end if;

  if p_remito_id is not null then
    select * into v_actual from public.remitos
    where id=p_remito_id and empresa_id=v_empresa and estado='Pendiente'
    for update;
    if v_actual.id is null then raise exception 'El remito no existe o ya fue cerrado'; end if;
    if v_actual.salida_at is not null then raise exception 'Una entrega en camino ya no se puede editar'; end if;
    v_nuevo_documento:=coalesce(v_actual.documento_url,'')<>p_documento_url;
  end if;

  if p_documento_url !~ ('^'||v_empresa::text||'/entradas/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](pdf|jpg|png|webp)$') then
    raise exception 'Referencia de documento invalida';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_documento_url,0));
  if v_nuevo_documento then
    if exists(select 1 from public.remitos r where r.documento_url=p_documento_url) then
      raise exception 'Este documento ya esta vinculado a otro remito';
    end if;
    v_meta:=public._documento_meta_v27(p_documento_url,p_documento_sha256,true);
  else
    if p_documento_sha256<>v_actual.documento_sha256
       or p_documento_nombre<>v_actual.documento_nombre
       or p_documento_mime<>v_actual.documento_mime
       or p_documento_size<>v_actual.documento_size then
      raise exception 'La metadata del documento existente no coincide';
    end if;
    v_meta:=public._documento_meta_v27(p_documento_url,p_documento_sha256,false);
  end if;

  if (v_meta->>'mimetype')<>p_documento_mime
     or (v_meta->>'size')::bigint<>p_documento_size
     or btrim(coalesce(v_meta->>'nombre_original',''))<>btrim(p_documento_nombre) then
    raise exception 'El nombre, tipo o tamaño del documento no coincide con Storage';
  end if;

  v_id:=public.guardar_remito_v26(
    p_remito_id,p_num,p_cliente,p_dir,p_contacto,p_tel,p_chofer_id,p_fecha,p_items
  );

  update public.remitos set
    documento_url=p_documento_url,
    documento_sha256=lower(p_documento_sha256),
    documento_nombre=btrim(p_documento_nombre),
    documento_mime=p_documento_mime,
    documento_size=p_documento_size
  where id=v_id;

  if v_nuevo_documento then
    insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    values(v_id,v_empresa,auth.uid(),'documento_asociado_v27',jsonb_build_object(
      'sha256',lower(p_documento_sha256),'nombre',btrim(p_documento_nombre),
      'mime',p_documento_mime,'size',p_documento_size
    ));
  end if;
  return v_id;
end
$$;

revoke all on function public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)
  from public,anon,authenticated;
grant execute on function public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)
  to authenticated;

create or replace function public.marcar_en_camino_v27(p_remito_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path=''
as $$
declare
  v_rem public.remitos%rowtype;
  v_now timestamptz:=now();
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Solo el chofer asignado puede iniciar la entrega';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public.current_empresa_id() is distinct from v_empresa
     or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Tu acceso de chofer ya no esta vigente';
  end if;
  if not public._plataforma_lista_v27() then raise exception 'El piloto todavía no está habilitado por GoRemitos'; end if;

  select * into v_rem from public.remitos
  where id=p_remito_id and empresa_id=v_empresa
    and chofer_id=auth.uid() and estado='Pendiente'
  for update;
  if v_rem.id is null then raise exception 'Entrega no disponible'; end if;
  if v_rem.documento_url is null then raise exception 'Falta adjuntar el remito original antes de iniciar'; end if;
  if v_rem.salida_at is not null then return v_rem.salida_at; end if;

  -- No se inicia una entrega cuyo documento fue borrado o cuya metadata ya no
  -- coincide. El cierre vuelve a verificarlo para cubrir todo el viaje.
  perform public._documento_meta_v27(v_rem.documento_url,v_rem.documento_sha256,false);

  update public.remitos set salida_at=v_now,salida_por=auth.uid() where id=v_rem.id;
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  values(v_rem.id,v_rem.empresa_id,auth.uid(),'entrega_iniciada_v27',jsonb_build_object('salida_at',v_now));
  return v_now;
end
$$;

revoke all on function public.marcar_en_camino_v27(uuid) from public,anon,authenticated;
grant execute on function public.marcar_en_camino_v27(uuid) to authenticated;

create or replace function public.resumen_remitos_v27()
returns table(
  total bigint,entregados bigint,programados bigint,en_camino bigint,
  con_problemas bigint,manuales bigint
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_rol text:=public.current_rol();
begin
  if auth.uid() is null or v_empresa is null then raise exception 'Sesion requerida'; end if;
  return query
  select count(*),
         count(*) filter(where r.estado in ('Firmado','Disconforme','Rechazado')),
         count(*) filter(where r.estado='Pendiente' and r.salida_at is null),
         count(*) filter(where r.estado='Pendiente' and r.salida_at is not null),
         count(*) filter(where r.estado in ('Disconforme','Rechazado')),
         count(*) filter(where r.estado='Manual')
  from public.remitos r
  where r.empresa_id=v_empresa
    and (v_rol in ('admin','oficina') or (v_rol='chofer' and r.chofer_id=auth.uid()));
end
$$;

revoke all on function public.resumen_remitos_v27() from public,anon,authenticated;
grant execute on function public.resumen_remitos_v27() to authenticated;

-- Seguimiento por token portador. Devuelve exclusivamente datos operativos
-- mínimos: nunca expone domicilio, teléfono, mercadería, documento, receptor,
-- DNI, firma, fotos, hashes, usuarios ni identificadores internos.
create or replace function public.obtener_seguimiento_publico_v27(p_token uuid)
returns table(
  empresa text,numero text,fecha date,estado text,
  creado_at timestamptz,salida_at timestamptz,cierre_at timestamptz
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
    r.created_at,r.salida_at,r.ts_firma
  from public.remitos r
  join public.empresas e on e.id=r.empresa_id
  where r.public_token=p_token
  limit 1
$$;

revoke all on function public.obtener_seguimiento_publico_v27(uuid) from public,anon,authenticated;
grant execute on function public.obtener_seguimiento_publico_v27(uuid) to anon,authenticated;

create or replace function public.confirmar_entrega_v27(
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
  v_rem public.remitos%rowtype;
  v_now timestamptz:=now();
  v_estado text;
  v_snapshot jsonb;
  v_hash text;
  v_item jsonb;
  v_db_count integer;
  v_distinct_count integer;
  v_empresa_datos jsonb;
  v_evidencias jsonb:='[]'::jsonb;
  v_meta jsonb;
  v_documento jsonb;
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null then raise exception 'Sesion requerida'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if public.current_empresa_id() is distinct from v_empresa
     or coalesce(public.current_rol(),'')<>'chofer' then
    raise exception 'Solo el chofer asignado puede confirmar';
  end if;
  if not public._plataforma_lista_v27() then raise exception 'El piloto todavía no está habilitado por GoRemitos'; end if;
  select * into v_rem from public.remitos
  where id=p_remito_id and empresa_id=v_empresa
    and chofer_id=auth.uid() and estado='Pendiente'
  for update;
  if v_rem.id is null then raise exception 'Entrega no disponible'; end if;
  if v_rem.salida_at is null then raise exception 'Primero inicia la entrega'; end if;
  if v_rem.documento_url is null then raise exception 'Falta el remito original'; end if;
  if not public._empresa_lista_v26(v_rem.empresa_id) then
    raise exception 'La empresa debe completar sus datos legales y política de conservación antes de registrar entregas';
  end if;
  if coalesce(p_conformidad,'') not in ('ok','disc','rech') then raise exception 'Conformidad invalida'; end if;
  if length(btrim(coalesce(p_receptor_nombre,''))) not between 2 and 100
     or coalesce(p_receptor_dni,'') !~ '^[0-9]{7,8}$'
     or length(coalesce(p_obs,''))>1000 then raise exception 'Datos del receptor invalidos'; end if;
  if p_consent is not true then raise exception 'Falta la constancia de informacion al receptor'; end if;
  if p_conformidad<>'rech' and p_firma_url is null then raise exception 'Falta la firma'; end if;
  if p_conformidad='rech' and p_firma_url is not null then raise exception 'Una entrega rechazada no debe incluir firma de conformidad'; end if;
  if p_conformidad='rech' and length(btrim(coalesce(p_obs,'')))<3 then raise exception 'Falta el motivo del rechazo'; end if;

  v_documento:=public._documento_meta_v27(v_rem.documento_url,v_rem.documento_sha256,false)
    || jsonb_build_object('nombre_original',v_rem.documento_nombre);

  if p_firma_url is not null then
    if length(p_firma_url)>600
       or p_firma_url !~ ('^'||v_rem.empresa_id::text||'/'||v_rem.id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/firma[.]png$') then
      raise exception 'Referencia de firma invalida';
    end if;
    v_meta:=public._evidencia_meta_v26(p_firma_url,p_firma_sha256);
    v_evidencias:=v_evidencias||jsonb_build_array(jsonb_build_object('tipo','firma','archivo',v_meta));
  elsif p_firma_sha256 is not null then
    raise exception 'Hash de firma sin archivo';
  end if;

  if p_foto_entrega_url is not null then
    if length(p_foto_entrega_url)>600
       or p_foto_entrega_url !~ ('^'||v_rem.empresa_id::text||'/'||v_rem.id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/entrega[.]jpg$') then
      raise exception 'Referencia de foto invalida';
    end if;
    v_meta:=public._evidencia_meta_v26(p_foto_entrega_url,p_foto_entrega_sha256);
    v_evidencias:=v_evidencias||jsonb_build_array(jsonb_build_object('tipo','foto_entrega','archivo',v_meta));
  elsif p_foto_entrega_sha256 is not null then
    raise exception 'Hash de foto sin archivo';
  end if;

  if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Detalle de items invalido'; end if;
  select count(*) into v_db_count from public.items_remito where remito_id=p_remito_id;
  if jsonb_array_length(p_items)<>v_db_count then raise exception 'Deben revisarse todos los items'; end if;
  select count(distinct value->>'id') into v_distinct_count from jsonb_array_elements(p_items);
  if v_distinct_count<>v_db_count then raise exception 'El detalle contiene items repetidos o faltantes'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if coalesce(v_item->>'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Identificador de item invalido';
    end if;
    if coalesce(v_item->>'estado','') not in ('ok','miss') then raise exception 'Estado de item invalido'; end if;
    if length(coalesce(v_item->>'nota',''))>500 then raise exception 'Observacion de item demasiado extensa'; end if;
    if nullif(v_item->>'foto_url','') is not null then
      if length(v_item->>'foto_url')>600
         or (v_item->>'foto_url') !~ ('^'||v_rem.empresa_id::text||'/'||v_rem.id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/item-'||(v_item->>'id')||'[.]jpg$') then
        raise exception 'Referencia de evidencia invalida';
      end if;
      v_meta:=public._evidencia_meta_v26(v_item->>'foto_url',v_item->>'foto_sha256');
      v_evidencias:=v_evidencias||jsonb_build_array(jsonb_build_object(
        'tipo','foto_item','item_id',v_item->>'id','archivo',v_meta
      ));
    elsif nullif(v_item->>'foto_sha256','') is not null then
      raise exception 'Hash de item sin archivo';
    end if;

    update public.items_remito set
      estado=v_item->>'estado',
      qty_recibida=case when v_item->>'estado'='ok' then qty
        else greatest(0,least(qty,coalesce((v_item->>'qty_recibida')::numeric,0))) end,
      nota=coalesce(v_item->>'nota',''),
      foto_url=nullif(v_item->>'foto_url',''),
      foto_sha256=nullif(v_item->>'foto_sha256','')
    where id=(v_item->>'id')::uuid and remito_id=p_remito_id;
    if not found then raise exception 'Item ajeno al remito'; end if;
  end loop;

  if exists(select 1 from public.items_remito where remito_id=p_remito_id and coalesce(estado,'') not in ('ok','miss')) then
    raise exception 'Quedaron items sin revisar';
  end if;

  v_estado:=case p_conformidad when 'ok' then 'Firmado' when 'disc' then 'Disconforme' else 'Rechazado' end;
  select jsonb_build_object(
    'nombre',e.nombre,'razon_social',e.razon_social,'cuit',e.cuit,
    'domicilio_privacidad',e.domicilio_privacidad,'email_privacidad',e.email_privacidad,
    'politica_retencion',e.politica_retencion
  ) into v_empresa_datos from public.empresas e where e.id=v_rem.empresa_id;

  v_snapshot:=jsonb_build_object(
    'version',4,'tipo','seguimiento_remito_externo','remito_id',v_rem.id,
    'empresa_id',v_rem.empresa_id,'numero',v_rem.num,'empresa',v_empresa_datos,
    'documento_original',v_documento,'cliente',v_rem.cliente,'direccion',v_rem.dir,
    'contacto',v_rem.contacto,'telefono',v_rem.tel,'chofer_id',v_rem.chofer_id,
    'chofer_nombre',v_rem.chofer_nombre,'fecha',v_rem.fecha,'salida_at',v_rem.salida_at,
    'estado',v_estado,'conformidad',p_conformidad,'observacion',coalesce(p_obs,''),
    'receptor',jsonb_build_object('nombre',btrim(p_receptor_nombre),'dni',p_receptor_dni),
    'informacion_receptor_confirmada',p_consent,'politica_version','2026-09-09-v2.7',
    'registrado_en',v_now,'evidencias',v_evidencias,
    'items',(select jsonb_agg(jsonb_build_object(
      'id',i.id,'codigo',i.cod,'descripcion',i.descripcion,'cantidad',i.qty,
      'estado',i.estado,'recibida',i.qty_recibida,'nota',i.nota,
      'foto_ref',i.foto_url,'foto_sha256',i.foto_sha256
    ) order by i.orden) from public.items_remito i where i.remito_id=p_remito_id)
  );

  v_hash:=encode(extensions.digest(convert_to(v_snapshot::text,'UTF8'),'sha256'),'hex');
  update public.remitos set
    estado=v_estado,conformidad=p_conformidad,obs=coalesce(p_obs,''),
    receptor_nombre=btrim(p_receptor_nombre),receptor_dni=p_receptor_dni,
    firma_url=p_firma_url,firma_sha256=nullif(p_firma_sha256,''),
    foto_entrega_url=p_foto_entrega_url,foto_entrega_sha256=nullif(p_foto_entrega_sha256,''),
    ts_firma=v_now,locked_at=v_now,signed_snapshot=v_snapshot,evidence_hash=v_hash
  where id=p_remito_id;

  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  values(p_remito_id,v_rem.empresa_id,auth.uid(),'entrega_cerrada_v27',
    jsonb_build_object('estado',v_estado,'hash',v_hash,'evidencias',jsonb_array_length(v_evidencias),
      'documento_sha256',v_rem.documento_sha256));
  return v_hash;
end
$$;

revoke all on function public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
grant execute on function public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  to authenticated;

create or replace function public.eliminar_remito_pendiente_v27(p_remito_id uuid)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_rem public.remitos%rowtype;
begin
  if auth.uid() is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede eliminar';
  end if;
  select * into v_rem from public.remitos
  where id=p_remito_id and empresa_id=v_empresa and estado='Pendiente'
  for update;
  if v_rem.id is null then raise exception 'El remito no existe o ya fue cerrado'; end if;
  if v_rem.salida_at is not null then raise exception 'Una entrega en camino no se puede eliminar'; end if;

  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  values(v_rem.id,v_empresa,auth.uid(),'pendiente_eliminado_v27',
    jsonb_build_object('numero',v_rem.num,'documento_sha256',v_rem.documento_sha256));
  delete from public.items_remito where remito_id=v_rem.id;
  delete from public.remitos where id=v_rem.id;
  return v_rem.documento_url;
end
$$;

revoke all on function public.eliminar_remito_pendiente_v27(uuid) from public,anon,authenticated;
grant execute on function public.eliminar_remito_pendiente_v27(uuid) to authenticated;

-- Los RPC de escritura v2.6 se bloquean en supabase-finalizar-v2.7.sql,
-- únicamente después de que Vercel confirme el deployment nuevo. Separar
-- ambos pasos evita una ventana en la que la web publicada quede sin backend.

commit;
