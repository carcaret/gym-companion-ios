import Domain
import Presentation
import Testing

@Suite("Textos de lo que se sube de Salud")
struct HealthTextTests {
    @Test("cuenta pesajes, medidas de cintura y días de comida, con el plural bien")
    func counts() {
        #expect(HealthText.upToDate(HealthRecord.Summary(weighings: 412, waistMeasurements: 6, nutritionDays: 380))
            == "412 pesajes · 6 medidas de cintura · 380 días de comida · al día")
        #expect(HealthText.uploaded(HealthRecord.Summary(weighings: 1, waistMeasurements: 1, nutritionDays: 1))
            == "1 pesaje · 1 medida de cintura · 1 día de comida · subido")
        #expect(HealthText.uploaded(HealthRecord.Summary(weighings: 3, waistMeasurements: 0, nutritionDays: 0))
            == "3 pesajes · 0 medidas de cintura · 0 días de comida · subido")
    }
}
