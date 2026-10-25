import Domain
import Testing

// Portados de tests/unit/catalog.test.js de la PWA (los de computeGroupSets, en StatsTests) y
// de getExerciseName (data.test.js).

@Suite("resolveSecundarios")
struct ResolveSecondaryGroupsTests {
    @Test("un ejercicio sin el campo hereda los del mapa hardcodeado")
    func inherits() {
        #expect(SecondaryGroups.resolve(exercise("jalon_al_pecho", "Jalón", .espalda), id: "jalon_al_pecho") == [.biceps])
    }

    @Test("una lista vacía guardada gana al mapa — es una decisión del usuario")
    func emptyWins() {
        #expect(SecondaryGroups.resolve(exercise("jalon_al_pecho", "Jalón", .espalda, secondary: []), id: "jalon_al_pecho") == [])
    }

    @Test("lo editado a mano manda")
    func edited() {
        #expect(SecondaryGroups.resolve(exercise("jalon_al_pecho", "Jalón", .espalda, secondary: [.hombros]), id: "jalon_al_pecho") == [.hombros])
    }

    @Test("un ejercicio fuera del mapa y sin campo no aporta a nada")
    func unknown() {
        #expect(SecondaryGroups.resolve(exercise("sentadilla", ""), id: "sentadilla") == [])
        #expect(SecondaryGroups.resolve(nil, id: "sentadilla") == [])
    }
}

@Suite("buildCatalogGroups")
struct CatalogGroupsTests {
    private let catalog = Catalog([
        exercise("press", "Press banca", .pecho, secondary: [.triceps]),
        exercise("aperturas", "Aperturas", .pecho, secondary: []),
        exercise("remo", "Remo", .espalda, secondary: []),
        exercise("huerfano", "Ejercicio raro", secondary: []),
    ])

    @Test("agrupa por grupo primario y ordena por nombre")
    func groupsAndSorts() {
        let pecho = catalog.groups().first { $0.group == .pecho }
        #expect(pecho?.exercises.map(\.id) == ["aperturas", "press"])
    }

    @Test("los grupos siguen el orden canónico y sin grupo va al final")
    func canonicalOrder() {
        #expect(catalog.groups().map(\.group) == [.pecho, .espalda, nil])
    }

    @Test("incluye ejercicios nunca entrenados — no mira el historial")
    func includesAll() {
        #expect(catalog.groups().reduce(0) { $0 + $1.exercises.count } == 4)
    }

    @Test("filtra por texto ignorando tildes y mayúsculas")
    func filters() {
        let withAccent = Catalog([exercise("jalon", "Jalón al pecho", .espalda, secondary: [])])
        #expect(withAccent.groups(matching: "JALON").first?.exercises.map(\.id) == ["jalon"])
    }

    @Test("una búsqueda sin resultados devuelve cero grupos")
    func noResults() {
        #expect(catalog.groups(matching: "zzz") == [])
    }

    @Test("el catálogo muestra los secundarios heredados del mapa aunque no estén en la DB")
    func inheritedSecondaries() {
        let withoutField = Catalog([exercise("jalon_al_pecho", "Jalón", .espalda)])
        #expect(withoutField.groups().first?.exercises.first?.secondaryGroups == [.biceps])
    }

    @Test("cada fila lleva su grupo y secundarios")
    func rows() {
        let pecho = catalog.groups().first { $0.group == .pecho }
        #expect(pecho?.exercises.first { $0.id == "press" } == exercise("press", "Press banca", .pecho, secondary: [.triceps]))
    }

    @Test("un grupo desconocido se lista como sin grupo, pero conserva su valor")
    func unknownGroup() {
        // El filtro de la PWA (`GRUPOS.includes(ex.grupo) ? ex.grupo : SIN_GRUPO`), explícito.
        let groups = Catalog([exercise("curl", "Curl", "brazos")]).groups()
        #expect(groups.map(\.group) == [nil])
        #expect(groups.first?.exercises.first?.group == "brazos")
    }
}

