-- GoRemitos v2.11. Ejecutar completo ANTES de publicar la interfaz v2.11.
-- Compatible con v2.10. No modifica ni elimina registros existentes.
begin;
do $$ begin
  if to_regprocedure('public.guardar_remito_v210(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)') is null then
    raise exception 'PRECHECK v2.11: primero debe estar instalada la migración v2.10';
  end if;
end $$;

-- El navegador comunica qué clase de documento cree estar creando. La
-- comprobación comparte el bloqueo del cambio de modo para evitar una carrera.
create or replace function public.guardar_remito_v211(
  p_remito_id uuid,p_num text,p_cliente text,p_dir text,p_contacto text,p_tel text,
  p_chofer_id uuid,p_fecha date,p_items jsonb,p_documento_url text,
  p_documento_sha256 text,p_documento_nombre text,p_documento_mime text,
  p_documento_size bigint,p_modo_prueba boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'') not in ('admin','oficina') then
    raise exception 'Sin permiso para guardar remitos';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if p_modo_prueba is null or p_modo_prueba is distinct from public._modo_prueba_empresa_v210(v_empresa) then
    raise exception 'El modo de la empresa cambió. Actualizá el estado y revisá el formulario antes de guardar';
  end if;
  return public.guardar_remito_v210(p_remito_id,p_num,p_cliente,p_dir,p_contacto,p_tel,
    p_chofer_id,p_fecha,p_items,p_documento_url,p_documento_sha256,p_documento_nombre,p_documento_mime,p_documento_size);
end $$;
revoke all on function public.guardar_remito_v211(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint,boolean) from public,anon,authenticated;
grant execute on function public.guardar_remito_v211(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint,boolean) to authenticated;

create or replace function public.guardar_remito_manual_v211(
  p_num text,p_fecha date,p_nota text,p_foto_url text,p_foto_sha256 text,p_modo_prueba boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.current_empresa_id();
begin
  if auth.uid() is null or v_empresa is null or coalesce(public.current_rol(),'')<>'chofer' then raise exception 'Operacion no permitida'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_empresa::text,1));
  if p_modo_prueba is null or p_modo_prueba is distinct from public._modo_prueba_empresa_v210(v_empresa) then
    raise exception 'El modo de la empresa cambió. Actualizá el estado antes de guardar';
  end if;
  return public.guardar_remito_manual_v210(p_num,p_fecha,p_nota,p_foto_url,p_foto_sha256);
end $$;
revoke all on function public.guardar_remito_manual_v211(text,date,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.guardar_remito_manual_v211(text,date,text,text,text,boolean) to authenticated;

-- Impide cerrar un resultado que contradiga la revisión de mercadería,
-- incluso desde una pestaña anterior o una llamada directa al RPC.
create or replace function public._validar_resultado_entrega_v211()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.estado='Pendiente' and new.estado='Firmado' and exists(
    select 1 from public.items_remito i where i.remito_id=new.id
      and (i.estado is distinct from 'ok' or i.qty_recibida is distinct from i.qty)
  ) then raise exception 'Hay faltantes o daños. La entrega debe quedar con observaciones'; end if;
  if old.estado='Pendiente' and new.estado='Rechazado' and exists(
    select 1 from public.items_remito i where i.remito_id=new.id and coalesce(i.qty_recibida,0)>0
  ) then raise exception 'Un rechazo total no puede tener cantidades recibidas. Registrá una entrega con observaciones'; end if;
  return new;
end $$;
revoke all on function public._validar_resultado_entrega_v211() from public,anon,authenticated;
drop trigger if exists remitos_validar_resultado_v211 on public.remitos;
create trigger remitos_validar_resultado_v211 before update of estado on public.remitos
for each row execute function public._validar_resultado_entrega_v211();

create or replace function public._cuit_valido_v211(p_cuit text)
returns boolean language plpgsql immutable set search_path='' as $$
declare v text:=regexp_replace(coalesce(p_cuit,''),'[^0-9]','','g');
  pesos integer[]:=array[5,4,3,2,7,6,5,4,3,2]; suma integer:=0; digito integer;
begin
  if v !~ '^[0-9]{11}$' then return false; end if;
  for i in 1..10 loop suma:=suma+substring(v,i,1)::integer*pesos[i]; end loop;
  digito:=11-(suma%11);if digito=11 then digito:=0;elsif digito=10 then digito:=9;end if;
  return substring(v,11,1)::integer=digito;
end $$;
revoke all on function public._cuit_valido_v211(text) from public,anon,authenticated;

create or replace function public._empresa_real_lista_v210(p_empresa uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((select length(btrim(coalesce(e.razon_social,'')))>=2
    and public._cuit_valido_v211(e.cuit)
    and length(btrim(coalesce(e.domicilio_privacidad,'')))>=5
    and coalesce(e.email_privacidad,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    and length(btrim(coalesce(e.politica_retencion,'')))>=10
    from public.empresas e where e.id=p_empresa),false)
$$;
revoke all on function public._empresa_real_lista_v210(uuid) from public,anon,authenticated;
commit;
