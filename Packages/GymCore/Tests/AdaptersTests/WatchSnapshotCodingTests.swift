import Adapters
import Domain
import Foundation
import Testing

@Suite("Lo que viaja al reloj")
struct WatchSnapshotCodingTests {
    private let workout = WatchSnapshot(workout: WatchSnapshot.Workout(
        date: LocalDate(year: 2026, month: 10, day: 25)!,
        routineName: "Full Body - Día 1",
        exercises: [
            WatchSnapshot.Exercise(
                name: "Press Banca", weight: 62.5, series: 4, targetReps: 11, skipped: false,
                best: WatchSnapshot.Reference(date: LocalDate(year: 2026, month: 10, day: 21)!, weight: 62.5, reps: [12, nil, 11, 10]),
                last: WatchSnapshot.Reference(date: LocalDate(year: 2026, month: 10, day: 23)!, weight: 60, reps: [10, 10, 10, 10])
            ),
            WatchSnapshot.Exercise(name: "Dominadas", weight: 0, series: 3, targetReps: 8, skipped: true, best: nil, last: nil),
        ]
    ))

    @Test("el entreno en curso llega igual que sale")
    func roundTrip() throws {
        #expect(try WatchSnapshotCoding.decode(WatchSnapshotCoding.encode(workout)) == workout)
    }

    @Test("sin entreno en curso, también")
    func roundTripWithoutWorkout() throws {
        let none = WatchSnapshot(workout: nil)
        #expect(try WatchSnapshotCoding.decode(WatchSnapshotCoding.encode(none)) == none)
    }

    @Test("lleva versión y las fechas como YYYY-MM-DD")
    func format() throws {
        let json = try #require(String(data: WatchSnapshotCoding.encode(workout), encoding: .utf8))
        #expect(json.contains(#""version":2"#))
        #expect(json.contains(#""date":"2026-10-21""#))
    }

    @Test("una versión que no conoce no se lee (tampoco la 1, de antes de la app de entreno)")
    func unsupportedVersion() {
        #expect(throws: WatchSnapshotCoding.FormatError.unsupportedVersion(1)) {
            try WatchSnapshotCoding.decode(Data(#"{"version":1}"#.utf8))
        }
        #expect(throws: WatchSnapshotCoding.FormatError.unsupportedVersion(3)) {
            try WatchSnapshotCoding.decode(Data(#"{"version":3}"#.utf8))
        }
    }

    @Test("una fecha que no es válida no se lee")
    func invalidDate() {
        let json = #"{"version":2,"workout":{"date":"2026-13-01","routineName":"X","exercises":[]}}"#
        #expect(throws: WatchSnapshotCoding.FormatError.invalidDate("2026-13-01")) {
            try WatchSnapshotCoding.decode(Data(json.utf8))
        }
    }
}
