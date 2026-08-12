-- GoRemitos v2.2 - migracion de seguridad, consistencia y acceso con Google
-- Ejecutar una sola vez en Supabase > SQL Editor antes de publicar esta version.
-- Supuestos del esquema existente: empresas.id uuid, perfiles.id uuid,
-- remitos.id uuid e items_remito.id uuid.

begin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
declare t text;
begin
  select data_type into t from information_schema.columns where table_schema='public' and table_name='empresas' and column_name='id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: empresas.id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='perfiles' and column_name='id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: perfiles.id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: remitos.id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='items_remito' and column_name='id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: items_remito.id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='perfiles' and column_name='empresa_id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: perfiles.empresa_id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='empresa_id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: remitos.empresa_id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='remitos' and column_name='chofer_id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: remitos.chofer_id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
  select data_type into t from information_schema.columns where table_schema='public' and table_name='items_remito' and column_name='remito_id';
  if t is distinct from 'uuid' then raise exception 'PRECHECK: items_remito.remito_id debe ser uuid y es %',coalesce(t,'inexistente'); end if;
end $$;

alter table public.perfiles
  add column if not exists activo boolean not null default true;

alter table public.empresas
  alter column codigo_invitacion type text using codigo_invitacion::text;

alter table public.remitos
  add column if not exists public_token uuid not null default gen_random_uuid(),
  add column if not exists locked_at timestamptz,
  add column if not exists evidence_hash text,
  add column if not exists signed_snapshot jsonb;

-- Los códigos cortos heredados se rotan una sola vez a 12 caracteres.
update public.empresas
set codigo_invitacion=upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))
where codigo_invitacion is null
   or upper(btrim(codigo_invitacion)) !~ '^[0-9A-F]{12}$';

do $$
begin
  if exists(
    select 1 from public.empresas
    group by upper(btrim(codigo_invitacion)) having count(*)>1
  ) then raise exception 'PRECHECK: hay codigos de invitacion duplicados'; end if;
  if exists(
    select 1 from public.remitos
    where estado<>'Manual' and nullif(btrim(num),'') is not null
    group by empresa_id,lower(btrim(num)) having count(*)>1
  ) then raise exception 'PRECHECK: hay numeros de remito duplicados dentro de una empresa'; end if;
end $$;

create unique index if not exists empresas_codigo_invitacion_uidx
  on public.empresas((upper(btrim(codigo_invitacion))));

create unique index if not exists remitos_empresa_num_operativo_uidx
  on public.remitos(empresa_id,(lower(btrim(num))))
  where estado<>'Manual';

-- La versión anterior guardaba URLs firmadas de un año. Se conserva sólo la
-- ruta privada para que la aplicación emita una URL corta en cada consulta.
update public.remitos
set firma_url=case when firma_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/' then replace(replace(regexp_replace(split_part(firma_url,'?',1),'^https?://[^/]+/storage/v1/object/sign/evidencias/','','i'),'%2F','/'),'%2f','/') else firma_url end,
    foto_entrega_url=case when foto_entrega_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/' then replace(replace(regexp_replace(split_part(foto_entrega_url,'?',1),'^https?://[^/]+/storage/v1/object/sign/evidencias/','','i'),'%2F','/'),'%2f','/') else foto_entrega_url end,
    foto_manual_url=case when foto_manual_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/' then replace(replace(regexp_replace(split_part(foto_manual_url,'?',1),'^https?://[^/]+/storage/v1/object/sign/evidencias/','','i'),'%2F','/'),'%2f','/') else foto_manual_url end
where firma_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/'
   or foto_entrega_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/'
   or foto_manual_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/';

update public.items_remito
set foto_url=replace(replace(regexp_replace(split_part(foto_url,'?',1),'^https?://[^/]+/storage/v1/object/sign/evidencias/','','i'),'%2F','/'),'%2f','/')
where foto_url ~* '^https?://[^/]+/storage/v1/object/sign/evidencias/';

update public.remitos
set locked_at=coalesce(ts_firma,created_at,now())
where estado<>'Pendiente' and locked_at is null;

create unique index if not exists remitos_public_token_uidx
  on public.remitos(public_token);

create index if not exists remitos_empresa_created_idx
  on public.remitos(empresa_id, created_at desc);

create index if not exists remitos_chofer_estado_idx
  on public.remitos(chofer_id, estado);

