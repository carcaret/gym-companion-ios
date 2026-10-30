# CLAUDE.md

App nativa de iOS (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA que sustituye. Responde en español de España. La migración de la PWA (épica #1) está hecha salvo #15 (el paso definitivo, que depende del usuario); #17 (HealthKit: el reloj como app de entreno) está hecha a falta de comprobarla con el reloj en la mano (`docs/pendiente-nas.md`), y #18 (iCloud) es para el futuro.

## Cómo se trabaja

La migración se planificó en la issue **#1** ("Migrar Gym Companion a app nativa iOS") y sus sub-issues #2–#18, con todo el contexto (decisiones, arquitectura, entorno, cadena de despliegue, estructura de la PWA y qué tests portar en cada una). **Antes de #15 o #18, leer #1 entera** y la sub-issue concreta.

- **Autonomía**: el usuario no quiere aprobar nada. Una rama y un PR por cambio (`Closes #N` si tiene issue); con el CI en verde, Claude revisa el diff y fusiona él mismo. **Nunca push directo a `master`**, aunque sea un arreglo pequeño, salvo que el usuario lo pida de forma explícita para ese cambio (decisión del usuario, 2026-10-26: los push directos de ese día fueron una excepción). Antes de fusionar, la rama al día con `master`: así el árbol fusionado es el probado y master no repite los tests (job `gate`). Solo se pregunta lo imprescindible (borrar o debilitar un test, decisiones de producto no deducibles, acciones con el iPhone o el Watch en la mano), de una en una.
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
  Sources/Application/       casos de uso y, en Ports/, un fichero por puerto (Clock, TrainingDataStore,
                             SyncSettingsStore, CredentialStore, RemoteTrainingDataSource, BackgroundActivity,
                             WatchPublisher, WorkoutRecorder, RestAlert, WatchWorkoutLauncher); TrainingRepository, el actor que guarda y sincroniza con la
                             política de la PWA, y WatchRelay, que envía al reloj lo que cambia. Depende de Domain
  Sources/ViewModels/        estado de cada pantalla (@Observable, @MainActor): AppModel (datos y aviso único),
                             SyncModel, NavigationModel, TodayModel, HistoryModel, ChartsModel, ProgressModel,
                             CatalogModel, SettingsModel, ExerciseCard (tarjeta compartida), WatchModel (la
                             pantalla del reloj) y AppLifecycle (arrancar, volver, segundo plano). Depende de Application, Presentation y Domain; las vistas
                             SwiftUI de App/ y Watch/ solo los pintan
  Sources/Adapters/          implementaciones de los puertos que compilan en Linux (SystemClock,
                             JSONFileTrainingDataStore, JSONFileSyncSettingsStore, PWAFormat para leer y
                             escribir db.json, GitHubTrainingDataSource con URLSession, WatchSnapshotCoding para
                             lo que viaja al reloj)
  Sources/AppleAdapters/     los que solo existen en Apple, tras `#if canImport` (KeychainCredentialStore,
                             UIKitBackgroundActivity, ConnectivityMonitor); en Linux compila vacío
  Sources/WatchAdapters/     el enlace con el reloj (WatchConnectivity): el que envía, en iOS, y el que recibe, en
                             watchOS (que no tiene UIKit, por eso no va en AppleAdapters), y la vibración del
                             descanso (WatchKitRestAlert); en Linux compila vacío
  Sources/HealthAdapters/    Salud (HealthKit): la sesión de entreno del reloj (HealthKitWorkoutRecorder) y abrir
                             el reloj desde el iPhone (HealthKitWatchLauncher); en Linux compila vacío
  Sources/GymCoreTesting/    para los tests: dobles de los puertos (InMemoryTrainingDataStore, InMemoryRemote...),
                             tests de contrato que pasa todo adaptador de un puerto con estado, un fichero por
                             puerto (<Puerto>Doubles, <Puerto>Contract), y el arnés de la sincronización
                             (SyncHarness, SyncFixtures)
  Tests/<Módulo>Tests/       Swift Testing
  test.sh                    los tests en el NAS
App/                         app iOS: vistas SwiftUI finas por pantalla (Today/, History/, Charts/, Progress/,
                             Catalog/, Settings/, DataError/, Shared/), un fichero por componente, RootView y
                             CompositionRoot.swift. Los argumentos de arranque (Shared/LaunchArgument.swift) y los
                             identificadores de accesibilidad (Shared/AccessibilityID.swift), compartidos con
                             los tests de UI; con `-demo`, Demo/ (DemoEnvironment y
                             DemoData): datos de ejemplo en una carpeta temporal y sin GitHub (las capturas)
UITests/                     XCUITest: pocos flujos y las capturas de pantalla; AppNavigation (arrancar con `-demo`
                             y los recorridos que se repiten), Waiting y Capture (estos dos, también en
                             WatchUITests/). Los identificadores, los de App/Shared/AccessibilityID.swift
Watch/                       app del reloj (#16, #17), la app de entreno: WatchRootView (según la fase; midiendo,
                             tres páginas: música, entreno y controles), un fichero por componente, WatchAppDelegate
                             (el entreno cuando lo abre el iPhone) y WatchCompositionRoot. Diseñada para el Series
                             10 de 46 mm. Con `-demo` mide un entreno de mentira con datos de ejemplo, o
                             `-demo-sin-entreno` (WatchDemo, capturas del CI)
Entitlements/                los de HealthKit de cada app; los firma el CI (no van en el proyecto)
WatchUITests/                las capturas del reloj
project.yml                  XcodeGen (el .xcodeproj no se versiona)
scripts/pwa_tests.py         cruza los tests de la PWA con los de la app (ver Tests)
docs/paridad.md              la tabla de los 829 tests de la PWA con su test nativo o el motivo (#15)
docs/decisiones-ui.md        las decisiones de interfaz, con su porqué
docs/pendiente-nas.md        lo que queda por comprobar desde el NAS o con el iPhone en la mano
```

- Solo `Adapters` (lo que compila en Linux: Foundation, FoundationNetworking), `AppleAdapters` (Security, UIKit, Network), `WatchAdapters` (WatchConnectivity, WatchKit) y `HealthAdapters` (HealthKit), estos tres siempre tras `#if canImport`, importan frameworks; `Domain`, `Presentation`, `Application` y `ViewModels` no importan frameworks de Apple. Todo el paquete se prueba en el NAS y en un job de Linux del CI, que es quien lo vigila. Por eso los ViewModels viven en el paquete y no en `App/`: sus tests no necesitan simulador.
- Puertos (`Application/Ports`): `Clock`, `TrainingDataStore`, `SyncSettingsStore`, `CredentialStore`, `RemoteTrainingDataSource`, `BackgroundActivity`, `WatchPublisher`, `WorkoutRecorder`, `RestAlert`, `WatchWorkoutLauncher`. Cada adaptador de un puerto con estado (`TrainingDataStore`, `SyncSettingsStore`, `CredentialStore`, `RemoteTrainingDataSource`) pasa su test de contrato de `GymCoreTesting` (p. ej. `@Test(arguments: TrainingDataStoreContract.allCases)`), y sus dobles también (`DoublesContractTests`); los casos de uso se prueban con los dobles en memoria. El adaptador traduce lo suyo: el mensaje del commit lo escribe el de GitHub, no el caso de uso.
- Datos en el iPhone: `Application Support/GymCompanion/training-data.json`, formato propio versionado (`StoredTrainingData`, `version`), escrito de forma atómica. Se conserva al reinstalar encima (lo que hace ios-signer). Al lado, `sync.json` (repo, rama, ruta y si hay cambios sin subir); el token de GitHub va al Llavero.
- Sincronización (#7): `TrainingRepository` es la única puerta a los datos. Lo local manda; cada cambio se guarda y se sube a los 500 ms (nada con un entreno en curso; al terminarlo, al momento); al arrancar, al volver a la app o al volver la red, sube lo pendiente o aplica lo remoto si es distinto; un 409/422 es un conflicto que elige el usuario. `PWAFormat.json(from:)` escribe el `db.json` byte a byte como `JSON.stringify(db, null, 2)` de la PWA. Con la app vacía, configurar GitHub baja los datos (no sube la app vacía encima).
- Un adaptador que solo exista en Apple va en `AppleAdapters`, o en su propio módulo si es grande (como `WatchAdapters` y `HealthAdapters`), para que el resto del paquete siga compilando en Linux.
- `App/CompositionRoot.swift` es el único sitio que crea adaptadores concretos (en el reloj, `Watch/WatchCompositionRoot.swift`); los de la demo, a través de `App/Demo/DemoEnvironment.swift`, que solo usa él.
- Reloj (#16, #17): la app de entreno; los datos los manda el iPhone. `AppModel` pasa cada cambio de los datos a `WatchRelay`, que calcula el `WatchSnapshot` del día (el plan de hoy y las sesiones de referencia) y lo envía si cambió (`updateApplicationContext`: solo lo último). El reloj lo pinta con `WatchModel`, que mide la sesión de Salud (`WorkoutRecorder`) y lleva el descanso (`RestTimer`, en tiempo del entreno; la vibración la programa `RestAlert`); un entreno de otro día ya no está en curso. «Empezar» en el iPhone abre el reloj (`WatchWorkoutLauncher`, que el reloj recibe en `WatchAppDelegate.handle`); terminar en el iPhone termina en el reloj (el snapshot pasa de tener entreno a no tenerlo: lo viejo que llega al abrir no termina nada), y terminar en el reloj deja el del iPhone abierto. ios-signer instala la app del reloj directamente en el reloj (#2), no a través del iPhone. Cómo es y por qué, en `docs/decisiones-ui.md`.
- Reglas de negocio en `Domain` (p. ej. lo que cambia al empezar, añadir, quitar o terminar un entreno: `TrainingData+Workout`); lo que es texto para la interfaz, en `Presentation` (p. ej. «60 kg» es `LogText.weight`). Los ViewModels solo guardan el estado de la pantalla (qué está abierto, qué se teclea) y llaman a las dos; las vistas no calculan ni montan textos.
- El modelo no calca `db.json`: el log no copia el nombre del ejercicio, las rutinas son entidades, las fechas son `LocalDate`. La traducción a `db.json` es cosa del adaptador (#6, #7).
- Fechas: el "hoy" es el día local (`Clock`), no el UTC que usaba la PWA.
- Orden alfabético siempre con `SpanishCollation` (el `localeCompare(…, 'es')` de la PWA) y búsquedas con `searchFolded`.
- Textos de la interfaz en español, en `Presentation` (`SettingsText.version`, `FormText.cancel`…): lo común a varias pantallas, en `FormText`. `App/Localizable.xcstrings` (idioma base `es`) no recoge esos textos, que son `String`.

## Tests

En el NAS (segundos; la primera vez descarga la imagen): `Packages/GymCore/test.sh` (admite los argumentos de `swift test`, p. ej. `--filter LocalDateTests`; el filtro es por nombre de tipo o función, no por el texto del `@Test`). Si `~/git/gym-companion` está clonado, le pasa su `db.json` real en `PWA_DB_JSON` para el test de importación (el CI hace lo mismo), con el usuario propio para que `.build` no quede de root.

La imagen de Docker lleva la misma versión de Swift que el Xcode del runner `macos-26` (sale en el paso "Generar proyecto" del CI): si Xcode cambia de versión, cambiarla en `test.sh` y en el job `core-linux` de `build.yml`.

En CI (`.github/workflows/build.yml`), en cada PR y en `master`, todo en paralelo y cada job en su máquina (el plan gratuito deja 5 macOS a la vez): `core-linux` (paquete en Linux), `pwa-tests` (cruce con la PWA), `app (1)`, `app (2)` y `app (3)` (los tests de UI del iPhone en tres partes: la 1 y la 2 corren las clases de `PART_1` y `PART_2`, y la 3 todas las demás, así una clase nueva nunca se queda fuera), `watch` (el reloj y, al final, el paquete en macOS) y `release-build` (la release, compilada a la vez que los tests). Un PR tarda unos 10–11 minutos; antes del PR #55 (2026-10-26) tardaba 25–38. Lo que lo hace posible, y no hay que romper:

- **Simulador migrado en caché** (`scripts/ci-simulator.sh`): un simulador nuevo pasa 5–10 minutos migrando en su primer arranque y frena la máquina entera. La primera vez se copia ya migrado (antes de instalar la app) a la caché de Actions, con el runtime y Xcode en la clave; los runs siguientes lo registran y arranca en un minuto, en segundo plano mientras se compila. Va después de restaurar la caché de la compilación, para no competir al descomprimir.
- **Compilación incremental**: la carpeta de compilación en la caché (la de `master` es la que usan las PR; sin el índice ni los logs) y `scripts/restore-mtimes.sh`, que pone a cada fichero la fecha de su commit y a cada carpeta la de su fichero más reciente (un `.xcassets` es una carpeta: sin fecha, el catálogo se recompilaba en cada run). Los commits de merge cuentan con lo que cambian respecto a su primer padre (`--diff-merges=first-parent`): sin eso, lo cambiado al resolver un conflicto no se recompilaba. XcodeGen se descarga de su release (`scripts/ci-xcodegen.sh`), sin `brew`.
- **master no repite los tests** de lo que ya pasó en su PR con el mismo árbol (job `gate`, `scripts/ci-gate.sh`): solo compila y publica (`publish-tested`). Un push directo o una PR sin estar al día pasa todos los tests y publica en `publish`. Los jobs del iPhone y del reloj corren en master sin tests, para dejar las cachés.
- **Un test de UI que falla se repite una vez** (`-retry-tests-on-failure`, decisión del usuario, 2026-10-27): el run sale verde si pasa a la segunda, y su resumen lista los repetidos. Un test que sale ahí a menudo es inestable y hay que arreglarlo, no dejarlo.
- **Esperas en los tests de UI con `appears(timeout:)`** (`UITests/Waiting.swift`, también en los del reloj), no `waitForExistence`: mira primero si el elemento ya está; `waitForExistence` tarda un segundo en su primera comprobación (decisión del usuario, 2026-10-27). Para arrancar, `XCUIApplication.launchDemo(…)` con los `LaunchArgument`, nunca el texto a mano.
- **XCUITest espera a que la app se quede quieta** antes de cada consulta: tras un gesto con animaciones largas (el refresco), un aviso de 2,5 s ya se ha ido cuando el test lo busca. Esos tests arrancan con `-avisos-largos` (`LaunchArgument.longNotices`: 10 s, `SyncModel.noticeDuration`). Y para ver qué pasa durante un gesto, la grabación del fallo a 5 fotogramas por segundo o más: a 2–4 no se ve el tirón (2026-10-26, C3 se dio por roto y funcionaba).
- **Diagnóstico**: cada job con simulador deja en el resumen del run su cronología y lo que tarda cada test, y sube como artefacto `diagnostico-<job>` los logs enteros con la hora, la CPU de la app cada 2 s (`cpu.log`), el arranque del simulador y el `.xcresult` (con el vídeo de los fallos; para verlo, sacar fotogramas con `AVAssetImageGenerator`). Antes de suponer por qué algo tarda, mirarlo ahí.

**Tests portados de la PWA**: cada test lleva en Swift el mismo nombre que en Vitest o Playwright (`@Suite` = el `describe`, `@Test` = el `test`), para poder cruzarlos; también los e2e, que se portan por comportamiento a tests de ViewModel. `scripts/pwa_tests.py ~/git/gym-companion` recorre todos los tests de la PWA (`tests/unit/*.test.js` y `tests/e2e/*.spec.js`) y falla si alguno no está portado ni en `docs/pwa-tests-no-aplican.tsv` con su motivo; con `--markdown` saca la tabla de `docs/paridad.md`, y el CI (`--check-table`) falla si esa tabla no está al día. Cambiar lo que comprueba un test portado necesita la aprobación del usuario y se anota en el propio test (p. ej. la media de reps, aprobado el 2026-10-25).

**Fixtures**: `PWATestDB` (`GymCoreTesting`) es el `db-test.json` de los e2e en Swift (un test lo ata al JSON); `SyncHarness` monta el repositorio con los dobles de todos los puertos, y `AppHarness` (`Tests/ViewModelsTests/Support/`), `AppModel` y `SyncModel` encima, para los tests de cada modelo.

**PR de pruebas visuales** (no van a master, solo para ver capturas; decisión del usuario, 2026-10-26): nada que no haga falta para las capturas, ni tests ni reloj. Se hace en la propia rama, con commits que nunca llegan a master: la app aprende a arrancar directamente en cada pantalla con un argumento (`-pantalla <nombre>` junto a `-demo`, lo que haga falta para la prueba), y en `build.yml` el job `app` solo compila la app (`xcodebuild build`, no `build-for-testing`), arranca el simulador del iPhone (no el del reloj) y saca cada captura con `xcrun simctl launch --terminate-running-process … -demo -pantalla X` + `xcrun simctl io <udid> screenshot`, que sube como artefacto `capturas`; `core-linux` y `pwa-tests` con `if: false`. Referencia: la rama `diseno-ios` (PR #54).

**Rama de prueba de un test** (decisión del usuario, 2026-10-28): para probar un gesto o un comportamiento que una captura no enseña (desplazar, deslizar, tocar y ver qué pasa), lo mismo que la de pruebas visuales, pero con un solo test de UI. Va en una rama que nunca llega a master. En `build.yml`, el job `app` corre una sola parte (`matrix.part: [1]`) y `scripts/ci-ui-selection.sh` da `-only-testing:GymCompanionUITests/<Clase>/<test>` en vez de la selección por partes; `core-linux`, `pwa-tests`, `watch` y `release-build`, con `if: false`. Se itera ahí hasta que el test pase, y después el cambio (sin lo del workflow) va a la rama del PR, que pasa el CI completo una sola vez. Antes de lanzar el CI completo para probar algo nuevo, plantearse si basta con esta rama.

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
- **Capacidades (HealthKit, App Groups...)**: plumesign las activa según los entitlements del binario, así que el job `release-build` firma ad hoc con los de `Entitlements/` (`codesign --force --sign - --entitlements …`), de dentro afuera (primero el reloj), y falla si alguno no los lleva; ver #3. Una capacidad nueva va en esos ficheros. Las compilaciones del simulador no los llevan: la demo no toca Salud.
- Un solo usuario y un solo aparato, como la PWA: nada de sincronización multi-aparato ni CRDT.

## Trampas de SwiftUI

Lo que la web daba hecho y en iOS hay que cuidar, y lo que SwiftUI hace distinto de lo que parece (repasos del 2026-10-25 al 2026-10-28):

- **Un botón no quita el foco del campo que se edita** (en la web el campo se aplica al perder el foco, antes del toque). Los campos de las tarjetas pasan lo tecleado al modelo (`type`, `TypedValue`) y el modelo lo aplica antes de cada acción y al salir del campo (`commitTyping`). Un campo nuevo que edite datos tiene que seguir el mismo camino; lo prueba `UITests/TypingTests.swift`.
- **El teclado no se cierra solo**: toda pantalla con campos lleva `keyboardDismissal()` (cerrar al desplazar; sin botón OK encima del teclado, también para el numérico, decisión del usuario del 2026-10-25), y tocar fuera de un campo lo cierra en toda la app (`dismissesKeyboardOnTapOutside()` en la raíz, `App/Shared/Keyboard.swift`; lo prueba `UITests/KeyboardTests.swift`). Salvo en las filas de un `Form` (los ajustes), donde ese reconocedor no actúa: ahí se cierra como en iOS, desplazando o con la tecla de retorno del último campo (la de los demás pasa al siguiente; decisión del usuario, 2026-10-26).
- **`confirmationDialog` en iOS 26 es un globo que apunta a la vista de la que cuelga**: se cuelga del botón o de la fila que lo abre, nunca de la pantalla entera. El globo no enseña el botón de `role: .cancel`: se cierra tocando fuera (en los tests de UI, tocar fuera).
- **`accessibilityIdentifier` en un contenedor pisa el de todo lo que tiene dentro** (`.xcresult` del CI, 2026-10-27): va en el elemento concreto (la cabecera de la tarjeta, `CardDisclosure(identifier:)`), nunca en la tarjeta ni en la pantalla entera. Si no sale de nada concreto (el conflicto de la sincronización), `.alert`. Lo que confirma una acción de deslizar cuelga de su fila, que no desaparece (borrar una sesión y quitar un ejercicio, el mismo globo; repaso de la HIG, 2026-10-28).
- **SwiftUI cierra un diálogo o alerta antes de ejecutar la acción del botón**: el `set` del `isPresented` (que descarta el aviso del modelo) va primero. La acción no puede leer el aviso del modelo: se usa `presenting:` y el modelo recibe el aviso (`confirmDelete(prompt)`). Así borrar del historial no hacía nada (2026-10-25); los tests del modelo lo prueban en ese orden y `UITests/HistoryTests.swift`, con el gesto real.
- **Una acción de deslizar (`swipeActions`) con `role: .destructive` quita la fila al tocarla**, antes de que los datos cambien: si se confirma después, la fila sale, vuelve y las demás bailan (2026-10-25). Las de borrar con confirmación van sin rol y con `.tint(Theme.actionRed)`: los fondos de las acciones de deslizar (`Theme.action…`) son más oscuros que los colores de la PWA para que el blanco de iOS se lea (4,5:1, `PaletteTests`).
- **Swift Charts con `AreaMark` incluye el 0 en el eje**: el relleno va con `yStart` en el mínimo del eje (`Chart.valueRange`), como el eje ajustado de Chart.js.
- **Fechas y números del sistema siguen la región del iPhone**: la raíz fija `es_ES` para los selectores de fecha y los ejes; los textos propios ya salen de `Presentation`.
- Zonas de toque de 44 pt aunque el control se vea más pequeño (`TouchTarget.side(for:)`, `App/Shared/TouchTarget.swift`: 4 pt más por cada lado de lo que se ve), sin montarse unas con otras (`UITests/TouchTargetTests.swift`). El margen de una fila va dentro de su botón, para que se toque entera (Progreso).
- **Lo que se abre y se cierra es `CardDisclosure`** (`App/Shared/Disclosure.swift`): toda la cabecera se toca, la flecha de iOS gira y VoiceOver dice «Plegado» o «Desplegado». No `DisclosureGroup`: dentro de una fila de `List` (el entreno) pintaba la cabecera y el contenido uno encima de otro (2026-10-26). Si al abrir se ve más de lo mismo y no algo escondido, `DisclosureHeader` suelta. Abre y cierra con `.snappy` (el contenido entra deslizándose), sin el relleno de las tarjetas: con él se veía demasiado la diferencia entre la cabecera iluminada y lo que se despliega (decisión del usuario, 2026-10-26). Las pantallas con tarjetas desplegables van en `VStack`, no `LazyVStack`: son pocas tarjetas. Dentro de una `List` (el entreno) se abren y se cierran sin animación (`disclosureAnimates` a `false`; solo gira la flecha): con animación, la lista daba a la fila su altura nueva pero seguía pintando la tarjeta a su tamaño de antes, con la cabecera encima del contenido (2026-10-27). Probado y descartado: quitar el `.offset` de la transición, atar la animación al valor de la fila, poner el contenido arriba, animar la altura desde 0. Si hace falta que una pantalla con tarjetas desplegables anime, que no sea una `List` (Progreso es un `VStack` por eso).
- **La corona del reloj, con un `ScrollView`**: desplaza el contenido sola (los ejercicios del reloj son páginas de un `ScrollView` con `.scrollTargetBehavior(.paging)` y `scrollPosition`). `digitalCrownRotation` a mano, con su foco, en una página de un `TabView` no respondía a la corona en los tests de UI (2026-10-29: tres runs a ciegas; antes de tocar, mirar el vídeo del fallo).
- **Nada de `onAppear` que cierre la pantalla empujada**: la pantalla de debajo lanza su `onAppear` en cuanto empieza el gesto de volver, y el detalle desaparecía de golpe a mitad del arrastre.
- **Una pantalla empujada (`navigationDestination`) es su propia vista, que lee el modelo** (`RoutinePreview`, `SessionDetail`), no una propiedad de la pantalla de debajo: construida ahí, los cambios del modelo le llegaban sin la animación y las tarjetas se abrían de golpe (vídeo del CI, 2026-10-27).

## Decisiones de interfaz

Cómo es cada parte de la app y por qué está en `docs/decisiones-ui.md`: leerlo antes de tocar una pantalla.
