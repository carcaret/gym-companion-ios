import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// La app del reloj mide el entreno (#17): empezar en el iPhone abre el reloj, y terminar en el
// reloj termina también en el iPhone (2026-10-31). Empezar en el reloj empieza en el iPhone
// (2026-11-03).

@MainActor
@Suite("Empezar abre el reloj")
struct TodayWatchTests {
    @Test("empezar el entreno abre la app del reloj")
    func launches() async {
        let launcher = RecordingWatchWorkoutLauncher()
        let today = await TodayHarness.make(watchLauncher: launcher)
        await today.start()
        #expect(launcher.launches == 1)
        #expect(today.model.stage == .active)
    }

    @Test("sin empezar (solo viendo la rutina), no lo abre")
    func previewDoesNotLaunch() async {
        let launcher = RecordingWatchWorkoutLauncher()
        let today = await TodayHarness.make(watchLauncher: launcher)
        today.model.select("DIA1")
        #expect(launcher.launches == 0)
    }
}

@MainActor
@Suite("Terminar en el reloj termina en el iPhone")
struct TodayFinishedOnWatchTests {
    @Test("termina sin preguntar, sube pidiendo tiempo al sistema y vuelve a las rutinas")
    func finishes() async {
        let today = await TodayHarness.make(configured: true)
        await today.start()
        await today.model.finishFromWatch(on: today.today)
        #expect(!today.model.isFinishPromptPresented)
        #expect(today.model.stage == .selector)
        #expect(await today.savedToday?.completed == true)
        #expect(await today.harness.remote.data?.history.session(on: today.today)?.completed == true)
        #expect(await today.harness.background.runs == 1)
        #expect(today.app.notice == nil)
    }

    @Test("con el globo de «Finalizar» abierto, lo cierra")
    func closesPrompt() async {
        let today = await TodayHarness.started()
        await today.model.requestFinish()
        await today.model.finishFromWatch(on: today.today)
        #expect(!today.model.isFinishPromptPresented)
        #expect(await today.savedToday?.completed == true)
    }

    @Test("aplica antes lo que se estaba tecleando")
    func commitsTyping() async {
        let today = await TodayHarness.started()
        today.model.type(.weight, text: "88", at: 0)
        await today.model.finishFromWatch(on: today.today)
        #expect(await today.savedToday?.logs[0].weight == 88)
        #expect(await today.savedToday?.completed == true)
    }

    @Test("si falta algo, se queda abierto, lo marca y avisa hasta que se cierre el aviso")
    func invalid() async {
        let today = await TodayHarness.started()
        var data = today.app.data!
        var session = data.history.session(on: today.today)!
        session.logs[1].actualReps[0] = nil
        data.history.replace(session)
        await today.app.update(data)

        await today.model.finishFromWatch(on: today.today)
        #expect(today.model.stage == .active)
        #expect(await today.savedToday?.completed == false)
        #expect(today.model.activeCards[1].errors == [.missingRep(index: 0)])
        #expect(today.model.activeCards.map(\.isOpen) == [false, true, false])
        #expect(today.app.notice == ValidationText.finishedOnWatchButInvalid)
        #expect(ValidationText.finishedOnWatchButInvalid.staysUntilDismissed)
    }

    @Test("sin entreno en curso ese día, no hace nada")
    func nothingActive() async {
        let today = await TodayHarness.make()
        let before = today.app.data
        await today.model.finishFromWatch(on: today.today)
        #expect(today.app.data == before)
        #expect(today.app.notice == nil)
    }

    @Test("ya terminado en el iPhone, no hace nada (llega dos veces)")
    func alreadyFinished() async {
        let today = await TodayHarness.started()
        await today.finish()
        let saves = await today.harness.local.saves
        await today.model.finishFromWatch(on: today.today)
        #expect(await today.harness.local.saves == saves)
    }

    @Test("llegado pasada la medianoche, termina el entreno de su día")
    func previousDay() async {
        let yesterday = SyncFixtures.day("2026-10-24")
        var data = PWATestDB.data
        data.startWorkout(routine: "DIA1", on: yesterday)
        let today = await TodayHarness.make(data)
        await today.model.finishFromWatch(on: yesterday)
        #expect(await today.saved?.history.session(on: yesterday)?.completed == true)
        #expect(today.model.stage == .selector)
    }
}

@MainActor
@Suite("Empezar en el reloj empieza en el iPhone")
struct TodayStartedOnWatchTests {
    @Test("empieza el entreno de esa rutina, como «Iniciar entreno», sin volver a abrir el reloj")
    func starts() async {
        let launcher = RecordingWatchWorkoutLauncher()
        let today = await TodayHarness.make(watchLauncher: launcher)
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "DIA2", day: today.today))
        #expect(today.model.stage == .active)
        #expect(await today.savedToday?.routineID == "DIA2")
        #expect(await today.savedToday?.completed == false)
        #expect(launcher.launches == 0)
    }

    @Test("con la vista previa de otra rutina abierta, pasa al entreno empezado")
    func fromPreview() async {
        let today = await TodayHarness.make()
        today.model.select("DIA1")
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "DIA2", day: today.today))
        #expect(today.model.stage == .active)
        #expect(await today.savedToday?.routineID == "DIA2")
    }

    @Test("con el entreno de hoy terminado, lo sustituye sin preguntar: ya se preguntó en el reloj")
    func replaces() async {
        let today = await TodayHarness.started(routine: "DIA1")
        await today.finish()
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "DIA2", day: today.today))
        #expect(today.model.replacePrompt == nil)
        #expect(await today.savedToday?.routineID == "DIA2")
        #expect(await today.savedToday?.completed == false)
    }

    @Test("con un entreno ya en curso, no hace nada: manda el del iPhone")
    func alreadyActive() async {
        let today = await TodayHarness.started(routine: "DIA1")
        let before = today.app.data
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "DIA2", day: today.today))
        #expect(today.app.data == before)
    }

    @Test("lo de otro día (llegado tarde) no hace nada")
    func otherDay() async {
        let today = await TodayHarness.make()
        let before = today.app.data
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "DIA1", day: today.today.adding(days: -1)))
        #expect(today.app.data == before)
    }

    @Test("una rutina que ya no existe no hace nada")
    func unknownRoutine() async {
        let today = await TodayHarness.make()
        let before = today.app.data
        await today.model.startFromWatch(PhoneWorkoutStart(routine: "BORRADA", day: today.today))
        #expect(today.app.data == before)
    }
}
