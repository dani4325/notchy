# Consumo de Notchy

Medido con `top` (CPU, despertares del procesador e impacto energético que estima macOS) en un MacBook con chip M4 y macOS 27.0.1, con `scripts/measure-energy.sh`. Cada fila es la media de muestras cada 5 s. «Despertares» son los que el proceso provoca durante la medición; «Impacto» es la columna POWER de `top`, comparable entre procesos pero sin unidades físicas.

Notchy son dos procesos: la app y el adaptador de MediaRemote (`perl`), que solo emite cuando cambia la música.

| Escenario | Proceso | CPU media | CPU máx. | Impacto medio | Despertares | Memoria |
|---|---|---|---|---|---|---|
| Reposo (sin música, panel recogido, alas visibles) | Notchy | 0.00 % | 0.0 % | 0.00 | 1 en 60 s | 26M |
| Reposo (sin música, panel recogido, alas visibles) | perl | 0.00 % | 0.0 % | 0.00 | 0 en 60 s | 8385K |

## Límites

Antes de cada versión se mide cada escenario durante 60 s. Si alguno supera su límite, la versión no se publica.

| Escenario | Límite de CPU media de Notchy |
|---|---|
| Panel cerrado | 0 % (sin despertares periódicos) |
| Panel abierto sin música | menos de 0,5 % |
| Panel abierto con música y visualizador | menos de 3 % |

## Mediciones del 19 de octubre de 2026 (antes de la 1.1.0)

MacBook con chip M4, macOS 27.0.1, enchufado. Cada fila son 60 s con `top`, muestras cada 5 s. «Con música» significa que Safari reproducía audio y el panel mostraba el visualizador.

| Escenario | Fondo | CPU media | Despertares | Memoria |
|---|---|---|---|---|
| Panel cerrado | imagen | 0,10 % | 2 en 60 s | 21 MB |
| Panel cerrado | GIF (57 fotogramas, 540 × 400) | 0,05 % | 0 en 60 s | 31 MB |
| Panel cerrado | vídeo | 0,01 % | 2 en 60 s | 20 MB |
| Panel abierto, sin música | sin fondo | 0,23 % | 5 en 60 s | 27 MB |
| Panel abierto, sin música | imagen | 0,00 % | 5 en 60 s | 35 MB |
| Panel abierto, sin música | GIF | 0,00 % | 10 en 60 s | 128 MB |
| Panel abierto, sin música | el mismo GIF convertido a vídeo | 0,00 % | 1 en 60 s | 25 MB |
| Panel abierto, sin música | vídeo | 0,00 % | 0 en 60 s | 25 MB |
| Panel abierto, con música | sin fondo | 15,66 % | 0 en 60 s | 26 MB |
| Panel abierto, con música | imagen | 15,57 % | 4 en 60 s | 32 MB |
| Panel abierto, con música | GIF | 15,12 % | 0 en 60 s | 124 MB |
| Panel abierto, con música | vídeo | 12,23 % | 2 en 60 s | 27 MB |

Lo que muestran:

- El fondo no gasta CPU en el proceso de Notchy. El GIF se anima con Core Animation y el vídeo lo decodifica el sistema, así que ese trabajo lo hacen `WindowServer` y `VTDecoderXPCService`. Midiendo esos procesos con una ventana de prueba, la diferencia entre GIF, vídeo y ninguna animación quedó por debajo del ruido de otro vídeo que se reproducía en Safari (±0,7 %). No está medida por separado.
- El GIF ocupa 128 MB porque se descomprimen todos sus fotogramas. Convertido a vídeo, 25 MB.
- Con música el panel gasta un 15 %. Según el perfil (`sample`, 10 s), el código de Notchy apenas cuenta (68 de 4.040 muestras del hilo principal). El gasto está en volver a pintar por software toda la columna de texto en cada fotograma del visualizador, porque una sombra de texto la convertía en una sola capa, y en la animación continua de la barra de progreso.

## Mediciones tras los cambios del 19 de octubre de 2026

Mismo equipo y método. Cambios: sin sombra de texto en la columna, visualizador dibujado con capas propias de Core Animation que reciben los niveles sin pasar por SwiftUI, y barra de progreso que se actualiza una vez por segundo con una transición lineal de Core Animation.

| Escenario | CPU media | CPU máx. | Despertares | Límite |
|---|---|---|---|---|
| Panel abierto con música y visualizador (tu tema, fondo GIF) | 1,65 % | 1,9 % | 0 en 60 s | menos de 3 % ✓ |
| Panel abierto sin música | 0,00 % | 0,0 % | 9 en 60 s | menos de 0,5 % ✓ |
| Panel cerrado, tras mostrar y ocultar el aviso de volumen | 0,00 % | 0,0 % | 3 en 60 s | 0 % ✓ |

Prueba controlada de las barras del visualizador (ventana de prueba, 6 barras, 30 niveles por segundo, 60 s): pasando por SwiftUI, 2,92 % de CPU; directo a las capas, 1,00 %.

La memoria del panel abierto con tu tema sigue en 126-131 MB porque su fondo es un GIF importado antes de la conversión a vídeo. Un GIF importado ahora se guarda como vídeo (25 MB en la prueba con ese mismo GIF).
