# Paridad con la PWA

Cada test de la PWA (`tests/unit` y `tests/e2e`) con su test nativo o el motivo por el que no aplica
(#15). La tabla sale de `python3 scripts/pwa_tests.py ~/git/gym-companion --markdown`; el CI
(`pwa-tests`) falla si algún test queda sin portar ni justificar, así que solo hay que regenerarla
si cambian los tests.

La app tiene además sus propios tests (contratos de los puertos, sincronización, adaptadores,
ViewModels): 944 `@Test` en el paquete y las capturas en `UITests/`, frente a los 829 de la PWA.

La épica (#1) y #15 hablan de 851 (508 unitarios y 343 e2e), pero la PWA tiene 829: los 508
unitarios y 321 e2e en 37 ficheros (contados en el commit `76243dc` de la PWA; ningún e2e se genera
en bucle, así que Playwright lista los mismos 321).

| Test de la PWA | Test nativo | Notas |
|---|---|---|
| `dates.test.js` › todayStr › devuelve formato YYYY-MM-DD | `SystemClockTests.swift` |  |
| `dates.test.js` › formatDate › formatea correctamente en español | `DateTextTests.swift` |  |
| `dates.test.js` › formatDateShort › fecha con día y mes de un dígito → sin ceros | `DateTextTests.swift` |  |
| `dates.test.js` › formatDateShort › fecha con día y mes de dos dígitos | `DateTextTests.swift` |  |
| `dates.test.js` › formatDateShort › primer día del año | `DateTextTests.swift` |  |
| `dates.test.js` › formatDateShort › mes con cero inicial se elimina | `DateTextTests.swift` |  |
| `dates.test.js` › addDaysStr › suma días positivos | `LocalDateTests.swift` |  |
| `dates.test.js` › addDaysStr › resta días (negativos) | `LocalDateTests.swift` |  |
| `dates.test.js` › addDaysStr › cruza cambio de mes | `LocalDateTests.swift` |  |
| `dates.test.js` › addDaysStr › cruza cambio de año | `LocalDateTests.swift` |  |
| `dates.test.js` › addDaysStr › cero días devuelve la misma fecha | `LocalDateTests.swift` |  |
| `dates.test.js` › addDaysStr › año bisiesto: 29-feb existe en 2024 | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › lunes devuelve el mismo lunes | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › miércoles devuelve el lunes anterior | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › domingo devuelve el lunes anterior | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › sábado devuelve el lunes de esa semana | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › cruza cambio de mes hacia atrás | `LocalDateTests.swift` |  |
| `dates.test.js` › getWeekStartStr › cruza cambio de año hacia atrás | `LocalDateTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › todos iguales a expected -> null | `LogTextTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › algunos diferentes -> "10-8-10" | `LogTextTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › con nulls -> "-" donde toque | `LogTextTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › array vacio -> null | `LogTextTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › null -> null | `LogTextTests.swift` |  |
| `formatting.test.js` › formatRepsInteligente › menos reps completadas que series -> muestra lo que hay | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › con peso → incluye "X kg · " | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › sin peso (0) → omite "kg" | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › con actual que difiere de expected → añade "· X-X-X" | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › con actual == expected en todas → omite reps reales | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › con reps actual null (no iniciadas) → solo muestra "series×expected" | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › array actual vacío → solo muestra "series×expected" | `LogTextTests.swift` |  |
| `formatting.test.js` › formatLogSummary › sin peso y con reps distintas → solo base + reps | `LogTextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › convierte tildes | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › convierte eñes | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › convierte espacios a guion bajo | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › elimina caracteres raros | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › convierte múltiples espacios | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › string vacío → string vacío | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › solo caracteres especiales → string vacío | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › números → se mantienen | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › nombre ya en formato slug → sin cambio | `TextTests.swift` |  |
| `formatting.test.js` › slugifyExerciseName › mayúsculas mezcladas → todo lowercase | `TextTests.swift` |  |
| `metrics.test.js` › computeAvgReps › con reps reales usa el promedio de actual | `MetricsTests.swift` |  |
| `metrics.test.js` › computeAvgReps › sin reps reales usa expected | `MetricsTests.swift` |  |
| `metrics.test.js` › computeAvgReps › con una sola rep | `MetricsTests.swift` |  |
| `metrics.test.js` › computeVolume › con peso > 0: peso * series * avgReps | `MetricsTests.swift` |  |
| `metrics.test.js` › computeVolume › con peso = 0 (bodyweight): series * avgReps | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › peso > 0, series uniformes: max coincide con valor de cualquier serie | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › series con reps distintas: devuelve la de mayor reps (no el promedio) | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › ejemplo de la spec: 90kg × 12 reps → 126 kg | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › peso = 0 (bodyweight) → retorna 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › peso negativo → retorna 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › series=1, una rep | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › reps = 0 en todas las series → excluidas → e1RM = 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › reps > 30 en todas las series → excluidas → e1RM = 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › mix de reps válidas e inválidas: solo considera las válidas | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › reps null en series incompletas → se ignoran | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › actual vacío → usa expected como rep única | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › expected > 30 sin actual → excluido → e1RM = 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › reps = 30 (límite superior válido): se incluye | `MetricsTests.swift` |  |
| `metrics.test.js` › computeE1RM › reps = 1 (límite inferior válido): se incluye | `MetricsTests.swift` |  |
| `metrics.test.js` › computeAvgReps (edge cases) › actual con nulls mezclados → suma incluye 0 por los nulls | `MetricsTests.swift` |  |
| `metrics.test.js` › computeAvgReps (edge cases) › actual todo nulls → reduce da 0/N = 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeAvgReps (edge cases) › actual vacío [] → cae al else, retorna expected | `MetricsTests.swift` |  |
| `metrics.test.js` › computeVolume (edge cases) › series=0 → volumen 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeVolume (edge cases) › reps all null (avgReps=0) → volumen 0 | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › mejora real → devuelve porcentaje positivo | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › bajada real → devuelve porcentaje negativo | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › sin cambio → devuelve null | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › prevMetric = 0 → devuelve null (evita división por cero) | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › prevMetric negativo → devuelve null | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › cambio menor de 0.5% que redondea a 0 → devuelve null | `MetricsTests.swift` |  |
| `metrics.test.js` › computeSessionDeltaPct › redondeo correcto: 10.5% → 11 | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › devuelve máximos de volumen y e1RM para un ejercicio | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › ignora ejercicios que no coinciden | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › historial vacío → maxVolume=0, maxE1RM=0 | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › ejercicio no encontrado → maxVolume=0, maxE1RM=0 | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › ignora los logs saltados al calcular máximos | `MetricsTests.swift` |  |
| `metrics.test.js` › getMaxMetrics › max e1RM es el de la mejor serie de la mejor sesión | `MetricsTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › crea entry con fecha, tipo y completed=false | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › carga peso/series/reps del último entreno equivalente | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › si no hay historial previo, usa defaults (3 series, 10 reps, 0 kg) | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › pre-rellena reps.actual con valores previos (no nulls) hasta el nº de series | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › si series actual < series previas, trunca reps.actual | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › si series actual > series previas, rellena con repsExpected | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › con rutina vacía (0 ejercicios), crea entry con logs=[] | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › ejercicio sin historial previo usa defaults | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › prevActual con nulls intercalados: copia no-null, null se rellena con expected | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › sin historial previo, reps.actual se pre-rellena con repsExpected (no nulls) | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › entry recién creado sin historial pasa validación (bug fix: no debe dar campos vacíos) | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › entry con historial parcial (más series que antes) también pasa validación | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › flujo completo build→validate→finish sin historial funciona sin error | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › flujo completo build→validate→finish con historial funciona sin error | `WorkoutTests.swift` |  |
| `workout.test.js` › buildWorkoutEntry › múltiples ejercicios sin historial todos pasan validación | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › devuelve log con shape correcto a partir de last | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › sin historial (repsActual vacío) prerellena actual con repsExpected | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › prevActual más corto que series rellena la cola con repsExpected | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › prevActual más largo que series trunca | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › prevActual con nulls intercalados los reemplaza por repsExpected | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › repsActual undefined se trata como [] | `WorkoutTests.swift` |  |
| `workout.test.js` › buildLog › log producido pasa validación | `WorkoutTests.swift` |  |
| `workout.test.js` › finishWorkoutEntry › marca completed=true | `WorkoutTests.swift` |  |
| `workout.test.js` › finishWorkoutEntry › no modifica reps que ya tenían valor | `WorkoutTests.swift` |  |
| `workout.test.js` › finishWorkoutEntry › con todas las reps ya completadas, no cambia nada | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — weight › incrementa peso en +delta | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — weight › decrementa peso en -delta | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — weight › peso no baja de 0 (clamp) | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — weight › redondea a 1 decimal (evita floating point) | `WorkoutTests.swift` |  |
| `workout.test.js` › weightStep › peso < 20 → escalon de 1kg | `WorkoutTests.swift` |  |
| `workout.test.js` › weightStep › 20 <= peso < 50 → escalon de 2kg | `WorkoutTests.swift` |  |
| `workout.test.js` › weightStep › peso >= 50 → escalon de 5kg | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — series › incrementa series en +1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — series › decrementa series en -1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — series › series no baja de 1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — series › al incrementar, añade reps.expected a reps.actual | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — series › al decrementar, elimina último de reps.actual | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › incrementa reps esperadas en +1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › decrementa reps esperadas en -1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › reps esperadas no bajan de 1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › sincroniza todas las reps actuales al nuevo expected (actuales con valores) | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › sincroniza todas las reps actuales al bajar expected | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › sincroniza reps actuales que eran null | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › sincroniza reps actuales mixtas (con valores y nulls) | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › al llegar al clamp (1), reps actuales también se ponen a 1 | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › cambiar weight NO toca reps.actual | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — repsExpected › cambiar series NO sincroniza reps.actual al expected (añade reps.expected) | `WorkoutTests.swift` |  |
| `workout.test.js` › setParam › setParam weight con valor válido | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam weight con 0 → acepta (bodyweight) | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam weight con negativo → clamp a 0 | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam weight con NaN → 0 | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam series con valor válido | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam series ajusta array de reps.actual (truncate) | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam series con 0 → clamp a 1 | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected con valor válido | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected con 0 → clamp a 1 | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected sincroniza todas las reps actuales al nuevo valor | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected sincroniza al bajar | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected sincroniza reps null | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam repsExpected con clamp a 1 sincroniza actuales a 1 | `InputTests.swift` |  |
| `workout.test.js` › setParam › setParam weight NO toca reps.actual | `InputTests.swift` |  |
| `workout.test.js` › adjustRep › incrementa rep de una serie específica | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustRep › decrementa rep de una serie específica | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustRep › si rep era null, usa expected como base y aplica delta | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustRep › rep no baja de 0 | `WorkoutTests.swift` |  |
| `workout.test.js` › setRep › establece rep a valor dado | `InputTests.swift` |  |
| `workout.test.js` › setRep › valor vacío → null (rep no completada) | `InputTests.swift` |  |
| `workout.test.js` › setRep › valor NaN → null | `InputTests.swift` |  |
| `workout.test.js` › setRep › valor 0 → acepta (0 reps completadas) | `WorkoutTests.swift` |  |
| `workout.test.js` › setRep › valor negativo → clamp a 0 | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: subir una real por encima del objetivo sube el objetivo | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: bajar el máximo baja el objetivo | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: editar real sin tocar el máximo deja el objetivo igual | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: ignora nulls al calcular el máximo | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: si todas las reales quedan null, objetivo no cambia | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › setRep: máximo 0 → objetivo clamp a 1 | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › adjustRep: subir real por encima del objetivo sube el objetivo | `WorkoutTests.swift` |  |
| `workout.test.js` › objetivo sigue al máximo de reps reales › adjustRep: bajar el máximo baja el objetivo | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › detecta nuevo PR de volumen cuando supera máximo histórico | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › detecta nuevo PR de e1RM cuando supera máximo histórico | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › NO detecta PR si ninguna rep está completada (todas null) | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › NO detecta PR si volumen/e1RM es 0 | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › NO detecta PR si es igual al máximo (solo si supera estrictamente) | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › sin historial previo y volumen > 0 → sí es PR (primer registro) | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › ejercicio con peso 0 (bodyweight): puede tener PR de volumen pero no de e1RM | `WorkoutTests.swift` |  |
| `workout.test.js` › detectRecords › excluye correctamente otros ejercicios del historial | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › log válido completo → sin errores | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › weight negativo → error en field weight | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › weight 0 → sin error (bodyweight) | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › series 0 → error en field series | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › series decimal → error en field series | — | Las series son `Int`: un número decimal no compila. |
| `workout.test.js` › validateLog › repsExpected 0 → error en field repsExpected | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › rep null en serie 0 → error con field rep, index 0 | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › rep negativo → error con field rep | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › todas las reps completadas → sin errores en reps | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › mezcla de reps válidas y null → errores solo en las null | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › rep undefined → error no completada | `WorkoutTests.swift` |  |
| `workout.test.js` › validateLog › rep 0 → válido (0 reps completadas) | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry › entry con todos los logs válidos → valid: true | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry › entry con un log inválido → valid: false, errorsByLog tiene ese logIdx | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry › entry con múltiples logs inválidos → todos aparecen en errorsByLog | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry › entry sin logs → valid: true | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — casos borde › delta 0 en weight no cambia nada | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — casos borde › delta 0 en series no cambia nada | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — casos borde › param inválido no hace nada | — | El parámetro es el enum `LogParameter`: uno inexistente no compila. |
| `workout.test.js` › adjustParam — casos borde › decrementar y volver a incrementar series → nuevo slot usa reps.expected actual | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustParam — casos borde › sincronizar repsExpected con 1 sola serie | `WorkoutTests.swift` |  |
| `workout.test.js` › setParam — casos borde › series con decimal redondea | `InputTests.swift` |  |
| `workout.test.js` › setParam — casos borde › param inválido no hace nada | — | El parámetro es el enum `LogParameter`: uno inexistente no compila. |
| `workout.test.js` › adjustRep — casos borde › delta 0 con rep null → parte del expected | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustRep — casos borde › reps.actual array vacío → parte del expected | `WorkoutTests.swift` |  |
| `workout.test.js` › adjustRep — casos borde › reps.actual con menos elementos que series → parte del expected | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 1 — swap normal A→B: exercise_id=B, swappedFrom=A | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 2 — doble swap A→B→C: swappedFrom queda en A (no en B) | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 3 — swap de vuelta al original A→B→A: sin swappedFrom | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 4 — ejercicio ya presente en otro log → duplicate, entry intacto | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 5 — mismo exercise_id → same, entry intacto | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 6 — entry completed → not_active, entry intacto | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 7 — logIdx fuera de rango → not_found | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 8 — nuevo log usa series/repsExpected/weight de last | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 9 — preserva logs vecinos (incluso con swappedFrom propio) | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 10 — nombre del log actualizado al nuevo ejercicio | — | El log ya no copia el nombre: se busca en el catálogo por `exerciseID` (cubierto por getExerciseName). |
| `workout.test.js` › swapLogExercise › 11 — swap de un log puntual: el nuevo log sigue siendo puntual | `WorkoutTests.swift` |  |
| `workout.test.js` › swapLogExercise › 12 — swap de un log normal no inventa oneOff | `WorkoutTests.swift` |  |
| `workout.test.js` › toggleSkip › alterna skipped y devuelve el nuevo estado | `WorkoutTests.swift` |  |
| `workout.test.js` › toggleSkip › no destruye los datos del log al alternar | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry con saltados › no valida un log saltado aunque tenga reps vacías | `WorkoutTests.swift` |  |
| `workout.test.js` › validateEntry con saltados › sí valida los logs no saltados del mismo entry | `WorkoutTests.swift` |  |
| `workout.test.js` › findReciprocalSwapTarget › 1 — match único en otro día → devuelve ese dayType | `WorkoutTests.swift` |  |
| `workout.test.js` › findReciprocalSwapTarget › 2 — ningún otro día lo tiene → null | `WorkoutTests.swift` |  |
| `workout.test.js` › findReciprocalSwapTarget › 3 — aparece en 2+ días distintos (ambiguo) → null | `WorkoutTests.swift` |  |
| `workout.test.js` › findReciprocalSwapTarget › 4 — el ejercicio está solo en el propio currentDayType → null (no cuenta el propio día) | `WorkoutTests.swift` |  |
| `workout.test.js` › buildPendingSwap › 1 — caso normal → construye el objeto pendiente | `WorkoutTests.swift` |  |
| `workout.test.js` › buildPendingSwap › 2 — toExerciseId ya presente en la rutina destino → null (evita duplicado) | `WorkoutTests.swift` |  |
| `workout.test.js` › consumePendingSwap › 1 — sin pendiente → routineIds intacto, clearNow false | `WorkoutTests.swift` |  |
| `workout.test.js` › consumePendingSwap › 2 — semana coincide y ejercicio presente → sustituye y NO limpia | `WorkoutTests.swift` |  |
| `workout.test.js` › consumePendingSwap › 3 — semana caducada → no sustituye, clearNow true | `WorkoutTests.swift` |  |
| `workout.test.js` › consumePendingSwap › 4 — ejercicio ya no está en la rutina destino → no sustituye, clearNow true | `WorkoutTests.swift` |  |
| `workout.test.js` › consumePendingSwap › 5 — reaplicar dos veces seguidas sin borrar el pendiente da la misma sustitución (reinicio mismo día) | `WorkoutTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › entry de hoy con completed=false → true | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › entry de hoy con completed=true → false | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › sin entry de hoy → false | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › historial vacío → false | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › db null → false | — | El historial es una lista no opcional; vacía, cubierto por «historial vacío → false». |
| `workout-sync.test.js` › isWorkoutActive › db sin history → false | — | Ídem: no hay `db` sin historial. |
| `workout-sync.test.js` › isWorkoutActive › db con history null → false | — | Ídem: el historial no puede ser nulo. |
| `workout-sync.test.js` › isWorkoutActive › entry de otro día completed=false no afecta → false | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › múltiples entries, solo la de hoy importa | `HistoryTests.swift` |  |
| `workout-sync.test.js` › isWorkoutActive › entry de hoy sin campo completed (undefined) → false | — | `completed` es `Bool`, nunca ausente. Qué hacer con una sesión de `db.json` sin `completed` lo decide la importación (#6). |
| `data.test.js` › getExerciseName › con ID existente devuelve nombre | `CatalogTests.swift` |  |
| `data.test.js` › getExerciseName › con ID inexistente devuelve el propio ID | `CatalogTests.swift` |  |
| `data.test.js` › getTodayEntry › encuentra entry de hoy | `HistoryTests.swift` |  |
| `data.test.js` › getTodayEntry › retorna undefined si no hay entry para hoy | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › mayor peso gana aunque su volumen sea menor | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › a igualdad de peso, gana mayor volumen (reps reales) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › mezcla mismo peso/series/reps → gana 12-12-12 frente a 12-12-10 frente a 12-10-10 | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › busca el ejercicio en cualquier dayType (caso real apertura) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › ventana = últimas 6 semanas (las anteriores no compiten aunque tengan más peso) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › ejercicio dormido (sin sesiones en ventana) → fallback devuelve la MÁS RECIENTE del historial | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › no usa una sesión saltada como semilla (dentro de ventana) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › fallback ignora saltados cuando no hay sesiones en ventana | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › sin historial → defaults | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › ejercicio inexistente en historial → defaults | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › excluye la entry cuya date === today | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › ignora entries con completed=false dentro de la ventana (coherente con la gráfica) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › fallback considera entries con completed=false (única referencia disponible) | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › empate total (peso, series, reps) → gana la más reciente | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › peso 0 (bodyweight) compite por volumen | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › reps.actual con nulls → devuelve el array tal cual | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › log sin reps.actual → devuelve array vacío | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › history desordenado → coge las 6 más recientes por fecha, no por posición | `HistoryTests.swift` |  |
| `data.test.js` › getBestRecentValuesForExercise › today opcional → sin argumento, no excluye ninguna entry | `HistoryTests.swift` |  |
| `data.test.js` › ensureHistorySorted › ordena history ascendente por fecha | `HistoryTests.swift` |  |
| `data.test.js` › ensureHistorySorted › array ya ordenado no cambia | `HistoryTests.swift` |  |
| `data.test.js` › ensureHistorySorted › array vacío no lanza error | `HistoryTests.swift` |  |
| `data.test.js` › ensureHistorySorted › array de un elemento no cambia | `HistoryTests.swift` |  |
| `data.test.js` › ensureHistorySorted › db null no lanza error | — | No hay `db` nulo; con la lista vacía, «array vacío no lanza error». |
| `data.test.js` › ensureHistorySorted › db sin history no lanza error | — | Ídem. |
| `data.test.js` › getWeeklyBucketsForExercise › devuelve 4 buckets por defecto, ordenados de más antiguo a actual | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › respeta el parámetro weeks | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › asigna sesión a su bucket semanal correcto | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › sesiones fuera de la ventana se ignoran | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › semanas sin sesión quedan null (hueco visual) | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › entries no completadas se ignoran | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › excludeDate omite esa fecha aunque caiga en ventana | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › varias sesiones en la misma semana: gana la de mayor volumen | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › empate de volumen en la misma semana: gana la más reciente | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › ejercicio sin historial: todos null | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › db null devuelve buckets vacíos bien formados | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › no muta db.history | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › ancla en lunes funciona igual (W0 empieza ese día) | `HistoryTests.swift` |  |
| `data.test.js` › getWeeklyBucketsForExercise › sesión el domingo cuenta en su semana (no se desliza a la siguiente) | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › happy path: devuelve sesiones recientes dentro de la ventana, ordenadas cronológicamente | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › sesiones fuera de la ventana de 6 semanas se excluyen | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › sesiones posteriores al anchor se excluyen | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › maxSessions limita a las N más recientes | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › si hay menos sesiones que maxSessions, devuelve todas | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › excludeDate excluye esa fecha | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › entries no completadas se ignoran | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › ejercicio no presente en las entries devuelve [] | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › db null devuelve [] | — | No hay `db` nulo; cubierto por «history vacía devuelve []». |
| `data.test.js` › getRecentSessionsForExercise › history vacía devuelve [] | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › historia desordenada → resultado ordenado cronológicamente | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › no muta db.history | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › sesión justo en el primer día de la ventana se incluye | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › sesión un día antes del inicio de ventana se excluye | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › dos sesiones en la misma semana: ambas aparecen como barras separadas | `HistoryTests.swift` |  |
| `data.test.js` › getRecentSessionsForExercise › log correcto asociado a cada sesión | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden de tiers › tier 0 primero: mismo grupo (pecho) + en rutina de otro día (DIA2) | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden de tiers › tier 1 segundo: mismo grupo (pecho) + sin rutina | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden de tiers › tier 2 tercero: distinto grupo + en rutina de otro día | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden de tiers › tier 3 último: distinto grupo + sin rutina | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden de tiers › orden completo correcto: [apertura, press_inclinado, sentadilla, plancha] | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden alfabético dentro de cada tier › tier 0 con varios ejercicios del mismo grupo: orden alfabético entre ellos | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — orden alfabético dentro de cada tier › tier 3 con varios ejercicios sin rutina: orden alfabético entre ellos | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — casos de ejercicio origen sin grupo › si currentExerciseId no tiene grupo, no se asigna tier 0 ni 1 (solo tier 2/3) | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — casos de ejercicio origen sin grupo › si ejercicio disponible no tiene grupo, no sube a tier 0/1 aunque coincida con undefined | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — cambio de dayType activo › swap desde DIA2: ejercicios de DIA1 van al tier correcto (no al 0 si DIA2 es el activo) | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — inmutabilidad del array de entrada › no muta el array original de ejercicios disponibles | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — edge cases › array vacío devuelve array vacío sin errores | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — edge cases › un único ejercicio se devuelve tal cual | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — edge cases › currentExerciseId no existe en allExercises: no lanza error y degrada a tier 2/3 | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — edge cases › routines con DIA vacío: ejercicios sin rutina siguen en tier 1 o 3 según grupo | `HistoryTests.swift` |  |
| `data.test.js` › sortExercisesForSwap — edge cases › ejercicio en varias rutinas (incluida otra): va a tier 0 si además comparte grupo | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 1 — hay una entrada completada de ese dayType dentro de la semana → true | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 2 — la entrada de ese dayType es de otra semana → false | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 3 — hay entrada esta semana pero no completada → false | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 4 — dayType sin ninguna entrada en el historial → false | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 5 — historial vacío/ausente → false | `HistoryTests.swift` |  |
| `data.test.js` › hasDayOccurredThisWeek › 6 — fecha en el último día de la semana (domingo) cuenta como dentro de la semana | `HistoryTests.swift` |  |
| `history.test.js` › sortHistory › ordena por fecha descendente (más reciente primero) | `HistoryTests.swift` |  |
| `history.test.js` › sortHistory › entries con misma fecha mantienen orden relativo | `HistoryTests.swift` |  |
| `history.test.js` › sortHistory › history vacío devuelve array vacío | `HistoryTests.swift` |  |
| `history.test.js` › sortHistory › no muta el array original | `HistoryTests.swift` |  |
| `history.test.js` › findLog › con fecha existente y logIdx válido devuelve el log | `HistoryTests.swift` |  |
| `history.test.js` › findLog › con fecha inexistente devuelve null | `HistoryTests.swift` |  |
| `history.test.js` › findLog › con logIdx fuera de rango devuelve null | `HistoryTests.swift` |  |
| `history.test.js` › findLog › con history vacío devuelve null | `HistoryTests.swift` |  |
| `stats.test.js` › computeTotalReps › suma las reps ejecutadas | `StatsTests.swift` |  |
| `stats.test.js` › computeTotalReps › ignora las series sin rellenar | `StatsTests.swift` |  |
| `stats.test.js` › computeTotalReps › sin reps ejecutadas devuelve 0 | `StatsTests.swift` |  |
| `stats.test.js` › getExerciseSessions › devuelve solo las sesiones del ejercicio, en orden ascendente | `StatsTests.swift` |  |
| `stats.test.js` › getExerciseSessions › excluye las sesiones saltadas | `StatsTests.swift` |  |
| `stats.test.js` › getExerciseSessions › respeta el rango de fechas | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › estancado: mismo peso y sin superar el mejor total | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › progresa por peso aunque las reps bajen | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › progresa por reps al mismo peso | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › no usa reps.expected: fallar el objetivo mientras suben las reps es progreso | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › sin recorrido con menos de 3 sesiones | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › recentReps trae las 3 últimas sesiones, la más antigua primero | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › la racha arranca en la última sesión que batió el récord, no antes | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › empatar el récord seis veces cuenta las seis sesiones | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › la racha solo cuenta sesiones al peso actual | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › subir de peso es progreso, aunque a la carga nueva aún no se mejore | `StatsTests.swift` |  |
| `stats.test.js` › analyzeExercise › el span de una subida de peso se mide desde la última sesión con la carga vieja | `StatsTests.swift` |  |
| `stats.test.js` › formatSpan › menos de dos semanas, en días | `ProgressTextTests.swift` |  |
| `stats.test.js` › formatSpan › menos de dos meses, en semanas | `ProgressTextTests.swift` |  |
| `stats.test.js` › formatSpan › a partir de dos meses, en meses | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExercisePhrase › sin recorrido dice cuántas sesiones lleva | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExercisePhrase › progreso por peso | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExercisePhrase › progreso por reps al mismo peso | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExercisePhrase › estancado sin fallar reps | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExercisePhrase › estancado con fallos usa el tiempo | `ProgressTextTests.swift` |  |
| `stats.test.js` › buildExerciseRows › ordena estancados primero y sin-recorrido al final | `StatsTests.swift` |  |
| `stats.test.js` › buildExerciseRows › cada fila trae su frase | `ProgressTextTests.swift` |  |
| `stats.test.js` › computeGroupSets › agrupa series por grupo y las divide entre las semanas | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › ordena de más a menos series | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › ignora las sesiones saltadas | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › los ejercicios sin grupo caen en (sin grupo) | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › los tirones suman media serie a bíceps sin tocar su grupo directo | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › un grupo que solo recibe trabajo indirecto también aparece | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › rangoDeVentana escala la franja semanal a la ventana | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › cada ejercicio trae sus series y sus sesiones | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › desglosa los ejercicios de cada grupo, de más a menos | `StatsTests.swift` |  |
| `stats.test.js` › computeGroupSets › deja fuera lo anterior a la ventana; el límite es inclusivo | `StatsTests.swift` |  |
| `catalog.test.js` › resolveSecundarios › un ejercicio sin el campo hereda los del mapa hardcodeado | `CatalogTests.swift` |  |
| `catalog.test.js` › resolveSecundarios › una lista vacía guardada gana al mapa — es una decisión del usuario | `CatalogTests.swift` |  |
| `catalog.test.js` › resolveSecundarios › lo editado a mano manda | `CatalogTests.swift` |  |
| `catalog.test.js` › resolveSecundarios › un ejercicio fuera del mapa y sin campo no aporta a nada | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › agrupa por grupo primario y ordena por nombre | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › los grupos siguen el orden canónico y sin grupo va al final | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › incluye ejercicios nunca entrenados — no mira el historial | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › filtra por texto ignorando tildes y mayúsculas | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › una búsqueda sin resultados devuelve cero grupos | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › el catálogo muestra los secundarios heredados del mapa aunque no estén en la DB | `CatalogTests.swift` |  |
| `catalog.test.js` › buildCatalogGroups › cada fila lleva su grupo y secundarios | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › renombra y asigna grupo y secundarios | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › el id nunca cambia al renombrar — el historial no se rompe | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › rechaza nombre vacío | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › recorta espacios del nombre | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › sin grupo se guarda como ausencia de grupo | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › descarta secundarios inválidos y el que repite al primario | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › rechaza grupo inválido | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › rechaza un id que no existe | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › no toca el historial, las rutinas ni los demás ejercicios | `CatalogTests.swift` |  |
| `catalog.test.js` › updateExercise › GRUPOS cubre los siete grupos musculares en uso | `CatalogTests.swift` |  |
| `catalog.test.js` › los secundarios editados alimentan Progreso › computeGroupSets usa los secundarios de la DB por encima del mapa | `StatsTests.swift` |  |
| `catalog.test.js` › los secundarios editados alimentan Progreso › secundarios vacíos en la DB anulan el mapa hardcodeado | `StatsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › devuelve ejercicios únicos dentro del rango de fechas | `ChartsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › excluye entries fuera del rango | `ChartsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › rango vacío (from > to) → array vacío | `ChartsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › ordena por nombre en español (locale es) | `ChartsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › history vacío devuelve array vacío | `ChartsTests.swift` |  |
| `charts.test.js` › getExercisesInRange › no duplica ejercicios que aparecen en múltiples entries | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › devuelve e1rmDatasets y weightDatasets (sin datasets de volumen) | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › e1RM usa la mejor serie (max, no promedio) | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › e1RM con series uniformes coincide con la fórmula directa | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › ejercicio bodyweight (weight=0) no genera e1rmDataset | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › genera weightDatasets excluyendo puntos donde weight=0 | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › ejercicio sin datos en rango → e1rmDatasets y weightDatasets vacíos | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › múltiples entries ordenadas por fecha en e1rmDatasets | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › e1RM dataset usa eje Y primario (yAxisID: y) | — | Formato de Chart.js; en la app lo decide la vista con Swift Charts (#11). |
| `charts.test.js` › buildChartDatasets › e1RM dataset no tiene borderDash (es la métrica principal) | — | Formato de Chart.js (#11). |
| `charts.test.js` › buildChartDatasets › chartType line → fill=true en e1RM y peso | — | Línea o barras es una opción de la vista, no de los datos (#11). |
| `charts.test.js` › buildChartDatasets › chartType bar → fill=false y type=bar en e1RM y peso | — | Línea o barras es una opción de la vista, no de los datos (#11). |
| `charts.test.js` › buildChartDatasets › múltiples ejercicios generan datasets separados con colores distintos | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › e1RM redondeado a 1 decimal | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › reps > 30 excluidas del e1RM (no genera punto) | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › forward-fill: punto saltado copia el valor previo y se marca _skipped | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › forward-fill: punto saltado al inicio del rango se omite (sin valor previo) | `ChartsTests.swift` |  |
| `charts.test.js` › buildChartDatasets › forward-fill: e1RM y peso se mantienen de forma independiente | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › separa en inRoutine y others según routineExerciseIds | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › inRoutine y others están ordenados alfabéticamente en español | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › todos en rutina → others vacío | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › ninguno en rutina → inRoutine vacío | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › ejercicios vacíos → ambos grupos vacíos | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › acepta routineExerciseIds como Set | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › IDs en rutina pero sin datos en rango no aparecen en inRoutine | `ChartsTests.swift` |  |
| `charts.test.js` › sortExercisesForDropdown › ejercicio en rutina duplicado en routineExerciseIds solo aparece una vez | `ChartsTests.swift` |  |
| `routine-rename.test.js` › DAY_LABELS usa etiquetas Full Body › DIA1 → Full Body - Día 1 | `RoutineTests.swift` |  |
| `routine-rename.test.js` › DAY_LABELS usa etiquetas Full Body › DIA2 → Full Body - Día 2 | `RoutineTests.swift` |  |
| `routine-rename.test.js` › DAY_LABELS usa etiquetas Full Body › DIA3 → Full Body - Día 3 | `RoutineTests.swift` |  |
| `routine-rename.test.js` › DAY_LABELS usa etiquetas Full Body › no hay etiquetas con nombres de días de la semana | `RoutineTests.swift` |  |
| `routine-rename.test.js` › DAY_LABELS usa etiquetas Full Body › no existen claves LUNES, MIERCOLES ni VIERNES | `RoutineTests.swift` |  |
| `routine-rename.test.js` › ROUTINE_KEYS › contiene exactamente DIA1, DIA2, DIA3 | `RoutineTests.swift` |  |
| `routine-rename.test.js` › ROUTINE_KEYS › tiene 3 elementos | `RoutineTests.swift` |  |
| `routine-rename.test.js` › consistencia ROUTINE_KEYS / DAY_LABELS › ROUTINE_KEYS coincide con claves de DAY_LABELS | — | Ids y nombres van juntos en cada `Routine`: no pueden desincronizarse. |
| `routine-reorder.test.js` › reorderByIndex › mueve elemento hacia adelante (0 → 2 en array de 3) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › mueve elemento hacia atrás (2 → 0 en array de 3) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › mover a la misma posición devuelve array equivalente | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › no muta el array original (inmutabilidad) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › el array original sigue siendo el mismo objeto después de llamar (no mutation) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › array de un elemento devuelve array equivalente | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › fromIndex === toIndex no cambia el array | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › funciona con array de objetos (logs) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › fromIndex en límite inferior (0) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › fromIndex en límite superior (length-1) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › toIndex en límite inferior (0) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › toIndex en límite superior (length-1) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › array vacío devuelve array vacío (edge case) | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › array de dos elementos, swap | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › array de dos elementos, swap inverso | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › mueve elemento del medio al principio | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › mueve elemento del medio al final | `ReorderTests.swift` |  |
| `routine-reorder.test.js` › reorderByIndex › devuelve un array nuevo (no el mismo objeto) | `ReorderTests.swift` |  |
| `constants.test.js` › constants › DAY_LABELS tiene etiquetas Full Body | `RoutineTests.swift` |  |
| `constants.test.js` › constants › ROUTINE_KEYS contiene las 3 rutinas | `RoutineTests.swift` |  |
| `constants.test.js` › constants › las claves de localStorage están definidas | — | No hay localStorage: dónde se guardan los datos y la configuración es del adaptador de persistencia (#6) y de Ajustes (#14). |
| `constants.test.js` › constants › SESSION_KEY y SALT ya no existen (sistema de auth eliminado) | — | La app nunca tuvo ese sistema de acceso. |
| `github.test.js` › buildGitHubPayload › genera JSON con content en base64 | `GitHubContentsTests.swift` |  |
| `github.test.js` › buildGitHubPayload › incluye sha si se proporciona (update) | `GitHubContentsTests.swift` |  |
| `github.test.js` › buildGitHubPayload › sin sha → no incluye campo sha (create) | `GitHubContentsTests.swift` |  |
| `github.test.js` › buildGitHubPayload › incluye message y branch | `GitHubContentsTests.swift` |  |
| `github.test.js` › buildGitHubPayload › DB con caracteres UTF-8 (tildes, eñes) → se codifica correctamente | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › extrae content (base64) y sha del response | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › content con line breaks en base64 → limpia y decodifica | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › response sin content → null | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › response con encoding !== base64 → null | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › response null → null | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › content con UTF-8 (tildes, eñes) → decodifica correctamente | `GitHubContentsTests.swift` |  |
| `github.test.js` › parseGitHubResponse › sin campo encoding pero con content válido → funciona (encoding es opcional) | `GitHubContentsTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › JSON válido → devuelve objeto | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › JSON inválido → devuelve null sin excepción | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › string vacío → devuelve null | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › null → devuelve null | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › undefined → devuelve null | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › HTML como valor → no lanza excepción | `JSONValueTests.swift` |  |
| `json-parse-safety.test.js` › safe JSON.parse pattern › JSON truncado → no lanza excepción | `JSONValueTests.swift` |  |
| `keepalive.test.js` › keepalive fetch option › sin options → no tiene keepalive | `TrainingRepositorySyncTests.swift` |  |
| `keepalive.test.js` › keepalive fetch option › con keepalive: true → fetch incluye keepalive | `TrainingRepositorySyncTests.swift` |  |
| `keepalive.test.js` › keepalive fetch option › con keepalive: false → no incluye keepalive | `TrainingRepositorySyncTests.swift` |  |
| `keepalive.test.js` › keepalive fetch option › con options vacío → no tiene keepalive | `TrainingRepositorySyncTests.swift` |  |
| `e2e/github-sync.spec.js` › GitHub sync (mock) › guardar datos intercepta PUT a api.github.com al finalizar entreno | `TrainingRepositorySyncTests.swift` |  |
| `e2e/github-sync.spec.js` › GitHub sync (mock) › GitHub devuelve 401 → muestra mensaje de error | `TrainingRepositorySyncTests.swift` |  |
| `e2e/github-sync.spec.js` › GitHub sync (mock) › sin conexión (fetch falla) → datos locales se mantienen | `TrainingRepositorySyncTests.swift` |  |
| `e2e/github-sync.spec.js` › GitHub sync (mock) › GitHub devuelve 409 (conflicto en save) → datos locales se conservan | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico A: entreno completado con GitHub caído → persiste en local y se sube al reload | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico C: needsUpload=true + remote diferente → local intacto al arrancar | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico B: botón "Sincronizar desde GitHub" sobreescribe local con remote tras confirmación | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico D: 409 en PUT → indicador pendiente → modal con 3 opciones | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico E: arranque con needsUpload=false → indicador "ok", sin PUT | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico F: arranque needsUpload=false + remote==local → GET ocurre, sin toast, sin PUT, local intacto | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico G: arranque needsUpload=false + remote≠local → local sobreescrito + toast | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico H: arranque needsUpload=true + remote≠local → NO se sobreescribe | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico I: arranque con entreno activo + remote≠local → NO se sobreescribe | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico J: edit local durante el fetch → pull aborta, local sobrevive | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico K: GitHub inaccesible al arrancar → local intacto, sin toast de error | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico L: GitHub 404 al arrancar → local intacto | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico M: needsUpload=true sin sha → GET pobla sha antes del PUT | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-canonicos.spec.js` › Canónicos de resiliencia — opción B estricta › Canónico N: sin sha + GET falla → no hay PUT, queda en pending | `TrainingRepositorySyncTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › sin GitHub → indicador en estado disabled | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › sync ok → indicador muestra estado ok | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › clic en indicador muestra toast con estado | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › PAT guardado en claro es legible directamente | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › Subir a GitHub dispara PUT y muestra toast de éxito | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › Subir a GitHub sin GitHub configurado → toast warn, no PUT | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › Subir a GitHub con conflicto activo → abre modal de conflicto | `SyncModelTests.swift` |  |
| `e2e/sync-ui.spec.js` › Sync — UI y ajustes › probar conexión NO sobrescribe la DB local | `SyncModelTests.swift` |  |
| `e2e/workout-github-sync.spec.js` › GitHub sync durante entreno activo › iniciar entreno NO dispara PUT a GitHub | `TrainingRepositorySyncTests.swift` |  |
| `e2e/workout-github-sync.spec.js` › GitHub sync durante entreno activo › ajustar peso durante entreno NO dispara PUT a GitHub | `TrainingRepositorySyncTests.swift` |  |
| `e2e/workout-github-sync.spec.js` › GitHub sync durante entreno activo › ajustar reps durante entreno NO dispara PUT a GitHub | `TrainingRepositorySyncTests.swift` |  |
| `e2e/workout-github-sync.spec.js` › GitHub sync durante entreno activo › finalizar entreno SÍ dispara PUT a GitHub | `TrainingRepositorySyncTests.swift` |  |
| `e2e/workout-github-sync.spec.js` › GitHub sync durante entreno activo › múltiples ajustes durante entreno → 0 PUTs, finalizar → 1 PUT | `TrainingRepositorySyncTests.swift` |  |
| `e2e/persistence.spec.js` › Persistencia y datos › app arranca → recarga → datos intactos | `TrainingRepositorySyncTests.swift` |  |
| `e2e/persistence.spec.js` › Persistencia y datos › iniciar entreno → ajustar peso → verificar en DB | `TrainingRepositorySyncTests.swift` |  |
| `e2e/persistence.spec.js` › Persistencia y datos › localStorage tiene DB_LOCAL_KEY con datos válidos | `TrainingRepositorySyncTests.swift` |  |
| `e2e/persistence.spec.js` › Persistencia y datos › finalizar entreno → historial muestra entry con datos correctos | `TrainingRepositorySyncTests.swift` |  |
| `e2e/tabbar-keyboard.spec.js` › Tab bar y teclado › enfocar el input de peso retira la tab bar y desenfocar la devuelve | — | La barra es la nativa de iOS (`TabView`): el teclado la tapa sin dejarla flotando sobre los campos. El fallo de `position: fixed` de la PWA standalone no existe. |
| `e2e/tabbar-keyboard.spec.js` › Tab bar y teclado › cerrar la card con el input enfocado devuelve la tab bar | — | Ídem: no hay barra que retirar ni devolver; la gestiona el sistema con el teclado. |
| `e2e/tabbar-keyboard.spec.js` › Tab bar y teclado › los tabs siguen siendo clicables tras enfocar y desenfocar | — | Ídem; que las pestañas se tocan y cambian de pantalla lo comprueba `ScreenshotTests.testPestanas` (XCUITest) y la selección, `NavigationModelTests`. |
| `builders.test.js` › buildHistoryStripHtml con saltados › pinta la sesión saltada como columna fantasma en su sitio | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildHistoryStripHtml con saltados › el delta "% vs última" ignora la sesión saltada y usa la real previa | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeSessionDelta › de peso corporal a lastrado → sube por la carga, aunque haya menos reps | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeSessionDelta › de lastrado a peso corporal → baja por la carga | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeSessionDelta › los dos a peso corporal → % de reps | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeSessionDelta › los dos lastrados → % de e1RM | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeSessionDelta › sin cambio → null | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeStripLevels › sin mezcla → métrica entre el máximo | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeStripLevels › mezcla sin lastre y lastrado → las lastradas siempre por encima | `HistoryStripTests.swift` |  |
| `builders.test.js` › computeStripLevels › mezcla: dentro del grupo lastrado manda la proporción de e1RM | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildHistoryStripHtml con lastre en un ejercicio de peso corporal › primera sesión lastrada → delta en kg hacia arriba y barra actual al máximo | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildChipValues › centra ventana de 5 alrededor del valor | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildChipValues › current=1 → borde inferior clampado a 0, desliza hacia arriba | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildChipValues › current=0 → ventana desde 0 | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildChipValues › current=2 → borde a 0, no negativos | `HistoryStripTests.swift` |  |
| `builders.test.js` › buildChipValues › current alto → ventana centrada sin clamp | `HistoryStripTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › todas las series clavan el objetivo → 0 | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › todas superan el objetivo → 0 (no negativo) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › una serie corta → déficit de esa serie | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › mismo total de reps → mismo shortfall (independiente del orden) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › varias cortas → suma de faltantes | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › mezcla superadas y cortas → solo cuentan las cortas | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › series sin rellenar (null) se ignoran — entreno en curso | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeRepShortfall › actual vacío → 0 | `BarColorTests.swift` |  |
| `bar-colors.test.js` › isGreenBar › objetivo cumplido → nunca verde | `BarColorTests.swift` |  |
| `bar-colors.test.js` › isGreenBar › objetivo no cumplido, sin peso de referencia → verde | `BarColorTests.swift` |  |
| `bar-colors.test.js` › isGreenBar › objetivo no cumplido, mismo peso que la referencia → verde | `BarColorTests.swift` |  |
| `bar-colors.test.js` › isGreenBar › objetivo no cumplido, peso distinto de la referencia → no verde (azul) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › isGreenBar › peso 0 en ambos (corporal) → cuenta como mismo peso | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › única barra azul del grupo → azul vívido (tope), sea cual sea su e1RM | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › mínimo e1RM del grupo azul → suelo | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › máximo e1RM del grupo azul → vívido | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › e1RM intermedio → azul entre suelo y vívido | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › más e1RM relativo al grupo → azul más claro (canal G sube) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul › peso distinto de la referencia (aunque no cumpla objetivo) → grupo azul | `BarColorTests.swift` |  |
| `bar-colors.test.js` › buildGreenScale — la intensidad del verde sale del volumen, no del objetivo › grupo vacío → rango neutro | `BarColorTests.swift` |  |
| `bar-colors.test.js` › buildGreenScale — la intensidad del verde sale del volumen, no del objetivo › volúmenes distintos → escala por volumen | `BarColorTests.swift` |  |
| `bar-colors.test.js` › buildGreenScale — la intensidad del verde sale del volumen, no del objetivo › todas empatan en volumen → desempata por e1RM | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › única barra verde del grupo → vívida (tope), por mal que fuera la sesión | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › caso real del jalón: más reps con objetivo más alto → la más vívida | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › un objetivo inflado no da color: manda lo ejecutado | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › más series = más trabajo = más vívida | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › empate de volumen → desempata el pico de la mejor serie (e1RM) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › mismo trabajo y mismo pico → mismo color (empate real) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › monótono: a más volumen relativo, verde más vívido (G sube, nunca baja) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › mismo peso pero objetivo cumplido → grupo azul (el peso no fuerza verde) | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde › peso 0 en ambos (corporal) → cuenta como mismo peso → verde | `BarColorTests.swift` |  |
| `bar-colors.test.js` › computeBarColor — azul vs verde son distinguibles › cumplido es azulado (B alto), no cumplido es verdoso (G domina) | `BarColorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › muestra 3 botones de día en la vista inicial | `TodaySelectorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › seleccionar DIA2 muestra preview con ejercicios de DIA2 | `TodaySelectorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › seleccionar DIA3 muestra preview con ejercicios de DIA3 | `TodaySelectorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › botón Volver desde DIA2 regresa al selector | `TodaySelectorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › iniciar desde DIA2 crea entry con type DIA2 en DB | `TodaySelectorTests.swift` |  |
| `e2e/day-selector.spec.js` › Selector de rutinas (Hoy) › entreno iniciado desde DIA2 muestra ejercicios de DIA2 | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › todas las cards empiezan colapsadas | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › hay una card por ejercicio de la rutina | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › las cards muestran nombre y subtitle antes de expandir | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › clicar header expande la card | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › el chevron se sincroniza al expandir | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › clicar una card expandida la colapsa | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › las cards son independientes — varias pueden estar abiertas a la vez | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › cerrar una card no afecta a las demás | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › el body expandido no contiene inputs de texto ni número | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › los parámetros se muestran como .param-value (no como inputs) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › los botones +/- de parámetros no existen en modo lectura | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › las series se muestran como .series-cell-static (no como inputs) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › los param-value muestran los valores del último entreno (press_banca) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › las series-cell-static muestran las reps reales del último entreno | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › los labels de serie son S1, S2, S3... | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › second exercise shows correct param values (curl_biceps) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › second exercise shows correct series values (curl_biceps) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › series con val >= expected tienen clase done (verde) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › series con val < expected tienen clase filled (azul) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › series sin valor no tienen clase done ni filled | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › ejercicio sin historial de reps muestra — en las series | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › la sección de series tiene label "Reps por serie" | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › la sección de params tiene los labels correctos | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › no hay botón Guardar en ninguna card de rutina preview | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › volver al selector y re-entrar resetea el estado (todas cerradas) | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › iniciar entreno funciona correctamente después de expandir cards | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › DIA2 muestra sus propios ejercicios con valores correctos | `TodaySelectorTests.swift` |  |
| `e2e/routine-preview-accordion.spec.js` › Rutina preview — cards expandibles (solo lectura) › el historial strip se muestra para ejercicios con historial | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › añadir ejercicio existente a rutina se guarda en DB | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › crear ejercicio nuevo se guarda en DB y rutina | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › crear ejercicio con nombre duplicado muestra warning y modal sigue abierto | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › crear ejercicio nuevo cierra el modal tras éxito | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › buscar ejercicio en modal filtra correctamente | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › añadir ejercicio durante entreno activo aparece como card | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › crear ejercicio nuevo a mitad de entreno aparece como card y en logs | `TodaySelectorTests.swift` |  |
| `e2e/routine.spec.js` › Gestion de rutina › crear ejercicio nuevo a mitad de entreno NO desaparece de la lista al re-abrir | `TodaySelectorTests.swift` |  |
| `e2e/session.spec.js` › Arranque sin sistema de sesiones › con DB en localStorage → app arranca directamente | `TodaySelectorTests.swift` |  |
| `e2e/session.spec.js` › Arranque sin sistema de sesiones › sin DB en localStorage → arranca con db.json por defecto | `TodaySelectorTests.swift` |  |
| `e2e/session.spec.js` › Arranque sin sistema de sesiones › gym_companion_session ignorado si existe (dato legado) | `TodaySelectorTests.swift` |  |
| `e2e/session.spec.js` › Arranque sin sistema de sesiones › no hay botón de logout ni pantalla de login | `TodaySelectorTests.swift` |  |
| `e2e/best-recent-preload.spec.js` › Precarga "mejor de las últimas 4" al iniciar entreno › iniciar DIA1 precarga los valores de la sesión con mayor volumen, no los de la más reciente | `TodaySelectorTests.swift` |  |
| `e2e/best-recent-preload.spec.js` › Precarga "mejor de las últimas 4" al iniciar entreno › añadir ejercicio mid-entreno precarga los valores de la sesión con mayor volumen (no los de la más reciente) | `TodaySelectorTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › iniciar entreno y verificar que muestra cards de ejercicios | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › ajustar peso (+1 escalon) se refleja en el input | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › ajustar series (+1) añade nueva fila de rep | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › decrementar series elimina fila | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › completar rep de serie 1 guarda el valor | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › finalizar entreno con reps completas marca completado | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › finalizar entreno y verificar en historial | `TodayWorkoutTests.swift` |  |
| `e2e/workout-full.spec.js` › Workout flow completo › entreno en curso se guarda en localStorage | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › todas las cards empiezan cerradas | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › clicar una card la expande | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › clicar otra card cierra la primera y abre la nueva | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › clicar la card abierta la cierra (todas cerradas) | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › solo hay una card-body.open como máximo en todo momento | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › la card abierta se preserva tras ajustar peso | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › la card abierta se preserva tras modificar una rep | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › después de cerrar todas, se puede abrir cualquiera | `TodayWorkoutTests.swift` |  |
| `e2e/workout-accordion.spec.js` › Accordion: solo una card expandida a la vez › chevrons se sincronizan con el estado de la card | `TodayWorkoutTests.swift` |  |
| `e2e/workout-open-state.spec.js` › Estado abierto de card tras swap / quitar / añadir › swap de la card abierta: queda abierta esa card con el nuevo ejercicio, no la siguiente | `TodayWorkoutTests.swift` |  |
| `e2e/workout-open-state.spec.js` › Estado abierto de card tras swap / quitar / añadir › quitar la card abierta: no queda ninguna abierta (la siguiente no se abre sola) | `TodayWorkoutTests.swift` |  |
| `e2e/workout-open-state.spec.js` › Estado abierto de card tras swap / quitar / añadir › añadir ejercicio mantiene abierta la card actual y añade la nueva cerrada | `TodayWorkoutTests.swift` |  |
| `e2e/workout-open-state.spec.js` › Estado abierto de card tras swap / quitar / añadir › reordenar mantiene abierta la card por ejercicio, no por índice | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo muestra reps reales al iniciar si difieren del historial previo | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo muestra reps de curl_biceps al iniciar si difieren | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo NO muestra reps cuando todas coinciden con expected | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo se actualiza al cambiar una rep | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo se actualiza tras ajustar peso | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › subtítulo incluye peso y series x reps esperadas junto a las reales | `TodayWorkoutTests.swift` |  |
| `e2e/workout-subtitle-reps.spec.js` › Subtítulo de card muestra reps reales cuando difieren › reps desaparecen del subtítulo si se corrigen para coincidir con expected | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › el handle (≡) es visible en cada tarjeta de ejercicio durante entreno activo | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › el handle NO aparece en la vista de historial | — | En la app el Historial (#10) no ofrece reordenar: no hay asa que esconder. Solo `TodayModel.canReorder` lo permite, y solo con entreno en curso. |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › el handle NO aparece cuando no hay entreno activo (vista previa de hoy) | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › reorderExercises actualiza DB.routines en localStorage | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › reorderExercises actualiza entry.logs del entreno activo (invariante) | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › tras reordenar y re-renderizar, el nuevo orden se refleja en el DOM | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › editar peso tras reordenar modifica el ejercicio mostrado, no el que estaba antes en esa posición | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › editar reps por serie (chip) tras reordenar afecta al ejercicio correcto | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › ajustar peso con botones +/- tras reordenar afecta al ejercicio correcto | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › varios reordenamientos consecutivos mantienen el DOM coherente y editar sigue siendo correcto | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › cambiar (swap) un ejercicio tras reordenar mantiene la correspondencia card↔log | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › escenario reportado: añadir ejercicio mid-workout, moverlo y editarlo modifica el ejercicio correcto | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › el acordeón sigue funcionando tras reordenar y re-renderizar | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › el ejercicio que estaba abierto sigue abierto tras reordenar, aunque cambie de posición | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › ejercicio añadido mid-workout también tiene drag-handle | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › clic en drag-handle no abre el acordeón | `TodayWorkoutTests.swift` |  |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › existe el wrapper #workout-cards-list durante un entreno activo | — | Estructura del DOM de la PWA (el contenedor de SortableJS). En SwiftUI la lista de tarjetas es `TodayModel.activeCards`. |
| `e2e/workout-reorder.spec.js` › drag-reorder workout exercises › los .card son hijos directos de #workout-cards-list | — | Ídem: detalle del DOM que necesitaba SortableJS. |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 1 — cambiar ejercicio actualiza el título del card | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 2 — log en localStorage tiene swappedFrom correcto | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 3 — finalizar entreno → historial muestra el ejercicio sustituto | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 4 — DIA1 sigue con el ejercicio original tras el swap (regresión clave) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 5 — modal de swap excluye los ejercicios ya presentes en el entreno | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 6 — swap A→B→A: swappedFrom desaparece al volver al original | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 7 — quitar de rutina sobre log swapped: log desaparece, plantilla DIA1 intacta | `TodayEditingTests.swift` |  |
| `e2e/workout-swap.spec.js` › swap puntual de ejercicio en entreno activo › 8 — tras swap A→B, "+ Ejercicio" no ofrece B (fix bug duplicado) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 1 — ejercicios de la rutina activa (DIA1) no aparecen en el modal | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 2 — ejercicios de otros días SÍ aparecen en el modal | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 3 — tier 0 primero: mismo grupo + en otra rutina (Apertura, pecho, DIA2) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 4 — tier 1 segundo: mismo grupo + sin rutina (Press Inclinado, pecho) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 5 — tier 2 tercero: distinto grupo + en otra rutina (Sentadilla, piernas, DIA2) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 6 — tier 3 último: distinto grupo + sin rutina (Plancha, core) | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 7 — orden completo: [Apertura, Press Inclinado, Sentadilla, Plancha] | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 8 — se puede seleccionar un ejercicio de cualquier tier y el swap funciona | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 9 — tras swap, la rutina DIA1 sigue intacta en localStorage | `TodayEditingTests.swift` |  |
| `e2e/workout-swap-order.spec.js` › orden del modal de swap de ejercicio › 10 — búsqueda filtra: con "press" solo queda visible Press Inclinado | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 1 — swap desde único match en otro día ofrece modal recíproco; confirmar crea el pendiente | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 2 — declinar el modal (No) no crea ningún pendiente | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 3 — swap ambiguo (ejercicio en 2+ días) no ofrece modal recíproco (regresión) | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 4 — selector de días muestra aviso del intercambio pendiente | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 5 — al iniciar el día destino, el ejercicio queda sustituido y el pendiente sigue vivo | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 7 — al terminar el entreno del día destino, el pendiente se borra | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco entre días de rutina › 9 — revertir un swap (A→B→A) no vuelve a ofrecer el modal recíproco | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco — pendiente caducado › 6 — pendiente con semana caducada no se aplica y se limpia al iniciar | `TodayEditingTests.swift` |  |
| `e2e/workout-reciprocal-swap.spec.js` › swap recíproco — día destino ya hecho esta semana › 8 — DIA1 ya hecho esta semana: swap hacia su ejercicio único no ofrece modal recíproco | `TodayEditingTests.swift` |  |
| `e2e/workout-remove-exercise.spec.js` › Quitar ejercicio de rutina durante entreno › botón Quitar de rutina visible al expandir card durante entreno | `TodayEditingTests.swift` |  |
| `e2e/workout-remove-exercise.spec.js` › Quitar ejercicio de rutina durante entreno › clic en Quitar abre modal con nombre del ejercicio | `TodayEditingTests.swift` |  |
| `e2e/workout-remove-exercise.spec.js` › Quitar ejercicio de rutina durante entreno › confirmar elimina card del entreno y ejercicio de DB.routines | `TodayEditingTests.swift` |  |
| `e2e/workout-remove-exercise.spec.js` › Quitar ejercicio de rutina durante entreno › cancelar mantiene el ejercicio en el entreno y en DB.routines | `TodayEditingTests.swift` |  |
| `e2e/skip-exercise.spec.js` › Saltar ejercicio › saltar y reactivar un ejercicio en entreno activo | `TodayEditingTests.swift` |  |
| `e2e/skip-exercise.spec.js` › Saltar ejercicio › la card saltada mantiene el fondo al expandir | `TodayEditingTests.swift` |  |
| `e2e/skip-exercise.spec.js` › Saltar ejercicio › skipped se persiste en la DB de la sesión | `TodayEditingTests.swift` |  |
| `e2e/skip-exercise.spec.js` › Saltar ejercicio › finalizar con un saltado cuenta como completo | `TodayEditingTests.swift` |  |
| `e2e/skip-exercise.spec.js` › Saltar ejercicio › un ejercicio saltado se ve con fondo en historial, sin botón | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 1 — el chip aparece en el modal y arranca apagado | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 2 — chip apagado: el ejercicio entra en la rutina (comportamiento de siempre) | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 3 — chip encendido: entra en el entreno pero NO en la rutina | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 4 — chip encendido oculta "Crear nuevo ejercicio"; apagarlo lo devuelve | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 5 — la card puntual dice "Quitar" y se borra sin modal ni tocar la rutina | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 6 — reordenar con un puntual presente no mete el puntual en la rutina | `TodayEditingTests.swift` |  |
| `e2e/one-off-exercise.spec.js` › Ejercicio puntual (solo esta sesión) › 7 — al finalizar, el puntual queda en el historial y la rutina sigue limpia | `TodayEditingTests.swift` |  |
| `e2e/records.spec.js` › Deteccion de PRs › subir peso por encima del historico y completar reps muestra badge PR | `TodayEditingTests.swift` |  |
| `e2e/records.spec.js` › Deteccion de PRs › mismos valores que historico NO muestra badge | `TodayEditingTests.swift` |  |
| `e2e/validation-workout.spec.js` › Validación en vista Hoy › todas las reps completas → finalizar funciona normalmente | `TodayEditingTests.swift` |  |
| `e2e/validation-workout.spec.js` › Validación en vista Hoy › series 0 (manual input) → se clampea a 1 por setParam | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › el mensaje de completado usa color verde (#6a9955) | — | Color del CSS de la PWA. En la app el aviso de completado usa el verde del sistema (la vista), sin estilo propio que comprobar. |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › las cards usan formato de historial (compact-card + card-title/subtitle) | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › las cards NO tienen botón de editar | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › las cards NO usan meta-pills con emojis | — | Regresión de un HTML antiguo de la PWA (las «meta-pills»): en la app nunca existieron. |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › el subtitle muestra peso, series y reps formateados | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › toast de inicio no tiene emoji | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › toast de fin no tiene emoji | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › la vista completada coincide en estructura con el detalle del historial | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › no hay botón Cerrar en la vista de completado | — | Regresión de un botón que la PWA quitó; en la app la vista solo tiene «Volver a rutinas» (`backFromCompleted`). |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › navegar entre múltiples pestañas y volver muestra el selector (no el resumen) | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › navegar a otra pestaña y volver muestra el selector (no el resumen completado) | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: existe botón #back-to-selector-btn | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: botón Volver tiene texto "← Volver a rutinas" | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: botón Volver tiene clase btn-secondary | — | Clase CSS. En la app es un botón con estilo secundario de SwiftUI. |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: botón Volver está dentro de view-nav-actions | — | Contenedor del DOM de la PWA. |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: view-nav-actions solo tiene un botón (ocupa ancho completo) | — | Maquetación del DOM de la PWA; en la app lo decide la vista. |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › vista completada: botón Volver ocupa el ancho del contenedor (flex: 1) | — | Ídem (anchura CSS). |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › durante el entreno activo NO existe el botón Volver a rutinas | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › tras pulsar Volver, aparece el selector de rutinas con título "Rutinas" | `TodayEditingTests.swift` |  |
| `e2e/workout-completed-view.spec.js` › Vista de entreno completado › sin pulsar Volver, el resumen sigue visible al recargar la vista (botón Volver presente) | `TodayEditingTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › click en entry muestra detalle con ejercicios | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › detalle muestra peso, series, reps por ejercicio | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › tap en card expande y muestra controles de edicion | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › segundo tap en card colapsa el body | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › boton Guardar no aparece antes de modificar nada | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › boton Guardar aparece al modificar un valor | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › guardar actualiza subtitulo y colapsa la card | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › colapsar sin guardar descarta cambios y muestra valor original al reexpandir | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › navegar atras sin guardar descarta cambios | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › eliminar entry confirmar desaparece de la lista | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › eliminar entry cancelar sigue en la lista | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › volver desde detalle vuelve a la lista | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › navegar a entry A → volver → entry B no muestra datos de A | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › subtitulo se actualiza al modificar peso sin guardar | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › boton + de peso actualiza el input de peso | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › boton - de peso actualiza el input de peso | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › boton + de series actualiza el input de series | `HistoryModelTests.swift` |  |
| `e2e/history-full.spec.js` › Historial completo › chip de serie en historial abre chip strip y permite cambiar rep | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card incompleta: tiene fondo y borde azulado | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card incompleta: tiene icono de pausa en .day-info-top | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card incompleta: icono de pausa contiene SVG | — | Detalle del HTML (el icono es un SVG). En la app el icono es un símbolo SF que la vista pinta si `Row.isIncomplete`. |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card incompleta: icono de pausa tiene color accent | — | Color CSS; lo decide la vista. |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card completa: NO tiene tinte azulado | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card completa: NO tiene icono de pausa en .day-info-top | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › card completa: .day-info-top no contiene SVG de pausa | — | Detalle del HTML; que una sesión terminada no lleva pausa lo prueba «card completa: NO tiene icono de pausa». |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno incompleto: header muestra badge "Incompleto" | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno completo: header NO muestra badge "Incompleto" | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno incompleto: muestra botón "Completar entreno" | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno incompleto: botón está en contenedor workout-actions | — | Contenedor del DOM de la PWA. |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno incompleto: "Completar entreno" tiene clase btn-primary | — | Clase CSS; en la app es el botón principal de SwiftUI. |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno completo: NO muestra botón "Completar entreno" | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno completo: botones en view-nav-actions (solo Volver) | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › detalle entreno incompleto: botón Volver regresa a la lista | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › botón "Completar entreno" navega al tab Hoy | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › botón "Completar entreno" marca el entreno como completado en DB | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › tras completar, el entreno ya no aparece con tinte azul en historial | `HistoryModelTests.swift` |  |
| `e2e/history-incomplete.spec.js` › Historial — entrenos incompletos › badge "Incompleto" aparece debajo del título, no incrustado en él | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › renderiza 6 columnas semanales en el card del ejercicio | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › W-5/W-4/W-3 quedan vacías (no hay sesión) y W-2/W-1 con datos | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › sesiones fuera de la ventana de 6 semanas no ocupan bucket W-5 | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › tooltip en 2 líneas: "e1RM Xkg\\n<peso>kg · <reps>" | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › barra más alta corresponde a la sesión con mayor e1RM | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › barras vacías no tienen atributo data-tooltip | `HistoryModelTests.swift` |  |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › tap en barra con datos añade clase tooltip-active; tap fuera la quita | — | Qué barra enseña su detalle es estado de la vista SwiftUI (`HistoryStripView`), no de los datos; el contenido del detalle lo prueba «tooltip en 2 líneas». |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › tap en otra barra mueve la clase tooltip-active (solo una a la vez) | — | Ídem: estado de la vista, que guarda una sola barra elegida. |
| `e2e/history-strip.spec.js` › History strip (franja de últimas sesiones) › el bucket W0 muestra la fecha de hoy durante entreno activo (precarga rellena actuals) | `HistoryModelTests.swift` |  |
| `e2e/validation-history.spec.js` › Validación en edición de Historial › expandir entry → todo correcto → guardar se cierra normalmente | `HistoryModelTests.swift` |  |
| `e2e/validation-history.spec.js` › Validación en edición de Historial › entry con reps.actual vacío → al expandir se rellenan con expected | `HistoryModelTests.swift` |  |
| `e2e/validation-history.spec.js` › Validación en edición de Historial › entry con reps.actual vacío → colapsar sin guardar → reexpandir → sigue rellenando con expected | `HistoryModelTests.swift` |  |
| `e2e/validation-history.spec.js` › Validación en edición de Historial › guardar persiste cambio en localStorage | `HistoryModelTests.swift` |  |
| `e2e/validation-history.spec.js` › Validación en edición de Historial › colapsar sin guardar NO persiste cambio en localStorage | `HistoryModelTests.swift` |  |
| `e2e/bar-colors.spec.js` › Colores de barras del history strip › sesión cumplida → barra AZUL (B > G); sesión por debajo → barra VERDE (G > B) | `HistoryModelTests.swift` |  |
| `e2e/bar-colors.spec.js` › Colores de barras del history strip › barra activa con reps en objetivo (precarga [12,11,10]) → AZUL | `HistoryModelTests.swift` |  |
| `e2e/bar-colors.spec.js` › Colores de barras del history strip › bajar una rep por debajo del objetivo recolorea la barra activa a VERDE en vivo | `HistoryModelTests.swift` |  |
| `e2e/bar-colors.spec.js` › Colores de reps reales (celdas) › reps en objetivo → AZUL (.done); reps por debajo → VERDE (.filled) | `HistoryModelTests.swift` |  |
| `e2e/bar-tooltip-position.spec.js` › Posición del tooltip de barras (no se recorta en los bordes) › tap en barra del extremo IZQUIERDO → tooltip dentro del viewport | — | Posición CSS del tooltip flotante de la PWA. En la app el detalle va en una línea debajo de la tira, dentro de la tarjeta: no puede salirse. |
| `e2e/bar-tooltip-position.spec.js` › Posición del tooltip de barras (no se recorta en los bordes) › tap en barra del extremo DERECHO → tooltip dentro del viewport | — | Ídem. |
| `e2e/bar-tooltip-position.spec.js` › Posición del tooltip de barras (no se recorta en los bordes) › barra CENTRAL queda centrada (sin desplazar, --tt-shift ~0) | — | Ídem. |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: botones Volver e Iniciar están en workout-actions | — | Contenedor del DOM de la PWA. Que la vista previa ofrece volver y empezar lo prueban «botón Volver vuelve al selector» y el selector de rutinas. |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: botón Volver es el primero (izquierda) | — | Orden visual de dos botones: lo decide la vista. |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: botón Volver tiene texto "← Volver" y estilo btn-secondary | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: no existe botón + Ejercicio | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: botón Volver vuelve al selector de rutinas | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › routine preview: botón Volver ocupa 1/3 del ancho, Iniciar 2/3 | — | Anchuras CSS (flex 1 / flex 2). |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › history detail: botón Volver está en view-nav-actions | — | Contenedor del DOM de la PWA. |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › history detail: botón Volver tiene texto "← Volver" y estilo btn-secondary | `HistoryModelTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › history detail: botón Volver vuelve a la lista de historial | `HistoryModelTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › history detail: botón Volver ocupa mitad del ancho del contenedor | — | Anchura CSS. |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › completed view: botón Volver lleva al selector de rutinas | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › completed view: botón Volver actualiza el título a "Rutinas" | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › completed view: botón Volver oculta la vista de completado | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › completed view: desde selector tras volver, se puede seleccionar otra rutina | `TodayEditingTests.swift` |  |
| `e2e/view-nav-buttons.spec.js` › Botones de navegación en vistas (Volver + Ejercicio) › completed view: tras volver al selector y navegar a otra pestaña, volver a Hoy muestra el selector | `TodayEditingTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › seleccionar ejercicio muestra 2 canvas | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › cambiar rango de fechas actualiza lista de ejercicios | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › rango sin datos muestra dropdown vacio | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › cambiar ejercicio actualiza graficas | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › buscador filtra ejercicios en el dropdown | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › botón clear está oculto sin texto y visible con texto | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › botón clear limpia selección y abre dropdown | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › leyenda de gráficas no contiene nombre de ejercicio | `ChartsModelTests.swift` |  |
| `e2e/charts-full.spec.js` › Graficas completo › tooltip usa colores del dark theme | — | Colores del tema oscuro de Chart.js. En la app el detalle de Swift Charts usa los colores del sistema, claros u oscuros según el iPhone. |
| `e2e/estadisticas.spec.js` › Estadísticas › la pestaña Progreso muestra las dos tarjetas | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › la tarjeta arranca plegada y solo muestra los estancados | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › tocar la cabecera de la tarjeta despliega y pliega el resto | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › cada fila trae nombre y frase; las reps van colapsadas | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › tocar la cabecera despliega y pliega las reps | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › cada fila lleva su clase de color según el estado | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › el estancado va primero y el ejercicio sin recorrido al final | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › un ejercicio sin peso no muestra columna de kg | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › el ejercicio sin recorrido no ofrece botón de Gráficas | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › el botón de dentro abre Gráficas con el ejercicio ya seleccionado | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › volver devuelve a Estadísticas | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › entrar a Gráficas desde la pestaña no muestra el botón de volver | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › cada grupo pinta la franja de referencia con sus dos límites | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › tocar un grupo despliega y pliega sus ejercicios | `ProgressModelTests.swift` |  |
| `e2e/estadisticas.spec.js` › Estadísticas › las cinco pestañas caben sin solaparse | — | La barra de pestañas es la nativa de iOS (`TabView`): el sistema la reparte. Las cinco pestañas las prueba `ScreenshotTests.testPestanas`. |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › Progreso muestra la tarjeta del catálogo con el total y los sin grupo | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › lista todos los ejercicios de la DB, entrenados o no | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › el buscador filtra ignorando tildes | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › volver deja Progreso como estaba | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › renombrar un ejercicio se propaga al resto de la app | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › cambiar el grupo mueve el ejercicio de sección | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › marcar un secundario alimenta la barra de indirecto de Progreso | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › el grupo principal no se puede marcar además como secundario | `CatalogModelTests.swift` |  |
| `e2e/catalogo.spec.js` › Catálogo de ejercicios › un nombre vacío no se guarda | `CatalogModelTests.swift` |  |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › guardar configuración GitHub almacena PAT en texto plano | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › guardar configuración GitHub sin PAT muestra error | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › guardar sin repo muestra error | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › al abrir ajustes con PAT guardado, se muestra en el campo | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › no hay sección "Cambiar contraseña" en ajustes | — | Regresión de un acceso con contraseña que la PWA quitó; la app nunca lo tuvo. |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › no hay botón de logout | — | Ídem: no hay sesión de la que salir. |
| `e2e/settings.spec.js` › Ajustes — GitHub y PAT en claro › probar conexión NO modifica la DB | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › probar conexión — respuestas de red › probar conexión sin config guardada → toast de aviso | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › probar conexión — respuestas de red › probar conexión con respuesta 200 → toast de éxito | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › probar conexión — respuestas de red › probar conexión con 401 → toast de error con código | `SettingsModelTests.swift` |  |
| `e2e/settings.spec.js` › probar conexión — respuestas de red › probar conexión con fallo de red → toast de error genérico | `SettingsModelTests.swift` |  |
| `e2e/login.spec.js` › Arranque directo (sin login) › la app arranca directamente sin pantalla de login | `SettingsModelTests.swift` |  |
| `e2e/login.spec.js` › Arranque directo (sin login) › sin datos locales → arranca con datos por defecto (db.json) | `SettingsModelTests.swift` |  |
| `e2e/login.spec.js` › Arranque directo (sin login) › la vista inicial es Rutinas | `SettingsModelTests.swift` |  |
| `e2e/login.spec.js` › Arranque directo (sin login) › el indicador de sync es visible en el header | `SettingsModelTests.swift` |  |
| `e2e/login.spec.js` › Arranque directo (sin login) › sin GitHub configurado → indicador en estado disabled | `SettingsModelTests.swift` |  |

**Total:** 779 portados, 50 no aplican, 0 sin portar, de 829.
