-- GoRemitos v2.6 - estabilizacion para piloto controlado
-- Requiere v2.5.2. Ejecutar completo en Supabase > SQL Editor.
-- No elimina empresas, usuarios, remitos ni evidencias existentes.

begin;

do $$
declare
  v_admins integer;
begin
  if to_regprocedure('public.actualizar_mi_nombre(text)') is null
     or to_regprocedure('public.listar_accesos_empresa()') is null then
    raise exception 'PRECHECK v2.6: primero ejecuta las migraciones v2.5 y v2.5.2';
  end if;

  select count(*) into v_admins
  from public.perfiles
  where activo=true and rol='admin';

  if v_admins<1 then
    raise exception 'PRECHECK v2.6: no existe ningun administrador activo';
  end if;
end
$$;

-- Datos legales y de contacto de cada empresa. Se muestran en privacidad y PDF.
alter table public.empresas
  add column if not exists razon_social text,
  add column if not exists domicilio_privacidad text,
  add column if not exists email_privacidad text,
  add column if not exists telefono_privacidad text,
  add column if not exists politica_retencion text,
  add column if not exists updated_at timestamptz not null default now();

do $$ begin
  alter table public.empresas add constraint empresas_razon_social_v26_ck
    check(razon_social is null or length(btrim(razon_social)) between 2 and 160);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.empresas add constraint empresas_domicilio_privacidad_v26_ck
    check(domicilio_privacidad is null or length(btrim(domicilio_privacidad)) between 5 and 250);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.empresas add constraint empresas_email_privacidad_v26_ck
    check(email_privacidad is null or (
      length(email_privacidad) between 5 and 254
      and email_privacidad=lower(btrim(email_privacidad))
      and email_privacidad ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.empresas add constraint empresas_politica_retencion_v26_ck
    check(politica_retencion is null or length(btrim(politica_retencion)) between 10 and 500);
exception when duplicate_object then null; end $$;

-- Hashes de los bytes calculados antes de subir cada evidencia.
alter table public.remitos
  add column if not exists firma_sha256 text,
  add column if not exists foto_entrega_sha256 text,
  add column if not exists foto_manual_sha256 text;

alter table public.items_remito
  add column if not exists foto_sha256 text;

do $$ begin
  alter table public.remitos add constraint remitos_firma_sha256_v26_ck
    check(firma_sha256 is null or firma_sha256 ~ '^[0-9a-f]{64}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_foto_entrega_sha256_v26_ck
    check(foto_entrega_sha256 is null or foto_entrega_sha256 ~ '^[0-9a-f]{64}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.remitos add constraint remitos_foto_manual_sha256_v26_ck
    check(foto_manual_sha256 is null or foto_manual_sha256 ~ '^[0-9a-f]{64}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.items_remito add constraint items_foto_sha256_v26_ck
    check(foto_sha256 is null or foto_sha256 ~ '^[0-9a-f]{64}$');
exception when duplicate_object then null; end $$;

-- Defensa de costo y abuso: el navegador reduce las fotos a 1600 px antes de
-- subirlas. El bucket rechaza archivos mayores aunque alguien saltee la UI.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('evidencias','evidencias',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

-- Configuracion central. El registro por contraseña nace cerrado y sólo se
-- habilita después de comprobar Confirm Email y SMTP desde la aplicación.
create table if not exists public.configuracion_plataforma(
  id boolean primary key default true check(id=true),
  registro_email_habilitado boolean not null default false,
  responsable_nombre text,
  responsable_cuit text,
  responsable_domicilio text,
  privacidad_email text,
  soporte_email text,
  captcha_site_key text,
  plan_pro_verificado boolean not null default false,
  smtp_verificado boolean not null default false,
  backup_db_verificado boolean not null default false,
  backup_storage_verificado boolean not null default false,
  oauth_produccion_verificado boolean not null default false,
  captcha_verificado boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

insert into public.configuracion_plataforma(id,registro_email_habilitado)
values(true,false)
on conflict(id) do nothing;

alter table public.configuracion_plataforma
  add column if not exists plan_pro_verificado boolean not null default false,
  add column if not exists smtp_verificado boolean not null default false,
  add column if not exists backup_db_verificado boolean not null default false,
  add column if not exists backup_storage_verificado boolean not null default false,
  add column if not exists oauth_produccion_verificado boolean not null default false,
  add column if not exists captcha_verificado boolean not null default false,
  add column if not exists captcha_site_key text;

do $$ begin
  alter table public.configuracion_plataforma add constraint configuracion_captcha_site_key_v26_ck
    check(captcha_site_key is null or length(btrim(captcha_site_key)) between 10 and 200);
exception when duplicate_object then null; end $$;

create table if not exists public.plataforma_admins(
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

-- En esta instalación existente, el administrador más antiguo queda como
-- responsable inicial de plataforma. Sólo ocurre si la tabla todavía está vacía.
insert into public.plataforma_admins(user_id,created_by)
select p.id,p.id
from public.perfiles p
join auth.users u on u.id=p.id
where p.activo=true and p.rol='admin'
  and not exists(select 1 from public.plataforma_admins)
order by u.created_at,p.id
limit 1
on conflict(user_id) do nothing;

create table if not exists public.autorizaciones_empresa(
  id uuid primary key default gen_random_uuid(),
  email text not null,
  admin_nombre text,
  empresa_nombre text not null,
  empresa_cuit text,
  activa boolean not null default true,
  creada_por uuid not null references auth.users(id) on delete restrict,
  usuario_id uuid references auth.users(id) on delete set null,
  empresa_id uuid references public.empresas(id) on delete set null,
  created_at timestamptz not null default now(),
  aceptada_at timestamptz,
  revocada_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint autorizaciones_empresa_email_normalizado_ck check(email=lower(btrim(email))),
  constraint autorizaciones_empresa_email_formato_ck check(
    length(email) between 5 and 254
    and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  constraint autorizaciones_empresa_nombre_ck check(length(btrim(empresa_nombre)) between 2 and 120),
  constraint autorizaciones_empresa_admin_ck check(admin_nombre is null or length(btrim(admin_nombre)) between 2 and 100),
  constraint autorizaciones_empresa_estado_ck check(
    (activa=true and revocada_at is null)
    or (activa=false and revocada_at is not null)
  )
);

create unique index if not exists autorizaciones_empresa_email_activa_uidx
  on public.autorizaciones_empresa(email) where activa=true;
create index if not exists autorizaciones_empresa_created_idx
  on public.autorizaciones_empresa(created_at desc);

create table if not exists public.client_error_events(
  id bigint generated by default as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  empresa_id uuid references public.empresas(id) on delete set null,
  app_version text not null,
  contexto text not null,
  mensaje text not null,
  stack text,
  url_path text,
  user_agent text,
  created_at timestamptz not null default now()
);
create index if not exists client_error_events_created_idx on public.client_error_events(created_at desc);
create index if not exists client_error_events_empresa_idx on public.client_error_events(empresa_id,created_at desc);
create index if not exists client_error_events_user_idx on public.client_error_events(user_id,created_at desc);

alter table public.configuracion_plataforma enable row level security;
alter table public.plataforma_admins enable row level security;
alter table public.autorizaciones_empresa enable row level security;
alter table public.client_error_events enable row level security;

revoke all on public.configuracion_plataforma from public,anon,authenticated;
revoke all on public.plataforma_admins from public,anon,authenticated;
revoke all on public.autorizaciones_empresa from public,anon,authenticated;
revoke all on public.client_error_events from public,anon,authenticated;

create or replace function public.es_admin_plataforma()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select auth.uid() is not null and exists(
    select 1 from public.plataforma_admins p where p.user_id=auth.uid()
  )
$$;

revoke all on function public.es_admin_plataforma() from public,anon,authenticated;
grant execute on function public.es_admin_plataforma() to authenticated;

create or replace function public._plataforma_lista_v26()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    c.plan_pro_verificado
    and c.smtp_verificado
    and c.backup_db_verificado
    and c.backup_storage_verificado
    and c.oauth_produccion_verificado
    and c.captcha_verificado
    and length(btrim(coalesce(c.captcha_site_key,''))) between 10 and 200
    and length(btrim(coalesce(c.responsable_nombre,'')))>=2
    and length(btrim(coalesce(c.responsable_domicilio,'')))>=5
    and coalesce(c.privacidad_email,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    and coalesce(c.soporte_email,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$',
    false
  )
  from public.configuracion_plataforma c
  where c.id=true
$$;

revoke all on function public._plataforma_lista_v26() from public,anon,authenticated;

create or replace function public._empresa_lista_v26(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    length(btrim(coalesce(e.razon_social,'')))>=2
    and regexp_replace(coalesce(e.cuit,''),'[^0-9]','','g') ~ '^[0-9]{11}$'
    and length(btrim(coalesce(e.domicilio_privacidad,'')))>=5
    and coalesce(e.email_privacidad,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    and length(btrim(coalesce(e.politica_retencion,'')))>=10,
    false
  )
  from public.empresas e
  where e.id=p_empresa
$$;

revoke all on function public._empresa_lista_v26(uuid) from public,anon,authenticated;

drop function if exists public.obtener_configuracion_publica();
create function public.obtener_configuracion_publica()
returns table(
  responsable_nombre text,
  responsable_cuit text,
  responsable_domicilio text,
  privacidad_email text,
  soporte_email text,
  captcha_site_key text
)
language sql
stable
security definer
set search_path=''
as $$
  select c.responsable_nombre,c.responsable_cuit,c.responsable_domicilio,
         c.privacidad_email,c.soporte_email,c.captcha_site_key
  from public.configuracion_plataforma c
  where c.id=true
$$;

revoke all on function public.obtener_configuracion_publica() from public,anon,authenticated;
grant execute on function public.obtener_configuracion_publica() to anon,authenticated;

create or replace function public.obtener_estado_registro()
returns table(registro_email_habilitado boolean)
language sql
stable
security definer
set search_path=''
as $$
  select c.registro_email_habilitado
  from public.configuracion_plataforma c
  where c.id=true
$$;

revoke all on function public.obtener_estado_registro() from public,anon,authenticated;
grant execute on function public.obtener_estado_registro() to anon,authenticated;

create or replace function public.obtener_estado_operativo_v26()
returns table(
  plan_pro_verificado boolean,
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
  select c.plan_pro_verificado,c.smtp_verificado,c.backup_db_verificado,
         c.backup_storage_verificado,c.oauth_produccion_verificado,
         c.captcha_verificado,public._plataforma_lista_v26()
  from public.configuracion_plataforma c
  where c.id=true;
end
$$;

revoke all on function public.obtener_estado_operativo_v26() from public,anon,authenticated;
grant execute on function public.obtener_estado_operativo_v26() to authenticated;

-- Cambiar el tipo de retorno exige eliminar y recrear la función.
drop function public.obtener_mi_acceso();
create function public.obtener_mi_acceso()
returns table(
  usuario_id uuid,
  nombre text,
  email text,
  rol text,
  empresa_id uuid,
  empresa_nombre text,
  empresa_cuit text,
  empresa_razon_social text,
  empresa_domicilio_privacidad text,
  empresa_email_privacidad text,
  empresa_telefono_privacidad text,
  empresa_politica_retencion text,
  activo boolean,
  admin_plataforma boolean,
  registro_email_habilitado boolean,
  plataforma_lista_piloto boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesion requerida'; end if;
  return query
  select p.id,p.nombre,coalesce(p.email,lower(btrim(u.email))),p.rol,p.empresa_id,
         e.nombre,e.cuit,e.razon_social,e.domicilio_privacidad,e.email_privacidad,
         e.telefono_privacidad,e.politica_retencion,p.activo,
         exists(select 1 from public.plataforma_admins pa where pa.user_id=p.id),
         coalesce((select c.registro_email_habilitado from public.configuracion_plataforma c where c.id=true),false),
         public._plataforma_lista_v26()
  from public.perfiles p
  join public.empresas e on e.id=p.empresa_id
  left join auth.users u on u.id=p.id
  where p.id=auth.uid()
  limit 1;
end
$$;

revoke all on function public.obtener_mi_acceso() from public,anon,authenticated;
grant execute on function public.obtener_mi_acceso() to authenticated;

-- Onboarding cerrado: primero busca una autorización dentro de una empresa;
-- después, una autorización de alta de empresa emitida por la plataforma.
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
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_email text;
  v_email_confirmado timestamptz;
  v_nombre text:=btrim(coalesce(p_nombre,''));
  v_empresa_id uuid;
  v_codigo text;
  v_aut public.autorizaciones_acceso%rowtype;
  v_alta public.autorizaciones_empresa%rowtype;
  v_tiene_google boolean:=false;
  v_email_habilitado boolean:=false;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;

  select lower(btrim(u.email)),u.email_confirmed_at,
         exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google')
    into v_email,v_email_confirmado,v_tiene_google
  from auth.users u
  where u.id=v_uid
  for update;

  if not found or v_email is null then raise exception 'Usuario autenticado invalido'; end if;
  if v_email_confirmado is null then raise exception 'Confirma tu email antes de continuar'; end if;

  select c.registro_email_habilitado into v_email_habilitado
  from public.configuracion_plataforma c where c.id=true;

  -- Los perfiles ya existentes pueden seguir entrando. La compuerta se aplica
  -- solamente a la toma de una autorización nueva.
  select p.empresa_id into v_empresa_id
  from public.perfiles p
  where p.id=v_uid and p.activo=true
  for update;
  if found then return v_empresa_id; end if;

  if not v_tiene_google and not coalesce(v_email_habilitado,false) then
    raise exception 'El alta con contraseña está temporalmente deshabilitada. Ingresá con Google o esperá la confirmación del administrador';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_email,0));

  select a.* into v_aut
  from public.autorizaciones_acceso a
  where a.activa=true and a.email=v_email
  for update;

  if found then
    if length(v_nombre)<2 then v_nombre:=coalesce(v_aut.nombre,''); end if;
    if length(v_nombre)<2 then v_nombre:=split_part(v_email,'@',1); end if;
    if length(v_nombre)<2 or length(v_nombre)>100 then raise exception 'Nombre de usuario invalido'; end if;

    insert into public.perfiles(id,nombre,email,rol,empresa_id,activo,eliminado_at,eliminado_por)
    values(v_uid,v_nombre,v_email,v_aut.rol,v_aut.empresa_id,true,null,null)
    on conflict(id) do update set
      nombre=excluded.nombre,email=excluded.email,rol=excluded.rol,
      empresa_id=excluded.empresa_id,activo=true,eliminado_at=null,eliminado_por=null;

    update public.autorizaciones_acceso
    set usuario_id=v_uid,nombre=v_nombre,aceptada_at=coalesce(aceptada_at,now()),updated_at=now()
    where id=v_aut.id;

    insert into public.acceso_eventos(empresa_id,actor_id,usuario_id,autorizacion_id,email,evento,detalle)
    values(v_aut.empresa_id,v_uid,v_uid,v_aut.id,v_email,'acceso_aceptado',jsonb_build_object('rol',v_aut.rol));
    return v_aut.empresa_id;
  end if;

  select a.* into v_alta
  from public.autorizaciones_empresa a
  where a.activa=true and a.email=v_email
  for update;

  if found then
    if not public._plataforma_lista_v26() then
      raise exception 'El alta de clientes está pausada hasta completar la preparación operativa de GoRemitos';
    end if;
    if length(v_nombre)<2 then v_nombre:=coalesce(v_alta.admin_nombre,''); end if;
    if length(v_nombre)<2 then v_nombre:=split_part(v_email,'@',1); end if;
    if length(v_nombre)<2 or length(v_nombre)>100 then raise exception 'Nombre de usuario invalido'; end if;

    loop
      v_codigo:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
      exit when not exists(
        select 1 from public.empresas e where upper(btrim(e.codigo_invitacion))=v_codigo
      );
    end loop;

    insert into public.empresas(nombre,cuit,razon_social,codigo_invitacion)
    values(btrim(v_alta.empresa_nombre),nullif(btrim(v_alta.empresa_cuit),''),btrim(v_alta.empresa_nombre),v_codigo)
    returning id into v_empresa_id;

    insert into public.perfiles(id,nombre,email,rol,empresa_id,activo,eliminado_at,eliminado_por)
    values(v_uid,v_nombre,v_email,'admin',v_empresa_id,true,null,null)
    on conflict(id) do update set
      nombre=excluded.nombre,email=excluded.email,rol='admin',
      empresa_id=excluded.empresa_id,activo=true,eliminado_at=null,eliminado_por=null;

    insert into public.autorizaciones_acceso(
      empresa_id,email,nombre,rol,usuario_id,activa,creada_por,aceptada_at,updated_at
    ) values(v_empresa_id,v_email,v_nombre,'admin',v_uid,true,v_alta.creada_por,now(),now());

    update public.autorizaciones_empresa
    set activa=false,usuario_id=v_uid,empresa_id=v_empresa_id,aceptada_at=now(),
        revocada_at=now(),updated_at=now()
    where id=v_alta.id;

    insert into public.acceso_eventos(empresa_id,actor_id,usuario_id,email,evento,detalle)
    values(v_empresa_id,v_uid,v_uid,v_email,'empresa_creada_autorizada',jsonb_build_object('alta_id',v_alta.id));
    return v_empresa_id;
  end if;

  raise exception 'Este email no está autorizado. Pedile acceso al administrador de tu empresa';
end
$$;

revoke all on function public.completar_onboarding_interactivo(text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.completar_onboarding_interactivo(text,text,text,text,text)
  to authenticated;

create or replace function public.autorizar_nueva_empresa(
  p_email text,
  p_admin_nombre text,
  p_empresa_nombre text,
  p_empresa_cuit text default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_email text:=lower(btrim(coalesce(p_email,'')));
  v_nombre text:=nullif(btrim(coalesce(p_admin_nombre,'')),'');
  v_empresa text:=btrim(coalesce(p_empresa_nombre,''));
  v_id uuid;
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  if not public._plataforma_lista_v26() then
    raise exception 'Completá y verificá la preparación del piloto antes de autorizar una empresa';
  end if;
  if length(v_email) not between 5 and 254
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Ingresá un email valido';
  end if;
  if v_nombre is not null and length(v_nombre) not between 2 and 100 then
    raise exception 'El nombre debe tener entre 2 y 100 caracteres';
  end if;
  if length(v_empresa) not between 2 and 120 then raise exception 'Nombre de empresa invalido'; end if;
  if length(btrim(coalesce(p_empresa_cuit,'')))>20 then raise exception 'CUIT demasiado extenso'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_email,0));

  if exists(select 1 from public.perfiles p where p.activo=true and lower(btrim(p.email))=v_email)
     or exists(select 1 from public.autorizaciones_acceso a where a.activa=true and a.email=v_email) then
    raise exception 'Este email ya tiene o espera acceso a una empresa';
  end if;

  insert into public.autorizaciones_empresa(email,admin_nombre,empresa_nombre,empresa_cuit,creada_por)
  values(v_email,v_nombre,v_empresa,nullif(btrim(coalesce(p_empresa_cuit,'')),''),v_actor)
  on conflict(email) where activa=true do update set
    admin_nombre=excluded.admin_nombre,empresa_nombre=excluded.empresa_nombre,
    empresa_cuit=excluded.empresa_cuit,updated_at=now()
  returning id into v_id;
  return v_id;
end
$$;

revoke all on function public.autorizar_nueva_empresa(text,text,text,text) from public,anon,authenticated;
grant execute on function public.autorizar_nueva_empresa(text,text,text,text) to authenticated;

create or replace function public.cancelar_alta_empresa(p_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  update public.autorizaciones_empresa
  set activa=false,revocada_at=now(),updated_at=now()
  where id=p_id and activa=true and usuario_id is null;
  if not found then raise exception 'Alta pendiente no encontrada'; end if;
end
$$;

revoke all on function public.cancelar_alta_empresa(uuid) from public,anon,authenticated;
grant execute on function public.cancelar_alta_empresa(uuid) to authenticated;

create or replace function public.listar_altas_empresa()
returns table(
  registro_id uuid,
  email text,
  admin_nombre text,
  empresa_nombre text,
  empresa_cuit text,
  estado text,
  empresa_id uuid,
  usuario_id uuid,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  return query
  select a.id,a.email,a.admin_nombre,a.empresa_nombre,a.empresa_cuit,
         case when a.usuario_id is not null then 'activa'
              when a.activa then 'pendiente' else 'cancelada' end,
         a.empresa_id,a.usuario_id,a.created_at
  from public.autorizaciones_empresa a
  order by a.created_at desc
  limit 200;
end
$$;

revoke all on function public.listar_altas_empresa() from public,anon,authenticated;
grant execute on function public.listar_altas_empresa() to authenticated;

create or replace function public.configurar_registro_email(p_habilitado boolean)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  if coalesce(p_habilitado,false) and not coalesce(
    (select c.smtp_verificado from public.configuracion_plataforma c where c.id=true),false
  ) then
    raise exception 'Primero verificá el SMTP propio';
  end if;
  update public.configuracion_plataforma
  set registro_email_habilitado=coalesce(p_habilitado,false),updated_at=now(),updated_by=auth.uid()
  where id=true;
  return coalesce(p_habilitado,false);
end
$$;

revoke all on function public.configurar_registro_email(boolean) from public,anon,authenticated;
grant execute on function public.configurar_registro_email(boolean) to authenticated;

create or replace function public.actualizar_preparacion_plataforma_v26(
  p_plan_pro boolean,
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
  if coalesce(p_captcha,false) and length(btrim(coalesce(
    (select c.captcha_site_key from public.configuracion_plataforma c where c.id=true),''
  ))) not between 10 and 200 then
    raise exception 'Configurá la Site Key de Cloudflare Turnstile antes de marcar CAPTCHA';
  end if;
  update public.configuracion_plataforma set
    plan_pro_verificado=coalesce(p_plan_pro,false),
    smtp_verificado=coalesce(p_smtp,false),
    backup_db_verificado=coalesce(p_backup_db,false),
    backup_storage_verificado=coalesce(p_backup_storage,false),
    oauth_produccion_verificado=coalesce(p_oauth_produccion,false),
    captcha_verificado=coalesce(p_captcha,false),
    updated_at=now(),updated_by=auth.uid()
  where id=true;
  return public._plataforma_lista_v26();
end
$$;

revoke all on function public.actualizar_preparacion_plataforma_v26(boolean,boolean,boolean,boolean,boolean,boolean)
  from public,anon,authenticated;
grant execute on function public.actualizar_preparacion_plataforma_v26(boolean,boolean,boolean,boolean,boolean,boolean)
  to authenticated;

drop function if exists public.actualizar_configuracion_publica(text,text,text,text,text);
create or replace function public.actualizar_configuracion_publica(
  p_responsable_nombre text,
  p_responsable_cuit text,
  p_responsable_domicilio text,
  p_privacidad_email text,
  p_soporte_email text,
  p_captcha_site_key text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_priv text:=lower(btrim(coalesce(p_privacidad_email,'')));
  v_sop text:=lower(btrim(coalesce(p_soporte_email,'')));
  v_site_key text:=nullif(btrim(coalesce(p_captcha_site_key,'')),'');
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  if length(btrim(coalesce(p_responsable_nombre,''))) not between 2 and 160 then raise exception 'Ingresá el responsable legal'; end if;
  if length(btrim(coalesce(p_responsable_domicilio,''))) not between 5 and 250 then raise exception 'Ingresá un domicilio válido'; end if;
  if v_priv !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     or v_sop !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Revisá los emails de privacidad y soporte';
  end if;
  if v_site_key is not null and length(v_site_key) not between 10 and 200 then
    raise exception 'La Site Key de Turnstile no es válida';
  end if;
  if v_site_key is null and coalesce(
    (select c.captcha_verificado from public.configuracion_plataforma c where c.id=true),false
  ) then
    raise exception 'Desmarcá CAPTCHA en la preparación antes de quitar la Site Key';
  end if;
  update public.configuracion_plataforma set
    responsable_nombre=btrim(p_responsable_nombre),
    responsable_cuit=nullif(btrim(coalesce(p_responsable_cuit,'')),''),
    responsable_domicilio=btrim(p_responsable_domicilio),
    privacidad_email=v_priv,soporte_email=v_sop,captcha_site_key=v_site_key,
    updated_at=now(),updated_by=auth.uid()
  where id=true;
end
$$;

revoke all on function public.actualizar_configuracion_publica(text,text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.actualizar_configuracion_publica(text,text,text,text,text,text)
  to authenticated;

create or replace function public.actualizar_datos_legales_empresa(
  p_razon_social text,
  p_cuit text,
  p_domicilio text,
  p_email text,
  p_telefono text,
  p_politica_retencion text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
  v_email text:=lower(btrim(coalesce(p_email,'')));
begin
  if auth.uid() is null or public.current_rol()<>'admin' or v_empresa is null then
    raise exception 'Solo un administrador puede actualizar la empresa';
  end if;
  if length(btrim(coalesce(p_razon_social,''))) not between 2 and 160 then raise exception 'Ingresá la razón social'; end if;
  if regexp_replace(coalesce(p_cuit,''),'[^0-9]','','g') !~ '^[0-9]{11}$' then raise exception 'Ingresá un CUIT de 11 dígitos'; end if;
  if length(btrim(coalesce(p_domicilio,''))) not between 5 and 250 then raise exception 'Ingresá el domicilio legal'; end if;
  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Ingresá un email válido'; end if;
  if length(btrim(coalesce(p_politica_retencion,''))) not between 10 and 500 then raise exception 'Definí la política de conservación'; end if;
  update public.empresas set
    razon_social=btrim(p_razon_social),cuit=regexp_replace(p_cuit,'[^0-9]','','g'),
    domicilio_privacidad=btrim(p_domicilio),email_privacidad=v_email,
    telefono_privacidad=nullif(btrim(coalesce(p_telefono,'')),''),
    politica_retencion=btrim(p_politica_retencion),updated_at=now()
  where id=v_empresa;
end
$$;

revoke all on function public.actualizar_datos_legales_empresa(text,text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.actualizar_datos_legales_empresa(text,text,text,text,text,text)
  to authenticated;

create or replace function public.registrar_error_cliente_v26(
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
  -- Los diagnósticos sirven para soporte, no como archivo histórico. La
  -- limpieza oportunista evita conservar identificadores técnicos sin plazo.
  delete from public.client_error_events
  where created_at<now()-interval '30 days';
  if (select count(*) from public.client_error_events e where e.user_id=v_uid and e.created_at>now()-interval '1 minute')>=20 then
    return null;
  end if;
  insert into public.client_error_events(user_id,empresa_id,app_version,contexto,mensaje,stack,url_path,user_agent)
  values(v_uid,public.current_empresa_id(),left(coalesce('2.6.0',''),20),left(coalesce(p_contexto,'desconocido'),80),
    left(coalesce(p_mensaje,'Error sin mensaje'),1000),left(coalesce(p_stack,''),4000),
    left(coalesce(p_path,''),500),left(coalesce(p_user_agent,''),500))
  returning id into v_id;
  return v_id;
end
$$;

revoke all on function public.registrar_error_cliente_v26(text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.registrar_error_cliente_v26(text,text,text,text,text) to authenticated;

create or replace function public.listar_errores_recientes_v26()
returns table(id bigint,empresa_nombre text,usuario_email text,contexto text,mensaje text,url_path text,created_at timestamptz)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not public.es_admin_plataforma() then raise exception 'Operacion reservada al administrador de GoRemitos'; end if;
  return query
  select er.id,e.nombre,u.email,er.contexto,er.mensaje,er.url_path,er.created_at
  from public.client_error_events er
  left join public.empresas e on e.id=er.empresa_id
  left join auth.users u on u.id=er.user_id
  order by er.created_at desc
  limit 100;
end
$$;

revoke all on function public.listar_errores_recientes_v26() from public,anon,authenticated;
grant execute on function public.listar_errores_recientes_v26() to authenticated;

create or replace function public.guardar_remito_v26(
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
set search_path=''
as $$
declare
  v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or public.current_rol() not in ('admin','oficina') then
    raise exception 'Sin permiso para guardar remitos';
  end if;
  if not public._plataforma_lista_v26() then
    raise exception 'El piloto todavía no está habilitado por GoRemitos';
  end if;
  if not public._empresa_lista_v26(v_empresa) then
    raise exception 'Completá los datos legales y la política de conservación antes de crear remitos';
  end if;
  return public.guardar_remito(
    p_remito_id,p_num,p_cliente,p_dir,p_contacto,p_tel,p_chofer_id,p_fecha,p_items
  );
end
$$;

revoke all on function public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)
  from public,anon,authenticated;
grant execute on function public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)
  to authenticated;

create or replace function public.resumen_remitos_v26()
returns table(total bigint,firmados bigint,en_camino bigint,con_problemas bigint,manuales bigint)
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
         count(*) filter(where r.estado='Firmado'),
         count(*) filter(where r.estado='Pendiente'),
         count(*) filter(where r.estado in ('Disconforme','Rechazado')),
         count(*) filter(where r.estado='Manual')
  from public.remitos r
  where r.empresa_id=v_empresa
    and (v_rol in ('admin','oficina') or (v_rol='chofer' and r.chofer_id=auth.uid()));
end
$$;

revoke all on function public.resumen_remitos_v26() from public,anon,authenticated;
grant execute on function public.resumen_remitos_v26() to authenticated;

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
begin
  if auth.uid() is null or v_empresa is null or public.current_rol()<>'chofer' then return false; end if;
  if not public._plataforma_lista_v26() or not public._empresa_lista_v26(v_empresa) then return false; end if;
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

drop policy if exists evidencias_empresa_insert on storage.objects;
create policy evidencias_empresa_insert on storage.objects for insert to authenticated with check(
  bucket_id='evidencias'
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and public.current_rol()='chofer'
  and public._subida_evidencia_valida_v26(name,user_metadata)
  and (
    (storage.foldername(name))[2]='manual'
    or exists(
      select 1 from public.remitos r
      where r.empresa_id=public.current_empresa_id()
        and r.chofer_id=auth.uid() and r.estado='Pendiente'
        and r.id=case when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then ((storage.foldername(name))[2])::uuid end
    )
  )
);

-- Verifica que la evidencia exista en Storage y que el hash guardado como
-- metadata coincida con el enviado al cerrar el remito.
create or replace function public._evidencia_meta_v26(p_path text,p_sha256 text)
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
begin
  if p_path is null or v_sha !~ '^[0-9a-f]{64}$' then
    raise exception 'Hash de evidencia invalido';
  end if;

  select to_jsonb(o) into v_obj
  from storage.objects o
  where o.bucket_id='evidencias' and o.name=p_path
  limit 1;

  if v_obj is null then raise exception 'La evidencia % no existe en Storage',p_path; end if;

  if coalesce(v_obj->>'owner_id','')<>auth.uid()::text then
    raise exception 'La evidencia % no pertenece al usuario actual',p_path;
  end if;

  v_meta:=coalesce(v_obj->'metadata','{}'::jsonb);
  v_guardado:=lower(coalesce(
    v_obj->'user_metadata'->>'sha256',
    v_meta->'userMetadata'->>'sha256',
    v_meta->>'sha256',''
  ));

  if v_guardado='' or v_guardado<>v_sha then
    raise exception 'La evidencia % no coincide con su hash',p_path;
  end if;

  if coalesce((v_meta->>'size')::bigint,0)<=0
     or coalesce((v_meta->>'size')::bigint,0)>5242880
     or coalesce(v_meta->>'mimetype',v_meta->>'contentType','') not in ('image/jpeg','image/png','image/webp') then
    raise exception 'La evidencia % tiene tamaño o formato inválido',p_path;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'path',p_path,'sha256',v_sha,
    'size',coalesce(v_meta->>'size',v_obj->>'size'),
    'mimetype',coalesce(v_meta->>'mimetype',v_meta->>'contentType'),
    'etag',coalesce(v_meta->>'eTag',v_meta->>'etag'),
    'created_at',v_obj->>'created_at'
  ));
end
$$;

revoke all on function public._evidencia_meta_v26(text,text) from public,anon,authenticated;

create or replace function public.confirmar_entrega_v26(
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
begin
  if not public._plataforma_lista_v26() then raise exception 'El piloto todavía no está habilitado por GoRemitos'; end if;
  if coalesce(public.current_rol(),'')<>'chofer' then raise exception 'Solo el chofer asignado puede confirmar'; end if;
  select * into v_rem from public.remitos
  where id=p_remito_id and empresa_id=public.current_empresa_id()
    and chofer_id=auth.uid() and estado='Pendiente'
  for update;
  if v_rem.id is null then raise exception 'Entrega no disponible'; end if;
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
    'version',3,'remito_id',v_rem.id,'empresa_id',v_rem.empresa_id,'numero',v_rem.num,
    'empresa',v_empresa_datos,'cliente',v_rem.cliente,'direccion',v_rem.dir,
    'contacto',v_rem.contacto,'telefono',v_rem.tel,'chofer_id',v_rem.chofer_id,
    'chofer_nombre',v_rem.chofer_nombre,'fecha',v_rem.fecha,'estado',v_estado,
    'conformidad',p_conformidad,'observacion',coalesce(p_obs,''),
    'receptor',jsonb_build_object('nombre',btrim(p_receptor_nombre),'dni',p_receptor_dni),
    'consentimiento_informado',p_consent,'politica_version','2026-08-18-v2.6',
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
  values(p_remito_id,v_rem.empresa_id,auth.uid(),'entrega_cerrada_v26',
    jsonb_build_object('estado',v_estado,'hash',v_hash,'evidencias',jsonb_array_length(v_evidencias)));
  return v_hash;
end
$$;

revoke all on function public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
grant execute on function public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  to authenticated;

create or replace function public.guardar_remito_manual_v26(
  p_num text,p_fecha date,p_nota text,p_foto_url text,p_foto_sha256 text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid;
  v_now timestamptz:=now();
  v_snapshot jsonb;
  v_hash text;
  v_empresa uuid:=public.current_empresa_id();
  v_empresa_datos jsonb;
  v_meta jsonb;
begin
  if not public._plataforma_lista_v26() then raise exception 'El piloto todavía no está habilitado por GoRemitos'; end if;
  if coalesce(public.current_rol(),'')<>'chofer' or v_empresa is null or p_foto_url is null then
    raise exception 'Operacion no permitida';
  end if;
  if not public._empresa_lista_v26(v_empresa) then
    raise exception 'La empresa debe completar sus datos legales y política de conservación antes de registrar entregas';
  end if;
  if p_fecha is null or length(coalesce(p_num,''))>50 or length(coalesce(p_nota,''))>500 then
    raise exception 'Datos invalidos o demasiado extensos';
  end if;
  if length(p_foto_url)>600
     or p_foto_url !~ ('^'||v_empresa::text||'/manual/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$') then
    raise exception 'Referencia de foto invalida';
  end if;
  -- Serializa dos cierres simultáneos sobre el mismo objeto. Sin este bloqueo,
  -- dos transacciones podrían superar juntas la comprobación de reutilización.
  perform pg_advisory_xact_lock(hashtextextended(p_foto_url,0));
  if exists(select 1 from public.remitos r where r.foto_manual_url=p_foto_url) then
    raise exception 'Esta evidencia manual ya fue utilizada';
  end if;
  v_meta:=public._evidencia_meta_v26(p_foto_url,p_foto_sha256);

  insert into public.remitos(
    empresa_id,num,cliente,dir,fecha,estado,chofer_nombre,chofer_id,nota,
    foto_manual_url,foto_manual_sha256,created_by
  ) values(
    v_empresa,coalesce(nullif(btrim(p_num),''),'—'),'Remito manual','—',p_fecha,
    'Manual',(select nombre from public.perfiles where id=auth.uid()),auth.uid(),
    coalesce(p_nota,''),p_foto_url,p_foto_sha256,auth.uid()
  ) returning id into v_id;

  select jsonb_build_object(
    'nombre',e.nombre,'razon_social',e.razon_social,'cuit',e.cuit,
    'domicilio_privacidad',e.domicilio_privacidad,'email_privacidad',e.email_privacidad,
    'politica_retencion',e.politica_retencion
  ) into v_empresa_datos from public.empresas e where e.id=v_empresa;

  v_snapshot:=jsonb_build_object(
    'version',3,'tipo','manual','remito_id',v_id,'empresa_id',v_empresa,
    'empresa',v_empresa_datos,'numero',p_num,'fecha',p_fecha,'chofer_id',auth.uid(),
    'nota',coalesce(p_nota,''),'evidencia',v_meta,'registrado_en',v_now,
    'politica_version','2026-08-18-v2.6'
  );
  v_hash:=encode(extensions.digest(convert_to(v_snapshot::text,'UTF8'),'sha256'),'hex');
  update public.remitos set signed_snapshot=v_snapshot,evidence_hash=v_hash,locked_at=v_now where id=v_id;
  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  values(v_id,v_empresa,auth.uid(),'manual_cargado_v26',jsonb_build_object('hash',v_hash,'evidencia',v_meta));
  return v_id;
end
$$;

revoke all on function public.guardar_remito_manual_v26(text,date,text,text,text)
  from public,anon,authenticated;
grant execute on function public.guardar_remito_manual_v26(text,date,text,text,text)
  to authenticated;

-- Permite borrar exclusivamente archivos huérfanos recientes. Nunca se pueden
-- borrar evidencias ya vinculadas a un remito o item cerrado.
drop policy if exists evidencias_chofer_cleanup_v26 on storage.objects;
create policy evidencias_chofer_cleanup_v26
on storage.objects for delete to authenticated using(
  bucket_id='evidencias'
  and owner_id::text=auth.uid()::text
  and (storage.foldername(name))[1]=public.current_empresa_id()::text
  and public.current_rol()='chofer'
  and created_at>now()-interval '24 hours'
  and not exists(select 1 from public.remitos r where r.firma_url=name or r.foto_entrega_url=name or r.foto_manual_url=name)
  and not exists(select 1 from public.items_remito i where i.foto_url=name)
  and (
    (storage.foldername(name))[2]='manual'
    or exists(
      select 1 from public.remitos r
      where r.empresa_id=public.current_empresa_id() and r.chofer_id=auth.uid()
        and r.estado='Pendiente'
        and r.id=case when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then ((storage.foldername(name))[2])::uuid end
    )
  )
);

-- Endurece funciones heredadas sin depender del esquema public en search_path.
alter function public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb)
  set search_path=pg_catalog,extensions;
alter function public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb)
  set search_path=pg_catalog,extensions;
alter function public.guardar_remito_manual(text,date,text,text)
  set search_path=pg_catalog,extensions;
alter function public.eliminar_remito_pendiente(uuid)
  set search_path=pg_catalog,extensions;
alter function public.proteger_remito_cerrado()
  set search_path=pg_catalog,extensions;
alter function public.proteger_items_cerrados()
  set search_path=pg_catalog,extensions;

revoke all on function public.proteger_remito_cerrado() from public,anon,authenticated;
revoke all on function public.proteger_items_cerrados() from public,anon,authenticated;

-- Las variantes anteriores no verifican existencia ni hash de evidencias.
-- La v2.6 usa exclusivamente confirmar_entrega_v26/guardar_remito_manual_v26.
revoke all on function public.guardar_remito(uuid,text,text,text,text,text,uuid,date,jsonb)
  from public,anon,authenticated;
revoke all on function public.confirmar_entrega(uuid,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
revoke all on function public.guardar_remito_manual(text,date,text,text)
  from public,anon,authenticated;

-- Superficies heredadas por códigos de invitación: ya no se usan.
revoke all on function public.administrar_usuario(uuid,text,boolean) from public,anon,authenticated;
revoke all on function public.rotar_codigo_invitacion() from public,anon,authenticated;
revoke all on function public.obtener_codigo_invitacion() from public,anon,authenticated;

commit;
