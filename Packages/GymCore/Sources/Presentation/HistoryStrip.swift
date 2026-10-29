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

/// El detalle de una sesión de la tira: el e1RM y lo hecho (peso y reps). Cualquiera de los dos
/// puede faltar (sin peso no hay e1RM; sin reps, solo el peso).
public struct BarDetail: Hashable, Sendable {
    public let e1RM: String?
    public let done: String?

    public init(e1RM: String?, done: String?) {
        self.e1RM = e1RM
        self.done = done
    }

    /// Las dos líneas del tooltip de la PWA (`buildBarTooltip`): "e1RM 84 kg" y "60 kg · 12·11·10".
    public var tooltip: String { [e1RM, done].compactMap(\.self).joined(separator: "\n") }
}

/// Una columna de la tira.
public struct StripBar: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Hueco delante cuando hay menos de seis sesiones.
        case empty
        /// Sesión saltada: una barra fantasma en su sitio.
        case skipped
        /// Altura en % (6–100), color, si es la de hoy y el detalle al tocarla.
        case session(height: Int, color: RGB, isCurrent: Bool, detail: BarDetail)
    }

    public let kind: Kind
    /// "1/6"; vacío en los huecos.
    public let dateLabel: String

    public init(kind: Kind, dateLabel: String) {
        self.kind = kind
        self.dateLabel = dateLabel
    }

    /// Solo las sesiones tienen detalle: un toque en una vacía o saltada cuenta como fuera.
    public var isSelectable: Bool {
        if case .session = kind { return true }
        return false
    }

    public var isCurrent: Bool {
        if case .session(_, _, true, _) = kind { return true }
        return false
    }

    /// El bocadillo al tocarla: el peso y las reps destacados y debajo el e1RM (las dos líneas del
    /// tooltip de la PWA, al revés). `nil` si no hay detalle.
    public var bubble: (main: String, secondary: String?)? {
        guard case .session(_, _, _, let detail) = kind else { return nil }
        if let done = detail.done { return (done, detail.e1RM) }
        return detail.e1RM.map { ($0, nil) }
    }

    /// Para VoiceOver: el detalle en una línea, o la fecha.
    public var accessibilityText: String {
        if case .session(_, _, _, let detail) = kind { return [detail.e1RM, detail.done].compactMap(\.self).joined(separator: " · ") }
        return dateLabel
    }
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
    static let columns = RecentWindow.maxSessions
    /// Techo de las barras sin lastre cuando la tira las mezcla con lastradas.
    static let unloadedCeiling = 0.5

    /// `nil` si no hay ninguna sesión que pintar.
    public static func make(history: [Session], exercise: ExerciseID, current: ExerciseLog, anchor: LocalDate) -> HistoryStripContent? {
        struct Item { let date: LocalDate; let log: ExerciseLog; let isCurrent: Bool }
        var items = history.recentSessions(for: exercise, anchor: anchor, excluding: anchor)
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
        var belowTargetLogs: [ExerciseLog] = []
        for (item, level) in zip(real, levels) {
            if BarColor.isBelowTarget(item.log, referenceWeight: current.weight) { belowTargetLogs.append(item.log) } else { blueLevels.append(level) }
        }
        let blueRange = blueLevels.isEmpty ? 0...0 : blueLevels.min()!...blueLevels.max()!
        let belowTargetScale = BarColor.belowTargetScale(belowTargetLogs)

        var levelIndex = 0
        let bars = Array(repeating: StripBar(kind: .empty, dateLabel: ""), count: columns - shown.count) + shown.map { item in
            let label = DateText.short(item.date)
            guard !item.log.skipped else { return StripBar(kind: .skipped, dateLabel: label) }
            let level = levels[levelIndex]
            levelIndex += 1
            let color = BarColor.color(item.log, blueRange: blueRange, belowTargetScale: belowTargetScale, referenceWeight: current.weight, blueMetric: level)
            let height = max(6, Int(jsRound(level * 100)))
            return StripBar(kind: .session(height: height, color: color, isCurrent: item.isCurrent, detail: detail(item.log)), dateLabel: label)
        }
        return HistoryStripContent(bars: bars, delta: delta)
    }

    /// "+5 kg" o "+10%": el texto del cambio respecto a la sesión anterior (`ExerciseLog.change`).
    public static func delta(current: ExerciseLog, previous: ExerciseLog) -> SessionDelta? {
        switch current.change(from: previous) {
        case .load(let kilograms):
            SessionDelta(up: kilograms > 0, label: "\(kilograms > 0 ? "+" : "")\(LogText.weight(kilograms))")
        case .percent(let percent):
            SessionDelta(up: percent > 0, label: "\(percent > 0 ? "+" : "")\(percent)%")
        case nil:
            nil
        }
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

    /// Detalle de una barra, como la PWA (`buildBarTooltip`): "e1RM 84 kg" y "60 kg · 12·11·10".
    /// Los kilos, como en el resto de la app: con espacio y coma decimal (la PWA ponía "84kg" y
    /// "73.3kg"; cambio aprobado por el usuario, 2026-10-27).
    public static func detail(_ log: ExerciseLog) -> BarDetail {
        let reps = log.actualReps.contains { $0 != nil } ? LogText.reps(log.actualReps) : ""
        let done = [log.weight > 0 ? LogText.weight(log.weight) : "", reps].filter { !$0.isEmpty }.joined(separator: " · ")
        return BarDetail(e1RM: log.estimatedOneRepMax > 0 ? "e1RM \(LogText.weight(log.roundedEstimatedOneRepMax))" : nil,
                         done: done.isEmpty ? nil : done)
    }

    /// El detalle en las dos líneas del tooltip de la PWA (sus tests lo comprueban así).
    public static func tooltip(_ log: ExerciseLog) -> String { detail(log).tooltip }
}
