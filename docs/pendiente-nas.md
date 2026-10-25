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

## Trabajo que pasa de una issue a otra

Para que no se pierda nada al repartir tests entre issues:

- [ ] `e2e/view-nav-buttons.spec.js` (de #8): los 11 de Hoy ya están portados o en el TSV (#9).
      Faltan los 4 de "history detail", con Historial en #10; entonces se añade el fichero a
      `docs/pwa-tests-ficheros.txt` (el cruce falla si queda alguno sin portar).
- [x] `unit/builders.test.js` y `unit/bar-colors.test.js` (de #10) se portaron en #9: la tira de
      historial también sale en las tarjetas de Hoy. En #10 solo queda pintarla en el detalle.

## Por sub-issue

### #7 Sincronización con GitHub

Hecho y probado en Docker (600 tests, con la ida y vuelta del `db.json` real idéntica) y en el CI.
Falta lo que necesita el iPhone o el NAS:

- [ ] El Llavero en el iPhone firmado con la cuenta gratuita: guardar el token desde Ajustes (#14)
      y comprobar que sigue tras cerrar la app y tras una reinstalación de ios-signer. Si
      `SecItemAdd` falla en el iPhone (`KeychainError`), mirar si plumesign pone
      `keychain-access-groups` en los entitlements; la salida sería firmar ad hoc con un
      `.entitlements` como en #3.
- [ ] Sincronización real contra `carcaret/gym-companion`: configurar en Ajustes (#14) con un PAT
      con permiso de escritura en ese repo. Con la app vacía, configurar **baja** los datos (no
      sube nada). Comprobar después que un cambio en la app crea un commit "Gym Companion update
      AAAA-MM-DD" y que el diff solo muestra lo cambiado (el primer commit reordena las claves de
      `exercises` por id: es normal, la app las escribe en orden alfabético).
- [ ] Que la PWA lee bien el `db.json` que escribe la app (abrirla tras una subida de la app).
- [ ] Segundo plano: hacer un cambio fuera de un entreno y bloquear el iPhone en menos de 500 ms;
      el commit debe llegar igual (tarea en segundo plano de `UIKitBackgroundActivity`).

### #8 Navegación

- [ ] Ver en el iPhone las cinco pestañas (Rutinas, Historial, Progreso, Gráficas, Ajustes) con
      el indicador de sincronización arriba a la derecha; en Ajustes, la versión y la compilación.

### #9 Hoy

- [ ] Entrenar de verdad con la app un día en el gimnasio: elegir rutina, ajustar pesos y reps con
      una mano, cambiar un ejercicio, terminar. Mirar sobre todo:
  - que los campos de peso, series y objetivo aceptan lo tecleado al tocar fuera o "OK";
  - que arrastrar para reordenar funciona en la lista (mantener pulsada la tarjeta);
  - que el aviso "Entreno guardado localmente" sale si no hay red al terminar.
- [ ] Ver que la PWA lee bien el entreno que sube la app (lo mismo que en #7, ahora con datos de un
      entreno de verdad).
