# Google OAuth de GoRemitos v2.6

Dominio público principal: `https://goremitos.vercel.app`

Proyecto Supabase: `ospgkovvqqaaebzswngv`

## 1. Google Cloud

1. Entrá a **Google Cloud Console > Google Auth Platform** y elegí el proyecto
   correcto de GoRemitos.
2. En **Información de la marca**, completá nombre de la app, email de soporte,
   dominio principal y contacto del desarrollador.
3. Publicá la aplicación para audiencia **Externa** antes de invitar clientes.
   Mientras siga en prueba, agregá expresamente todas las cuentas de prueba.
4. En **Acceso a los datos**, solicitá solamente `openid`, email y perfil.
5. En **Clientes**, creá o editá un cliente **Aplicación web**.
6. En **Orígenes autorizados de JavaScript**, dejá:

   `https://goremitos.vercel.app`

7. En **URIs de redireccionamiento autorizados**, dejá exactamente:

   `https://ospgkovvqqaaebzswngv.supabase.co/auth/v1/callback`

8. Guardá y copiá el Client ID y Client Secret al administrador de contraseñas.
   No guardes capturas con el secreto ni lo subas a GitHub.

## 2. Supabase

1. Abrí **Authentication > Sign In / Providers > Google**.
2. Activá **Enable Sign in with Google**.
3. En **Client IDs** pegá el Client ID terminado en
   `.apps.googleusercontent.com`, no un email ni una clave API.
4. En **Client Secret** pegá el secreto del mismo cliente OAuth.
5. Dejá desactivados **Skip nonce checks** y **Allow users without an email**.
6. Guardá.
7. En **Authentication > URL Configuration** usá:

   Site URL: `https://goremitos.vercel.app`

   Redirect URL: `https://goremitos.vercel.app/**`

No agregues URLs `file:///`, `localhost` ni previews de Vercel al entorno de
producción. Para pruebas aisladas usá otro proyecto o retiralas al terminar.

## 3. Prueba obligatoria

Usá dos perfiles de Chrome diferentes o una ventana incógnita sólo para evitar
reutilizar la sesión del administrador:

1. Desde GoRemitos, autorizá un email de prueba como Chofer.
2. Cerrá sesión.
3. Entrá con Google usando exactamente ese correo.
4. Google debe permitir elegir cuenta y luego GoRemitos debe pedir nombre.
5. Confirmá que figure en **Usuarios activos** con empresa y rol correctos.
6. Eliminá su acceso y comprobá que ya no pueda leer datos ni volver a entrar.
7. Probá una cuenta no autorizada: debe quedar fuera de toda empresa.

## 4. Señales de error

- `Unsupported provider`: Google sigue desactivado en Supabase.
- `redirect_uri_mismatch`: la URI de callback de Supabase no coincide
  exactamente con Google Cloud.
- Vuelve a `localhost`: Site URL o Redirect URLs de Supabase siguen apuntando a
  desarrollo.
- Entra con la cuenta equivocada: cerrá la sesión Google o usá otro perfil; la
  app solicita `select_account`, pero Google puede mantener varias sesiones.

Referencia oficial:
https://supabase.com/docs/guides/auth/social-login/auth-google