create table if not exists public.remito_eventos(
  id bigint generated by default as identity primary key,
  remito_id uuid,
  empresa_id uuid not null,
  actor_id uuid,
  evento text not null,
  detalle jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists remito_eventos_remito_idx on public.remito_eventos(remito_id,created_at);
create index if not exists remito_eventos_empresa_idx on public.remito_eventos(empresa_id,created_at desc);

create or replace function public.current_empresa_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select empresa_id from public.perfiles
  where id = auth.uid() and activo = true
  limit 1
$$;

create or replace function public.current_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.perfiles
  where id = auth.uid() and activo = true
  limit 1
$$;

revoke all on function public.current_empresa_id() from public;
revoke all on function public.current_rol() from public;
grant execute on function public.current_empresa_id() to authenticated;
grant execute on function public.current_rol() to authenticated;

-- Completa el alta de cualquier usuario autenticado que todavía no tenga
-- empresa. Sirve tanto para Google OAuth como para email y contraseña.
create or replace function public.completar_onboarding_interactivo(
  p_tipo text,
  p_nombre text,
  p_empresa_nombre text default null,
  p_empresa_cuit text default null,
  p_codigo text default null
)
returns uuid
language plpgsql
security definer
set search_path = extensions, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_tipo text := lower(trim(coalesce(p_tipo,'')));
  v_nombre text := trim(coalesce(p_nombre,''));
  v_empresa_id uuid;
  v_codigo text;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;

  -- Serializa dos intentos simultáneos y vuelve idempotente el alta.
  perform 1 from auth.users where id = v_uid for update;
  if not found then raise exception 'Usuario autenticado invalido'; end if;
  select empresa_id into v_empresa_id from public.perfiles where id = v_uid;
  if v_empresa_id is not null then return v_empresa_id; end if;
  if length(v_nombre) < 2 or length(v_nombre)>100 then raise exception 'Nombre de usuario invalido'; end if;

  if v_tipo = 'empresa' then
    if length(trim(coalesce(p_empresa_nombre,''))) < 2
       or length(trim(coalesce(p_empresa_nombre,''))) > 120
       or length(trim(coalesce(p_empresa_cuit,''))) > 20 then
      raise exception 'Nombre de empresa invalido';
    end if;
    loop
      v_codigo := upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
      exit when not exists(select 1 from public.empresas where upper(btrim(codigo_invitacion)) = v_codigo);
    end loop;
    insert into public.empresas(nombre,cuit,codigo_invitacion)
      values(trim(p_empresa_nombre),nullif(trim(p_empresa_cuit),''),v_codigo)
      returning id into v_empresa_id;
    insert into public.perfiles(id,nombre,rol,empresa_id,activo)
      values(v_uid,v_nombre,'admin',v_empresa_id,true)
      on conflict(id) do update set nombre=excluded.nombre,rol=excluded.rol,empresa_id=excluded.empresa_id,activo=true
      where public.perfiles.empresa_id is null;
  elsif v_tipo = 'unirse' then
    v_codigo := upper(trim(coalesce(p_codigo,'')));
    if v_codigo !~ '^[0-9A-F]{12}$' then raise exception 'Codigo de invitacion invalido'; end if;
    select id into v_empresa_id from public.empresas where upper(btrim(codigo_invitacion))=v_codigo;
    if v_empresa_id is null then raise exception 'Codigo de invitacion invalido'; end if;
    insert into public.perfiles(id,nombre,rol,empresa_id,activo)
      values(v_uid,v_nombre,'chofer',v_empresa_id,true)
      on conflict(id) do update set nombre=excluded.nombre,rol=excluded.rol,empresa_id=excluded.empresa_id,activo=true
      where public.perfiles.empresa_id is null;
  else
    raise exception 'Elegí crear una empresa o unirte a una existente';
  end if;
  return v_empresa_id;
end
$$;

revoke all on function public.completar_onboarding_interactivo(text,text,text,text,text) from public;
grant execute on function public.completar_onboarding_interactivo(text,text,text,text,text) to authenticated;

-- Mantiene compatibilidad con el alta por email: signUp guarda estos datos en
-- raw_user_meta_data y, al confirmar, este wrapper usa el mismo flujo seguro.
create or replace function public.completar_onboarding()
returns uuid
language plpgsql
security definer
set search_path = extensions, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_meta jsonb;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;
  select raw_user_meta_data into v_meta from auth.users where id = v_uid;
  if nullif(v_meta->>'onboarding_tipo','') is null then
    raise exception 'No hay una solicitud de registro pendiente';
  end if;
  return public.completar_onboarding_interactivo(
    v_meta->>'onboarding_tipo',
    v_meta->>'nombre',
    v_meta->>'empresa_nombre',
    v_meta->>'empresa_cuit',
    v_meta->>'codigo_invitacion'
  );
end
$$;

revoke all on function public.completar_onboarding() from public;
grant execute on function public.completar_onboarding() to authenticated;

-- Desactiva los RPC de alta de la versión anterior, si todavía existen.
do $$
declare f record;
begin
  for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) as args
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname in ('crear_empresa','unirse_empresa')
  loop
    execute format('revoke all on function %I.%I(%s) from public, anon, authenticated',f.nspname,f.proname,f.args);
  end loop;
