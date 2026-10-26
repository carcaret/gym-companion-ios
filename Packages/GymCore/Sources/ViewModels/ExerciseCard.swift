import Domain
import Presentation

/// Una tarjeta de ejercicio ya calculada, la misma en Hoy (vista previa y entreno) y en el detalle
/// del Historial (`buildExerciseCardBodyHtml` de la PWA): título y resumen, peso, series y objetivo,
/// una celda por serie, los chips de la serie enfocada y la tira de últimas sesiones.
public struct ExerciseCard: Hashable, Sendable, Identifiable {
    public enum SeriesState: Hashable, Sendable {
        /// Llegó al objetivo.
        case done
        /// Rellenada por debajo del objetivo.
        case filled
        case empty
    }

    public struct SeriesCell: Hashable, Sendable {
        public let label: String
        public let text: String
        public let value: Int?
        public let state: SeriesState
        public let isFocused: Bool
        public let hasError: Bool
    }

    public enum ChipRelation: Hashable, Sendable { case below, atTarget, above }

    public struct Chip: Hashable, Sendable {
        public let value: Int
        public let isCurrent: Bool
        public let relation: ChipRelation
    }

    public var id: ExerciseID { exerciseID }
    public let exerciseID: ExerciseID
    public let title: String
    public let subtitle: String
    public let isOpen: Bool
    /// Sin edición (vista previa) todo es de solo lectura: sin −/+, sin campos y sin chips.
    public let isEditable: Bool
    public let weight: Double
    public let series: Int
    public let targetReps: Int
    public let cells: [SeriesCell]
    /// Los chips de la serie enfocada.
    public let chips: [Chip]
    public let strip: HistoryStripContent?
    public let isVolumeRecord: Bool
    public let isE1RMRecord: Bool
    public let isSkipped: Bool
    public let isOneOff: Bool
    public let skipLabel: String
    public let removeLabel: String
    /// Errores de validación que hay que marcar.
    public let errors: [LogValidationError]
    /// Historial: hay cambios sin guardar (sale el botón "Guardar").
    public let isDirty: Bool

    public var hasRecord: Bool { isVolumeRecord || isE1RMRecord }

    /// `anchor`: el día de la sesión (la tira la pone la última y los récords no la cuentan).
    init(log: ExerciseLog, data: TrainingData, isOpen: Bool, isEditable: Bool, anchor: LocalDate,
         focusedSeries: Int?, errors: [LogValidationError], showsRecords: Bool, isDirty: Bool = false) {
        exerciseID = log.exerciseID
        title = data.catalog.name(of: log.exerciseID)
        subtitle = LogText.summary(log)
        self.isOpen = isOpen
        self.isEditable = isEditable
        weight = log.weight
        series = log.series
        targetReps = log.targetReps
        cells = (0..<max(0, log.series)).map { series in
            let value = series < log.actualReps.count ? log.actualReps[series] : nil
            let state: SeriesState = value.map { $0 >= log.targetReps ? .done : .filled } ?? .empty
            return SeriesCell(label: TodayText.seriesLabel(series), text: value.map(String.init) ?? TodayText.emptyRep, value: value, state: state,
                              isFocused: focusedSeries == series, hasError: errors.contains { $0.repIndex == series })
        }
        if let focused = focusedSeries, focused < log.series {
            let current = (focused < log.actualReps.count ? log.actualReps[focused] : nil) ?? log.targetReps
            chips = RepChips.values(around: current).map { value in
                Chip(value: value, isCurrent: value == current,
                     relation: value < log.targetReps ? .below : value == log.targetReps ? .atTarget : .above)
            }
        } else {
            chips = []
        }
        strip = HistoryStrip.make(history: data.history, exercise: log.exerciseID, current: log, anchor: anchor)
        let records = showsRecords ? log.records(against: data.history.filter { $0.date != anchor }) : nil
        isVolumeRecord = records?.isVolumeRecord ?? false
        isE1RMRecord = records?.isE1RMRecord ?? false
        isSkipped = log.skipped
        isOneOff = log.oneOff
        skipLabel = TodayText.skipLabel(skipped: log.skipped)
        removeLabel = TodayText.removeLabel(oneOff: log.oneOff)
        self.errors = errors
        self.isDirty = isDirty
    }
}
