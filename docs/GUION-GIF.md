# Guion del GIF de demostración (15–20 s)

Graba con **Cmd + Mayús + 5 → Grabar parte seleccionada**, encuadrando la parte superior central de la pantalla (unos 900 × 300 px alrededor del notch). Prepara antes:
- Spotify o Música con una canción con carátula, en pausa.
- La plantilla **Steins;Gate** activa y un archivo en el escritorio.
- Accesibilidad concedida (para el HUD de volumen) y el cargador desenchufado.
- El escritorio limpio, con un fondo oscuro.

| Seg. | Acción | Qué se ve |
|---|---|---|
| 0–2 | Pulsa play en el teclado (F8). | Aparecen las alas con la carátula junto al notch. |
| 2–5 | Pasa el ratón por el notch y quédate quieto. | El panel se abre con el glitch: carátula, visualizador, tubos nixie. |
| 5–7 | Pulsa siguiente canción en el panel. | Cambia carátula y título. |
| 7–10 | Saca el ratón. Abre Ajustes → Temas, elige **Attack on Titan** y pulsa **Probar apertura**. *(Si sale demasiado largo, salta este paso y cambia el tema antes de grabar.)* | El portón se abre en la vista previa. |
| 10–13 | Arrastra el archivo del escritorio al notch. | El panel se abre en modo estantería y el archivo queda guardado. |
| 13–15 | Enchufa el cargador. | El notch muestra la batería cargando con la apertura del tema. |
| 15–18 | Sube el volumen dos veces. | El medidor de volumen del tema sustituye al de macOS. |

Después, convierte el vídeo en GIF de unos 800 px de ancho y 20 fps, por ejemplo con `ffmpeg -i demo.mov -vf "fps=20,scale=800:-1:flags=lanczos" -loop 0 demo.gif`, y guárdalo como `docs/images/demo.gif`.
