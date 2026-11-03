import Domain
import Presentation

extension WatchModel {
    public enum Screen: Hashable, Sendable {
        /// Sin entreno que enseñar: el porqué.
        case message(String)
        /// Sin entreno en curso: las rutinas para empezarlo aquí.
        case routines([RoutineRow])
        /// Hay entreno en el iPhone y el reloj aún no lo mide.
        case ready(Ready)
        /// Midiendo: las tres páginas (`Tab`).
        case workout
        case summary(Summary)
    }

    /// Las páginas mientras se mide, de izquierda a derecha.
    public enum Tab: Hashable, Sendable {
        case controls, workout, music
    }

    /// Una rutina de la lista, con su color (el de la tarjeta del iPhone).
    public struct RoutineRow: Hashable, Sendable, Identifiable {
        public let id: RoutineID
        public let name: String
        public let tint: RoutineTint?

        public init(id: RoutineID, name: String, tint: RoutineTint?) {
            self.id = id
            self.name = name
            self.tint = tint
        }
    }

    /// Sustituir el entreno de hoy, ya terminado, por el que se empieza.
    public struct ReplacePrompt: Hashable, Sendable {
        public let title: String
        public let message: String

        public init(title: String, message: String) {
            self.title = title
            self.message = message
        }
    }

    public struct Ready: Hashable, Sendable {
        public let routine: String
        /// "7 ejercicios", o los ejercicios de la rutina elegida en el reloj
        /// ("Press Banca · Sentadilla").
        public let detail: String
        /// Por qué no se ha podido empezar la última vez.
        public let error: String?
        /// Pidiendo permiso o arrancando la sesión: el botón no se puede volver a pulsar.
        public let isStarting: Bool
        /// El color de la rutina elegida en el reloj; sin él, el del texto.
        public let tint: RoutineTint?

        public init(routine: String, detail: String, error: String?, isStarting: Bool, tint: RoutineTint? = nil) {
            self.routine = routine
            self.detail = detail
            self.error = error
            self.isStarting = isStarting
            self.tint = tint
        }
    }

    public struct Exercise: Hashable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        /// "2/6".
        public let position: String
        /// El peso de hoy: "62,5 kg" o "Peso corporal".
        public let weight: String
        /// Junto al peso: "11·11·10·8", las reps de la mejor sesión reciente del peso de hoy, o
        /// "11·11·11·11", las objetivo, si no hay ninguna (`WatchText.planReps`).
        public let planReps: String
        /// "10·10·9": las de la última, si es otra sesión y del peso de hoy.
        public let lastReps: String?
        /// Saltado hoy: se pinta atenuado.
        public let isSkipped: Bool
        /// "Saltado", encima del peso: no basta con que se vea más apagado.
        public let status: String?
        /// "Primera vez", si nunca se ha hecho.
        public let firstTime: String?
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