end $$;

create or replace function public.guardar_remito(
  p_remito_id uuid,
  p_num text,
  p_cliente text,
  p_dir text,
  p_contacto text,
  p_tel text,
  p_chofer_id uuid,
  p_fecha date,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empresa uuid := public.current_empresa_id();
  v_rol text := public.current_rol();
  v_chofer_nombre text;
  v_id uuid;
  v_count integer;
begin
  if v_empresa is null or v_rol not in ('admin','oficina') then raise exception 'Sin permiso para guardar remitos'; end if;
  if p_fecha is null or length(trim(coalesce(p_num,''))) not between 1 and 50 or length(trim(coalesce(p_cliente,''))) not between 1 and 160 or length(trim(coalesce(p_dir,''))) not between 1 and 250 or length(coalesce(p_contacto,''))>100 or length(coalesce(p_tel,''))>30 then raise exception 'Datos obligatorios invalidos'; end if;
  select nombre into v_chofer_nombre from public.perfiles where id=p_chofer_id and empresa_id=v_empresa and rol='chofer' and activo=true;
  if v_chofer_nombre is null then raise exception 'Chofer invalido o inactivo'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'El detalle de items debe ser una lista'; end if;
  if jsonb_array_length(p_items) not between 1 and 500 then raise exception 'Debe incluir entre 1 y 500 items'; end if;
  select count(*) into v_count from jsonb_to_recordset(p_items) as x(cod text,descripcion text,qty numeric,orden integer) where length(trim(coalesce(descripcion,''))) not between 1 and 300 or length(coalesce(cod,''))>50 or qty is null or qty<=0 or qty>99999999;
  if v_count>0 then raise exception 'Hay items invalidos'; end if;
  if exists(select 1 from public.remitos where empresa_id=v_empresa and estado<>'Manual' and lower(btrim(num))=lower(btrim(p_num)) and (p_remito_id is null or id<>p_remito_id)) then raise exception 'Ya existe un remito con ese numero'; end if;

  if p_remito_id is null then
    insert into public.remitos(empresa_id,num,cliente,dir,contacto,tel,chofer_nombre,chofer_id,fecha,estado,created_by)
      values(v_empresa,trim(p_num),trim(p_cliente),trim(p_dir),nullif(trim(p_contacto),''),nullif(trim(p_tel),''),v_chofer_nombre,p_chofer_id,p_fecha,'Pendiente',auth.uid())
      returning id into v_id;
  else
    select id into v_id from public.remitos where id=p_remito_id and empresa_id=v_empresa and estado='Pendiente' for update;
    if v_id is null then raise exception 'El remito no existe o ya fue cerrado'; end if;
    update public.remitos set num=trim(p_num),cliente=trim(p_cliente),dir=trim(p_dir),contacto=nullif(trim(p_contacto),''),tel=nullif(trim(p_tel),''),chofer_nombre=v_chofer_nombre,chofer_id=p_chofer_id,fecha=p_fecha where id=v_id;
    delete from public.items_remito where remito_id=v_id;
  end if;

  insert into public.items_remito(remito_id,cod,descripcion,qty,orden)
    select v_id,coalesce(cod,''),trim(descripcion),qty,coalesce(orden,0)
    from jsonb_to_recordset(p_items) as x(cod text,descripcion text,qty numeric,orden integer);
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    values(v_id,v_empresa,auth.uid(),case when p_remito_id is null then 'creado' else 'editado' end,jsonb_build_object('numero',trim(p_num),'chofer_id',p_chofer_id));
  return v_id;
end
$$;

revoke all on function public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb) from public;
grant execute on function public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb) to authenticated;

