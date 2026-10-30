import Presentation
import SwiftUI
import ViewModels

/// La página del entreno: arriba, el pulso, en la fila de la hora que pone watchOS; el tiempo o el
/// descanso, que se tocan (o el doble toque) para descansar; debajo, los ejercicios, de uno en uno:
/// la corona (o el dedo) los pasa, porque es un `ScrollView` con páginas. Con la muñeca bajada, lo
/// mismo atenuado.
///
/// Sin barra de navegación: el pulso en ella dejaba unos 30 pt vacíos encima del tiempo, y al lado
/// del tiempo no cabe (con «22:22» y «toca para descansar» la fila no llega). La página ocupa toda
/// la pantalla y el pulso va en la franja de la hora (foto del reloj, 2026-10-30).
struct WorkoutPage: View {
    @Bindable var model: WatchModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                heartRate
                    .frame(height: proxy.safeAreaInsets.top)
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
                // Con aire arriba y abajo: el ejercicio ya cabe y así no se ve todo apelotonado.
                Divider()
                    .padding(.top, 11)
                    .padding(.bottom, 10)
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
                .clipShape(Rectangle())
                .accessibilityIdentifier(AccessibilityID.watchExercises)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // De arriba abajo: arriba, el pulso entra en la franja de la hora; abajo, la lista llega
            // a los puntos de las páginas (con el margen de watchOS se cortaba unos 30 pt antes y
            // cada página de la lista medía menos de lo que se ve).
            .ignoresSafeArea(edges: [.top, .bottom])
        }
    }

    private var heartRate: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
            Text(model.metrics.heartRate)
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(Theme.redSoft)
        // Tan lejos del borde como la hora del suyo: pegado, la esquina redonda lo cortaba.
        .padding(.leading, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.watchHeartRate)
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
