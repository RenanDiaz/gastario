import AppIntents
import GastarioCore
import OSLog

/// Lo llama el atajo "When Any Card is tapped" (docs/shortcuts.md).
struct LogCardMovementIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Card Transaction" }
    static var description: IntentDescription { IntentDescription("Guarda un pago con tarjeta en Gastario.") }
    /// Corre sin abrir la app.
    static var supportedModes: IntentModes { .background }

    // Opcionales a propósito: con un parámetro requerido vacío, Atajos le pregunta al usuario y
    // la captura en segundo plano se detiene. Wallet a veces entrega Merchant o Amount vacíos.
    @Parameter(title: "Merchant") var merchant: String?
    @Parameter(title: "Amount") var amount: String?
    @Parameter(title: "Card or Pass") var cardName: String?
    @Parameter(title: "City") var city: String?
    @Parameter(title: "Latitude") var latitude: Double?
    @Parameter(title: "Longitude") var longitude: Double?

    @MainActor
    func perform() async throws -> some IntentResult {
        let inputs = CardRawInputs(
            merchant: merchant ?? "", amount: amount ?? "", cardName: cardName ?? "",
            city: city, latitude: latitude, longitude: longitude)
        // Solo lanza si el store no responde: un fallo de parseo se guarda igual (principio 1).
        let outcome = try await CaptureService(container: SharedModelContainer.container).captureCard(inputs)
        Logger.app.info("Tarjeta capturada: \(String(describing: outcome), privacy: .public)")
        return .result()
    }
}