create or replace function public.confirmar_entrega(
  p_remito_id uuid,
  p_conformidad text,
  p_obs text,
  p_receptor_nombre text,
  p_receptor_dni text,
  p_firma_url text,
  p_foto_entrega_url text,
  p_consent boolean,
  p_items jsonb
)
returns text
language plpgsql
security definer
set search_path = extensions, public
as $$
declare
  v_rem public.remitos%rowtype;
  v_now timestamptz := now();
  v_estado text;
  v_snapshot jsonb;
  v_hash text;
  v_item jsonb;
  v_db_count integer;
  v_distinct_count integer;
  v_empresa_datos jsonb;
begin
  if coalesce(public.current_rol(),'')<>'chofer' then raise exception 'Solo el chofer asignado puede confirmar'; end if;
  select * into v_rem from public.remitos where id=p_remito_id and empresa_id=public.current_empresa_id() and chofer_id=auth.uid() and estado='Pendiente' for update;
  if v_rem.id is null then raise exception 'Entrega no disponible'; end if;
  if coalesce(p_conformidad,'') not in ('ok','disc','rech') then raise exception 'Conformidad invalida'; end if;
  if length(trim(coalesce(p_receptor_nombre,''))) not between 2 and 100 or coalesce(p_receptor_dni,'') !~ '^[0-9]{7,8}$' or length(coalesce(p_obs,''))>1000 then raise exception 'Datos del receptor invalidos'; end if;
  if p_consent is not true then raise exception 'Falta la constancia de informacion al receptor'; end if;
  if p_conformidad<>'rech' and p_firma_url is null then raise exception 'Falta la firma'; end if;
  if p_conformidad='rech' and p_firma_url is not null then raise exception 'Una entrega rechazada no debe incluir firma de conformidad'; end if;
  if p_conformidad='rech' and length(trim(coalesce(p_obs,'')))<3 then raise exception 'Falta el motivo del rechazo'; end if;
  if p_firma_url is not null and (length(p_firma_url)>600 or strpos(p_firma_url,v_rem.empresa_id::text||'/'||v_rem.id::text||'/')<>1) then raise exception 'Referencia de firma invalida'; end if;
  if p_foto_entrega_url is not null and (length(p_foto_entrega_url)>600 or strpos(p_foto_entrega_url,v_rem.empresa_id::text||'/'||v_rem.id::text||'/')<>1) then raise exception 'Referencia de foto invalida'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Detalle de items invalido'; end if;
  select count(*) into v_db_count from public.items_remito where remito_id=p_remito_id;
  if jsonb_array_length(p_items)<>v_db_count then raise exception 'Deben revisarse todos los items'; end if;
  select count(distinct value->>'id') into v_distinct_count from jsonb_array_elements(p_items);
  if v_distinct_count<>v_db_count then raise exception 'El detalle contiene items repetidos o faltantes'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if coalesce(v_item->>'estado','') not in ('ok','miss') then raise exception 'Estado de item invalido'; end if;
    if length(coalesce(v_item->>'nota',''))>500 then raise exception 'Observacion de item demasiado extensa'; end if;
    if nullif(v_item->>'foto_url','') is not null and (length(v_item->>'foto_url')>600 or strpos(v_item->>'foto_url',v_rem.empresa_id::text||'/'||v_rem.id::text||'/')<>1) then raise exception 'Referencia de evidencia invalida'; end if;
    update public.items_remito
      set estado=v_item->>'estado',
          qty_recibida=case when v_item->>'estado'='ok' then qty else greatest(0,least(qty,coalesce((v_item->>'qty_recibida')::numeric,0))) end,
          nota=coalesce(v_item->>'nota',''),
          foto_url=nullif(v_item->>'foto_url','')
      where id=(v_item->>'id')::uuid and remito_id=p_remito_id;
    if not found then raise exception 'Item ajeno al remito'; end if;
  end loop;
  if exists(select 1 from public.items_remito where remito_id=p_remito_id and coalesce(estado,'') not in ('ok','miss')) then raise exception 'Quedaron items sin revisar'; end if;

  v_estado := case p_conformidad when 'ok' then 'Firmado' when 'disc' then 'Disconforme' else 'Rechazado' end;
  select jsonb_build_object('nombre',e.nombre,'cuit',e.cuit) into v_empresa_datos from public.empresas e where e.id=v_rem.empresa_id;
  v_snapshot := jsonb_build_object(
    'version',2,'remito_id',v_rem.id,'empresa_id',v_rem.empresa_id,'numero',v_rem.num,
    'empresa',v_empresa_datos,
    'cliente',v_rem.cliente,'direccion',v_rem.dir,'contacto',v_rem.contacto,'telefono',v_rem.tel,
    'chofer_id',v_rem.chofer_id,'chofer_nombre',v_rem.chofer_nombre,'fecha',v_rem.fecha,
    'estado',v_estado,'conformidad',p_conformidad,'observacion',coalesce(p_obs,''),
    'receptor',jsonb_build_object('nombre',trim(p_receptor_nombre),'dni',p_receptor_dni),
    'firma_ref',p_firma_url,'foto_entrega_ref',p_foto_entrega_url,'consentimiento_informado',p_consent,'politica_version','2026-07-16-v2.1','registrado_en',v_now,
    'items',(select jsonb_agg(jsonb_build_object('id',i.id,'codigo',i.cod,'descripcion',i.descripcion,'cantidad',i.qty,'estado',i.estado,'recibida',i.qty_recibida,'nota',i.nota,'foto_ref',i.foto_url) order by i.orden) from public.items_remito i where i.remito_id=p_remito_id)
  );
  v_hash := encode(digest(convert_to(v_snapshot::text,'UTF8'),'sha256'),'hex');
  update public.remitos set estado=v_estado,conformidad=p_conformidad,obs=coalesce(p_obs,''),receptor_nombre=trim(p_receptor_nombre),receptor_dni=p_receptor_dni,firma_url=p_firma_url,foto_entrega_url=p_foto_entrega_url,ts_firma=v_now,locked_at=v_now,signed_snapshot=v_snapshot,evidence_hash=v_hash where id=p_remito_id;
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    values(p_remito_id,v_rem.empresa_id,auth.uid(),'entrega_cerrada',jsonb_build_object('estado',v_estado,'hash',v_hash));
  return v_hash;
