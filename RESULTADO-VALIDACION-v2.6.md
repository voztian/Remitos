# Resultado de validación técnica — GoRemitos v2.6

Fecha de build: 18 de agosto de 2026

## Controles ejecutados sobre el paquete

- JavaScript de `index.html` y `privacidad.html`: sintaxis válida.
- HTML: validación estructural sin errores.
- JSON de manifest y Vercel: válido.
- Referencias a archivos: todas resuelven dentro del paquete.
- Dependencias principales: locales y versionadas. Turnstile carga únicamente
  el runtime oficial de Cloudflare cuando la protección está configurada.
- Búsqueda de secretos: sólo se incluye la clave pública `sb_publishable`.
- SQL: análisis sintáctico PostgreSQL correcto.
- Migración completa v2.2 → v2.5 → v2.5.2 → v2.6 ejecutada en PostgreSQL 17
  aislado con esquemas compatibles de prueba.
- Verificación v2.6: 30 controles aprobados.
- Segunda ejecución de la migración sobre el mismo esquema: aprobada sin
  duplicar ni romper objetos.
- Compuerta operativa: rechaza guardados antes de completar preparación.
- Accesos: alta de una empresa cliente, incorporación de su administrador,
  autorización de un chofer y revocación inmediata aprobadas.
- Aislamiento: un administrador de cliente no pudo autorizar empresas ni leer
  accesos o remitos de otra empresa.
- Subidas: bloqueadas antes de la preparación operativa y limitadas a 5 MB.
- Ruta de evidencia normal: aceptada.
- Ruta de remito manual: aceptada.
- Flujo de prueba: creación, carga de evidencias, hash, cierre e inmutabilidad
  aprobados.
- Respaldo manual: evidencia verificada, constancia cerrada, reutilización
  rechazada y dos intentos simultáneos serializados.
- DOM: carga inicial, ingreso y recuperación navegables sin error JavaScript.
- Turnstile: ingreso, recuperación y alta envían su token a Supabase.
- Service worker anterior: caché `remitos-*` retirado por la versión nueva.

## Lo que debe validarse en el proyecto real

El entorno aislado no reemplaza estas pruebas externas:

- envío real por SMTP;
- OAuth Google con la pantalla de consentimiento de producción;
- CAPTCHA;
- permisos y versión efectiva del proyecto Supabase alojado;
- backup/restauración real de base y Storage;
- cámara y firma en los teléfonos de los choferes;
- Vercel con cabeceras de producción;
- texto legal y contratos de la actividad.

La política CSP limita orígenes, marcos, objetos y conexiones. La aplicación
monolítica todavía requiere estilos y manejadores de eventos en línea; por eso
la CSP no reemplaza la revisión de entradas ni las pruebas de penetración. Esta
limitación queda aceptada sólo para el piloto controlado y debe reevaluarse
antes de una apertura masiva.

Por eso la aplicación conserva bloqueadas las operaciones hasta completar la
preparación y `PRUEBAS-PILOTO-v2.6.md`.
