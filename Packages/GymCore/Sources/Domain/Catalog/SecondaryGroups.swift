/// Músculos que un ejercicio trabaja de forma indirecta.
public enum SecondaryGroups {
    /// Los de por defecto, escritos a mano: los datos solo guardan un grupo por ejercicio, así
    /// que esta es la única forma de saber que un jalón trabaja bíceps. Solo cubre lo que se
    /// entrena de hecho: lo que no esté aquí no aporta trabajo indirecto. (`SECUNDARIOS`.)
    public static let defaults: [ExerciseID: [MuscleGroup]] = [
        // Tirones: bíceps
        "jalon_al_pecho": [.biceps],
        "jalon_al_pecho_neutro": [.biceps],
        "hammer_row_prono": [.biceps],
        "doninadas": [.biceps],
        "remo_con_barra": [.biceps],
        "remo_en_maquina": [.biceps],
        // Empujes: tríceps
        "press_banca_mancuernas": [.triceps],
        "press_inclinado_mancuernas": [.triceps],
        "press_inclinado_maquina": [.triceps],
        "press_maquina": [.triceps],
        "press_de_hombros_mancuernas_sentado": [.triceps],
        "press_de_hombros_maquina": [.triceps],
        "press_banca_barra": [.triceps],
        "landmine_press": [.triceps],
    ]

    /// Los del ejercicio si alguna vez se editaron (una lista vacía también es una decisión), y
    /// si no los de por defecto. `exercise` es `nil` si el id no está en el catálogo.
    public static func resolve(_ exercise: Exercise?, id: ExerciseID) -> [MuscleGroup] {
        exercise?.secondaryGroups ?? defaults[id] ?? []
    }

    /// Cuánto cuenta una serie para un músculo secundario: media serie, la convención de
    /// "fractional sets" de la literatura. (`FRACCION_INDIRECTA`.)
    public static let indirectFraction = 0.5
}
