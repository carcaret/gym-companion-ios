import Domain
import Presentation
import SwiftUI

/// El grupo principal de un ejercicio, en un menú: «Sin grupo» y los que se pueden elegir. Lo usan
/// el editor del catálogo y la pantalla de crear un ejercicio.
struct MuscleGroupPicker: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        Picker(CatalogText.groupLabel, selection: $selection) {
            Text(CatalogText.noGroup).tag(MuscleGroup?.none)
            ForEach(MuscleGroup.all, id: \.self) { group in
                Text(GroupText.name(group)).tag(MuscleGroup?.some(group))
            }
        }
        .pickerStyle(.menu)
    }
}
