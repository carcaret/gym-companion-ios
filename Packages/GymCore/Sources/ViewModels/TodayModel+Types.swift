import Domain
import Presentation

extension TodayModel {
    public enum Stage: Hashable, Sendable {
        case selector
        case preview(RoutineID)
        case active
        case completed
    }

    /// Empezar con el entreno de hoy ya terminado: el `db.json` guarda uno por día, así que el
    /// nuevo lo sustituye. Se confirma antes.
    public struct ReplacePrompt: Hashable, Sendable {
        public let title: String
        public let message: String
    }

    public struct RoutineRow: Hashable, Sendable {
        public let id: RoutineID
        public let title: String
        public let subtitle: String
        /// "Próxima vez: B en vez de A", si hay un cambio recíproco pendiente esta semana.
        public let pendingNote: String?
        public let tint: RoutineTint?
    }

    /// Una línea del entreno terminado (el formato del historial).
    public struct SummaryRow: Hashable, Sendable {
        public let title: String
        public let subtitle: String
        /// Saltado: se pinta con el fondo de saltado y sin botones.
        public let isSkipped: Bool
    }

    public enum PickerPurpose: Hashable, Sendable {
        case add
        case swap(index: Int)
    }

    /// El selector de ejercicios (añadir o cambiar).
    public struct Picker: Hashable, Sendable {
        public let purpose: PickerPurpose
        public let title: String
        /// Al cambiar, el ejercicio que se sustituye.
        public let subtitle: String?
        /// Ya ordenadas y filtradas por la búsqueda, sin secciones vacías.
        public let sections: [PickerSection]
        /// Todos los de las secciones, en orden.
        public var exercises: [Exercise] { sections.flatMap { $0.rows.map(\.exercise) } }
        /// El chip "Solo esta sesión" (solo al añadir con entreno en curso).
        public let offersOneOff: Bool
        public let isOneOff: Bool
        /// "Crear nuevo ejercicio" (al añadir, y no si es puntual: lo nuevo entra en la rutina).
        public let canCreate: Bool
        /// "Crear «Press Arnold»": lo buscado, si no existe, se crea de un toque, sin alerta (con el
        /// teclado abierto, la alerta se perdía al cerrarse la búsqueda; 2026-10-27).
        public let searchCreateLabel: String?
        /// "Crear nuevo ejercicio", con su alerta: solo sin nada buscado.
        public let offersNewExercise: Bool
    }

    /// Una sección del selector; sin título cuando es la única.
    public struct PickerSection: Hashable, Sendable {
        public let title: String?
        public let rows: [PickerRow]
    }

    public struct PickerRow: Hashable, Sendable, Identifiable {
        public let exercise: Exercise
        /// Segunda línea: grupo (si no lo dice la sección) y rutinas donde está.
        public let detail: String?

        public var id: ExerciseID { exercise.id }
    }

    public struct RemovalPrompt: Hashable, Sendable {
        public let exerciseID: ExerciseID
        public let title: String
        public let message: String
    }

    public struct ReciprocalOffer: Hashable, Sendable {
        public let routine: RoutineID
        public let swap: PendingSwap
        public let title: String
        public let message: String
        public let acceptLabel: String
    }
}
