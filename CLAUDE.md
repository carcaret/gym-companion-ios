# CLAUDE.md

App nativa de iOS (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA que sustituye. Responde en español de España. La migración de la PWA está en curso (épica #1).

## Plan de trabajo: épica #1

La migración está planificada en la issue **#1** ("Migrar Gym Companion a app nativa iOS") y sus sub-issues #2–#18, con todo el contexto (decisiones, arquitectura, entorno, cadena de despliegue, estructura de la PWA y qué tests portar en cada una). **Leer #1 entera antes de empezar cualquier sub-issue**, y la sub-issue concreta.

- **Autonomía**: el usuario no quiere aprobar nada. Una rama y un PR por sub-issue (`Closes #N`); con el CI en verde, Claude revisa el diff y fusiona él mismo. **Nunca push directo a `master`**, aunque sea un arreglo pequeño, salvo que el usuario lo pida de forma explícita para ese cambio (decisión del usuario, 2026-10-26: los push directos de ese día fueron una excepción). Antes de fusionar, la rama al día con `master`: así el árbol fusionado es el probado y master no repite los tests (job `gate`). Solo se pregunta lo imprescindible (borrar o debilitar un test, decisiones de producto no deducibles, acciones con el iPhone o el Watch en la mano), de una en una.
- **Sin guarradas**: arquitectura hexagonal por capas (un módulo por capa), cada regla con su test, y cuestionar el criterio del usuario cuando no sea el correcto.
- **TDD**: primero el test. Los tests de la PWA se portan (unitarios uno a uno; e2e por comportamiento) y nunca se borran ni debilitan sin aprobación.
- **Sin iCloud** mientras no se pague la cuenta de Apple: datos locales + sincronización con el `db.json` de la PWA (detalles en #1 y #7).

## Estructura y capas

```
Packages/GymCore/            paquete Swift, un módulo por capa (las dependencias las impone el compilador)
  Sources/Domain/            modelo (TrainingData, Catalog, Routine, Session, ExerciseLog, LocalDate...) y reglas puras,
                             también lo que enseña el reloj (WatchSnapshot)
  Sources/Presentation/      textos en español para la interfaz (fechas, resúmenes, frases, mensajes) y
                             lectura de lo tecleado. Depende de Domain
  Sources/Application/       casos de uso y puertos (protocolos: Clock, TrainingDataStore, SyncSettingsStore,
                             CredentialStore, RemoteTrainingDataSource, BackgroundActivity, WatchPublisher),
                             TrainingRepository, el actor que guarda y sincroniza con la política de la PWA, y
                             WatchRelay, que envía al reloj lo que cambia. Depende de Domain
  Sources/ViewModels/        estado de cada pantalla (@Observable, @MainActor): AppModel (datos y aviso único),
                             SyncModel, NavigationModel, TodayModel, HistoryModel, ChartsModel, ProgressModel,
                             CatalogModel, SettingsModel, ExerciseCard (tarjeta compartida) y WatchModel (la
                             pantalla del reloj). Depende de Application, Presentation y Domain; las vistas
                             SwiftUI de App/ y Watch/ solo los pintan
  Sources/Adapters/          implementaciones de los puertos que compilan en Linux (SystemClock,
                             JSONFileTrainingDataStore, JSONFileSyncSettingsStore, PWAFormat para leer y
                             escribir db.json, GitHubTrainingDataSource con URLSession, WatchSnapshotCoding para
                             lo que viaja al reloj)
  Sources/AppleAdapters/     los que solo existen en Apple, tras `#if canImport` (KeychainCredentialStore,
                             UIKitBackgroundActivity, ConnectivityMonitor); en Linux compila vacío
  Sources/WatchAdapters/     el enlace con el reloj (WatchConnectivity): el que envía, en iOS, y el que recibe, en
                             watchOS (que no tiene UIKit, por eso no va en AppleAdapters); en Linux compila vacío
  Sources/GymCoreTesting/    para los tests: dobles de los puertos (InMemoryTrainingDataStore, InMemoryRemote...),
                             tests de contrato que todo adaptador de un puerto pasa (TrainingDataStoreContract...)
                             y el arnés de la sincronización (SyncHarness, SyncFixtures)
  Tests/<Módulo>Tests/       Swift Testing
  test.sh                    los tests en el NAS
App/                         app iOS: vistas SwiftUI finas por pantalla (Today/, History/, Charts/, Progress/,
                             Catalog/, Settings/, Shared/), RootView y CompositionRoot.swift. Con `-demo` arranca
                             con DemoData en una carpeta temporal y sin GitHub (solo para las capturas del CI)
UITests/                     XCUITest: pocos flujos y las capturas de pantalla
Watch/                       app del reloj (#16, solo lectura): WatchRootView (un ejercicio por página, con la
                             corona), ExercisePageView y WatchCompositionRoot. Diseñada para el Series 10 de 46 mm.
                             Con `-demo` o `-demo-sin-entreno` enseña datos de ejemplo (capturas del CI)
WatchUITests/                las capturas del reloj
project.yml                  XcodeGen (el .xcodeproj no se versiona)
scripts/pwa_tests.py         cruza los tests de la PWA con los de la app (ver Tests)
docs/paridad.md              la tabla de los 829 tests de la PWA con su test nativo o el motivo (#15)
docs/pendiente-nas.md        lo que queda por comprobar desde el NAS o con el iPhone en la mano
```

- Solo `Adapters` (lo que compila en Linux: Foundation, FoundationNetworking), `AppleAdapters` (Security, UIKit, Network) y `WatchAdapters` (WatchConnectivity), estos dos siempre tras `#if canImport`, importan frameworks; `Domain`, `Presentation`, `Application` y `ViewModels` no importan frameworks de Apple. Todo el paquete se prueba en el NAS y en un job de Linux del CI, que es quien lo vigila. Por eso los ViewModels viven en el paquete y no en `App/`: sus tests no necesitan simulador.
- Puertos (`Application`): `Clock`, `TrainingDataStore`, `SyncSettingsStore`, `CredentialStore`, `RemoteTrainingDataSource`, `BackgroundActivity`, `WatchPublisher`. Cada adaptador de un puerto pasa su test de contrato de `GymCoreTesting` (p. ej. `@Test(arguments: TrainingDataStoreContract.allCases)`), y los casos de uso se prueban con los dobles en memoria.
- Datos en el iPhone: `Application Support/GymCompanion/training-data.json`, formato propio versionado (`StoredTrainingData`, `version`), escrito de forma atómica. Se conserva al reinstalar encima (lo que hace ios-signer). Al lado, `sync.json` (repo, rama, ruta y si hay cambios sin subir); el token de GitHub va al Llavero.
- Sincronización (#7): `TrainingRepository` es la única puerta a los datos. Lo local manda; cada cambio se guarda y se sube a los 500 ms (nada con un entreno en curso; al terminarlo, al momento); al arrancar, al volver a la app o al volver la red, sube lo pendiente o aplica lo remoto si es distinto; un 409/422 es un conflicto que elige el usuario. `PWAFormat.json(from:)` escribe el `db.json` byte a byte como `JSON.stringify(db, null, 2)` de la PWA. Con la app vacía, configurar GitHub baja los datos (no sube la app vacía encima).
- Un adaptador que solo exista en Apple va en `AppleAdapters` (o en su propio módulo si es grande: HealthKit, WatchConnectivity...), para que el resto del paquete siga compilando en Linux.
- `App/CompositionRoot.swift` es el único sitio que crea adaptadores concretos (en el reloj, `Watch/WatchCompositionRoot.swift`).
- Reloj (#16): solo lectura, manda el iPhone. `AppModel` pasa cada cambio de los datos a `WatchRelay`, que calcula el `WatchSnapshot` del día y lo envía si cambió (`updateApplicationContext`: solo lo último). El reloj lo pinta con `WatchModel`; un entreno de otro día ya no está en curso. ios-signer instala la app del reloj directamente en el reloj (#2), no a través del iPhone.
- Reglas de negocio en `Domain`; lo que es texto para la interfaz, en `Presentation` (p. ej. el error es `LogValidationError.negativeWeight` y el mensaje "Peso debe ser >= 0" lo da `ValidationText`).
- El modelo no calca `db.json`: el log no copia el nombre del ejercicio, las rutinas son entidades, las fechas son `LocalDate`. La traducción a `db.json` es cosa del adaptador (#6, #7).
- Fechas: el "hoy" es el día local (`Clock`), no el UTC que usaba la PWA.
- Orden alfabético siempre con `SpanishCollation` (el `localeCompare(…, 'es')` de la PWA) y búsquedas con `searchFolded`.
- Textos de la interfaz en español en el código (`Text("Versión \(…)")`), recogidos en `App/Localizable.xcstrings` (idioma base `es`).

## Tests

En el NAS (segundos; la primera vez descarga la imagen): `Packages/GymCore/test.sh` (admite los argumentos de `swift test`, p. ej. `--filter LocalDateTests`; el filtro es por nombre de tipo o función, no por el texto del `@Test`). Si `~/git/gym-companion` está clonado, le pasa su `db.json` real en `PWA_DB_JSON` para el test de importación (el CI hace lo mismo). Es esto, con el usuario propio para que `.build` no quede de root:

```sh
docker run --rm --user 1000:10 -e HOME=/tmp -v ~/git/gym-companion-ios:/w -w /w/Packages/GymCore swift:6.3.3 swift test
```
 La imagen lleva la misma versión de Swift que el Xcode del runner `macos-26` (Xcode 26.6 → Swift 6.3.3, sale en el paso "Generar proyecto" del CI) y la misma que el job `core-linux` de `build.yml`: si Xcode cambia de versión, cambiarla en los dos sitios.

En CI (`.github/workflows/build.yml`), en cada PR y en `master`, todo en paralelo y cada job en su máquina (el plan gratuito deja 5 macOS a la vez): `core-linux` (paquete en Linux), `pwa-tests` (cruce con la PWA), `app (1)`, `app (2)` y `app (3)` (los tests de UI del iPhone en tres partes: la 1 y la 2 corren las clases de `PART_1` y `PART_2`, y la 3 todas las demás, así una clase nueva nunca se queda fuera), `watch` (el reloj y, al final, el paquete en macOS) y `release-build` (la release, compilada a la vez que los tests). Un PR tarda unos 10–11 minutos; antes del PR #55 (2026-10-26) tardaba 25–38. Lo que lo hace posible, y no hay que romper:

- **Simulador migrado en caché** (`scripts/ci-simulator.sh`): un simulador nuevo pasa 5–10 minutos migrando en su primer arranque y frena la máquina entera. La primera vez se copia ya migrado (antes de instalar la app) a la caché de Actions, con el runtime y Xcode en la clave; los runs siguientes lo registran y arranca en un minuto, en segundo plano mientras se compila. Va después de restaurar la caché de la compilación, para no competir al descomprimir.
- **Compilación incremental**: la carpeta de compilación en la caché (la de `master` es la que usan las PR; sin el índice ni los logs) y `scripts/restore-mtimes.sh`, que pone a cada fichero la fecha de su commit y a cada carpeta la de su fichero más reciente (un `.xcassets` es una carpeta: sin fecha, el catálogo se recompilaba en cada run). Los commits de merge cuentan con lo que cambian respecto a su primer padre (`--diff-merges=first-parent`): sin eso, lo cambiado al resolver un conflicto no se recompilaba. XcodeGen se descarga de su release (`scripts/ci-xcodegen.sh`), sin `brew`.
- **master no repite los tests** de lo que ya pasó en su PR con el mismo árbol (job `gate`, `scripts/ci-gate.sh`): solo compila y publica (`publish-tested`). Un push directo o una PR sin estar al día pasa todos los tests y publica en `publish`. Los jobs del iPhone y del reloj corren en master sin tests, para dejar las cachés.
- **Un test de UI que falla se repite una vez** (`-retry-tests-on-failure`, decisión del usuario, 2026-10-27): el run sale verde si pasa a la segunda, y su resumen lista los repetidos. Un test que sale ahí a menudo es inestable y hay que arreglarlo, no dejarlo.
- **Esperas en los tests de UI con `appears(timeout:)`** (`UITests/Waiting.swift`), no `waitForExistence`: mira primero si el elemento ya está; `waitForExistence` tarda un segundo en su primera comprobación (decisión del usuario, 2026-10-27).
- **Diagnóstico**: cada job con simulador deja en el resumen del run su cronología y lo que tarda cada test, y sube como artefacto `diagnostico-<job>` los logs enteros con la hora, la CPU de la app cada 2 s (`cpu.log`), el arranque del simulador y el `.xcresult` (con el vídeo de los fallos; para verlo, sacar fotogramas con `AVAssetImageGenerator`). Antes de suponer por qué algo tarda, mirarlo ahí.

**Tests portados de la PWA**: cada test lleva en Swift el mismo nombre que en Vitest o Playwright (`@Suite` = el `describe`, `@Test` = el `test`), para poder cruzarlos; también los e2e, que se portan por comportamiento a tests de ViewModel. `scripts/pwa_tests.py ~/git/gym-companion` comprueba los ficheros de `docs/pwa-tests-ficheros.txt` (unitarios por nombre, e2e como `e2e/<fichero>`; ya están todos) y falla si alguno no está portado ni en `docs/pwa-tests-no-aplican.tsv` con su motivo; con `--markdown` saca la tabla del PR. Cambiar lo que comprueba un test portado necesita la aprobación del usuario y se anota en el propio test (p. ej. la media de reps, aprobado el 2026-10-25).

**Fixtures**: `PWATestDB` (`GymCoreTesting`) es el `db-test.json` de los e2e en Swift (un test lo ata al JSON); `SyncHarness` monta el repositorio con los dobles de todos los puertos.

**PR de pruebas visuales** (no van a master, solo para ver capturas; decisión del usuario, 2026-10-26): nada que no haga falta para las capturas, ni tests ni reloj. Se hace en la propia rama, con commits que nunca llegan a master: la app aprende a arrancar directamente en cada pantalla con un argumento (`-pantalla <nombre>` junto a `-demo`, lo que haga falta para la prueba), y en `build.yml` el job `app` solo compila la app (`xcodebuild build`, no `build-for-testing`), arranca el simulador del iPhone (no el del reloj) y saca cada captura con `xcrun simctl launch --terminate-running-process … -demo -pantalla X` + `xcrun simctl io <udid> screenshot`, que sube como artefacto `capturas`; `core-linux` y `pwa-tests` con `if: false`. Referencia: la rama `diseno-ios` (PR #54).

**Capturas**: `UITests/ScreenshotTests.swift` guarda una captura por pantalla principal (`testHoy` recorre la app con `-demo`), y `WatchUITests/WatchScreenshotTests.swift` las del reloj (`70-reloj-…`, en el simulador del Series 10 de 46 mm); el job `capturas` junta las de las tres partes y el reloj en el artefacto `capturas` (PNG con el nombre de la captura). Para verlas: `gh run download <id> -n capturas` y abrir los PNG con Read. Al añadir una pantalla, añadir su captura.

## Cómo se despliega (sin Mac y sin cuenta de pago de Apple)

1. PR fusionada en `master` → `.github/workflows/build.yml`: compila la release con XcodeGen (`project.yml`) y `CODE_SIGNING_ALLOWED=NO` y publica la release `latest` ("Build N", `GymCompanion.ipa` + `.sha256`) en unos 3 minutos, porque los tests ya pasaron en la PR (job `gate`). Un push directo pasa antes todos los tests.
2. El NAS (`ios-signer`, en el repo `home-nas`, README sección ios-signer) ve la release nueva en menos de 5 minutos, la firma con un Apple ID gratuito y la instala por WiFi en cuanto el iPhone está en casa (desbloqueado, o bloqueado y cargando). Avisa por Home Assistant.

Para comprobar un despliegue: el run en `GET /repos/carcaret/gym-companion-ios/actions/runs?per_page=1` y, en el NAS, `tail /volume1/docker/ios-signer/data/ios-signer.log`.

## Reglas

- No hay Xcode a mano: todo se compila en Actions. El `.xcodeproj` no se versiona; cualquier ajuste del proyecto (targets, capacidades, Info.plist) va en `project.yml`.
- **No cambiar `PRODUCT_BUNDLE_IDENTIFIER`** (`com.carcaret.gymcompanion`): plumesign le añade el team ID y es lo que identifica la app en el iPhone; si cambia, se instala otra app nueva y la vieja se queda con los datos.
- `CURRENT_PROJECT_VERSION` lo pone el workflow (número de ejecución); `MARKETING_VERSION` se sube a mano.
- El repo es público (las máquinas macOS de Actions son gratis solo así): nada de secretos ni datos personales en el código.
- Límites de la cuenta gratuita de Apple: sin iCloud/CloudKit ni notificaciones push; cada target extra (widget, Apple Watch) gasta uno de los 10 identificadores de app por semana. Si un día hace falta algo de eso, la salida es la cuenta de pago (TestFlight).
- **Capacidades (HealthKit, App Groups...)**: plumesign las activa según los entitlements del binario, así que hay que firmar ad hoc en CI con el `.entitlements` (`codesign --force --sign - --entitlements …`); ver #3. **Apple Watch**: la app del reloj no se puede instalar a través del iPhone con la cuenta gratuita; ios-signer tendrá que instalarla directamente en el reloj (ver #2).
- Los datos irán en local en el iPhone, con copia en GitHub como hace la PWA (`db.json`). La PWA es de un solo usuario y un solo aparato: nada de sincronización multi-aparato ni CRDT.

## Lo que en nativo es distinto que en la PWA

Cosas que la web daba hechas y en iOS hay que cuidar (repaso del 2026-10-25):

- **Un botón no quita el foco del campo que se edita** (en la web el campo se aplica al perder el foco, antes del toque). Los campos de las tarjetas pasan lo tecleado al modelo (`type`, `TypedValue`) y el modelo lo aplica antes de cada acción y al salir del campo (`commitTyping`). Un campo nuevo que edite datos tiene que seguir el mismo camino; lo prueba `UITests/TypingTests.swift`.
- **El teclado no se cierra solo**: toda pantalla con campos lleva `keyboardDismissal()` (cerrar al desplazar; sin botón OK encima del teclado, también para el numérico, decisión del usuario del 2026-10-25), y tocar fuera de un campo lo cierra en toda la app (`dismissesKeyboardOnTapOutside()` en la raíz, `App/Shared/Keyboard.swift`; lo prueba `UITests/KeyboardTests.swift`). Salvo en las filas de un `Form` (los ajustes), donde ese reconocedor no actúa: ahí se cierra como en iOS, desplazando o con la tecla de retorno (decisión del usuario, 2026-10-26).
- **`confirmationDialog` en iOS 26 es un globo que apunta a la vista de la que cuelga**: se cuelga del botón o de la fila que lo abre, nunca de la pantalla entera. Si no sale de nada concreto (el conflicto de la sincronización, o una acción de deslizar, que desaparece al tocarla), `.alert`.
- **SwiftUI cierra un diálogo o alerta antes de ejecutar la acción del botón**: el `set` del `isPresented` (que descarta el aviso del modelo) va primero. La acción no puede leer el aviso del modelo: se usa `presenting:` y el modelo recibe el aviso (`confirmDelete(prompt)`). Así borrar del historial no hacía nada (2026-10-25); los tests del modelo lo prueban en ese orden y `UITests/HistoryTests.swift`, con el gesto real.
- **Una acción de deslizar (`swipeActions`) con `role: .destructive` quita la fila al tocarla**, antes de que los datos cambien: si se confirma después, la fila sale, vuelve y las demás bailan (2026-10-25). Las de borrar con confirmación van sin rol y con `.tint(Theme.red)` (además, heredan el `.tint` de la raíz).
- **Swift Charts con `AreaMark` incluye el 0 en el eje**: el relleno va con `yStart` en el mínimo del eje (`Chart.valueRange`), como el eje ajustado de Chart.js.
- **Fechas y números del sistema siguen la región del iPhone**: la raíz fija `es_ES` para los selectores de fecha y los ejes; los textos propios ya salen de `Presentation`.
- Zonas de toque de 44 pt aunque el texto sea pequeño (`frame(minHeight: 44)` + `contentShape`).
- **Volver es el de iOS**: la vista previa de una rutina, el detalle del historial y las gráficas de un ejercicio abiertas desde Progreso («Ver en Gráficas», sin saltar de pestaña) entran empujados (`navigationDestination`) y se vuelve con la flecha de la barra o deslizando desde el borde; sin botón «Volver» (decisión del usuario, 2026-10-25). El entreno terminado no tiene botón para salir (arriba solo la nube, decisión del usuario del 2026-10-26): se vuelve a las rutinas tocando otra vez la pestaña. Abajo, fija sobre la barra de pestañas, solo la acción principal a todo el ancho (`BottomActions(primary:)`), o secundaria y principal cuando hay dos de verdad (el entreno en curso). Son píldoras de cristal (`.glassPill`), como la barra de pestañas, con los colores de la PWA y el texto oscuro en la principal, sin fondo detrás y con el ancho de la barra de pestañas (21 pt de margen, medido; decisión del usuario, 2026-10-27). Borrar una sesión es deslizando la fila; quitar o saltar un ejercicio del entreno, también deslizando (además de los botones de la tarjeta). **Nada de `onAppear` que cierre la pantalla empujada**: la pantalla de debajo lanza su `onAppear` en cuanto empieza el gesto de volver, y el detalle desaparecía de golpe a mitad del arrastre.
- **Las pestañas son las de iOS**: cambiar de pestaña conserva su pantalla, y tocar otra vez la activa vuelve a la de entrada (decisión del usuario, 2026-10-25; la PWA volvía a la entrada al cambiar). `NavigationModel.select` distingue los dos casos y `RootView` lo aplica en `onChange(of: reselection)`: vacía la pila de la pestaña y llama al `reselect()` de su modelo. Lo empujado sin modelo (catálogo, elegir ejercicio) va con `NavigationLink(value:)`, para que esa pila lo pueda vaciar (`UITests/NavigationTests.swift`).
- **La letra sigue el tamaño de texto del iPhone (Dynamic Type)**: `scaledFont(15, .semibold)` (`App/Shared/ThemeStyles.swift`), que con el tamaño normal mide lo mismo que la PWA; nunca `.font(.system(size:))`, que no escala. Los anchos fijos que contienen texto van con `@ScaledMetric`. La raíz pone el tope en `accessibility1` (`UITests/DynamicTypeTests.swift`).
- **Gestos y formularios de iOS**: tirar hacia abajo en Historial sincroniza con GitHub (`SyncModel.pullToRefresh`), con la lista que se estira siempre (`scrollBounceBehavior(.always)`). En los ajustes la tecla de retorno pasa al campo siguiente (`UITests/SettingsTests.swift`).
- **XCUITest espera a que la app se quede quieta** antes de cada consulta: tras un gesto con animaciones largas (el refresco), un aviso de 2,5 s ya se ha ido cuando el test lo busca. Esos tests arrancan con `-avisos-largos` (10 s, `CompositionRoot.noticeDuration`). Y para ver qué pasa durante un gesto, la grabación del fallo a 5 fotogramas por segundo o más: a 2–4 no se ve el tirón (2026-10-26, C3 se dio por roto y funcionaba).
- **Avisos solo para lo que no se ve** (2026-10-26): el aviso de abajo (el toast de la PWA, de cristal como lo demás que flota sobre el contenido) queda para errores, advertencias, sincronización y lo que pasa fuera de la pantalla (p. ej. el intercambio recíproco). Lo que ya se ve al momento (empezar, terminar, reordenar, añadir, cambiar, quitar, borrar, guardar en el catálogo, la subida diferida) no avisa: el indicador ya dice que está subido.
- **El indicador de la sincronización es un menú** (`SyncModel.statusText`, `menuAction`): dice el estado y ofrece sincronizar ahora, resolver el conflicto o configurar GitHub, y con GitHub configurado también «Ajustes de sincronización» (`offersSettings`). Amarillo es pendiente; late (`indicatorPulses`) solo si lo pendiente no espera al final del entreno (`SyncStatus.waitingForWorkout`): durante el entreno no se sube nada a propósito y el amarillo se queda quieto (decisión del usuario, 2026-10-26).
- **Ajustes no es una pestaña** (decisión del usuario, 2026-10-26): solo eran la configuración de GitHub y la versión, así que son una hoja que abre el menú del indicador (`SyncModel.isSettingsPresented`) y se cierra con la X de iOS 26 (`Button(role: .close)`). Con algo escrito sin guardar, deslizarla hacia abajo no la cierra (`SettingsModel.hasUnsavedChanges`). Lo que cuelga de la raíz queda debajo de una hoja: la de los ajustes lleva su propio `syncPresentation` (avisos y conflicto, que sus botones también disparan) y el de la raíz se apaga mientras está abierta. Si un día hay ajustes generales, irán en esa hoja o tras un botón en la barra, no en una pestaña.
- **Lo que se abre y se cierra es `CardDisclosure`** (`App/Shared/Disclosure.swift`): toda la cabecera se toca, la flecha de iOS gira y VoiceOver dice «Plegado» o «Desplegado». No `DisclosureGroup`: dentro de una fila de `List` (el entreno) pintaba la cabecera y el contenido uno encima de otro (2026-10-26). Si al abrir se ve más de lo mismo y no algo escondido, `DisclosureHeader` suelta. Abre y cierra con `.snappy` (el contenido entra deslizándose), sin el relleno de las tarjetas: con él se veía demasiado la diferencia entre la cabecera iluminada y lo que se despliega (decisión del usuario, 2026-10-26). Las pantallas con tarjetas desplegables van en `VStack`, no `LazyVStack`: son pocas tarjetas.
- **Una pantalla empujada (`navigationDestination`) es su propia vista, que lee el modelo** (`RoutinePreview`, `SessionDetail`), no una propiedad de la pantalla de debajo: construida ahí, los cambios del modelo le llegaban sin la animación y las tarjetas se abrían de golpe (vídeo del CI, 2026-10-27).
- **La nube de la sincronización sale en todas las pantallas**: cada pantalla empujada trae su propia barra, así que donde se empuja lleva `.syncToolbar()` (`App/Shared/SyncViews.swift`; el modelo va en el entorno), igual que la de entrada de cada pestaña en `RootView`. No dentro de la pantalla: Gráficas es entrada de su pestaña y también se empuja desde Progreso. Lo prueba `NavigationTests.testLaNubeSaleEnLasPantallasEmpujadas`.
- **Las tarjetas que se tocan enteras** (rutinas de Hoy, sesiones del Historial) llevan `.buttonStyle(.card)` (`App/Shared/CardButtonStyle.swift`): al apoyar el dedo, un círculo blanco nace donde se toca y crece hasta los bordes en 120 ms, y la tarjeta se encoge un pelín (decisión del usuario, 2026-10-27). La acción espera a que el círculo llene la tarjeta: en una `List`, un toque rápido no marca la pulsación y la pantalla cambiaba antes de verse nada. El círculo se pinta según la hora (`TimelineView`), sin `withAnimation`: en una fila de `List` el cambio de la pulsación llega sin animación.
- **Tarjetas o listas de iOS** (2026-10-27): lo que se entrena o se lee de un vistazo (rutinas, entreno, historial) va en tarjetas (`.card()`); lo que se gestiona, se elige o se configura (catálogo, filtros de Gráficas, elegir ejercicio, ajustes), en listas de iOS. Progreso también es una lista de iOS (decisión del usuario, 2026-10-27): el estado de cada ejercicio es un icono de color a la izquierda, como en Ajustes. Las tarjetas llevan las esquinas de las secciones de iOS 26 (`Theme.radius`, 26 pt) y no llevan borde, salvo cuando el borde dice algo (la sesión sin terminar): así las dos familias encajan.
- **Formularios con `Form`** (los ajustes): una fila por campo (`LabeledContent`), las acciones como filas y lo destructivo con `role: .destructive`.
- **Barras con Swift Charts**: la tira «Últimas sesiones» y las barras de grupos de Progreso son `Chart`, con el aspecto de la PWA (colores, alturas mínimas, el borde de la barra de hoy dibujado en `chartOverlay`).
