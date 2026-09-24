-- Lectura solamente. Ejecutar después de la migración v2.11.
select control,ok from (values
 ('alta_con_modo_esperado',to_regprocedure('public.guardar_remito_v211(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint,boolean)') is not null),
 ('manual_con_modo_esperado',to_regprocedure('public.guardar_remito_manual_v211(text,date,text,text,text,boolean)') is not null),
 ('resultado_coherente',exists(select 1 from pg_trigger where tgrelid='public.remitos'::regclass and tgname='remitos_validar_resultado_v211' and tgenabled='O')),
 ('cuit_servidor',public._cuit_valido_v211('20123456786') and not public._cuit_valido_v211('20123456785')),
 ('alta_sin_anon',not has_function_privilege('anon','public.guardar_remito_v211(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint,boolean)','EXECUTE')),
 ('alta_para_autenticados',has_function_privilege('authenticated','public.guardar_remito_v211(uuid,text,text,text,text,text,uuid,date,jsonb,text,text,text,text,bigint,boolean)','EXECUTE'))
) as controles(control,ok) order by control;

-- Diagnóstico de registros heredados: no se alteran constancias cerradas.
select r.id,r.num,r.estado from public.remitos r
where (r.estado='Firmado' and exists(select 1 from public.items_remito i where i.remito_id=r.id and i.estado='miss'))
   or (r.estado='Rechazado' and exists(select 1 from public.items_remito i where i.remito_id=r.id and i.qty_recibida>0));
