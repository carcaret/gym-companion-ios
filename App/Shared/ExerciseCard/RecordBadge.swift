import SwiftUI

/// Récord: dorado sobre dorado muy suave (`.record-badge`).
struct RecordBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "trophy.fill")
            .scaledFont(11, .bold)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Theme.gold.opacity(0.1), in: .capsule)
    }
}
