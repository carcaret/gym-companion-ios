# CLAUDE.md

App nativa de iOS (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA que sustituye. Responde en español de España. Por ahora es una app vacía que sirvió de prueba de concepto del despliegue (2026-10-25); la migración de la PWA está pendiente.

## Cómo se despliega (sin Mac y sin cuenta de pago de Apple)

1. Push a `master` → `.github/workflows/build.yml` en `macos-26`: genera el proyecto con XcodeGen (`project.yml`), compila con `CODE_SIGNING_ALLOWED=NO` y publica la release `latest` ("Build N", `GymCompanion.ipa` + `.sha256`). Tarda unos 2 minutos.
2. El NAS (`ios-signer`, en el repo `home-nas`, README sección ios-signer) ve la release nueva en menos de 5 minutos, la firma con un Apple ID gratuito y la instala por WiFi en cuanto el iPhone está en casa (desbloqueado, o bloqueado y cargando). Avisa por Home Assistant.

Para comprobar un despliegue: el run en `GET /repos/carcaret/gym-companion-ios/actions/runs?per_page=1` y, en el NAS, `tail /volume1/docker/ios-signer/data/ios-signer.log`.

## Reglas

- No hay Xcode a mano: todo se compila en Actions. El `.xcodeproj` no se versiona; cualquier ajuste del proyecto (targets, capacidades, Info.plist) va en `project.yml`.
- **No cambiar `PRODUCT_BUNDLE_IDENTIFIER`** (`com.carcaret.gymcompanion`): plumesign le añade el team ID y es lo que identifica la app en el iPhone; si cambia, se instala otra app nueva y la vieja se queda con los datos.
- `CURRENT_PROJECT_VERSION` lo pone el workflow (número de ejecución); `MARKETING_VERSION` se sube a mano.
- El repo es público (las máquinas macOS de Actions son gratis solo así): nada de secretos ni datos personales en el código.
- Límites de la cuenta gratuita de Apple: sin iCloud/CloudKit ni notificaciones push; cada target extra (widget, Apple Watch) gasta uno de los 10 identificadores de app por semana. Si un día hace falta algo de eso, la salida es la cuenta de pago (TestFlight).
- Los datos irán en local en el iPhone, con copia en GitHub como hace la PWA (`db.json`). La PWA es de un solo usuario y un solo aparato: nada de sincronización multi-aparato ni CRDT.
