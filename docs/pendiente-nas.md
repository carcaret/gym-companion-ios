# Pendiente para terminar en el NAS

Lo que queda por comprobar desde el NAS o con el iPhone en la mano: la app solo se compila y se
prueba en el CI. Al comprobarlo, se borra la línea; cuando no quede nada, el fichero.

## Comprobaciones que solo se pueden hacer desde el NAS

- [ ] Los datos de la app se conservan tras la reinstalación (pendiente desde #6: comprobar con
      `house_arrest` antes y después de una instalación que `Application Support/GymCompanion/`
      sigue ahí).

## Por sub-issue

### #7 Sincronización con GitHub

Hecho y probado en Docker (con la ida y vuelta del `db.json` real idéntica) y en el CI.
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
  - que, sin red al terminar, la nube se queda en amarillo y sube sola al volver la red.
- [ ] Deslizar una tarjeta del entreno a la derecha enseña "Cambiar por otro" y "Saltar" sin hacer
      nada aunque se deslice del todo; a la izquierda, quitarla pide confirmación.
- [ ] Ver que la PWA lee bien el entreno que sube la app (lo mismo que en #7, ahora con datos de un
      entreno de verdad).

### #10 Historial

- [ ] En el iPhone: abrir una sesión pasada, «Editar», corregir un peso, la ✓ y comprobar que el
      cambio sube a GitHub (un commit nuevo en `db.json`). La ✕ con cambios pregunta antes de
      tirarlos y no cambia nada.
- [ ] Deslizar una sesión a la izquierda para borrarla pide confirmación.

### #11 Gráficas

- [ ] En el iPhone: elegir un ejercicio y ver las dos gráficas (1RM estimado y peso); tocar la
      gráfica enseña el valor del punto. Cambiar las fechas con los selectores.

### #12 Progreso

- [ ] Con los datos reales: la sección de ejercicios dice cuántos hay estancados y la de grupos
      pinta las barras con la franja de 32–80 series. «Ver en Gráficas» abre las gráficas del
      ejercicio y se vuelve con la flecha.

### #13 Catálogo

- [ ] Renombrar un ejercicio y comprobar que el nombre nuevo sale en Rutinas y que llega a
      `db.json` (y que la PWA lo enseña también).

### #14 Ajustes

- [ ] **Primera configuración de verdad** (hace falta para todo lo de #7): en los ajustes (menú del indicador → «Configurar GitHub…»), repositorio
      `carcaret/gym-companion` y un PAT con permiso de escritura en ese repo (rama `master` y ruta
      `db.json`, en «Avanzado», ya vienen puestas). Con la app vacía, la ✓ baja los datos; comprobar que salen las 297+
      sesiones en Historial.
- [ ] La ✓ con un token malo da "GitHub no acepta el token de acceso. Revisa el token, el repositorio y la rama."
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
      en el iPhone, el reloj enseña sus ejercicios; al cambiar un peso, quitar o saltar un
      ejercicio en el iPhone, el reloj se pone al día; al terminar el entreno en el iPhone, el reloj
      deja de medir y enseña el resumen (y, tras «Listo», "Empieza el entreno en el iPhone"). Nadie documenta
      si WatchConnectivity empareja una app del reloj que no instaló el iPhone: si no, la salida es
      que el reloj lea el `db.json` de GitHub él mismo (otro adaptador del mismo `WatchModel`).

### #17 El reloj como app de entreno (HealthKit)

Hecho y probado en Docker (las reglas, los textos y el `WatchModel`) y en el CI (compilación,
firma ad hoc con los entitlements y capturas del simulador). Falta lo que necesita el reloj en la
mano:

- [ ] **plumesign activa Salud en los dos App ID** (el del iPhone y el del reloj) con los
      entitlements de cada binario, como en #3: en el log de ios-signer y en el perfil de cada uno
      (`com.apple.developer.healthkit`).
- [ ] **Los permisos de Salud**: la hoja del sistema sale en el reloj la primera vez que se empieza
      a medir, y con ellos aceptados el entreno se guarda (Fitness y Salud, con el nombre de Gym).
- [ ] **Borrar una sesión del Historial la borra de Fitness**: entrenar con el reloj, borrar la
      sesión en el iPhone (el globo dice «También se borra de Fitness»; la primera vez sale la hoja
      de permisos de Salud) y comprobar que el entreno desaparece de Fitness y de los anillos. Lo
      borra el reloj (desde el iPhone, Salud no dejaba: 2026-10-30): con la app del reloj cerrada
      debería llegarle en segundo plano; si no, al abrirla. La primera vez que se empiece a medir
      tras esta versión, el reloj vuelve a pedir permisos (ahora también para borrar).
- [ ] **«Empezar» en el iPhone abre el reloj** (`startWatchApp`) con la app del reloj instalada
      directamente por ios-signer (#2). Si no la abre, se empieza en el reloj y no pasa nada más.
- [ ] **La app sigue en primer plano** al bajar y levantar la muñeca durante el entreno, y con la
      muñeca bajada: si los segundos se refrescan o solo una vez por minuto.
- [ ] **La vibración a 1:30** con la pantalla apagada, y el doble toque para el descanso.
- [ ] **Terminar en el iPhone** termina también el del reloj y enseña el resumen.
- [ ] **La música**: la página de la izquierda controla lo que suena en el iPhone y la corona sube y
      baja el volumen.
