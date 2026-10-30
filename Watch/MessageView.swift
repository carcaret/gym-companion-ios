import SwiftUI

/// Sin entreno que enseñar: el porqué («Empieza el entreno en el iPhone»).
struct MessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textSecondary)
    }
}
