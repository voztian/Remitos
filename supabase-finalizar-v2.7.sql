-- GoRemitos v2.7 - cierre de actualización sin downtime
-- Ejecutar sólo después de que Vercel muestre la v2.7 como Ready.
-- No elimina ni modifica datos.

begin;

do $$
begin
  if to_regprocedure('public.guardar_remito_v27(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint)') is null
     or to_regprocedure('public.marcar_en_camino_v27(uuid)') is null
     or to_regprocedure('public.confirmar_entrega_v27(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)') is null then
    raise exception 'PRECHECK: la migracion v2.7 no esta completa';
  end if;
end
$$;

-- Desde este punto no puede saltearse el documento original ni el inicio de
-- viaje mediante los RPC que utilizaba la web v2.6.
revoke all on function public.guardar_remito_v26(uuid,text,text,text,text,text,uuid,date,jsonb)
  from public,anon,authenticated;
revoke all on function public.confirmar_entrega_v26(uuid,text,text,text,text,text,text,text,text,boolean,jsonb)
  from public,anon,authenticated;
revoke all on function public.eliminar_remito_pendiente(uuid)
  from public,anon,authenticated;

commit;
