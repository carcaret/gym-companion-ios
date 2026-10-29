# Gym Companion (iOS)

App nativa (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion), la PWA a la que sustituye. La migración está planificada en la issue #1; cómo se trabaja en el repo (capas, tests, CI, capturas), en `CLAUDE.md`.

- `Packages/GymCore`: el núcleo, un módulo por capa (`Domain`, `Presentation`, `Application`, `ViewModels` y los adaptadores); el detalle, en `CLAUDE.md`.
- `App/` y `Watch/`: las apps del iPhone y del reloj (SwiftUI), clientes del paquete; `UITests/` y `WatchUITests/`, sus tests de interfaz. El proyecto de Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`.

Despliegue sin cuenta de pago de Apple:

1. Cada PR pasa los tests en GitHub Actions (Linux y `macos-26`, con el simulador). Al fusionarla, `master` no los repite (ya pasaron con el mismo árbol): compila la app **sin firmar** y la publica como release `latest` (`GymCompanion.ipa`). Un push directo, o una PR que no estaba al día, pasa antes todos los tests.
2. El NAS (contenedor `ios-signer` del repo `home-nas`, sección ios-signer de su README) la firma con un Apple ID gratuito (perfil de 7 días, renovado a los 5) y la instala en el iPhone por WiFi en cuanto está en casa.
