/// El `db.json` de la PWA tal cual (ver su CLAUDE.md). Solo se usa para importar y, en #7, para
/// sincronizar: el modelo de la app es otro.
struct PWADatabase: Codable {
    var exercises: [String: PWAExercise]?
    var routines: [String: [String]]?
    var pendingSwaps: [String: PWAPendingSwap]?
    var history: [PWASession]?
}

struct PWAExercise: Codable {
    var id: String?
    var name: String?
    var grupo: String?
    var secundarios: [String]?
}

struct PWAPendingSwap: Codable {
    var fromExerciseId: String
    var toExerciseId: String
    var weekStart: String
}

struct PWASession: Codable {
    var date: String
    var type: String
    var completed: Bool?
    var logs: [PWALog]
}

struct PWALog: Codable {
    var exercise_id: String
    var name: String?
    var series: Int
    var reps: PWAReps
    var weight: Double
    var skipped: Bool?
    var swappedFrom: String?
    var oneOff: Bool?
}

struct PWAReps: Codable {
    var expected: Int
    var actual: [Int?]?
}
