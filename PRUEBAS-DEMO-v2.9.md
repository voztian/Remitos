# Pruebas de la simulación v2.9

1. Ingresar como Administrador u Oficina.
2. Con la operación real incompleta, tocar **Probar circuito sin guardar**.
3. Confirmar que la franja dice que no se guarda ni envía información.
4. Iniciar el viaje de prueba y verificar el estado **En camino**.
5. Simular la llegada y revisar los dos ítems.
6. Marcar uno completo y otro con faltante.
7. Confirmar que aparecen datos ficticios y firma de prueba.
8. Dibujar una firma y cerrar la entrega simulada.
9. Confirmar el mensaje **Prueba completada**.
10. Salir y verificar que Dashboard, Remitos e Historial siguen con cero datos si estaban vacíos antes.

La simulación nunca debe ejecutar llamadas `insert`, `update`, `delete`, Storage ni RPC de escritura.