end
$$;

revoke all on function public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb) from public;
grant execute on function public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb) to authenticated;

create or replace function public.guardar_remito_manual(p_num text,p_fecha date,p_nota text,p_foto_url text)
returns uuid
language plpgsql
security definer
set search_path = extensions, public
as $$
declare v_id uuid; v_now timestamptz:=now(); v_snapshot jsonb; v_hash text; v_empresa uuid:=public.current_empresa_id(); v_empresa_datos jsonb;
begin
  if coalesce(public.current_rol(),'')<>'chofer' or v_empresa is null or p_foto_url is null then raise exception 'Operacion no permitida'; end if;
  if p_fecha is null or length(coalesce(p_num,''))>50 or length(coalesce(p_nota,''))>500 then raise exception 'Datos invalidos o demasiado extensos'; end if;
  if length(p_foto_url)>600 or strpos(p_foto_url,v_empresa::text||'/manual/')<>1 then raise exception 'Referencia de foto invalida'; end if;
  insert into public.remitos(empresa_id,num,cliente,dir,fecha,estado,chofer_nombre,chofer_id,nota,foto_manual_url,created_by)
    values(v_empresa,coalesce(nullif(trim(p_num),''),'—'),'Remito manual','—',p_fecha,'Manual',(select nombre from public.perfiles where id=auth.uid()),auth.uid(),coalesce(p_nota,''),p_foto_url,auth.uid())
    returning id into v_id;
  select jsonb_build_object('nombre',e.nombre,'cuit',e.cuit) into v_empresa_datos from public.empresas e where e.id=v_empresa;
  v_snapshot:=jsonb_build_object('version',2,'tipo','manual','remito_id',v_id,'empresa_id',v_empresa,'empresa',v_empresa_datos,'numero',p_num,'fecha',p_fecha,'chofer_id',auth.uid(),'nota',coalesce(p_nota,''),'foto_ref',p_foto_url,'registrado_en',v_now);
  v_hash:=encode(digest(convert_to(v_snapshot::text,'UTF8'),'sha256'),'hex');
  update public.remitos set signed_snapshot=v_snapshot,evidence_hash=v_hash,locked_at=v_now where id=v_id;
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    values(v_id,v_empresa,auth.uid(),'manual_cargado',jsonb_build_object('hash',v_hash));
  return v_id;
