# Activar el acceso con Google

La aplicación ya contiene el botón y el flujo de alta. Falta conectar las
credenciales privadas entre Google Cloud y Supabase. El proyecto Supabase de
esta entrega es `ospgkovvqqaaebzswngv`.

## 1. Configurar Google Cloud

1. Entrá a **Google Cloud Console > Google Auth Platform** y elegí o creá el
   proyecto de GoRemitos.
2. Completá Branding y Audience. Si la app está en modo de prueba, agregá como
   usuarios de prueba todas las cuentas que vayan a participar del piloto.
3. En Data Access usá solamente los scopes básicos `openid`,
   `.../auth/userinfo.email` y `.../auth/userinfo.profile`.
4. Creá un cliente OAuth de tipo **Web application**.
5. En **Authorized JavaScript origins**, cargá el origen público exacto:

   `https://goremitos.vercel.app`
6. En **Authorized redirect URIs**, cargá exactamente:

   `https://ospgkovvqqaaebzswngv.supabase.co/auth/v1/callback`

7. Copiá el Client ID y el Client Secret. No los pegues en `index.html`.

## 2. Habilitar Google en Supabase

1. Entrá a **Supabase Dashboard > Authentication > Providers > Google**.
2. Activá el proveedor y pegá allí el Client ID y el Client Secret.
3. En **Authentication > URL Configuration**, definí como Site URL:

   `https://goremitos.vercel.app`

4. En Redirect URLs conservá estas dos entradas:

   `https://goremitos.vercel.app`

   `https://goremitos.vercel.app/**`
5. Para una prueba local podés agregar temporalmente `http://localhost:8000/**`.
   No uses comodines para la URL definitiva de producción.

La aplicación envía el retorno a su origen y ruta actuales. Además conserva en
la misma pestaña el enlace QR que el usuario intentaba abrir antes de ingresar.

## 3. Prueba de aceptación

- Autorizar primero el email de prueba desde **Usuarios** en GoRemitos.
- Ingresar con Google usando exactamente ese email: debe aceptar la
  autorización sin pedir ningún código.
- Ingresar con una cuenta Google no autorizada: no debe mostrar datos de ninguna
  empresa; debe permitir reintentar después de que un administrador la agregue
  o crear una empresa nueva.
- Volver a ingresar con esa cuenta: debe abrir la app directamente.
- Ingresar con Google usando el mismo email verificado de una cuenta existente:
  debe conservar el mismo usuario y sus permisos.
- Probar el enlace QR estando desconectado: después de Google debe volver al
  remito solicitado.
- Cerrar sesión y comprobar que email/contraseña siga disponible.

## Seguridad

- El Client Secret sólo se guarda en la configuración privada de Supabase.
- Usá URLs exactas en producción y HTTPS.
- No solicites acceso a Gmail, Drive ni contactos: para iniciar sesión sólo se
  necesitan identidad básica, email y perfil.
- Si cambiás de dominio, actualizá tanto Google Cloud como Supabase antes de
  publicar.
- Una autorización sólo se acepta cuando Google/Supabase entrega un email
  confirmado que coincide exactamente con el cargado por el administrador.
