# Tap de Homebrew de Notchy

Este directorio es la plantilla del repositorio `TU_USUARIO/homebrew-notchy`.

1. Crea en GitHub un repositorio público llamado `homebrew-notchy` y sube `Casks/notchy.rb`.
2. Sustituye `TU_USUARIO` por tu usuario de GitHub en el cask.
3. En cada versión, después de subir el `.zip` a Releases, ejecuta desde la raíz del proyecto:
   `./scripts/update-cask.sh <versión>` y sube el cask actualizado al tap.

Los usuarios instalan con:

```sh
brew tap TU_USUARIO/notchy
brew install --cask notchy
```

Normas de Homebrew aplicadas (comprobadas en octubre de 2026):
- Desde el 1 de septiembre de 2026, Homebrew desactiva en `Homebrew/homebrew-cask` los casks que no pasan Gatekeeper. En un tap propio no hace falta firmar.
- `--no-quarantine` se ha retirado. Por eso el cask no quita la cuarentena y avisa en `caveats` del paso de Gatekeeper.
