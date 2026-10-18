# Notchy

Convierte el notch de tu MacBook en un panel tipo Dynamic Island que puedes vestir con tus propias imágenes, GIFs y vídeos.

- Requisitos: macOS 15 o posterior. Apple Silicon.
- Sin notch (monitor externo o Mac sin notch): muestra una píldora flotante, o nada, según los ajustes.
- La app no incluye arte de ninguna serie. Cada tema lo montas tú con tus archivos.

## Instalar

1. Descarga el `.zip` de la última versión en **Releases** y descomprímelo.
2. Arrastra `Notchy.app` a **Aplicaciones**.
3. Ábrela con doble clic. No tiene icono en el Dock: aparece en la barra de menús, arriba a la derecha.

### La primera vez: aviso de Gatekeeper

La app está firmada *ad-hoc*: no está notarizada por Apple porque no se distribuye con cuenta de desarrollador. Por eso la primera vez macOS dirá que **no puede verificar** la app. Es normal. Para abrirla:

1. Haz doble clic en la app y pulsa **OK** (o **Listo**) en el aviso. No la muevas a la papelera.
2. Abre **Ajustes del Sistema → Privacidad y seguridad**.
3. Baja hasta la sección **Seguridad**. Verás «Se ha bloqueado el uso de Notchy…». Pulsa **Abrir igualmente**.
4. Confirma con tu contraseña o Touch ID y pulsa **Abrir**.

Solo hace falta una vez. Desde macOS 15, el truco antiguo de *Control + clic → Abrir* ya no evita este aviso.

**Alternativa por Terminal**, si prefieres no pasar por Ajustes. Quita la marca de cuarentena de la descarga:

```sh
xattr -dr com.apple.quarantine /Applications/Notchy.app
```

> Pasos según el flujo que Apple documenta desde macOS 15. Aún no los he verificado con una descarga real en macOS 27; los nombres de los menús pueden variar ligeramente.

## Compilar desde el código

Necesitas las Command Line Tools de Xcode o Xcode completo.

```sh
./scripts/build-app.sh   # compila y genera build/Notchy.app (firmada ad-hoc)
./scripts/run.sh         # compila, cierra la instancia anterior y abre la app
swift test               # tests
```

## Créditos y licencias

- Now Playing mediante [MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter) © 2025 Jonas van den Berg y colaboradores, licencia BSD-3-Clause.
- Inspirado en las técnicas de [boring.notch](https://github.com/TheBoredTeam/boring.notch). No incluye código suyo.

Documentación del desarrollo: [docs/FASE0.md](docs/FASE0.md), [docs/BRIEF.md](docs/BRIEF.md).
