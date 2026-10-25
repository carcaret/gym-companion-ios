# Gym Companion (iOS)

App nativa (SwiftUI) de [gym-companion](https://github.com/carcaret/gym-companion). Por ahora, prueba de concepto de la cadena de despliegue sin cuenta de pago de Apple:

1. Cada push a `master` compila la app **sin firmar** en GitHub Actions (`macos-26`) y la publica como release `latest` (`GymCompanion.ipa`).
2. El NAS (contenedor `ios-signer` del repo `home-nas`) la firma con un Apple ID gratuito (certificado de 7 días) y la instala en el iPhone por WiFi.

El proyecto de Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`.
