# GoRemitos v2.8 — escritorio adaptable

Esta versión conserva completo el circuito seguro de v2.7 y agrega una interfaz realmente adaptada a computadoras, sin quitar la experiencia móvil:

- En pantallas de 900 px o más aparece un menú lateral con textos claros.
- El dashboard usa el ancho disponible y separa indicadores de actividad reciente.
- Remitos, usuarios y formularios se presentan en paneles amplios y ordenados.
- En celulares continúa la navegación inferior conocida.
- El cambio es solamente de interfaz: no modifica tablas, permisos, usuarios ni remitos.

El circuito operativo sigue siendo:

1. La empresa emite su remito en el sistema que ya utiliza.
2. Administración u oficina adjunta ese remito a GoRemitos en PDF o imagen.
3. Asigna la entrega a un chofer.
4. El chofer inicia el viaje; recién entonces el estado cambia de **Programado** a **En camino**.
5. El destinatario puede consultar el avance mediante un enlace limitado.
6. En destino, el chofer revisa la mercadería y registra conformidad, rechazo o diferencias, receptor, firma y evidencias.
7. GoRemitos cierra una constancia inmutable vinculada al hash del remito original.

## Qué es y qué no es

GoRemitos v2.8 es una plataforma de seguimiento y constancia digital de entregas asociada a un remito externo.

- No genera numeración fiscal.
- No solicita CAI/CAE.
- No imprime formularios fiscales.
- No reemplaza el remito que la empresa debe emitir según su actividad.
- Sí conserva una copia privada, registra el viaje y produce evidencia de entrega.

El archivo descargable que genera GoRemitos dice expresamente **“Constancia digital de seguimiento y entrega”**. No debe presentarse como Remito R ni como factura.

## Actualizar desde v2.7

**No tenés que entrar a Supabase ni ejecutar SQL.** La base segura de v2.7 se mantiene sin cambios.

1. Descomprimí el ZIP.
2. En GitHub, abrí el mismo repositorio `voztian/Remitos` y elegí **Add file → Upload files**.
3. Subí el contenido descomprimido a la raíz, reemplazando los archivos anteriores. No subas la carpeta contenedora ni el ZIP.
4. Mantené seleccionada la opción **Commit directly to the main branch**.
5. Usá como mensaje: `GoRemitos v2.8 - interfaz para escritorio`.
6. Tocá **Commit changes**.
7. Esperá a que Vercel muestre el deployment como **Ready / Production / Current**.
8. Abrí `goremitos.vercel.app` en una pestaña nueva. Si aparece la versión anterior, usá `Ctrl + F5` una vez.

Los archivos SQL v2.7 siguen incluidos sólo como respaldo y trazabilidad. No los vuelvas a ejecutar para instalar v2.8.

## Qué comprobar después de publicar

Hacé una prueba breve con datos de prueba:

1. En una computadora, confirmá que aparece el menú lateral y que abre Inicio, Remitos, Usuarios e Historial.
2. Tocá **Nuevo remito** y comprobá que el formulario sea amplio y legible.
3. Cambiá entre tema claro y oscuro.
4. Achicá la ventana por debajo de 900 px: debe volver automáticamente al diseño móvil con menú inferior.
5. En el celular, confirmá que iniciar con Google y navegar funciona igual que antes.

La lista específica de pantalla está en `PRUEBAS-ESCRITORIO-v2.8.md`. La aceptación funcional completa continúa en `PRUEBAS-PILOTO-v2.7.md` porque la lógica de datos no cambió.

## Prueba mínima antes de un cliente

Usá cuentas y documentos de prueba, sin datos reales:

1. Administrador: programá una entrega y adjuntá un PDF pequeño.
2. Abrí el enlace de seguimiento en incógnito: debe mostrar **Programado** y no debe pedir cuenta.
3. Chofer: abrí la entrega; todavía no debe permitir firmarla.
4. Tocá **Iniciar viaje**.
5. Volvé al enlace incógnito: debe mostrar **En camino** y la hora de salida.
6. Chofer: revisá todos los ítems y cerrá una entrega de prueba.
7. El enlace debe mostrar **Entregado**.
8. Administrador: comprobá que puede abrir el remito original, la constancia y la trazabilidad.
9. Confirmá que el enlace público no muestra domicilio, teléfono, ítems, documento, DNI, firma ni fotos.

La ventana incógnita se usa únicamente para comprobar que el seguimiento no
depende de la sesión del administrador. El destinatario puede abrir el enlace
normalmente en Chrome, Safari u otro navegador compatible.

La lista completa está en `PRUEBAS-PILOTO-v2.7.md`.

## Seguridad aplicada

