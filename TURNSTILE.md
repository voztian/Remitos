# Cloudflare Turnstile — configuración exacta

GoRemitos ya incluye el componente y envía el token a Supabase en ingreso con
contraseña, alta por contraseña y recuperación. Google OAuth no necesita este
desafío adicional.

## Orden seguro de activación

1. Iniciá sesión como administrador de plataforma con Google y dejá esa sesión
   abierta hasta terminar.
2. En Cloudflare, abrí **Turnstile > Add widget**.
3. Nombre sugerido: `GoRemitos producción`.
4. Agregá el hostname `goremitos.vercel.app` y elegí modo **Managed**.
5. Copiá por separado:
   - **Site Key:** es pública y puede estar en la aplicación.
   - **Secret Key:** es secreta y nunca debe ir a GitHub, HTML, WhatsApp o una
     captura compartida.
6. En GoRemitos abrí **Usuarios > Administración de GoRemitos > Responsable de
   la plataforma**, pegá solamente la **Site Key** y guardá.
7. En Supabase abrí **Authentication > Bot and Abuse Protection**, activá
   CAPTCHA, elegí **Cloudflare Turnstile** y pegá la **Secret Key**.
8. Cerrá sesión y probá con datos ficticios:
   - ingreso con email y contraseña;
   - solicitud de recuperación;
   - alta por contraseña sólo si esa modalidad ya fue habilitada.
9. Volvé con Google y marcá **Turnstile activo y probado** en la preparación del
   piloto únicamente si las pruebas anteriores funcionaron.

Si el widget no carga, Google sigue disponible para el administrador. Revisá el
hostname, la pareja Site Key/Secret Key y que Vercel haya desplegado
`vercel.json` con las cabeceras de v2.6.

## Rotación de claves

Hacela durante una ventana de mantenimiento y conservá una sesión Google de
administración abierta. Actualizá la Site Key en GoRemitos y la Secret Key en
Supabase como una sola operación; después repetí las tres pruebas. No marques
el control como listo mientras las claves no coincidan.

Referencias oficiales:

- Supabase CAPTCHA: https://supabase.com/docs/guides/auth/auth-captcha
- Turnstile en una SPA: https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/
- CSP de Turnstile: https://developers.cloudflare.com/turnstile/reference/content-security-policy/
