import Domain
import Presentation

extension WatchModel {
    public enum Screen: Hashable, Sendable {
        /// Sin entreno que enseñar: el porqué.
        case message(String)
        /// Hay entreno en el iPhone y el reloj aún no lo mide.
        case ready(Ready)
        /// Midiendo: las tres páginas (`Tab`).
        case workout
        case summary(Summary)
    }

    /// Las páginas mientras se mide, de izquierda a derecha.
    public enum Tab: Hashable, Sendable {
        case music, workout, controls
    }

    public struct Ready: Hashable, Sendable {
        public let routine: String
        /// "7 ejercicios".
        public let detail: String
        /// Por qué no se ha podido empezar la última vez.
        public let error: String?
        /// Pidiendo permiso o arrancando la sesión: el botón no se puede volver a pulsar.
        public let isStarting: Bool

        public init(routine: String, detail: String, error: String?, isStarting: Bool) {
            self.routine = routine
            self.detail = detail
            self.error = error
            self.isStarting = isStarting
        }
    }

    public struct Exercise: Hashable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        /// "2/6".
        public let position: String
        /// "62,5 kg · 4 × 11".
        public let plan: String
        /// Saltado hoy: se pinta atenuado.
        public let isSkipped: Bool
        /// "Saltado", encima del plan: no basta con que se vea más apagado.
        public let status: String?
        public let best: Reference?
        public let last: Reference?
        /// "Primera vez", si nunca se ha hecho.
        public let firstTime: String?
    }

    /// Una sesión de referencia: "Mejor 11·11·10·8 · 26 oct" o "Última 12 kg · 10·10·10 · 21 oct".
    public struct Reference: Hashable, Sendable {
        public let label: String
        public let detail: String
        public let date: String

        public init(label: String, detail: String, date: String) {
            self.label = label
            self.detail = detail
            self.date = date
        }
    }

    public enum RestPhase: Hashable, Sendable {
        case idle, resting, overdue
    }

    /// El tiempo del entreno y el descanso, en este momento.
    public struct Time: Hashable, Sendable {
        public let elapsed: String
        public let rest: String
        public let restLabel: String
        public let restPhase: RestPhase
        /// Cuánto se lleva del descanso hasta cumplirlo, de 0 a 1.
        public let restProgress: Double
    }

    public struct Metrics: Hashable, Sendable {
        public let heartRate: String
        public let activeEnergy: String
        public let totalEnergy: String

        public init(heartRate: String, activeEnergy: String, totalEnergy: String) {
            self.heartRate = heartRate
            self.activeEnergy = activeEnergy
            self.totalEnergy = totalEnergy
        }

        init(_ metrics: WorkoutMetrics) {
            self.init(heartRate: WatchText.heartRate(metrics.heartRate), activeEnergy: WatchText.energy(metrics.activeEnergy),
                      totalEnergy: WatchText.energy(metrics.totalEnergy))
        }
    }

    public struct Summary: Hashable, Sendable {
        public let duration: String
        public let activeEnergy: String
        public let totalEnergy: String
        public let averageHeartRate: String

        public init(duration: String, activeEnergy: String, totalEnergy: String, averageHeartRate: String) {
            self.duration = duration
            self.activeEnergy = activeEnergy
            self.totalEnergy = totalEnergy
            self.averageHeartRate = averageHeartRate
        }

        init(_ summary: WorkoutSummary) {
            self.init(duration: WatchText.duration(summary.duration), activeEnergy: WatchText.energy(summary.activeEnergy),
                      totalEnergy: WatchText.energy(summary.totalEnergy), averageHeartRate: WatchText.averageHeartRate(summary.averageHeartRate))
        }
    }
}
