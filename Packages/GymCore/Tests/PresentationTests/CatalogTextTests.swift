import Presentation
import Testing

@Suite("Textos del catálogo")
struct CatalogTextTests {
    @Test("el resumen del catálogo, con los que no tienen grupo solo si los hay")
    func summary() {
        #expect(CatalogText.summary(total: 4, withoutGroup: 1) == "4 en total · 1 sin grupo")
        #expect(CatalogText.summary(total: 4, withoutGroup: 0) == "4 en total")
    }
}
