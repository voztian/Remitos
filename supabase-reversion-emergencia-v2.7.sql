-- GoRemitos v2.7 - reversión operativa de emergencia a la web v2.6
-- No borra datos, columnas, documentos ni evidencias.
-- Usar únicamente si el deployment v2.7 falló y primero se confirmó que no
-- existe ninguna entrega v2.7 actualmente en camino.

begin;

do $$
begin
  if exists(
    select 1 from public.remitos
    where estado='Pendiente' and salida_at is not null
  ) then
    raise exception 'REVERSIÓN BLOQUEADA: hay entregas en camino. Cerrá o resolvé esos viajes antes de volver a v2.6';
  end if;
end
$$;

-- Evita que pestañas v2.7 que hayan quedado abiertas sigan escribiendo.
revoke all on function public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)
  from public,anon,authenticated;
revoke all on function public.marcar_en_camino_v27(uuid)
  from public,anon,authenticated;
revoke all on function public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
revoke all on function public.eliminar_remito_pendiente_v27(uuid)
  from public,anon,authenticated;

-- Reactiva sólo las variantes endurecidas de v2.6; las funciones antiguas
-- sin verificación de hashes continúan bloqueadas.
grant execute on function public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)
  to authenticated;
grant execute on function public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  to authenticated;
grant execute on function public.eliminar_remito_pendiente(uuid)
  to authenticated;

commit;
