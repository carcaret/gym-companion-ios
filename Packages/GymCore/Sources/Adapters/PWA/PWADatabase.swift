/// El `db.json` de la PWA tal cual (ver su CLAUDE.md), para leerlo al importar y al sincronizar: el
/// modelo de la app es otro. Para escribirlo, `PWAFormat.json(from:)`.
struct PWADatabase: Decodable {
    var exercises: [String: PWAExercise]?
    var routines: [String: [String]]?
    var pendingSwaps: [String: PWAPendingSwap]?
    var history: [PWASession]?
}

struct PWAExercise: Decodable {
    var id: String?
    var name: String?
    var grupo: String?
    var secundarios: [String]?
}

struct PWAPendingSwap: Decodable {
    var fromExerciseId: String
    var toExerciseId: String
    var weekStart: String
}

struct PWASession: Decodable {
    var date: String
    var type: String
    var completed: Bool?
    var logs: [PWALog]
}

struct PWALog: Decodable {
    var exercise_id: String
    var name: String?
    var series: Int
    var reps: PWAReps
    var weight: Double
    var skipped: Bool?
    var swappedFrom: String?
    var oneOff: Bool?
}

struct PWAReps: Decodable {
    var expected: Int
    var actual: [Int?]?
}