@Suite("updateExercise")
struct UpdateExerciseTests {
    private func fresh() -> Catalog { Catalog([exercise("press", "Press banca", .pecho, secondary: [])]) }

    @Test("renombra y asigna grupo y secundarios")
    func updates() throws {
        var catalog = fresh()
        try catalog.update("press", name: "Press banca plano", group: .pecho, secondaryGroups: [.triceps, .hombros])
        #expect(catalog["press"] == exercise("press", "Press banca plano", .pecho, secondary: [.triceps, .hombros]))
    }

    @Test("el id nunca cambia al renombrar — el historial no se rompe")
    func keepsID() throws {
        var catalog = fresh()
        try catalog.update("press", name: "Otro nombre", group: .pecho, secondaryGroups: [])
        #expect(catalog.ids == ["press"])
        #expect(catalog["press"]?.id == "press")
    }

    @Test("rechaza nombre vacío")
    func emptyName() {
        var catalog = fresh()
        #expect(throws: CatalogError.emptyName) { try catalog.update("press", name: "   ", group: .pecho, secondaryGroups: []) }
        #expect(catalog["press"]?.name == "Press banca")
    }

    @Test("recorta espacios del nombre")
    func trims() throws {
        var catalog = fresh()
        try catalog.update("press", name: "  Press inclinado  ", group: .pecho, secondaryGroups: [])
        #expect(catalog["press"]?.name == "Press inclinado")
    }

    @Test("sin grupo se guarda como ausencia de grupo")
    func noGroup() throws {
        var catalog = fresh()
        try catalog.update("press", name: "Press banca", group: nil, secondaryGroups: [])
        #expect(catalog["press"]?.group == nil)
    }

    @Test("descarta secundarios inválidos y el que repite al primario")
    func cleansSecondaries() throws {
        var catalog = fresh()
        try catalog.update("press", name: "Press banca", group: .pecho, secondaryGroups: [.pecho, .triceps, "inventado", .triceps])
        #expect(catalog["press"]?.secondaryGroups == [.triceps])
    }

    @Test("rechaza grupo inválido")
    func invalidGroup() {
        var catalog = fresh()
        #expect(throws: CatalogError.invalidGroup) { try catalog.update("press", name: "Press banca", group: "inventado", secondaryGroups: []) }
        #expect(catalog["press"]?.group == .pecho)
    }

    @Test("rechaza un id que no existe")
    func unknownID() {
        var catalog = fresh()
        #expect(throws: CatalogError.notFound) { try catalog.update("noexiste", name: "X", group: .pecho, secondaryGroups: []) }
    }

    @Test("no toca el historial, las rutinas ni los demás ejercicios")
    func touchesNothingElse() throws {
        // El catálogo no contiene historial ni rutinas: lo que queda por comprobar es que los
        // demás ejercicios no cambian y que el editado solo cambia esos campos.
        var catalog = Catalog([
            exercise("press", "Press banca", .pecho, secondary: []),
            exercise("remo", "Remo", .espalda, secondary: [.biceps]),
        ])
        let remo = catalog["remo"]
        try catalog.update("press", name: "Press banca plano", group: .hombros, secondaryGroups: [.triceps])
        #expect(catalog["remo"] == remo)
        #expect(catalog["press"] == exercise("press", "Press banca plano", .hombros, secondary: [.triceps]))
    }

    @Test("GRUPOS cubre los siete grupos musculares en uso")
    func sevenGroups() {
        #expect(MuscleGroup.all.map(\.rawValue).sorted() == ["biceps", "core", "espalda", "hombros", "pecho", "piernas", "triceps"])
    }
}

@Suite("getExerciseName")
struct ExerciseNameTests {
    private let catalog = Catalog([exercise("press_banca", "Press Banca"), exercise("curl_biceps", "Curl Bíceps")])

    @Test("con ID existente devuelve nombre")
    func existing() { #expect(catalog.name(of: "press_banca") == "Press Banca") }

    @Test("con ID inexistente devuelve el propio ID")
    func missing() { #expect(catalog.name(of: "no_existe") == "no_existe") }
}