- El remito original se guarda en un bucket privado separado.
- Sólo administración/oficina de la empresa pueden subirlo.
- Sólo administración/oficina de la empresa y el chofer asignado pueden leerlo.
- El archivo admite PDF, JPG, PNG o WebP y un máximo de 10 MB.
- El navegador comprueba extensión y firma interna del archivo; cambiarle el nombre a un ejecutable no alcanza para subirlo.
- Se calcula SHA-256 antes de subirlo y se vuelve a verificar al descargarlo.
- Un mismo objeto no puede asociarse a dos remitos.
- Una entrega iniciada ya no se puede editar ni eliminar.
- Un chofer con una entrega en camino no puede ser eliminado ni perder su rol
  hasta cerrar el viaje; así la entrega no queda sin una cuenta habilitada.
- Los RPC de escritura v2.6 quedan revocados para impedir que se saltee el documento o el inicio del viaje.
- El cierre incluye el hash y la metadata del documento original en el snapshot firmado.
- El seguimiento público usa un UUID aleatorio y devuelve un conjunto mínimo de campos.
- Los enlaces nuevos guardan ese UUID en el fragmento `#seguimiento=`, para que el hosting no reciba el token; los enlaces anteriores siguen abriendo.
- Evidencias, firma y documentos se entregan a usuarios internos mediante URL firmada de corta duración.
- RLS continúa aislando empresas y roles.

## Operación y límites

- No existe sincronización offline. Sin conexión, no se puede iniciar ni cerrar una entrega.
- El modo **Manual** sirve como contingencia: se conserva el papel firmado y se carga una foto al recuperar conexión.
- El enlace público es un enlace portador: quien lo recibe puede ver el estado mínimo. Debe compartirse sólo con las personas involucradas.
- El hash calculado en el navegador permite detectar cambios posteriores, pero no sustituye una firma digital certificada ni una certificación notarial.
- La captura de firma es firma electrónica, no firma digital certificada.
- La validación de formato no es un antivirus. Durante el piloto, adjuntá únicamente documentos exportados por sistemas y equipos confiables; el análisis antimalware del lado servidor queda fuera de esta etapa.
- Para uso con datos reales deben completarse los datos legales, la política de conservación, SMTP, OAuth, CAPTCHA y la rutina de backups ya previstas en v2.6.

Al 2 de septiembre de 2026, Supabase Free ofrece 1 GB de Storage, OAuth social, SMTP personalizado, RLS y Realtime, pero puede pausar proyectos tras una semana de inactividad y no incluye backups automáticos. Pro parte de USD 25 por mes, evita esas pausas e incluye backups diarios de base por 7 días. Fuente: https://supabase.com/pricing.

La aplicación permite elegir **Supabase Pro** o **Piloto controlado en Free**. Free exige aceptar expresamente ese riesgo y marcar como verificados los backups externos tanto de base como de Storage. La elección del plan responde a continuidad y recuperación; no cambia la naturaleza fiscal del documento.

## Archivos principales

- `index.html`: aplicación v2.8 adaptable a escritorio y celular.
- `supabase-migration-v2.7.sql`: actualización transaccional desde v2.6.
- `supabase-finalizar-v2.7.sql`: bloqueo de métodos anteriores después del deployment.
- `supabase-reversion-emergencia-v2.7.sql`: retorno no destructivo a v2.6 si no hay viajes en curso.
- `supabase-verificacion-v2.7.sql`: controles posteriores.
- `PRUEBAS-PILOTO-v2.7.md`: aceptación antes de habilitar clientes.
- `RESULTADO-VALIDACION-v2.7.md`: controles superados, riesgos residuales y condición exacta de salida.
- `OPERACION-Y-BACKUPS-v2.7.md`: rutina de continuidad para la base y los dos buckets privados.
- `CAMBIOS-v2.7.md`: detalle funcional y técnico.
- `ALCANCE-ETAPA-1-v2.7.md`: límite de producto de esta etapa.
- `PRIVACIDAD-Y-CONTRATOS-v2.7.md`: puntos que deben acordarse con cada cliente antes del piloto.
- `privacidad.html`: política actualizada.
- `vercel.json` y `_headers`: encabezados de seguridad y caché.
- `PRUEBAS-ESCRITORIO-v2.8.md`: aceptación visual y responsive de esta versión.
- `CAMBIOS-v2.8.md`: detalle de la actualización de interfaz.
- `tests/verificar-paquete.mjs`: validación local integral; también ejecuta las pruebas de lógica de v2.7.

Los archivos de migraciones anteriores se conservan únicamente para una instalación nueva y para trazabilidad. Una instalación que ya funciona con v2.7 no requiere ningún cambio en Supabase para pasar a v2.8.
