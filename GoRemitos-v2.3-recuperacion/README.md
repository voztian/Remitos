# GoRemitos v2.3 — recuperación de contraseña segura y clara

Esta entrega conserva las mejoras de v2.2 y corrige por completo la experiencia
de recuperación de contraseña. El usuario confirma primero el email de destino
y, al abrir el enlace, define y repite la nueva contraseña en una pantalla
dedicada. La aplicación no abre el panel si Supabase rechaza el cambio.

## Cambios de v2.3

- Email visible y editable antes de enviar el enlace de recuperación.
- Confirmación clara de la cuenta a la que se envió el enlace.
- Pantalla propia para escribir y repetir la nueva contraseña.
- Mensajes comprensibles para contraseñas que no coinciden, son cortas o
  repiten la contraseña anterior.
- La sesión temporal de recuperación no abre el panel mientras el cambio esté
  pendiente.
- Después de guardar, cierra la sesión temporal y pide ingresar con la nueva
  contraseña.
- Dominio visible actualizado a `goremitos.vercel.app`.

## Importante: orden de instalación

1. Hacé un backup del proyecto de Supabase.
2. Abrí `supabase-migration-v2.2.sql` y revisá los tipos indicados al comienzo.
3. Ejecutá el archivo completo en **Supabase > SQL Editor**.
4. Ejecutá `supabase-verificacion-v2.2.sql` y comprobá que todos los controles den
   `true` y que la consulta de permisos peligrosos devuelva cero filas.
5. En **Storage > evidencias**, confirmá que el bucket sea privado.
6. Revisá que no queden políticas antiguas y permisivas sobre
   `storage.objects` para el bucket `evidencias`.
7. Seguí `GOOGLE-OAUTH.md` para habilitar Google en Google Cloud y Supabase.
8. Recién después publicá el resto de esta carpeta en Netlify o Vercel.

La aplicación v2.2 depende de las funciones y columnas creadas por esa migración.
No reemplaces solamente el `index.html` sin ejecutar primero el SQL.
El botón de Google queda visible, pero hasta habilitar el proveedor mostrará un
error de configuración. El Client Secret se carga únicamente en Supabase: nunca
debe copiarse al HTML ni incluirse en esta carpeta.
La primera ejecución rota automáticamente los códigos de invitación heredados
que tengan menos de 12 caracteres; compartí el nuevo código desde Usuarios.
Los remitos pendientes creados con la versión anterior pueden no tener
`chofer_id`: abrilos desde Oficina/Admin, editá y asigná el chofer. Las
constancias ya cerradas quedan bloqueadas, pero sólo las nuevas incorporan el
snapshot y hash de v2.

La mejora técnica de trazabilidad no reemplaza una revisión legal. Antes de
usar datos reales, completá en la política la identidad, domicilio y canal de
contacto del operador de GoRemitos y de cada empresa responsable.

## Cambios principales

- Tipografías auxiliares más grandes y contraste reforzado en temas oscuro y claro.
- Identidad visual oficial multicolor de Google en todos los accesos.
- Botón de onboarding descriptivo según se cree una empresa o se ingrese a una.
- Acceso directo con Google mediante Supabase Auth.
- Onboarding después del primer acceso: crear empresa o ingresar un código.
- Vinculación habitual por email verificado para no duplicar identidades.
- Reinicio obligatorio de firma y conformidad entre entregas.
- Asignación real mediante el ID del usuario chofer.
- Lista de entregas pendientes para cada chofer.
- Edición transaccional de remitos pendientes, sin duplicados.
- Cierre inmutable de constancias firmadas.
- Hora de servidor, snapshot y hash SHA-256 de cada entrega.
- Evidencias privadas guardadas por ruta y URL temporales al consultar.
- Evidencias de chofer limitadas a sus propios remitos, no a toda la empresa.
- PDF paginado, también para respaldos manuales, con fotos, firma, empresa,
  CUIT y hash.
- QR autenticado para abrir el remito asignado.
- Roles, activación de usuarios y código de invitación visible sólo al admin.
- Alta compatible con confirmación de email.
- Fotos redimensionadas y comprimidas antes de subir.
- Datos dinámicos escapados para evitar inyección de HTML.
- Encabezados de seguridad para Netlify y Vercel.
- Fecha local correcta para Argentina.

## Funcionamiento sin conexión

Esta versión no afirma guardar offline. Si se pierde la señal, bloquea el
guardado y conserva el formulario visible mientras la pestaña siga abierta.
Para una contingencia en papel, el chofer puede cargar la foto al recuperar
conexión. Una cola offline completa requiere una etapa adicional con IndexedDB,
service worker, resolución de conflictos y pruebas en Android/iOS.

## Verificación mínima antes del piloto

- Activar Google y probar una cuenta nueva, una existente y el cierre de sesión.
- Confirmar que un usuario Google nuevo pueda crear empresa o unirse por código.
- Crear una empresa nueva y confirmar el email.
- Unir un segundo usuario con el código y asignarle rol Chofer.
- Crear, editar y reasignar un remito pendiente.
- Verificar que otro chofer no pueda verlo.
- Firmar una entrega conforme y otra disconforme.
- Confirmar que ninguna pueda editarse ni eliminarse.
- Descargar ambos PDF y revisar fotos, firma, paginación y hash.
- Probar el QR con el usuario asignado y con un usuario sin permiso.
- Probar tema claro/oscuro y cámara en Android/iPhone.

## Alcance pendiente

El modo offline real y el envío automático del PDF por WhatsApp/email no están
incluidos. WhatsApp se abre con el mensaje preparado, pero la web no puede
confirmar si el usuario finalmente lo envió.
