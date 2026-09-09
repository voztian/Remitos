-- GoRemitos v2.6 - revisión MANUAL de cuentas existentes
-- No modifica nada. Ejecutar antes de activar "Confirm Email" y antes de
-- habilitar nuevas altas con contraseña.

select
  u.id,
  u.email,
  u.created_at,
  u.last_sign_in_at,
  u.email_confirmed_at,
  exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google') as usa_google,
  exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='email') as usa_password,
  p.nombre,
  p.rol,
  p.activo,
  e.nombre as empresa,
  case
    when p.id is not null and p.activo=true then 'REVISAR: acceso activo conocido'
    when exists(select 1 from public.autorizaciones_acceso a where a.activa=true and a.usuario_id=u.id) then 'REVISAR: autorización vinculada'
    else 'REVISAR ESPECIALMENTE: cuenta sin perfil activo'
  end as accion
from auth.users u
left join public.perfiles p on p.id=u.id
left join public.empresas e on e.id=p.empresa_id
order by u.created_at;

-- Esta única fila será el administrador inicial de la plataforma durante la
-- migración. Debe corresponder al titular de GoRemitos. Si no lo reconocés,
-- detené la actualización y corregí las cuentas antes de continuar.
select p.id,u.email,p.nombre,e.nombre as empresa,u.created_at,
       'DEBE SER EL TITULAR DE GOREMITOS' as comprobacion
from public.perfiles p
join auth.users u on u.id=p.id
join public.empresas e on e.id=p.empresa_id
where p.activo=true and p.rol='admin'
order by u.created_at,p.id
limit 1;

-- Cualquier fila requiere decisión manual: reconocer al titular, revocar el
-- acceso o eliminar la identidad desde Authentication > Users. No borres una
-- cuenta vinculada sin verificar antes su historial y su empresa.
select u.id,u.email,u.created_at,u.last_sign_in_at
from auth.users u
left join public.perfiles p on p.id=u.id and p.activo=true
left join public.autorizaciones_acceso a on a.usuario_id=u.id and a.activa=true
where p.id is null and a.id is null
order by u.created_at;
