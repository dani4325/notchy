# Cómo publicar una versión

## Claves

Hay dos secretos. Viven en el **llavero de inicio de sesión** del Mac donde se publica, y su copia de seguridad en una carpeta de claves que guardas tú, fuera del proyecto (un disco cifrado o un gestor de contraseñas). **Nunca los copies dentro del repositorio**: `.gitignore` bloquea `*.p12`, `*.pem`, `*private-key*`, `*password*` y las carpetas `secrets/` y `Notchy-claves-PRIVADAS/`, pero no dependas de ello.

| Archivo de la copia | Qué es | Dónde se usa | Si se pierde |
|---|---|---|---|
| `notchy-codesign.p12` + `p12-password.txt` | Certificado autofirmado «Notchy Self-Signed Code Signing» con el que se firma la app. | Llavero (`scripts/build-app.sh` lo busca por su nombre). | Las versiones nuevas tendrían otra firma: macOS volvería a pedir los permisos y Gatekeeper avisaría de nuevo. |
| `sparkle-eddsa-private-key.txt` | Clave privada EdDSA de Sparkle. | Llavero, cuenta `notchy` (`scripts/release.sh` la usa). | Las copias instaladas **no podrán actualizarse nunca más** con Sparkle. |

Los scripts no leen nunca la carpeta de copia: solo usan el llavero. Para restaurar los secretos en otro Mac, desde la carpeta donde guardes la copia:

```sh
CLAVES="/ruta/a/tu/carpeta/de/claves"
security import "$CLAVES/notchy-codesign.p12" -k ~/Library/Keychains/login.keychain-db \
  -P "$(cat "$CLAVES/p12-password.txt")" -T /usr/bin/codesign
./scripts/fetch-sparkle-tools.sh
tools/sparkle-2.10.0/bin/generate_keys --account notchy -f "$CLAVES/sparkle-eddsa-private-key.txt"
```

La primera vez que `codesign` use el certificado, macOS pedirá la contraseña del Mac: pulsa **Permitir siempre**.

Para comprobar que nada sensible está bajo seguimiento: `git ls-files | grep -iE '\.p12$|\.pem$|private-key|password'` no debe mostrar nada.

## Pasos de cada versión

1. Define las URL reales (o sustituye `TU_USUARIO` en `scripts/build-app.sh` y `scripts/release.sh`, los README y el cask):
   `export NOTCHY_REPO_URL=https://github.com/<usuario>/notchy`
   `export NOTCHY_FEED_URL=https://raw.githubusercontent.com/<usuario>/notchy/main/appcast.xml`
   El script se niega a publicar con `TU_USUARIO` (solo `NOTCHY_ALLOW_PLACEHOLDER=1` lo permite, para pruebas locales).
2. `./scripts/release.sh <versión> <build>`. El build es obligatorio y debe ser mayor que el último del `appcast.xml`, o Sparkle no ofrecería la actualización. El script se niega también si el certificado de firma no está en el llavero, y comprueba que la app salga firmada con él. Pasa los tests y la comprobación de idiomas, crea `dist/Notchy-<versión>.zip`, su `.sha256` y actualiza `appcast.xml` con la firma EdDSA.
3. Crea en GitHub la release `v<versión>` y sube el `.zip` y el `.sha256`. Usa como texto `docs/release-notes/<versión>.md`.
4. Haz commit y push de `appcast.xml`: es el archivo que Sparkle consulta.
5. `./scripts/update-cask.sh <versión>` y sube `packaging/homebrew/Casks/notchy.rb` al repositorio `homebrew-notchy`.
