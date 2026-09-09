# Resultado de validación — GoRemitos v2.7

Fecha de revisión: 9 de septiembre de 2026.

## Dictamen

El paquete queda **apto para instalar en un entorno controlado y ejecutar el piloto de aceptación**. No debe habilitarse todavía a clientes reales hasta completar, en la infraestructura de GoRemitos, todas las pruebas marcadas en `PRUEBAS-PILOTO-v2.7.md`.

El alcance validado es seguimiento y constancia digital de una entrega asociada a un remito externo. Esta versión no emite un Remito R, una factura ni otro comprobante fiscal.

## Controles automatizados superados

- Sintaxis del JavaScript embebido y validez de los archivos JSON.
- Presencia de todos los recursos locales y ausencia de dependencias CDN.
- Separación entre documento original, evidencias y seguimiento público.
- Validación de PDF/JPEG/PNG/WebP por tamaño, extensión, MIME y firma interna.
- Hash SHA-256 antes de subir y al volver a abrir, descargar o emitir constancia.
- Escape de datos dinámicos utilizados en atributos y eventos HTML.
- Seguimiento público mediante token en el fragmento de la URL y respuesta mínima.
- Flujo obligatorio Programado → En camino → Entregado.
- Bloqueo de edición y borrado después de iniciar el viaje.
- Protección de continuidad: un chofer no puede perder rol o acceso mientras
  tenga una entrega en camino, incluso ante solicitudes simultáneas.
- Migración, finalización y reversión delimitadas y no destructivas.
- Exclusión de SQL, documentación y pruebas del deployment público de Vercel.
- Ausencia de JWT privados, `service_role` o secretos equivalentes en la web.
- Integridad SHA-256 de los archivos críticos del paquete.

## Pruebas que requieren la infraestructura real

Estas comprobaciones no pueden simularse con fidelidad fuera del proyecto real y son obligatorias antes de invitar clientes:

1. Ejecutar la migración y la verificación en el Supabase correcto.
2. Probar RLS con tres cuentas reales: administrador, oficina y chofer.
3. Probar Google OAuth y recuperación de contraseña desde una sesión cerrada.
4. Subir, abrir, descargar y compartir un documento de prueba desde celular y computadora.
5. Completar una entrega conforme, una con diferencias y una rechazada.
6. Confirmar que el enlace público no expone personas, domicilio, teléfono, ítems, firma, fotos ni documento.
7. Descargar backups de base, `documentos-remito` y `evidencias`, y ensayar una restauración.
8. Verificar la experiencia en los dispositivos y navegadores que usarán los choferes.

## Riesgos residuales aceptados para el piloto

- Supabase Free puede pausarse por inactividad y no aporta backups automáticos; el piloto depende de la rutina externa documentada.
- La validación de formato no sustituye un antivirus del lado servidor. Sólo deben cargarse archivos obtenidos de fuentes confiables.
- El seguimiento público es un enlace portador: cualquiera que obtenga el token puede consultar el estado mínimo.
- No hay operación offline, GPS continuo, optimización de rutas ni ETA automática.
- La firma capturada es electrónica; no equivale a una firma digital certificada.
- La política CSP conserva código en línea por la arquitectura actual. Los datos dinámicos están escapados y las fuentes externas restringidas, pero separar el código en módulos será una mejora futura.

## Condición de salida a clientes

La salida queda aprobada únicamente cuando:

- `supabase-verificacion-v2.7.sql` muestre todos los controles en `true` y cero inconsistencias;
- la lista `PRUEBAS-PILOTO-v2.7.md` esté completada sin fallas bloqueantes;
- exista un backup recuperable de base y Storage;
- la configuración operativa de la aplicación figure completa;
- el cliente haya aceptado por escrito el alcance, la privacidad, la conservación y que el remito original sigue siendo responsabilidad de su empresa.
