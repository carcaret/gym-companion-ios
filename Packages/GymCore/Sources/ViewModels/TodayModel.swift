import Application
import Domain
import Observation
import Presentation

/// La pestaña Rutinas (`views/hoy.js` de la PWA): elegir rutina, verla, entrenar y ver el entreno
/// terminado. Todo lo que pinta la vista sale de aquí ya calculado; las reglas son del dominio
/// (`TrainingData+Workout`) y los textos, de `TodayText`. Va en cuatro ficheros: los tipos, este (el
/// selector y la vista previa), el entreno en curso (`+Workout`) y el selector de ejercicios
/// (`+Picker`). El estado es `internal` para que lo vean las extensiones de los otros ficheros.
@MainActor
@Observable
public final class TodayModel {
    // MARK: - Estado

    var storedStage: Stage = .selector
    /// Tarjetas abiertas de la vista previa (independientes entre sí), por posición.
    public internal(set) var openPreviewCards: Set<Int> = []
    /// La tarjeta abierta del entreno (como mucho una), por ejercicio: sigue abierta aunque cambie
    /// de posición.
    var openExercise: ExerciseID?
    var editing = LogEditing()
    var pickerPurpose: PickerPurpose?
    public var pickerQuery = ""
    var pickerOneOff = false
    public var isCreatePresented = false
    public var createName = ""
    /// El grupo del ejercicio nuevo, en su pantalla (como en el editor del catálogo).
    public var createGroup: MuscleGroup?
    /// El mensaje de la pantalla de crear: por qué se ha vuelto a abrir (`TodayText.alreadyExists`).
    public internal(set) var createMessage: String?
    public internal(set) var replacePrompt: ReplacePrompt?
    public internal(set) var removalPrompt: RemovalPrompt?
    public internal(set) var reciprocalOffer: ReciprocalOffer?

    let app: AppModel
    private let clock: any Clock
    /// Abre el reloj al empezar el entreno, para que lo mida. `nil` sin reloj (la demo).
    private let watchLauncher: (any WatchWorkoutLauncher)?

    public init(app: AppModel, clock: any Clock, watchLauncher: (any WatchWorkoutLauncher)? = nil) {
        self.app = app
        self.clock = clock
        self.watchLauncher = watchLauncher
    }

    var data: TrainingData { app.current }
    var today: LocalDate { clock.today() }
    var todaySession: Session? { data.history.session(on: today) }
    var activeSession: Session? { data.activeWorkout(on: today) }

    /// Lo tecleado en un campo del entreno que aún no se ha aplicado (`TypedValue`).
    public var typed: TypedValue? { editing.typed }

    /// Con un entreno en curso, siempre el entreno.
    public var stage: Stage { activeSession != nil ? .active : storedStage }

    /// El selector, «Rutinas»; lo demás, el nombre de la rutina (y en qué punto está, `subtitle`).
    public var title: String {
        switch stage {
        case .selector: TodayText.selectorTitle
        case .preview(let routine): data.routines.name(of: routine)
        case .active: activeSession.map { data.routines.name(of: $0.routineID) } ?? ""
        case .completed: todaySession.map { data.routines.name(of: $0.routineID) } ?? ""
        }
    }

    /// Debajo del título: vista previa, en curso o terminado; el selector no lleva.
    public var subtitle: String? {
        switch stage {
        case .selector: nil
        case .preview: TodayText.previewStatus
        case .active: TodayText.inProgress
        case .completed: TodayText.completedSubtitle
        }
    }

    // MARK: - Selector

    public var routineRows: [RoutineRow] {
        data.routines.map { routine in
            let names = routine.exerciseIDs.map { data.catalog.name(of: $0) }
            var note: String?
            if let pending = data.pendingSwaps[routine.id], pending.isActive(inWeekStarting: today.weekStart) {
                note = TodayText.pendingSwapNote(to: data.catalog.name(of: pending.to), from: data.catalog.name(of: pending.from))
            }
            return RoutineRow(id: routine.id, title: routine.name, subtitle: TodayText.routineSummary(names), pendingNote: note,
                              tint: RoutineTint.of(routine.id, in: data.routines.map(\.id)))
        }
    }

    /// Tocar otra vez la pestaña: el selector, salvo con un entreno en curso (`renderHoy`). Cambiar
    /// de pestaña no lo hace: en iOS cada pestaña conserva su pantalla.
    public func reselect() {
        storedStage = .selector
        openPreviewCards = []
        if activeSession == nil { openExercise = nil }
    }

    public func select(_ routine: RoutineID) {
        storedStage = .preview(routine)
        openPreviewCards = []
    }

    public func backToSelector() {
        storedStage = .selector
        openPreviewCards = []
        openExercise = nil
    }

    // MARK: - Vista previa

    /// La vista previa de una rutina sin ejercicios, que dice qué hacer. Mira la etapa, no solo las
    /// tarjetas: al empezar el entreno no hay tarjetas de vista previa, y la que se va lo enseñaba.
    public var isPreviewEmpty: Bool {
        guard case .preview(let routine) = stage else { return false }
        return data.routines.routine(routine)?.exerciseIDs.isEmpty ?? true
    }

    /// Cada ejercicio con los valores con los que arrancaría (`getBestRecentValuesForExercise`).
    public var previewCards: [ExerciseCard] {
        guard case .preview(let routine) = stage else { return [] }
        let exerciseIDs = data.routines.routine(routine)?.exerciseIDs ?? []
        return exerciseIDs.enumerated().map { index, id in
            let seed = data.history.bestRecentSeed(for: id, today: today)
            let log = ExerciseLog(exerciseID: id, series: seed.series, targetReps: seed.targetReps, actualReps: seed.actualReps, weight: seed.weight)
            return card(for: log, index: index, isOpen: openPreviewCards.contains(index), editable: false, anchor: today)
        }
    }

    public func togglePreviewCard(_ index: Int) {
        openPreviewCards.toggle(index)
    }

    /// «Iniciar entreno»: si hoy ya hay uno terminado, antes pregunta.
    public func requestStart() async {
        guard case .preview(let routine) = storedStage else { return }
        if let done = todaySession, done.completed {
            replacePrompt = ReplacePrompt(title: TodayText.replaceTitle(data.routines.name(of: done.routineID)),
                                          message: TodayText.replaceMessage(data.routines.name(of: routine)))
            return
        }
        await start()
    }

    /// «Sustituir». No lee `replacePrompt`: SwiftUI cierra el diálogo (`cancelReplace`) antes de
    /// ejecutar la acción del botón. Recibe el aviso como los demás `confirm…`, aunque no lo use.
    public func confirmReplace(_ prompt: ReplacePrompt) async {
        replacePrompt = nil
        await start()
    }

    public func cancelReplace() {
        replacePrompt = nil
    }

    /// Empieza sin preguntar: el entreno de hoy, si lo hay, se sustituye. Abre el reloj para que
    /// mida el entreno.
    public func start() async {
        guard case .preview(let routine) = storedStage else { return }
        var data = data
        data.startWorkout(routine: routine, on: today)
        openExercise = nil
        editing.reset()
        await app.update(data)
        await watchLauncher?.launch()
    }

    // MARK: - Ayudas

    func card(for log: ExerciseLog, index: Int, isOpen: Bool, editable: Bool, anchor: LocalDate) -> ExerciseCard {
        ExerciseCard(
            log: log, data: data, isOpen: isOpen, isEditable: editable, anchor: anchor,
            focusedSeries: editable ? editing.focusedSeries(at: index) : nil,
            errors: editable ? editing.validationErrors[index] ?? [] : [], showsRecords: editable
        )
    }
}
