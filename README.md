# GoRemitos v2.5 — acceso autorizado por email

Esta versión reemplaza los códigos de invitación por una lista de emails
autorizados administrada por cada empresa. Conserva la recuperación de
contraseña de v2.3 y todas las mejoras operativas de v2.2.

## Cómo funciona

1. Un administrador abre **Usuarios**.
2. Carga el email, el nombre opcional y el rol inicial.
3. La autorización queda como **Pendiente**.
4. La persona entra con Google o crea una cuenta usando exactamente ese email.
5. Supabase compara el email confirmado de la sesión con la autorización.
6. Si coincide, crea o reactiva el perfil en la empresa y aplica el rol elegido.

El usuario nunca escribe un código. El administrador puede compartir unas
instrucciones listas para WhatsApp, pero el enlace no contiene el email ni otro
dato personal.

## Cambios de v2.5

- Autorizaciones por email normalizado y único.
- Roles iniciales Administrador, Oficina o Chofer.
- Estados Pendiente y Activo en la pantalla Usuarios.
- Cambio de rol para cualquier otro usuario activo.
- Cancelación de autorizaciones todavía no utilizadas.
- Eliminación del acceso de otros usuarios, incluidos otros administradores.
- Protección contra eliminarse o cambiarse el propio rol.
- Protección para que la empresa nunca quede sin administradores.
- Remitos cerrados e historial preservados al eliminar un usuario.
- Remitos pendientes desasignados automáticamente si se elimina o cambia de
  rol al chofer responsable.
- Registro de quién autorizó, aceptó, cambió o eliminó cada acceso.
- Comprobación periódica del acceso: un usuario eliminado pierde permisos en la
  base inmediatamente y la interfaz cierra su sesión al volver a enfocarse o en
  un máximo aproximado de 30 segundos.
- Email de otros usuarios visible sólo mediante el RPC reservado a admins.
- Códigos de invitación y RPC administrativos anteriores bloqueados.
- Alta por Google y por email compatible con el nuevo sistema.
- Recuperación de contraseña v2.3 conservada.
- Dominio del pie de los PDF corregido a `goremitos.vercel.app`.

## Importante sobre “Eliminar usuario”

La acción elimina el acceso a la empresa, no destruye físicamente la identidad
de Supabase. Esto es intencional: mantiene la trazabilidad de firmas y remitos,
permite volver a autorizar el mismo email y evita exponer una clave secreta en
el navegador. El usuario eliminado no puede consultar ni modificar datos porque
las políticas verifican su perfil activo en cada operación.

La eliminación completa de una identidad de `auth.users` requiere una función
de servidor con una clave secreta. Esa clave nunca debe incluirse en el HTML.

## Orden exacto de instalación

1. Hacé un backup del proyecto de Supabase.
2. Confirmá que ya ejecutaste `supabase-migration-v2.2.sql`. No hace falta
   volver a ejecutarlo si la v2.3 ya estaba funcionando.
3. Abrí `supabase-migration-v2.5.sql` y ejecutalo completo en
   **Supabase > SQL Editor**.
4. Ejecutá `supabase-verificacion-v2.5.sql`.
5. Confirmá que todos los controles de la primera consulta sean `true` y que la
   consulta de permisos peligrosos devuelva cero filas.
6. En la configuración de Email de Supabase Auth, mantené activada la
   confirmación de email. Es necesaria para impedir que alguien registre un
   correo ajeno.
7. Recién después publicá todos los archivos de esta carpeta en GitHub/Vercel.

No publiques primero el `index.html`: la pantalla v2.5 depende de los nuevos
RPC y tablas creados por la migración.

Si Supabase muestra un error que empieza con `PRECHECK v2.5`, no publiques los
archivos todavía: guardá una captura del mensaje para corregir el dato señalado.

El ZIP es sólo para descargar y transportar la versión. Para GitHub hay que
descomprimirlo y subir los **15 archivos** que contiene, igual que en la versión
anterior.

## Qué ocurre con los usuarios existentes

La migración copia sus emails desde `auth.users`, conserva empresa, nombre y
rol, y crea autorizaciones ya aceptadas. Nadie debería perder acceso por la
actualización.

Si un administrador elimina a una persona y luego vuelve a autorizar el mismo
email, esa persona podrá iniciar sesión nuevamente y quedará vinculada con el
nuevo rol seleccionado.

## Verificación funcional recomendada

- Comprobar que el administrador actual siga entrando.
- Autorizar un email nuevo como Chofer.
- Abrir el enlace de registro en una ventana de incógnito.
- Crear la cuenta con exactamente ese email y confirmar el correo.
- Verificar que pase de Pendiente a Activo automáticamente.
- Intentar entrar con otro email y confirmar que no obtiene acceso.
- Cambiar el rol del usuario entre Chofer, Oficina y Administrador.
- Crear un remito para el chofer y luego eliminar su acceso.
- Confirmar que el remito pendiente quede como “Sin asignar”.
- Confirmar que los remitos cerrados y sus firmas sigan visibles para Admin.
- Volver a autorizar el email eliminado y comprobar la reactivación.
- Probar recuperación de contraseña y tema claro/oscuro.

## Seguridad aplicada

- El navegador usa solamente la clave pública de Supabase.
- La empresa y el rol se asignan dentro de funciones `security definer` con
  `search_path` restringido.
- La autorización se resuelve con el email confirmado de `auth.users`, no con
  `user_metadata` editable por el usuario.
- Las tablas de autorizaciones no admiten lectura ni escritura directa desde
  `anon` o `authenticated`.
- RLS sigue aislando empresas, roles, remitos y evidencias privadas.
- Los emails se normalizan en minúsculas y sólo puede existir una autorización
  activa por email.
- Las operaciones simultáneas sobre el mismo email se serializan para evitar
  duplicados o altas en dos empresas.

## Pendientes fuera de esta versión

El envío automático de emails de invitación no está incluido: Supabase exige
hacerlo desde un servidor confiable con credenciales secretas. La aplicación
permite copiar o compartir instrucciones sin exponer esas credenciales.

El modo offline real tampoco está incluido. Si se pierde la señal, GoRemitos
bloquea el guardado y conserva el formulario mientras la pestaña siga abierta.
