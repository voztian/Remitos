# Cambios de GoRemitos v2.6

## Seguridad

- Onboarding cerrado y nuevas empresas autorizadas por plataforma.
- Compuerta de producción para infraestructura y datos legales.
- Rutas, propiedad, formato, tamaño y hash de evidencias verificados en base.
- Hash SHA-256 calculado antes de subir y comprobado al cerrar/PDF.
- RPC antiguos de guardado y cierre revocados.
- Funciones `security definer` con `search_path` restringido.
- Storage privado, evidencias limitadas a 5 MB y limpieza limitada a huérfanos propios recientes.
- Una evidencia manual no puede reutilizarse en dos constancias.
- Dos guardados manuales simultáneos sobre la misma evidencia se serializan.
- La web verifica formato y límite final de 5 MB antes de subir cada evidencia.
- Acceso eliminado comprobado periódicamente.
- Sesiones operativas con cierre por inactividad.
- Diagnósticos limitados y eliminados a los 30 días.

## Confiabilidad

- Paginación de remitos y resumen agregado.
- Errores de carga visibles con reintento.
- Estado de Realtime visible.
- Limpieza de archivos si el cierre falla.
- Librerías locales versionadas y Turnstile oficial para los formularios de Auth.
- Retiro del service worker/caché offline anterior.
- Protocolo explícito para operación sin señal.

## Identidad y usuarios

- Google directo con selector de cuenta.
- Recuperación pide email y pantalla separada para repetir contraseña; el modo
  recuperación persiste aunque se abra otra pestaña hasta guardar o cancelar.
- Nombre completo editable e identidad visible junto a empresa y rol.
- Emails autorizados sin códigos.
- Roles, revocación y protección del último administrador.
- Alta de nuevos clientes reservada al administrador de plataforma.

## Privacidad y operación

- Política pública accesible sin sesión.
- Datos legales y conservación configurables por empresa.
- Responsable y canales públicos de plataforma.
- Lista de salida a piloto con Pro, SMTP, backups, OAuth y CAPTCHA.
- Documentación de pruebas, backups, incidentes y contratos.

## Compatibilidad

- Requiere que la instalación existente tenga v2.5.2.
- Conserva empresas, usuarios, roles, remitos, firmas y evidencias existentes.
- Los registros anteriores no obtienen hashes retroactivos; siguen conservando
  su snapshot e integridad disponibles en la versión en que fueron cerrados.
