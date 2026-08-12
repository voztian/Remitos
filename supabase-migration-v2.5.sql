-- GoRemitos v2.5 - autorizaciones por email y administracion segura de accesos
-- Requiere que supabase-migration-v2.2.sql ya se haya ejecutado.
-- Ejecutar una sola vez en Supabase > SQL Editor ANTES de publicar index.html.

begin;

do $$
declare t text;
begin
  select data_type into t from information_schema.columns
  where table_schema='public' and table_name='perfiles' and column_name='id';
  if t is distinct from 'uuid' then
    raise exception 'PRECHECK v2.5: perfiles.id debe ser uuid y es %',coalesce(t,'inexistente');
  end if;

  if to_regprocedure('public.current_empresa_id()') is null
     or to_regprocedure('public.current_rol()') is null then
    raise exception 'PRECHECK v2.5: primero ejecuta supabase-migration-v2.2.sql';
  end if;
end $$;

alter table public.perfiles
  add column if not exists email text,
  add column if not exists eliminado_at timestamptz,
  add column if not exists eliminado_por uuid;

-- Un usuario eliminado deja de recibir entregas nuevas. Los remitos pendientes
-- se pueden dejar temporalmente sin chofer hasta que Oficina/Admin los reasigne.
alter table public.remitos alter column chofer_id drop not null;

-- El email visible del perfil se copia desde Auth, que es la fuente confiable.
update public.perfiles p
set email=lower(btrim(u.email))
from auth.users u
where u.id=p.id
  and u.email is not null
  and (p.email is null or p.email is distinct from lower(btrim(u.email)));

do $$
begin
  if exists(
    select 1 from public.perfiles p
    where p.activo=true and p.email is null
  ) then
    raise exception 'PRECHECK v2.5: hay perfiles activos sin email en Auth';
  end if;

  if exists(
    select 1
    from public.perfiles p
    where p.activo=true and p.email is not null
    group by lower(btrim(p.email))
    having count(*)>1
  ) then
    raise exception 'PRECHECK v2.5: hay emails activos duplicados en perfiles';
  end if;

  if exists(
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
  ) then
    raise exception 'PRECHECK v2.5: hay empresas activas sin administrador';
  end if;
end $$;

create unique index if not exists perfiles_email_activo_uidx
  on public.perfiles((lower(btrim(email))))
  where activo=true and email is not null;

create index if not exists perfiles_empresa_activo_idx
  on public.perfiles(empresa_id,activo,rol);

-- Endurece los dos helpers usados por todas las políticas RLS. Los objetos se
-- califican con su esquema y el search_path queda vacío.
create or replace function public.current_empresa_id()
returns uuid
language sql
stable
security definer
set search_path=''
as $$
  select p.empresa_id
  from public.perfiles p
  where p.id=auth.uid() and p.activo=true
  limit 1
$$;

create or replace function public.current_rol()
returns text
language sql
stable
security definer
set search_path=''
as $$
  select p.rol
  from public.perfiles p
  where p.id=auth.uid() and p.activo=true
  limit 1
$$;

revoke all on function public.current_empresa_id() from public,anon,authenticated;
revoke all on function public.current_rol() from public,anon,authenticated;
grant execute on function public.current_empresa_id() to authenticated;
grant execute on function public.current_rol() to authenticated;