end
$$;

revoke all on function public.guardar_remito_manual(text,date,text,text) from public;
grant execute on function public.guardar_remito_manual(text,date,text,text) to authenticated;

create or replace function public.eliminar_remito_pendiente(p_remito_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.current_rol(),'')<>'admin' then raise exception 'Solo un administrador puede eliminar'; end if;
  if not exists(select 1 from public.remitos where id=p_remito_id and empresa_id=public.current_empresa_id() and estado='Pendiente') then raise exception 'El remito no existe o ya fue cerrado'; end if;
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento)
    values(p_remito_id,public.current_empresa_id(),auth.uid(),'pendiente_eliminado');
  delete from public.items_remito where remito_id=p_remito_id;
  delete from public.remitos where id=p_remito_id;
end $$;
revoke all on function public.eliminar_remito_pendiente(uuid) from public;
grant execute on function public.eliminar_remito_pendiente(uuid) to authenticated;

create or replace function public.administrar_usuario(p_usuario_id uuid,p_rol text,p_activo boolean)
returns void language plpgsql security definer set search_path=public as $$
declare v_empresa uuid:=public.current_empresa_id();
begin
  if coalesce(public.current_rol(),'')<>'admin' then raise exception 'Solo un administrador puede gestionar usuarios'; end if;
  if p_usuario_id=auth.uid() then raise exception 'No podes modificar tu propio acceso'; end if;
  if not exists(select 1 from public.perfiles where id=p_usuario_id and empresa_id=v_empresa) then raise exception 'Usuario no encontrado'; end if;
  if p_rol is not null and p_rol not in ('admin','oficina','chofer') then raise exception 'Rol invalido'; end if;
  update public.perfiles set rol=coalesce(p_rol,rol),activo=coalesce(p_activo,activo) where id=p_usuario_id and empresa_id=v_empresa;
end $$;
revoke all on function public.administrar_usuario(uuid,text,boolean) from public;
grant execute on function public.administrar_usuario(uuid,text,boolean) to authenticated;

create or replace function public.rotar_codigo_invitacion()
returns text language plpgsql security definer set search_path=extensions,public as $$
declare v_codigo text;
begin
  if coalesce(public.current_rol(),'')<>'admin' then raise exception 'Solo un administrador puede rotar el codigo'; end if;
  loop v_codigo:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)); exit when not exists(select 1 from public.empresas where upper(btrim(codigo_invitacion))=v_codigo); end loop;
  update public.empresas set codigo_invitacion=v_codigo where id=public.current_empresa_id();
  return v_codigo;
end $$;
revoke all on function public.rotar_codigo_invitacion() from public;
grant execute on function public.rotar_codigo_invitacion() to authenticated;

create or replace function public.obtener_codigo_invitacion()
returns text language plpgsql stable security definer set search_path=public as $$
declare v_codigo text;
begin
  if coalesce(public.current_rol(),'')<>'admin' then raise exception 'Solo un administrador puede ver el codigo'; end if;
  select codigo_invitacion into v_codigo from public.empresas where id=public.current_empresa_id();
  return v_codigo;
end $$;
revoke all on function public.obtener_codigo_invitacion() from public;
grant execute on function public.obtener_codigo_invitacion() to authenticated;

-- Inmutabilidad: una constancia cerrada no admite cambios ni borrado.
create or replace function public.proteger_remito_cerrado()
returns trigger language plpgsql set search_path=public as $$
begin
  if old.locked_at is not null then raise exception 'La constancia esta cerrada y no se puede modificar'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists trg_proteger_remito_cerrado on public.remitos;
create trigger trg_proteger_remito_cerrado before update or delete on public.remitos for each row execute function public.proteger_remito_cerrado();

create or replace function public.proteger_items_cerrados()
returns trigger language plpgsql set search_path=public as $$
declare v_remito uuid;
begin
  if tg_op='DELETE' then v_remito:=old.remito_id; else v_remito:=new.remito_id; end if;
  if exists(select 1 from public.remitos where id=v_remito and locked_at is not null) then raise exception 'Los items de una constancia cerrada no se pueden modificar'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists trg_proteger_items_cerrados on public.items_remito;
