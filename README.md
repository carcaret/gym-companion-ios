# Gym Companion (iOS)

App nativa (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA a la que sustituye. La migración está planificada en la issue #1; cómo se trabaja en el repo (capas, tests, CI, capturas), en `CLAUDE.md`.

- `Packages/GymCore`: el núcleo, un módulo por capa (`Domain`, `Application`, `Adapters`).
- `App/`: la app iOS (SwiftUI), cliente del paquete. El proyecto de Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`.

Despliegue sin cuenta de pago de Apple:

1. Cada PR y cada push a `master` pasan los tests en GitHub Actions (Linux y `macos-26`, con el simulador). En `master`, si pasan, la app se compila **sin firmar** y se publica como release `latest` (`GymCompanion.ipa`).
2. El NAS (contenedor `ios-signer` del repo `home-nas`, sección ios-signer de su README) la firma con un Apple ID gratuito (perfil de 7 días, renovado a los 5) y la instala en el iPhone por WiFi en cuanto está en casa.
