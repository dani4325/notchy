# Consumo de Notchy

Medido con `top` (CPU, despertares del procesador e impacto energético que estima macOS) en un MacBook con chip M4 y macOS 27.0.1, con `scripts/measure-energy.sh`. Cada fila es la media de muestras cada 5 s. «Despertares» son los que el proceso provoca durante la medición; «Impacto» es la columna POWER de `top`, comparable entre procesos pero sin unidades físicas.

Notchy son dos procesos: la app y el adaptador de MediaRemote (`perl`), que solo emite cuando cambia la música.

| Escenario | Proceso | CPU media | CPU máx. | Impacto medio | Despertares | Memoria |
|---|---|---|---|---|---|---|
| Reposo (sin música, panel recogido, alas visibles) | Notchy | 0.00 % | 0.0 % | 0.00 | 1 en 60 s | 26M |
| Reposo (sin música, panel recogido, alas visibles) | perl | 0.00 % | 0.0 % | 0.00 | 0 en 60 s | 8385K |
