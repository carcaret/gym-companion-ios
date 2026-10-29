import Presentation
import SwiftUI
import ViewModels

/// La página del entreno: arriba, el pulso (la hora la pone watchOS); en grande, el tiempo o el
/// descanso, que se tocan (o el doble toque) para descansar; debajo, el ejercicio, que se cambia
/// con la corona. Con la muñeca bajada, lo mismo atenuado.
struct WorkoutPage: View {
    @Bindable var model: WatchModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var crown = 0.0
    /// La corona es de esta página: sin el foco, no le llega.
    @FocusState private var isCrownFocused: Bool

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
                if let exercise = model.currentExercise {
                    ExerciseView(exercise: exercise, isDimmed: isLuminanceReduced)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusable()
            .focused($isCrownFocused)
            .digitalCrownRotation(
                $crown, from: 0, through: Double(max(model.exercises.count - 1, 1)), by: 1,
                sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
            )
            .onChange(of: crown) { _, value in
                model.showExercise(at: Int(value.rounded()))
            }
            .onChange(of: model.exerciseIndex) { _, index in
                if Int(crown.rounded()) != index { crown = Double(index) }
            }
            .onAppear {
                crown = Double(model.exerciseIndex)
                isCrownFocused = true
            }
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
}
