import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una tarjeta de ejercicio. En la vista previa es de solo lectura; en el entreno, `actions` trae
/// lo que se puede hacer con ella.
struct ExerciseCardView: View {
    let card: TodayModel.Card
    let toggle: () -> Void
    var actions: CardActions?

    struct CardActions {
        let adjust: (LogParameter, Int) -> Void
        let set: (LogParameter, String) -> Void
        let focusSeries: (Int) -> Void
        let chooseRep: (Int, Int) -> Void
        let swap: () -> Void
        let toggleSkip: () -> Void
        let remove: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if card.isOpen { content }
        }
        .padding()
        .background(card.isSkipped ? Color.gray.opacity(0.15) : Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("card-\(card.exerciseID.rawValue)")
    }

    private var header: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(card.title).font(.headline)
                        if card.isVolumeRecord { RecordBadge(text: TodayText.volumeRecord) }
                        if card.isE1RMRecord { RecordBadge(text: TodayText.e1rmRecord) }
                    }
                    Text(card.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(card.isOpen ? 180 : 0))
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(card.isOpen ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if let strip = card.strip { HistoryStripView(strip: strip) }
        VStack(spacing: 8) {
            ParameterRow(label: TodayText.weightLabel, value: LogText.kilograms(card.weight), decimal: true, hasError: card.errors.contains(.negativeWeight),
                         adjust: actions.map { a in { a.adjust(.weight, $0) } }, set: actions.map { a in { a.set(.weight, $0) } })
            ParameterRow(label: TodayText.seriesLabel, value: "\(card.series)", decimal: false, hasError: card.errors.contains(.invalidSeries),
                         adjust: actions.map { a in { a.adjust(.series, $0) } }, set: actions.map { a in { a.set(.series, $0) } })
            ParameterRow(label: TodayText.targetRepsLabel, value: "\(card.targetReps)", decimal: false, hasError: card.errors.contains(.invalidTargetReps),
                         adjust: actions.map { a in { a.adjust(.targetReps, $0) } }, set: actions.map { a in { a.set(.targetReps, $0) } })
        }
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            Text(TodayText.seriesSectionLabel).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(max(card.cells.count, 1), 5)), spacing: 8) {
                ForEach(Array(card.cells.enumerated()), id: \.offset) { series, cell in
                    SeriesCellView(cell: cell, onTap: actions.map { a in { a.focusSeries(series) } })
                }
            }
            if !card.chips.isEmpty, let actions, let focused = card.cells.firstIndex(where: \.isFocused) {
                HStack(spacing: 8) {
                    ForEach(card.chips, id: \.value) { chip in
                        Button("\(chip.value)") { actions.chooseRep(chip.value, focused) }
                            .buttonStyle(.bordered)
                            .tint(chip.relation == .below ? .orange : chip.relation == .atTarget ? .green : .blue)
                            .fontWeight(chip.isCurrent ? .bold : .regular)
                            .accessibilityIdentifier("chip-\(chip.value)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        if card.isEditable, let actions {
            HStack {
                Button(TodayText.swapLabel, action: actions.swap)
                Spacer()
                Button(card.skipLabel, action: actions.toggleSkip)
                Spacer()
                Button(card.removeLabel, role: .destructive, action: actions.remove)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
    }
}

private struct RecordBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "trophy.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.yellow.opacity(0.25), in: .capsule)
    }
}

/// Peso, series u objetivo: −/+ y el valor, que se puede teclear (en la vista previa, solo el valor).
private struct ParameterRow: View {
    let label: String
    let value: String
    let decimal: Bool
    let hasError: Bool
    let adjust: ((Int) -> Void)?
    let set: ((String) -> Void)?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if let adjust, let set {
                Button { adjust(-1) } label: { Image(systemName: "minus") }.buttonStyle(.bordered)
                TextField(label, text: $text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .overlay { if hasError { RoundedRectangle(cornerRadius: 6).stroke(.red) } }
                    .onAppear { text = value }
                    .onChange(of: value) { _, new in if !focused { text = new } }
                    .onChange(of: focused) { _, isFocused in if !isFocused, text != value { set(text) } }
                Button { adjust(1) } label: { Image(systemName: "plus") }.buttonStyle(.bordered)
            } else {
                Text(value).font(.body.monospacedDigit().weight(.semibold))
            }
        }
    }
}

private struct SeriesCellView: View {
    let cell: TodayModel.SeriesCell
    let onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            Text(cell.label).font(.caption2).foregroundStyle(.secondary)
            if let onTap {
                Button(action: onTap) { valueText }
                    .buttonStyle(.plain)
            } else {
                valueText
            }
        }
    }

    private var valueText: some View {
        Text(cell.text)
            .font(.body.monospacedDigit().weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(background, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(cell.hasError ? .red : cell.isFocused ? .accentColor : .clear, lineWidth: 2)
            }
    }

    private var background: Color {
        switch cell.state {
        case .done: .green.opacity(0.25)
        case .filled: .blue.opacity(0.25)
        case .empty: Color(.tertiarySystemFill)
        }
    }
}
