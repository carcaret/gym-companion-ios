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

- [x] `e2e/view-nav-buttons.spec.js` (de #8): los 11 de Hoy en #9 y los 4 del historial en #10;
      el fichero ya está en el cruce.
- [x] `unit/builders.test.js` y `unit/bar-colors.test.js` (de #10) se portaron en #9: la tira de
      historial también sale en las tarjetas de Hoy. En #10 solo queda pintarla en el detalle.

## Por sub-issue

### #7 Sincronización con GitHub

Hecho y probado en Docker (600 tests, con la ida y vuelta del `db.json` real idéntica) y en el CI.
Falta lo que necesita el iPhone o el NAS:

- [ ] El Llavero en el iPhone firmado con la cuenta gratuita: guardar el token desde los ajustes (#14)
      y comprobar que sigue tras cerrar la app y tras una reinstalación de ios-signer. Si
      `SecItemAdd` falla en el iPhone (`KeychainError`), mirar si plumesign pone
      `keychain-access-groups` en los entitlements; la salida sería firmar ad hoc con un
      `.entitlements` como en #3.
- [ ] Sincronización real contra `carcaret/gym-companion`: configurar en los ajustes (#14) con un PAT
      con permiso de escritura en ese repo. Con la app vacía, configurar **baja** los datos (no
      sube nada). Comprobar después que un cambio en la app crea un commit "Gym Companion update
      AAAA-MM-DD" y que el diff solo muestra lo cambiado (el primer commit reordena las claves de
      `exercises` por id: es normal, la app las escribe en orden alfabético).
- [ ] Que la PWA lee bien el `db.json` que escribe la app (abrirla tras una subida de la app).
- [ ] Segundo plano: hacer un cambio fuera de un entreno y bloquear el iPhone en menos de 500 ms;
      el commit debe llegar igual (tarea en segundo plano de `UIKitBackgroundActivity`).

### #8 Navegación

- [ ] Ver en el iPhone las cuatro pestañas (Rutinas, Historial, Progreso, Gráficas) con el
      indicador de sincronización arriba a la derecha; en sus ajustes (menú del indicador), la
      versión y la compilación.

### #9 Hoy

- [ ] Entrenar de verdad con la app un día en el gimnasio: elegir rutina, ajustar pesos y reps con
      una mano, cambiar un ejercicio, terminar. Mirar sobre todo:
  - que los campos de peso, series y objetivo aceptan lo tecleado al tocar fuera;
  - que arrastrar para reordenar funciona en la lista (mantener pulsada la tarjeta);
  - que el aviso "Entreno guardado localmente" sale si no hay red al terminar.
- [ ] Deslizar una tarjeta del entreno a la derecha enseña "Cambiar por otro" y "Saltar" sin hacer
      nada aunque se deslice del todo; a la izquierda, quitarla pide confirmación.
- [ ] Ver que la PWA lee bien el entreno que sube la app (lo mismo que en #7, ahora con datos de un
      entreno de verdad).

### #10 Historial

- [ ] En el iPhone: abrir una sesión pasada, corregir un peso, "Guardar" y comprobar que el cambio
      sube a GitHub (un commit nuevo en `db.json`). Cerrar la tarjeta sin guardar no debe cambiar
      nada.
- [ ] Deslizar una sesión a la izquierda para borrarla pide confirmación.

### #11 Gráficas

- [ ] En el iPhone: elegir un ejercicio y ver las dos gráficas (1RM estimado y peso); tocar la
      gráfica enseña el valor del punto. Cambiar las fechas con los selectores.

### #12 Progreso

- [ ] Con los datos reales: la tarjeta de ejercicios dice cuántos hay estancados y la de grupos
      pinta las barras con la franja de 32–80 series. "Ver en Gráficas" abre Gráficas con el
      ejercicio elegido y el botón de volver.

### #13 Catálogo

- [ ] Renombrar un ejercicio y comprobar que el nombre nuevo sale en Rutinas y que llega a
      `db.json` (y que la PWA lo enseña también).

### #14 Ajustes

- [ ] **Primera configuración de verdad** (hace falta para todo lo de #7): en los ajustes (menú del indicador → «Configurar GitHub»), repositorio
      `carcaret/gym-companion`, rama `master`, ruta `db.json` y un PAT con permiso de escritura
      en ese repo. Con la app vacía, "Guardar" baja los datos; comprobar que salen las 297+
      sesiones en Historial.
- [ ] Guardar los ajustes con un token malo da "GitHub no acepta el token de acceso. Revisa el token, el repositorio y la rama."
- [ ] Teclado (PR #32): escribir en un campo y tocar fuera lo cierra y vuelve la barra de
      pestañas; también desplazar la pantalla. Probarlo además en las
      reps del entreno, el buscador de Gráficas y el editor del Catálogo.

### #15 Paridad y paso definitivo

Hecho fuera del NAS: la tabla global (`docs/paridad.md`, 829 de 829 tests de la PWA portados o
justificados) y `CLAUDE.md` al día. Falta, y es del usuario:

- [ ] Entrenar una semana solo con la app nativa y decir si se echa algo en falta.
- [ ] Decidir el futuro de la PWA (archivarla, dejarla de solo lectura…) y, si se retira, si
      cambia el formato de `db.json` y si los datos pasan a un repo privado (hoy están en el
      repo público `carcaret/gym-companion`).
- [ ] Cerrar #15 y la épica #1 cuando lo anterior esté hecho.

### #16 App del Apple Watch

Hecho y probado en Docker (la lógica del reloj, en el paquete) y en el CI (compilación y capturas
del simulador del Series 10 de 46 mm). Falta lo que necesita el NAS o el reloj en la mano:

- [ ] **ios-signer instala la app del reloj** (repo `home-nas`, lo que dice #2): tras instalar la
      de iOS, si la `.ipa` firmada trae `Payload/GymCompanion.app/Watch/*.app`, empaquetarla sola
      e instalarla en el reloj por el companion proxy y `streaming_zip_conduit`; tomar el perfil de
      `Payload/GymCompanion.app/embedded.mobileprovision` exactamente (ahora hay dos); y la
      reinstalación en el reloj al renovar a los 7 días.
- [ ] **WatchConnectivity con la app instalada directamente en el reloj**: con un entreno en curso
      en el iPhone, el reloj enseña sus ejercicios; al cambiar un peso o unas reps en el iPhone,
      el reloj se pone al día; al terminar el entreno, dice "Sin entreno en curso". Nadie documenta
      si WatchConnectivity empareja una app del reloj que no instaló el iPhone: si no, la salida es
      que el reloj lea el `db.json` de GitHub él mismo (otro adaptador del mismo `WatchModel`).
