import Domain

/// Cambio de una sesión frente a la anterior: "+5 kg", "-50%".
public struct SessionDelta: Hashable, Sendable {
    public let up: Bool
    public let label: String

    public init(up: Bool, label: String) {
        self.up = up
        self.label = label
    }
}

/// Una columna de la tira.
public struct StripBar: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Hueco delante cuando hay menos de seis sesiones.
        case empty
        /// Sesión saltada: una barra fantasma en su sitio.
        case skipped
        /// Altura en % (6–100), color, si es la de hoy y el detalle al tocarla.
        case session(height: Int, color: RGB, isCurrent: Bool, tooltip: String)
    }

    public let kind: Kind
    /// "1/6"; vacío en los huecos.
    public let dateLabel: String
}

/// La tira "Últimas sesiones" de un ejercicio.
public struct HistoryStripContent: Hashable, Sendable {
    /// Siempre seis columnas.
    public let bars: [StripBar]
    public let delta: SessionDelta?

    /// "↑ +5 kg vs última".
    public var deltaText: String? {
        delta.map { "\($0.up ? "↑" : "↓") \($0.label) vs última" }
    }
}

/// La tira de historial de cada ejercicio (`buildHistoryStripHtml` y compañía en la PWA): las
/// últimas sesiones terminadas (6 semanas, 6 como mucho) más la de hoy, con la altura según la
/// métrica principal y el color según `BarColor`.
public enum HistoryStrip {
    static let columns = 6
    /// Techo de las barras sin lastre cuando la tira las mezcla con lastradas.
    static let unloadedCeiling = 0.5

    /// `nil` si no hay ninguna sesión que pintar.
    public static func make(history: [Session], exercise: ExerciseID, current: ExerciseLog, anchor: LocalDate) -> HistoryStripContent? {
        struct Item { let date: LocalDate; let log: ExerciseLog; let isCurrent: Bool }
        var items = history.recentSessions(for: exercise, anchor: anchor, maxSessions: 6, weeks: 6, excluding: anchor)
            .map { Item(date: $0.date, log: $0.log, isCurrent: false) }
        let hasCurrent = current.primaryMetric > 0
        if hasCurrent { items.append(Item(date: anchor, log: current, isCurrent: true)) }
        guard !items.isEmpty else { return nil }

        var delta: SessionDelta?
        if hasCurrent, let previous = items.dropLast().last(where: { !$0.log.skipped }) {
            delta = Self.delta(current: current, previous: previous.log)
        }

        let shown = Array(items.suffix(columns))
        let real = shown.filter { !$0.log.skipped }
        let levels = Self.levels(real.map(\.log))
        var blueLevels: [Double] = []
        var greenLogs: [ExerciseLog] = []
        for (item, level) in zip(real, levels) {
            if BarColor.isGreen(item.log, referenceWeight: current.weight) { greenLogs.append(item.log) } else { blueLevels.append(level) }
        }
        let blueRange = blueLevels.isEmpty ? 0...0 : blueLevels.min()!...blueLevels.max()!
        let greenScale = BarColor.greenScale(greenLogs)

        var levelIndex = 0
        let bars = Array(repeating: StripBar(kind: .empty, dateLabel: ""), count: columns - shown.count) + shown.map { item in
            let label = DateText.short(item.date)
            guard !item.log.skipped else { return StripBar(kind: .skipped, dateLabel: label) }
            let level = levels[levelIndex]
            levelIndex += 1
            let color = BarColor.color(item.log, blueRange: blueRange, greenScale: greenScale, referenceWeight: current.weight, blueMetric: level)
            let height = max(6, Int((level * 100 + 0.5).rounded(.down)))
            return StripBar(kind: .session(height: height, color: color, isCurrent: item.isCurrent, tooltip: tooltip(item.log)), dateLabel: label)
        }
        return HistoryStripContent(bars: bars, delta: delta)
    }

    /// Misma unidad (las dos con lastre o las dos sin él): % de la métrica principal. Si una va con
    /// lastre y la otra no, manda la carga. `nil` si no cambia. (`computeSessionDelta`.)
    public static func delta(current: ExerciseLog, previous: ExerciseLog) -> SessionDelta? {
        if (current.weight > 0) != (previous.weight > 0) {
            let kilograms = current.weight - previous.weight
            return SessionDelta(up: kilograms > 0, label: "\(kilograms > 0 ? "+" : "")\(LogText.kilograms(kilograms)) kg")
        }
        guard let percent = Metrics.sessionDeltaPercent(current: current.primaryMetric, previous: previous.primaryMetric) else { return nil }
        return SessionDelta(up: percent > 0, label: "\(percent > 0 ? "+" : "")\(percent)%")
    }

    /// Nivel 0…1 de cada barra (su altura). Si se mezclan sesiones sin lastre y con lastre, cada
    /// grupo se normaliza contra su máximo y las lastradas van por encima. (`computeStripLevels`.)
    public static func levels(_ logs: [ExerciseLog]) -> [Double] {
        let metrics = logs.map(\.primaryMetric)
        func ratio(_ metric: Double, _ group: (ExerciseLog) -> Bool) -> Double {
            let maximum = zip(logs, metrics).filter { group($0.0) }.map(\.1).max() ?? 0
            return maximum > 0 ? metric / maximum : 0
        }
        let loaded: (ExerciseLog) -> Bool = { $0.weight > 0 }
        let mixed = logs.contains(where: loaded) && !logs.allSatisfy(loaded)
        guard mixed else { return metrics.map { ratio($0, { _ in true }) } }
        return zip(logs, metrics).map { log, metric in
            loaded(log)
                ? unloadedCeiling + (1 - unloadedCeiling) * ratio(metric, loaded)
                : unloadedCeiling * ratio(metric, { !loaded($0) })
        }
    }

    /// Detalle de una barra en dos líneas, igual que la PWA (`buildBarTooltip`): "e1RM 84kg" y
    /// "60kg · 12-11-10", con los números como los escribe JavaScript.
    public static func tooltip(_ log: ExerciseLog) -> String {
        let e1rm = log.estimatedOneRepMax
        let first = e1rm > 0 ? "e1RM \(jsNumber((e1rm * 10 + 0.5).rounded(.down) / 10))kg" : ""
        let reps = log.actualReps.contains { $0 != nil } ? log.actualReps.map { $0.map(String.init) ?? "-" }.joined(separator: "-") : ""
        let second = [log.weight > 0 ? "\(jsNumber(log.weight))kg" : "", reps].filter { !$0.isEmpty }.joined(separator: " · ")
        return [first, second].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Un número como lo escribe JavaScript: "60", "73.3".
    static func jsNumber(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int64(value)) : "\(value)"
    }
}

/// Los chips para elegir las reps de una serie (`buildChipValues`, `buildChipStripHtml`).
public enum RepChips {
    /// Cinco valores alrededor de `current`, sin bajar de 0.
    public static func values(around current: Int) -> [Int] {
        let low = max(0, current - 2)
        return Array(low...(low + 4))
    }
}
