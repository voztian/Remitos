-- GoRemitos v2.5.2 - identidad visible y nombre editable
-- Ejecutar una sola vez en Supabase > SQL Editor, despues de v2.5.

begin;

create or replace function public.actualizar_mi_nombre(p_nombre text)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_nombre text:=btrim(coalesce(p_nombre,''));
  v_nombre_anterior text;
  v_empresa uuid;
  v_email text;
begin
  if v_uid is null then raise exception 'Sesion requerida'; end if;
  if length(v_nombre) not between 2 and 100 then
    raise exception 'El nombre debe tener entre 2 y 100 caracteres';
  end if;

  select p.nombre,p.empresa_id,p.email
    into v_nombre_anterior,v_empresa,v_email
  from public.perfiles p
  where p.id=v_uid and p.activo=true
  for update;

  if not found then raise exception 'Acceso activo no encontrado'; end if;

  update public.perfiles
  set nombre=v_nombre
  where id=v_uid and empresa_id=v_empresa and activo=true;

  update public.autorizaciones_acceso
  set nombre=v_nombre,updated_at=now()
  where usuario_id=v_uid and empresa_id=v_empresa and activa=true;

  -- Mantiene actualizado el nombre operativo sin alterar comprobantes cerrados.
  update public.remitos
  set chofer_nombre=v_nombre
  where chofer_id=v_uid and empresa_id=v_empresa and estado='Pendiente';

  if v_nombre is distinct from v_nombre_anterior then
    insert into public.acceso_eventos(
      empresa_id,actor_id,usuario_id,email,evento,detalle
    ) values(
      v_empresa,v_uid,v_uid,v_email,'nombre_actualizado',
      jsonb_build_object('anterior',v_nombre_anterior,'nuevo',v_nombre)
    );
  end if;

  return v_nombre;
end
$$;

revoke all on function public.actualizar_mi_nombre(text)
  from public,anon,authenticated;
grant execute on function public.actualizar_mi_nombre(text) to authenticated;

commit;
