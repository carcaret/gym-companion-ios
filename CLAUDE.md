# CLAUDE.md

App nativa de iOS (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA que sustituye. Responde en español de España. La migración de la PWA está en curso (épica #1).

## Plan de trabajo: épica #1

La migración está planificada en la issue **#1** ("Migrar Gym Companion a app nativa iOS") y sus sub-issues #2–#18, con todo el contexto (decisiones, arquitectura, entorno, cadena de despliegue, estructura de la PWA y qué tests portar en cada una). **Leer #1 entera antes de empezar cualquier sub-issue**, y la sub-issue concreta.

- **Autonomía**: el usuario no quiere aprobar nada. Una rama y un PR por sub-issue (`Closes #N`); con el CI en verde, Claude revisa el diff y fusiona él mismo. Solo se pregunta lo imprescindible (borrar o debilitar un test, decisiones de producto no deducibles, acciones con el iPhone o el Watch en la mano), de una en una.
- **Sin guarradas**: arquitectura hexagonal por capas (un módulo por capa), cada regla con su test, y cuestionar el criterio del usuario cuando no sea el correcto.
- **TDD**: primero el test. Los tests de la PWA se portan (unitarios uno a uno; e2e por comportamiento) y nunca se borran ni debilitan sin aprobación.
- **Sin iCloud** mientras no se pague la cuenta de Apple: datos locales + sincronización con el `db.json` de la PWA (detalles en #1 y #7).

## Estructura y capas

```
Packages/GymCore/            paquete Swift, un módulo por capa (las dependencias las impone el compilador)
  Sources/Domain/            modelo (TrainingData, Catalog, Routine, Session, ExerciseLog, LocalDate...) y reglas puras
  Sources/Presentation/      textos en español para la interfaz (fechas, resúmenes, frases, mensajes) y
                             lectura de lo tecleado. Depende de Domain
  Sources/Application/       casos de uso y puertos (protocolos: Clock...). Depende de Domain
  Sources/Adapters/          implementaciones de los puertos (SystemClock; después GitHub, almacenamiento...)
  Tests/<Módulo>Tests/       Swift Testing
  test.sh                    los tests en el NAS
App/                         app iOS: vistas SwiftUI finas, ViewModels @Observable y CompositionRoot.swift
UITests/                     XCUITest: pocos flujos y las capturas de pantalla
project.yml                  XcodeGen (el .xcodeproj no se versiona)
scripts/pwa_tests.py         cruza los tests de la PWA con los de la app (ver Tests)
```

- `Domain`, `Presentation` y `Application` **no importan frameworks de Apple** (hoy ni siquiera Foundation; si hiciera falta, solo lo que compile en Linux): sus tests corren en el NAS y en un job de Linux del CI, que es quien lo vigila.
- Un adaptador que solo exista en Apple (SwiftData, HealthKit, WatchConnectivity...) va en su propio módulo, para que el resto del paquete siga compilando en Linux.
- `App/CompositionRoot.swift` es el único sitio que crea adaptadores concretos.
- Reglas de negocio en `Domain`; lo que es texto para la interfaz, en `Presentation` (p. ej. el error es `LogValidationError.negativeWeight` y el mensaje "Peso debe ser >= 0" lo da `ValidationText`).
- El modelo no calca `db.json`: el log no copia el nombre del ejercicio, las rutinas son entidades, las fechas son `LocalDate`. La traducción a `db.json` es cosa del adaptador (#6, #7).
- Fechas: el "hoy" es el día local (`Clock`), no el UTC que usaba la PWA.
- Orden alfabético siempre con `SpanishCollation` (el `localeCompare(…, 'es')` de la PWA) y búsquedas con `searchFolded`.
- Textos de la interfaz en español en el código (`Text("Versión \(…)")`), recogidos en `App/Localizable.xcstrings` (idioma base `es`).

## Tests

En el NAS (segundos; la primera vez descarga la imagen): `Packages/GymCore/test.sh` (admite los argumentos de `swift test`, p. ej. `--filter LocalDate`). Es esto, con el usuario propio para que `.build` no quede de root:

```sh
docker run --rm --user 1000:10 -e HOME=/tmp -v ~/git/gym-companion-ios:/w -w /w/Packages/GymCore swift:6.3.3 swift test
```
 La imagen lleva la misma versión de Swift que el Xcode del runner `macos-26` (Xcode 26.6 → Swift 6.3.3, sale en el paso "Generar proyecto" del CI) y la misma que el job `core-linux` de `build.yml`: si Xcode cambia de versión, cambiarla en los dos sitios.

En CI (`.github/workflows/build.yml`), en cada PR y en `master`: `core-linux` (paquete en Linux), `pwa-tests` (cruce con la PWA) y `app` (paquete en macOS y tests de la app en el simulador). La release solo se publica en `master` y si todos pasan.

**Tests portados de la PWA**: cada test lleva en Swift el mismo nombre que en Vitest (`@Suite` = el `describe`, `@Test` = el `test`), para poder cruzarlos. `scripts/pwa_tests.py ~/git/gym-companion` comprueba los ficheros de `docs/pwa-tests-ficheros.txt` (cada sub-issue añade los suyos) y falla si alguno no está portado ni en `docs/pwa-tests-no-aplican.tsv` con su motivo; con `--markdown` saca la tabla del PR. Cambiar lo que comprueba un test portado necesita la aprobación del usuario y se anota en el propio test (p. ej. la media de reps, aprobado el 2026-10-25).

**Capturas**: `UITests/ScreenshotTests.swift` guarda una captura por pantalla principal; el job `app` las sube como artefacto `capturas` (PNG con el nombre de la captura). Para verlas: `GET /repos/carcaret/gym-companion-ios/actions/runs/{id}/artifacts` → `archive_download_url` (zip, con el token) y abrir los PNG con Read. Al añadir una pantalla, añadir su captura.

## Cómo se despliega (sin Mac y sin cuenta de pago de Apple)

1. Push a `master` → `.github/workflows/build.yml`: tests y, si pasan, genera el proyecto con XcodeGen (`project.yml`), compila con `CODE_SIGNING_ALLOWED=NO` y publica la release `latest` ("Build N", `GymCompanion.ipa` + `.sha256`).
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
