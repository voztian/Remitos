# Pruebas de aceptación — GoRemitos v2.6

Fecha: __________  Responsable: __________  Deployment: __________

Usá datos ficticios y dos perfiles de navegador distintos. No cargues firmas,
DNI ni fotos reales hasta aprobar todos los controles P0 y P1.

## P0 — bloqueantes de seguridad y datos

| # | Prueba | Resultado esperado | Estado |
|---|---|---|---|
| P0.1 | Ejecutar `supabase-verificacion-v2.6.sql` | Todos `true`, cero funciones inseguras; permisos `anon_*` en `false` | ☐ |
| P0.2 | Abrir sin sesión | No muestra empresa, remitos, usuarios ni evidencias | ☐ |
| P0.3 | Ingresar con Google no autorizado | No obtiene perfil ni datos de ninguna empresa | ☐ |
| P0.4 | Autorizar email en Empresa A e intentar usarlo también en B | La segunda autorización es rechazada | ☐ |
| P0.5 | Chofer de A intenta abrir remito o evidencia de B | Acceso denegado | ☐ |
| P0.6 | Oficina intenta abrir Usuarios | No recibe emails ni administración de accesos | ☐ |
| P0.7 | Eliminar usuario activo | Pierde acceso; los cerrados quedan; los pendientes quedan sin chofer | ☐ |
| P0.8 | Intentar eliminarse o eliminar el último admin | La operación es rechazada | ☐ |
| P0.9 | Cerrar entrega con firma/foto | Storage queda privado; el PDF verifica hash y abre la imagen correcta | ☐ |
| P0.10 | Alterar o borrar una constancia cerrada desde la aplicación | No existe opción; la base rechaza cambios | ☐ |
| P0.11 | Forzar pérdida de red antes de guardar | No guarda parcialmente y conserva el formulario abierto | ☐ |
| P0.12 | Probar restauración de DB y una evidencia en entorno no productivo | La copia se puede recuperar y relacionar | ☐ |
| P0.13 | Intentar subir una evidencia final mayor a 5 MB | Storage la rechaza antes de guardarla | ☐ |
| P0.14 | Intentar reutilizar la misma foto en dos remitos manuales | La segunda constancia es rechazada | ☐ |
| P0.15 | Activar Turnstile y probar ingreso/recuperación con y sin desafío | Sin token se bloquea; con token válido Supabase continúa | ☐ |
| P0.16 | Intentar cerrar simultáneamente dos remitos manuales con la misma evidencia | Sólo uno se guarda; el segundo rechaza la reutilización | ☐ |

Cualquier falla P0 impide entregar el sistema a clientes.

## P1 — flujo operativo

| # | Prueba | Resultado esperado | Estado |
|---|---|---|---|
| P1.1 | Abrir con tema claro y oscuro, móvil y escritorio | Todos los botones tienen texto/ícono visible y foco claro | ☐ |
| P1.2 | Google con email autorizado | Pide nombre una vez y muestra nombre, empresa y rol | ☐ |
| P1.3 | Recuperar contraseña | Pide el email, envía enlace al dominio correcto y exige repetir la nueva contraseña | ☐ |
| P1.4 | Autorizar Chofer, Oficina y Admin | Cada uno aparece con su rol y sólo ve sus opciones | ☐ |
| P1.5 | Cambiar Chofer a Oficina con remito pendiente | Remito queda sin asignar y avisa cuántos se deben reasignar | ☐ |
| P1.6 | Crear y editar remito pendiente | Valida campos, número duplicado, cantidades y chofer activo | ☐ |
| P1.7 | Entrega conforme | Exige receptor, DNI, revisión de ítems, información y firma | ☐ |
| P1.8 | Entrega disconforme | Conserva observación, cantidades y evidencias | ☐ |
| P1.9 | Entrega rechazada | Exige motivo y no admite firma de conformidad | ☐ |
| P1.10 | Remito manual | Foto obligatoria, hash registrado, constancia cerrada | ☐ |
| P1.11 | Historial con más de 100 remitos | Totales correctos y botón Cargar más sin duplicados | ☐ |
| P1.12 | Error simulado de carga | Muestra error y Reintentar; no lo presenta como lista vacía | ☐ |
| P1.13 | Cerrar sesión y volver | No quedan datos de otra cuenta visibles | ☐ |
| P1.14 | Sesión inactiva | Admin/Oficina cierra a 2 h; Chofer a 8 h | ☐ |

## P2 — operación y soporte

| # | Prueba | Resultado esperado | Estado |
|---|---|---|---|
| P2.1 | Abrir `/privacidad.html` sin sesión | Muestra responsable, canales y política completa | ☐ |
| P2.2 | Dejar incompletos datos legales | Creación y cierre de remitos permanecen bloqueados | ☐ |
| P2.3 | Dejar una casilla operativa sin marcar | El piloto permanece bloqueado | ☐ |
| P2.4 | Generar un error autenticado | Aparece para admin de plataforma y no para admins de clientes | ☐ |
| P2.5 | Abrir versión después de haber usado v2.3/v2.5 | No reaparece interfaz vieja; el caché `remitos-*` se elimina | ☐ |
| P2.6 | Chrome Android y Safari iPhone actuales | Cámara, firma, Google y PDF funcionan | ☐ |

## Criterio de aprobación

- P0: 100 % aprobado.
- P1: 100 % aprobado antes de cliente real.
- P2: P2.1 a P2.5 aprobados; P2.6 probado en los dispositivos que usarán los
  primeros choferes.
- Cada evidencia de prueba tiene fecha, navegador, cuenta/rol y captura sin
  datos personales reales.

Resultado final: ☐ APROBADO  ☐ NO APROBADO

Observaciones: _______________________________________________________________
