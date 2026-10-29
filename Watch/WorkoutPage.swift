import Presentation
import SwiftUI
import ViewModels

/// La página del entreno: arriba, el pulso (la hora la pone watchOS); en grande, el tiempo o el
/// descanso, que se tocan (o el doble toque) para descansar; debajo, los ejercicios, de uno en uno:
/// la corona (o el dedo) los pasa, porque es un `ScrollView` con páginas. Con la muñeca bajada, lo
/// mismo atenuado.
struct WorkoutPage: View {
    @Bindable var model: WatchModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    model.tapRest()
                } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        TimeView(time: model.time, isDimmed: isLuminanceReduced)
                    }
                }
                .buttonStyle(.plain)
                .handGestureShortcut(.primaryAction)
                .accessibilityIdentifier(AccessibilityID.watchRest)
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.exercises) { exercise in
                            ExerciseView(exercise: exercise, isDimmed: isLuminanceReduced)
                                .containerRelativeFrame(.vertical, alignment: .topLeading)
                                .id(exercise.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: exercisePosition)
                // watchOS pinta el contenido también en el margen de abajo: sin recortar, el
                // siguiente ejercicio asoma debajo del que se ve.
                .clipShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                        Text(model.metrics.heartRate)
                    }
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.redSoft)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// El ejercicio a la vista es el del modelo: si un entreno nuevo vuelve al primero, la lista
    /// también.
    private var exercisePosition: Binding<Int?> {
        Binding(
            get: { model.exerciseIndex },
            set: { index in
                if let index { model.showExercise(at: index) }
            }
        )
    }
}
