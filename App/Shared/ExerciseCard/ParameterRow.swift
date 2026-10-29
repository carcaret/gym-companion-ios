import Domain
import Presentation
import SwiftUI
import ViewModels

/// Peso, series u objetivo: −/+ redondos y el valor, que se puede teclear (en la vista previa,
/// solo el valor).
struct ParameterRow: View {
    let parameter: LogParameter
    let label: String
    let value: String
    let decimal: Bool
    let hasError: Bool
    let adjust: ((Int) -> Void)?
    let type: ((String) -> Void)?
    let commit: (() -> Void)?
    @State private var text = ""
    /// La caja del valor crece con la letra (Dynamic Type).
    @ScaledMetric(relativeTo: .subheadline) private var boxWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .subheadline) private var boxHeight: CGFloat = 36
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Con letra grande pasa a dos líneas en vez de cortarse.
            Text(label).scaledFont(12, .medium).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            // Las zonas de toque sobresalen 4 pt de cada círculo: entre ellos y la caja se ven 10.
            HStack(spacing: 6) { controls }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let adjust, let type, let commit {
            RoundIconButton(systemImage: "minus") { adjust(-1) }
                .accessibilityLabel(CardAccessibilityText.decrease(parameter))
                .accessibilityIdentifier("\(identifier)-minus")
            TextField(label, text: $text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .scaledFont(15, .semibold)
                .foregroundStyle(Theme.text)
                // La caja se ve de su altura, pero la zona de toque es de 44: el campo de texto solo
                // ocupa la línea del texto, y lo que queda alrededor (detrás) también lo abre.
                .frame(width: boxWidth, height: TouchTarget.side(for: boxHeight))
                .background {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.input)
                        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(hasError ? Theme.red : focused ? Theme.accent : Theme.border) }
                        .frame(height: boxHeight)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                        .onTapGesture { focused = true }
                }
                .focused($focused)
                .onAppear { text = value }
                .onChange(of: value) { _, new in text = new }
                // Un botón no quita el foco: el modelo se queda con lo tecleado y lo aplica
                // al salir del campo o antes de la siguiente acción (`TypedValue`).
                .onChange(of: text) { _, new in if focused, new != value { type(new) } }
                .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                .onDisappear { if focused { commit() } }
                // VoiceOver: «Peso, 60 kg», y deslizar arriba o abajo lo cambia, como un
                // Stepper; tocar dos veces lo edita con el teclado.
                .accessibilityLabel(CardAccessibilityText.name(parameter))
                .accessibilityValue(CardAccessibilityText.value(parameter, value, hasError: hasError))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: adjust(1)
                    case .decrement: adjust(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("\(identifier)-field")
            RoundIconButton(systemImage: "plus") { adjust(1) }
                .accessibilityLabel(CardAccessibilityText.increase(parameter))
                .accessibilityIdentifier("\(identifier)-plus")
        } else {
            Text(value)
                .scaledFont(15, .semibold)
                .foregroundStyle(Theme.text)
                .frame(width: boxWidth, height: boxHeight)
                .background(Theme.input, in: .rect(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border) }
                .accessibilityLabel(CardAccessibilityText.name(parameter))
                .accessibilityValue(CardAccessibilityText.value(parameter, value, hasError: hasError))
                .accessibilityIdentifier("\(identifier)-value")
                .frame(height: TouchTarget.side(for: boxHeight))
        }
    }

    /// Para los tests de UI: `weight-plus`, `series-field`…
    private var identifier: String {
        switch parameter {
        case .weight: "weight"
        case .series: "series"
        case .targetReps: "target-reps"
        }
    }
}

/// `.btn-icon`: botón redondo con borde.
struct RoundIconButton: View {
    let systemImage: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .scaledFont(14, .semibold)
                .foregroundStyle(Theme.text)
                .frame(width: side, height: side)
                .background(Theme.input, in: .circle)
                .overlay { Circle().strokeBorder(Theme.border) }
                .frame(width: TouchTarget.side(for: side), height: TouchTarget.side(for: side))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