create trigger trg_proteger_items_cerrados before insert or update or delete on public.items_remito for each row execute function public.proteger_items_cerrados();

-- RLS y privilegios. Toda escritura operativa se hace mediante las funciones anteriores.
alter table public.empresas enable row level security;
alter table public.perfiles enable row level security;
alter table public.remitos enable row level security;
alter table public.items_remito enable row level security;
alter table public.remito_eventos enable row level security;

-- Elimina políticas anteriores de estas cuatro tablas para evitar que una
-- política permisiva vieja anule el aislamiento de v2.
do $$
declare p record;
begin
  for p in select schemaname,tablename,policyname from pg_policies
           where schemaname='public' and tablename in ('empresas','perfiles','remitos','items_remito','remito_eventos')
  loop
    execute format('drop policy if exists %I on %I.%I',p.policyname,p.schemaname,p.tablename);
  end loop;
end $$;

drop policy if exists empresas_misma_empresa on public.empresas;
create policy empresas_misma_empresa on public.empresas for select to authenticated using(id=public.current_empresa_id());

drop policy if exists perfiles_misma_empresa on public.perfiles;
create policy perfiles_misma_empresa on public.perfiles for select to authenticated using(
  empresa_id=public.current_empresa_id() and (public.current_rol() in ('admin','oficina') or id=auth.uid())
);

drop policy if exists remitos_lectura_por_rol on public.remitos;
create policy remitos_lectura_por_rol on public.remitos for select to authenticated using(
  empresa_id=public.current_empresa_id() and (public.current_rol() in ('admin','oficina') or chofer_id=auth.uid())
);

drop policy if exists items_lectura_por_remito on public.items_remito;
create policy items_lectura_por_remito on public.items_remito for select to authenticated using(
  exists(select 1 from public.remitos r where r.id=remito_id and r.empresa_id=public.current_empresa_id() and (public.current_rol() in ('admin','oficina') or r.chofer_id=auth.uid()))
);

drop policy if exists eventos_lectura_empresa on public.remito_eventos;
create policy eventos_lectura_empresa on public.remito_eventos for select to authenticated using(
  empresa_id=public.current_empresa_id() and public.current_rol() in ('admin','oficina')
);

revoke insert,update,delete on public.empresas from public,authenticated,anon;
revoke insert,update,delete on public.perfiles from public,authenticated,anon;
revoke insert,update,delete on public.remitos from public,authenticated,anon;
revoke insert,update,delete on public.items_remito from public,authenticated,anon;
revoke insert,update,delete on public.remito_eventos from public,authenticated,anon;
revoke select on public.empresas from public,authenticated,anon;
revoke select(codigo_invitacion) on public.empresas from public,authenticated,anon;
grant select(id,nombre,cuit) on public.empresas to authenticated;
grant select on public.perfiles,public.remitos,public.items_remito,public.remito_eventos to authenticated;

-- Storage privado: solo usuarios activos de la empresa pueden subir o leer
-- dentro de la carpeta cuyo primer segmento es empresa_id.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('evidencias','evidencias',false,15728640,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists evidencias_empresa_select on storage.objects;
create policy evidencias_empresa_select on storage.objects for select to authenticated using(
  bucket_id='evidencias'
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and (
    public.current_rol() in ('admin','oficina')
    or (
      public.current_rol()='chofer'
      and exists(
        select 1 from public.remitos r
        where r.empresa_id=public.current_empresa_id()
          and r.chofer_id=auth.uid()
          and (
            r.id=case when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then ((storage.foldername(name))[2])::uuid end
            or r.foto_manual_url=name
          )
      )
    )
  )
);
drop policy if exists evidencias_empresa_insert on storage.objects;
create policy evidencias_empresa_insert on storage.objects for insert to authenticated with check(
  bucket_id='evidencias'
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and public.current_rol()='chofer'
  and (
    (storage.foldername(name))[2]='manual'
    or exists(
      select 1 from public.remitos r
      where r.empresa_id=public.current_empresa_id()
        and r.chofer_id=auth.uid()
        and r.estado='Pendiente'
        and r.id=case when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then ((storage.foldername(name))[2])::uuid end
    )
  )
);

-- Habilita cambios en tiempo real sin duplicar la entrada si ya existe.
do $$ begin
  alter publication supabase_realtime add table public.remitos;
exception when duplicate_object then null;
end $$;

commit;
