import Domain
import GymCoreTesting
import Testing
import ViewModels

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

// La pantalla del reloj (#16): una página por ejercicio del entreno en curso.

@MainActor
@Suite("Pantalla del reloj")
struct WatchModelTests {
    private let today = LocalDate(year: 2026, month: 10, day: 25)!

    private func exercise(
        _ name: String, weight: Double = 62.5, reps: [Int] = [12, 12, 11, 10], skipped: Bool = false,
        previous: [WatchSnapshot.Previous] = []
    ) -> WatchSnapshot.Exercise {
        WatchSnapshot.Exercise(name: name, weight: weight, reps: reps, skipped: skipped, previous: previous)
    }

    private func workout(_ exercises: [WatchSnapshot.Exercise], routine: String = "Full Body - Día 1", date: LocalDate? = nil) -> WatchSnapshot {
        WatchSnapshot(workout: WatchSnapshot.Workout(date: date ?? today, routineName: routine, exercises: exercises))
    }

    private var threeExercises: WatchSnapshot {
        workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo")])
    }

    @Test("hasta recibir algo del iPhone, lo dice")
    func waiting() {
        #expect(WatchModel(clock: FixedClock(today)).content == .message("Abre Gym en el iPhone"))
    }

    @Test("sin entreno en curso, lo dice")
    func noWorkout() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(WatchSnapshot(workout: nil))
        #expect(model.content == .message("Sin entreno en curso"))
    }

    @Test("una página por ejercicio, con nombre, posición, peso y reps de hoy")
    func pages() throws {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(workout([exercise("Press Banca"), exercise("Dominadas", weight: 0, reps: [8, 8, 6])]))
        guard case .workout(let pages) = model.content else { Issue.record("sin entreno"); return }
        #expect(pages.map(\.name) == ["Press Banca", "Dominadas"])
        #expect(pages.map(\.position) == ["1/2", "2/2"])
        #expect(pages.map(\.weight) == ["62,5 kg", "Peso corporal"])
        #expect(pages.map(\.reps) == ["12·12·11·10", "8·8·6"])
    }

    @Test("las sesiones anteriores, una fila por sesión con la fecha y las reps")
    func previousRows() throws {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(workout([exercise("Press Banca", previous: [
            WatchSnapshot.Previous(date: LocalDate(iso: "2026-10-21")!, reps: [12, 12, 11, 10]),
            WatchSnapshot.Previous(date: LocalDate(iso: "2026-10-17")!, reps: [12, 11, nil, 10]),
        ])]))
        guard case .workout(let pages) = model.content else { Issue.record("sin entreno"); return }
        #expect(pages[0].previous == [
            WatchModel.PreviousRow(date: "21 oct", reps: "12·12·11·10"),
            WatchModel.PreviousRow(date: "17 oct", reps: "12·11·—·10"),
        ])
        #expect(pages[0].noPrevious == nil)
    }

    @Test("un ejercicio nunca hecho dice que es la primera vez")
    func firstTime() throws {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(workout([exercise("Press Banca")]))
        guard case .workout(let pages) = model.content else { Issue.record("sin entreno"); return }
        #expect(pages[0].previous.isEmpty)
        #expect(pages[0].noPrevious == "Primera vez")
    }

    @Test("un ejercicio saltado hoy se marca")
    func skipped() throws {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(workout([exercise("Press Banca", skipped: true), exercise("Remo")]))
        guard case .workout(let pages) = model.content else { Issue.record("sin entreno"); return }
        #expect(pages.map(\.isSkipped) == [true, false])
    }

    @Test("empieza en el primer ejercicio")
    func startsAtFirst() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(threeExercises)
        #expect(model.page == 0)
    }

    @Test("un cambio del mismo entreno no mueve de ejercicio")
    func keepsPage() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(threeExercises)
        model.page = 2
        model.receive(workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo", weight: 70)]))
        #expect(model.page == 2)
    }

    @Test("si el entreno se queda con menos ejercicios, va al último")
    func clampsPage() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(threeExercises)
        model.page = 2
        model.receive(workout([exercise("Press Banca"), exercise("Sentadilla")]))
        #expect(model.page == 1)
    }

    @Test("un entreno nuevo empieza otra vez en el primer ejercicio")
    func newWorkout() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(threeExercises)
        model.page = 2
        model.receive(workout([exercise("Press Banca"), exercise("Sentadilla"), exercise("Remo")], routine: "Full Body - Día 2"))
        #expect(model.page == 0)
    }

    @Test("un entreno de otro día (lo último que llegó, quizá de ayer) no se enseña")
    func staleWorkout() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(workout([exercise("Press Banca")], date: today.adding(days: -1)))
        #expect(model.content == .message("Sin entreno en curso"))
    }

    @Test("después de un rato sin entreno, el siguiente empieza en el primer ejercicio")
    func afterNoWorkout() {
        let model = WatchModel(clock: FixedClock(today))
        model.receive(threeExercises)
        model.page = 2
        model.receive(WatchSnapshot(workout: nil))
        model.receive(threeExercises)
        #expect(model.page == 0)
    }
}
