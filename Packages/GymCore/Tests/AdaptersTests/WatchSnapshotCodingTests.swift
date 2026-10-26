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
            WatchSnapshot.Exercise(name: "Press Banca", weight: 62.5, reps: [12, 12, 11, 10], skipped: false, previous: [
                WatchSnapshot.Previous(date: LocalDate(year: 2026, month: 10, day: 21)!, reps: [12, nil, 11, 10]),
            ]),
            WatchSnapshot.Exercise(name: "Dominadas", weight: 0, reps: [8, 8, 6], skipped: true, previous: []),
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
        #expect(json.contains(#""version":1"#))
        #expect(json.contains(#""date":"2026-10-21""#))
    }

    @Test("una versión que no conoce no se lee")
    func unsupportedVersion() {
        #expect(throws: WatchSnapshotCoding.FormatError.unsupportedVersion(2)) {
            try WatchSnapshotCoding.decode(Data(#"{"version":2}"#.utf8))
        }
    }

    @Test("una fecha que no es válida no se lee")
    func invalidDate() {
        let json = #"{"version":1,"workout":{"date":"2026-13-01","routineName":"X","exercises":[]}}"#
        #expect(throws: WatchSnapshotCoding.FormatError.invalidDate("2026-13-01")) {
            try WatchSnapshotCoding.decode(Data(json.utf8))
        }
    }
}
