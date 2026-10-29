/// Los identificadores de accesibilidad que buscan los tests de interfaz. Los comparten la app y
/// `UITests` (`project.yml`): cambiar uno aquí cambia los dos lados, y un nombre que ya no existe no
/// compila.
enum AccessibilityID {
    // El reloj
    static let watchStart = "watch-start"
    static let watchRest = "watch-rest"
    static let watchFinish = "watch-finish"
    static let watchDone = "watch-done"

    // Rutinas y entreno
    static let startWorkout = "start-workout"
    static let finishWorkout = "finish-workout"
    static let addExercise = "add-exercise"
    static let workoutCompleted = "workout-completed"
    static let createExercise = "create-exercise"
    static let createFromSearch = "create-from-search"
    static let createName = "create-name"
    static let createConfirm = "create-confirm"
    static func routine(_ id: String) -> String { "routine-\(id)" }

    // La tarjeta de un ejercicio
    static let cardPrefix = "card-"
    static func card(_ exercise: String) -> String { cardPrefix + exercise }
    static func series(_ index: Int) -> String { "series-\(index)" }
    static let chipPrefix = "chip-"
    static func chip(_ value: Int) -> String { chipPrefix + "\(value)" }
    static let stripBarPrefix = "strip-bar-"
    static func stripBar(_ index: Int) -> String { stripBarPrefix + "\(index)" }

    /// Peso, series y objetivo, y cada parte de su fila: `weight-plus`, `series-field`…
    enum Parameter: String, CaseIterable {
        case weight, series
        case targetReps = "target-reps"
    }

    enum ParameterPart: String {
        case minus, field, plus, value
    }

    static func parameter(_ parameter: Parameter, _ part: ParameterPart) -> String { "\(parameter.rawValue)-\(part.rawValue)" }

    // Historial
    static let historyPrefix = "history-"
    static func history(_ isoDate: String) -> String { historyPrefix + isoDate }
    static let sessionEdit = "session-edit"
    static let sessionDone = "session-done"
    static let sessionCancel = "session-cancel"

    // Gráficas, Progreso y catálogo
    static let chartExercise = "chart-exercise"
    static let statsExercises = "stats-exercises"
    static func statsRow(_ exercise: String) -> String { "stats-row-\(exercise)" }
    static let statsGroupPrefix = "stats-group-"
    static func statsGroup(_ name: String) -> String { statsGroupPrefix + name }
    static let catalogButton = "catalog-button"

    // Sincronización y ajustes
    static let syncIndicator = "sync-indicator"
    static let notice = "notice"
    static let settingsRepository = "settings-repository"
    static let settingsBranch = "settings-branch"
    static let settingsPath = "settings-path"
    static let settingsToken = "settings-token"
    static let settingsClose = "settings-close"
    static let settingsVersion = "settings-version"
    static let dataRetry = "data-retry"
    static let dataDownload = "data-download"
}