create table if not exists public.autorizaciones_acceso(
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  email text not null,
  nombre text,
  rol text not null default 'chofer',
  usuario_id uuid references auth.users(id) on delete set null,
  activa boolean not null default true,
  creada_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  aceptada_at timestamptz,
  revocada_por uuid references auth.users(id) on delete set null,
  revocada_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint autorizaciones_email_normalizado_ck check(email=lower(btrim(email))),
  constraint autorizaciones_email_formato_ck check(
    length(email) between 5 and 254
    and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  constraint autorizaciones_nombre_ck check(
    nombre is null or length(nombre) between 2 and 100
  ),
  constraint autorizaciones_rol_ck check(rol in ('admin','oficina','chofer')),
  constraint autorizaciones_revocacion_ck check(
    (activa=true and revocada_at is null)
    or (activa=false and revocada_at is not null)
  )
);

create unique index if not exists autorizaciones_email_activa_uidx
  on public.autorizaciones_acceso(email)
  where activa=true;

create unique index if not exists autorizaciones_usuario_activa_uidx
  on public.autorizaciones_acceso(usuario_id)
  where activa=true and usuario_id is not null;

create index if not exists autorizaciones_empresa_estado_idx
  on public.autorizaciones_acceso(empresa_id,activa,created_at desc);

create table if not exists public.acceso_eventos(
  id bigint generated by default as identity primary key,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  usuario_id uuid references auth.users(id) on delete set null,
  autorizacion_id uuid references public.autorizaciones_acceso(id) on delete set null,
  email text,
  evento text not null,
  detalle jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists acceso_eventos_empresa_idx
  on public.acceso_eventos(empresa_id,created_at desc);

-- Registra como autorizaciones aceptadas a los usuarios actuales. Así la
-- migración no cambia sus accesos y la nueva pantalla puede administrarlos.
insert into public.autorizaciones_acceso(
  empresa_id,email,nombre,rol,usuario_id,activa,creada_por,created_at,aceptada_at,updated_at
)
select p.empresa_id,lower(btrim(p.email)),p.nombre,p.rol,p.id,true,p.id,now(),now(),now()
from public.perfiles p
where p.activo=true
  and p.email is not null
  and not exists(
    select 1 from public.autorizaciones_acceso a
    where a.activa=true and a.email=lower(btrim(p.email))
  );

-- Devuelve el propio acceso, incluso cuando fue revocado. Esto permite cerrar
-- la sesion y mostrar un mensaje claro sin exponer perfiles de otras empresas.
create or replace function public.obtener_mi_acceso()
returns table(
  usuario_id uuid,
  nombre text,
  email text,
  rol text,
  empresa_id uuid,
  empresa_nombre text,
  empresa_cuit text,
  activo boolean
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
         e.nombre,e.cuit,p.activo
  from public.perfiles p
  join public.empresas e on e.id=p.empresa_id
  left join auth.users u on u.id=p.id
  where p.id=auth.uid()
  limit 1;
end
$$;

revoke all on function public.obtener_mi_acceso() from public,anon,authenticated;
grant execute on function public.obtener_mi_acceso() to authenticated;

-- Alta compatible con Google y email/contraseña. La autorizacion se busca por
-- el email confirmado de auth.users; nunca se confía en un email enviado por
-- el navegador ni en user_metadata para decidir la empresa o el rol.
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
  v_tipo text:=lower(btrim(coalesce(p_tipo,'')));
  v_email text;
  v_email_confirmado timestamptz;
  v_nombre text:=btrim(coalesce(p_nombre,''));
  v_empresa_id uuid;
  v_codigo text;
  v_aut public.autorizaciones_acceso%rowtype;
  v_tiene_aut boolean:=false;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;

  select lower(btrim(u.email)),u.email_confirmed_at
    into v_email,v_email_confirmado
  from auth.users u
  where u.id=v_uid
  for update;
  if not found or v_email is null then raise exception 'Usuario autenticado invalido'; end if;
  if v_email_confirmado is null then raise exception 'Confirma tu email antes de continuar'; end if;

  -- La fila de Auth y un bloqueo por email hacen idempotentes dos intentos
  -- simultáneos desde distintas pestañas.
  perform pg_advisory_xact_lock(hashtextextended(v_email,0));

  select p.empresa_id into v_empresa_id
  from public.perfiles p
  where p.id=v_uid and p.activo=true
  for update;
  if found then return v_empresa_id; end if;

  select a.* into v_aut
  from public.autorizaciones_acceso a
  where a.activa=true and a.email=v_email
  for update;
  v_tiene_aut:=found;

  if length(v_nombre)<2 and v_tiene_aut then v_nombre:=coalesce(v_aut.nombre,''); end if;
  if length(v_nombre)<2 then v_nombre:=split_part(v_email,'@',1); end if;
  if length(v_nombre)<2 or length(v_nombre)>100 then raise exception 'Nombre de usuario invalido'; end if;

  if v_tiene_aut then
    insert into public.perfiles(id,nombre,email,rol,empresa_id,activo,eliminado_at,eliminado_por)
    values(v_uid,v_nombre,v_email,v_aut.rol,v_aut.empresa_id,true,null,null)
    on conflict(id) do update set
      nombre=excluded.nombre,
      email=excluded.email,
      rol=excluded.rol,
      empresa_id=excluded.empresa_id,
      activo=true,
      eliminado_at=null,
      eliminado_por=null;

    update public.autorizaciones_acceso
    set usuario_id=v_uid,nombre=v_nombre,aceptada_at=coalesce(aceptada_at,now()),updated_at=now()
    where id=v_aut.id;

    insert into public.acceso_eventos(
      empresa_id,actor_id,usuario_id,autorizacion_id,email,evento,detalle
    ) values(
      v_aut.empresa_id,v_uid,v_uid,v_aut.id,v_email,'acceso_aceptado',
      jsonb_build_object('rol',v_aut.rol)
    );
    return v_aut.empresa_id;
  end if;

  if v_tipo='empresa' then
    if length(btrim(coalesce(p_empresa_nombre,'')))<2
       or length(btrim(coalesce(p_empresa_nombre,'')))>120
       or length(btrim(coalesce(p_empresa_cuit,'')))>20 then
      raise exception 'Nombre de empresa invalido';
    end if;

    loop
      v_codigo:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
      exit when not exists(
        select 1 from public.empresas e
        where upper(btrim(e.codigo_invitacion))=v_codigo
      );
    end loop;

    insert into public.empresas(nombre,cuit,codigo_invitacion)
    values(btrim(p_empresa_nombre),nullif(btrim(p_empresa_cuit),''),v_codigo)
    returning id into v_empresa_id;

    insert into public.perfiles(id,nombre,email,rol,empresa_id,activo,eliminado_at,eliminado_por)
    values(v_uid,v_nombre,v_email,'admin',v_empresa_id,true,null,null)
    on conflict(id) do update set
      nombre=excluded.nombre,
      email=excluded.email,
      rol='admin',
      empresa_id=excluded.empresa_id,
      activo=true,
      eliminado_at=null,
      eliminado_por=null;

    insert into public.autorizaciones_acceso(
      empresa_id,email,nombre,rol,usuario_id,activa,creada_por,aceptada_at,updated_at
    ) values(v_empresa_id,v_email,v_nombre,'admin',v_uid,true,v_uid,now(),now())
    returning id into v_aut.id;

    insert into public.acceso_eventos(
      empresa_id,actor_id,usuario_id,autorizacion_id,email,evento,detalle
    ) values(
      v_empresa_id,v_uid,v_uid,v_aut.id,v_email,'empresa_creada',
      jsonb_build_object('rol','admin')
    );
    return v_empresa_id;
  end if;

  raise exception 'Este email no esta autorizado por ninguna empresa';
end
$$;

revoke all on function public.completar_onboarding_interactivo(text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.completar_onboarding_interactivo(text,text,text,text,text)
  to authenticated;

-- Wrapper automático para el primer ingreso. Si el usuario ya tuvo un perfil
-- y fue eliminado, no reutiliza metadata antigua para crear otra empresa.
create or replace function public.completar_onboarding()
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_meta jsonb;
  v_tipo text;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;
  select u.raw_user_meta_data into v_meta from auth.users u where u.id=v_uid;

  if exists(select 1 from public.perfiles p where p.id=v_uid) then
    v_tipo:='autorizado';
  else
    v_tipo:=coalesce(nullif(v_meta->>'onboarding_tipo',''),'autorizado');
  end if;

  return public.completar_onboarding_interactivo(
    v_tipo,
    coalesce(v_meta->>'nombre',v_meta->>'full_name',v_meta->>'name'),
    v_meta->>'empresa_nombre',
    v_meta->>'empresa_cuit',
    null
  );
end
$$;

revoke all on function public.completar_onboarding() from public,anon,authenticated;
grant execute on function public.completar_onboarding() to authenticated;

create or replace function public.autorizar_usuario(
  p_email text,
  p_nombre text,
  p_rol text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_empresa uuid:=public.current_empresa_id();
  v_email text:=lower(btrim(coalesce(p_email,'')));
  v_nombre text:=nullif(btrim(coalesce(p_nombre,'')),'');
  v_rol text:=lower(btrim(coalesce(p_rol,'')));
  v_aut public.autorizaciones_acceso%rowtype;
  v_perfil_id uuid;
  v_perfil_empresa uuid;
begin
  if v_actor is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede autorizar usuarios';
  end if;
  if length(v_email) not between 5 and 254
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Ingresá un email valido';
  end if;
  if v_nombre is not null and length(v_nombre) not between 2 and 100 then
    raise exception 'El nombre debe tener entre 2 y 100 caracteres';
  end if;
  if v_rol not in ('admin','oficina','chofer') then raise exception 'Rol invalido'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Tu acceso de administrador ya no esta vigente';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_email,0));

  select p.id,p.empresa_id into v_perfil_id,v_perfil_empresa
  from public.perfiles p
  where p.activo=true and lower(btrim(p.email))=v_email
  limit 1;
  if found then
    if v_perfil_empresa=v_empresa then raise exception 'Este email ya tiene acceso activo en tu empresa'; end if;
    raise exception 'Este email ya tiene acceso activo en otra empresa';
  end if;

  select a.* into v_aut
  from public.autorizaciones_acceso a
  where a.activa=true and a.email=v_email
  for update;

  if found then
    if v_aut.empresa_id<>v_empresa then raise exception 'Este email ya esta autorizado en otra empresa'; end if;
    if v_aut.usuario_id is not null then raise exception 'Este email ya tiene acceso activo'; end if;
    update public.autorizaciones_acceso
    set nombre=v_nombre,rol=v_rol,updated_at=now()
    where id=v_aut.id;
    insert into public.acceso_eventos(
      empresa_id,actor_id,autorizacion_id,email,evento,detalle
    ) values(
      v_empresa,v_actor,v_aut.id,v_email,'autorizacion_actualizada',
      jsonb_build_object('rol',v_rol)
    );
    return v_aut.id;
  end if;

  insert into public.autorizaciones_acceso(
    empresa_id,email,nombre,rol,activa,creada_por,created_at,updated_at
  ) values(v_empresa,v_email,v_nombre,v_rol,true,v_actor,now(),now())
  returning * into v_aut;

  insert into public.acceso_eventos(
    empresa_id,actor_id,autorizacion_id,email,evento,detalle
  ) values(
    v_empresa,v_actor,v_aut.id,v_email,'email_autorizado',
    jsonb_build_object('rol',v_rol)
  );
  return v_aut.id;
end
$$;

revoke all on function public.autorizar_usuario(text,text,text)
  from public,anon,authenticated;
grant execute on function public.autorizar_usuario(text,text,text) to authenticated;

create or replace function public.cancelar_autorizacion(p_autorizacion_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_empresa uuid:=public.current_empresa_id();
  v_aut public.autorizaciones_acceso%rowtype;
begin
  if v_actor is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede cancelar autorizaciones';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Tu acceso de administrador ya no esta vigente';
  end if;

  select a.* into v_aut
  from public.autorizaciones_acceso a
  where a.id=p_autorizacion_id and a.empresa_id=v_empresa and a.activa=true
  for update;
  if not found then raise exception 'Autorizacion no encontrada'; end if;
  if v_aut.usuario_id is not null then raise exception 'El acceso ya fue utilizado; elimina el usuario desde la lista'; end if;

  update public.autorizaciones_acceso
  set activa=false,revocada_por=v_actor,revocada_at=now(),updated_at=now()
  where id=v_aut.id;

  insert into public.acceso_eventos(
    empresa_id,actor_id,autorizacion_id,email,evento,detalle
  ) values(
    v_empresa,v_actor,v_aut.id,v_aut.email,'autorizacion_cancelada',
    jsonb_build_object('rol',v_aut.rol)
  );
end
$$;

revoke all on function public.cancelar_autorizacion(uuid)
  from public,anon,authenticated;
grant execute on function public.cancelar_autorizacion(uuid) to authenticated;

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
  if v_actor is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede cambiar roles';
  end if;
  if p_usuario_id=v_actor then raise exception 'No podes modificar tu propio rol'; end if;
  if v_rol not in ('admin','oficina','chofer') then raise exception 'Rol invalido'; end if;

  -- Serializa cambios de administradores para impedir que dos operaciones
  -- simultáneas dejen a la empresa sin ningún admin.
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

  if v_anterior='chofer' and v_rol<>'chofer' then
    insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
    select r.id,v_empresa,v_actor,'chofer_desasignado',
           jsonb_build_object('usuario_id',p_usuario_id,'motivo','cambio_de_rol')
    from public.remitos r
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id and r.estado='Pendiente';

    update public.remitos r
    set chofer_id=null,chofer_nombre='Sin asignar'
    where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id and r.estado='Pendiente';
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

revoke all on function public.cambiar_rol_usuario(uuid,text)
  from public,anon,authenticated;
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
  if v_actor is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede eliminar usuarios';
  end if;
  if p_usuario_id=v_actor then raise exception 'No podes eliminar tu propio acceso'; end if;

  -- Comparte el mismo bloqueo que el cambio de rol para proteger al último
  -- administrador incluso ante dos solicitudes concurrentes.
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

  insert into public.remito_eventos(remito_id,empresa_id,actor_id,evento,detalle)
  select r.id,v_empresa,v_actor,'chofer_desasignado',
         jsonb_build_object('usuario_id',p_usuario_id,'motivo','usuario_eliminado')
  from public.remitos r
  where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id and r.estado='Pendiente';

  update public.remitos r
  set chofer_id=null,chofer_nombre='Sin asignar'
  where r.empresa_id=v_empresa and r.chofer_id=p_usuario_id and r.estado='Pendiente';
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

revoke all on function public.eliminar_usuario_empresa(uuid)
  from public,anon,authenticated;
grant execute on function public.eliminar_usuario_empresa(uuid) to authenticated;

create or replace function public.listar_accesos_empresa()
returns table(
  tipo text,
  registro_id uuid,
  usuario_id uuid,
  nombre text,
  email text,
  rol text,
  estado text,
  fecha timestamptz,
  es_actual boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or coalesce(public.current_rol(),'')<>'admin' then
    raise exception 'Solo un administrador puede ver los accesos';
  end if;

  return query
  select x.tipo,x.registro_id,x.usuario_id,x.nombre,x.email,x.rol,x.estado,x.fecha,x.es_actual
  from (
    select 'usuario'::text as tipo,p.id as registro_id,p.id as usuario_id,p.nombre,
           coalesce(p.email,a.email,'') as email,p.rol,'activo'::text as estado,
           coalesce(a.aceptada_at,a.created_at) as fecha,(p.id=auth.uid()) as es_actual
    from public.perfiles p
    left join public.autorizaciones_acceso a
      on a.usuario_id=p.id and a.empresa_id=p.empresa_id and a.activa=true
    where p.empresa_id=v_empresa and p.activo=true

    union all

    select 'autorizacion'::text,a.id,null::uuid,coalesce(a.nombre,''),a.email,a.rol,
           'pendiente'::text,a.created_at,false
    from public.autorizaciones_acceso a
    where a.empresa_id=v_empresa and a.activa=true and a.usuario_id is null
  ) x
  order by case when x.estado='pendiente' then 0 else 1 end,lower(x.nombre),x.email;
end
$$;

revoke all on function public.listar_accesos_empresa()
  from public,anon,authenticated;
grant execute on function public.listar_accesos_empresa() to authenticated;

-- Los RPC anteriores dejan de ser vías de administración o invitación.
revoke all on function public.administrar_usuario(uuid,text,boolean)
  from public,anon,authenticated;
revoke all on function public.rotar_codigo_invitacion()
  from public,anon,authenticated;
revoke all on function public.obtener_codigo_invitacion()
  from public,anon,authenticated;

-- RLS y privilegios: las autorizaciones sólo se consultan o modifican mediante
-- los RPC anteriores. Los eventos son visibles únicamente para admins.
alter table public.autorizaciones_acceso enable row level security;
alter table public.acceso_eventos enable row level security;

do $$
declare p record;
begin
  for p in select schemaname,tablename,policyname from pg_policies
           where schemaname='public' and tablename in ('autorizaciones_acceso','acceso_eventos')
  loop
    execute format('drop policy if exists %I on %I.%I',p.policyname,p.schemaname,p.tablename);
  end loop;
end $$;

create policy acceso_eventos_admin_select
on public.acceso_eventos for select to authenticated
using(
  empresa_id=public.current_empresa_id()
  and public.current_rol()='admin'
);

revoke all on public.autorizaciones_acceso from public,anon,authenticated;
revoke all on public.acceso_eventos from public,anon,authenticated;
grant select on public.acceso_eventos to authenticated;

-- El email de otros usuarios sólo sale por listar_accesos_empresa(), que exige
-- rol admin. Oficina y chofer no reciben esa columna por la API de tablas.
revoke select on public.perfiles from public,anon,authenticated;
grant select(id,nombre,rol,empresa_id,activo) on public.perfiles to authenticated;

commit;
