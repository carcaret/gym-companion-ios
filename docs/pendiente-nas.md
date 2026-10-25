# Pendiente para terminar en el NAS

Lo que Claude no pudo hacer al avanzar la épica #1 fuera del NAS (sesión del 2026-10-25, en un
portátil tratado como un PC con Windows: sin Xcode ni `swift` local, solo Docker y `gh`). Cada
sub-issue añade aquí lo que deja sin hacer. Al terminarlo en el NAS, se tacha (`[x]`) y, cuando no
quede nada, se borra este fichero.

## Cómo se trabajó fuera del NAS

- Tests del paquete: `sh Packages/GymCore/test.sh` con Docker (`swift:6.3.3`), igual que en el
  NAS. La PWA se clonó en `~/git/gym-companion` para el cruce de tests y el `db.json` real.
- La app (vistas SwiftUI, Llavero, XCUITest y capturas) solo la compila y prueba el CI (`app`).
- Nada del NAS: ni `ios-signer`, ni su log, ni el iPhone.

## Comprobaciones que solo se pueden hacer desde el NAS

Para cada PR fusionada, después de que el CI publique la release:

- [ ] `tail /volume1/docker/ios-signer/data/ios-signer.log`: "Instalada la compilación N" con la
      última compilación (la N es la del run de `master` de cada fusión).
- [ ] Los datos de la app se conservan tras la reinstalación (pendiente desde #6: comprobar con
      `house_arrest` antes y después de una instalación que `Application Support/GymCompanion/`
      sigue ahí).

## Por sub-issue

### #7 Sincronización con GitHub

(se rellena al cerrar la PR)
