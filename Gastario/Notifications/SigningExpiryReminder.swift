import Foundation
import GastarioCore
import Observation
import OSLog
import UserNotifications

/// Vencimiento de la firma (SPEC Fase 7b, C18): lee `embedded.mobileprovision` del bundle y
/// (re)programa la notificación 24 h antes. La usan Ajustes, el aviso de la lista y el arranque.
@MainActor
@Observable
final class SigningExpiryReminder {
    static let shared = SigningExpiryReminder()

    /// Fijo: reprogramar reemplaza el aviso anterior en lugar de sumar otro.
    nonisolated static let notificationID = "signing-expiry"
    /// Aparte, para que reprogramar al volver a la app no borre la prueba de Debug.
    nonisolated static let debugNotificationID = "signing-expiry-debug"

    /// `nil` sin perfil (App Store, TestFlight, simulador) o si no se puede leer: no se avisa nada.
    private(set) var expiry: SigningExpiry?

    /// El bundle no cambia mientras vive el proceso: reinstalar lo reinicia.
    private init() {
        expiry = Self.bundleExpiry()
    }

    private static func bundleExpiry() -> SigningExpiry? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let date = ProvisioningProfile.expirationDate(fromProfile: data)
        else { return nil }
        return SigningExpiry(expiresAt: date)
    }

    /// Cada vez que la app pasa a `active`: borra el aviso pendiente y, si todavía no pasó su hora,
    /// programa otro con la fecha del perfil instalado ahora.
    func reschedule(now: Date = .now) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard let expiry, let date = expiry.reminderDate(now: now) else { return }
        await Self.schedule(expiry, id: Self.notificationID, after: date.timeIntervalSince(now))
    }

    #if DEBUG
    /// Gate de la Fase 7b sin esperar 6 días: vencimiento en 24 h (Ajustes y la lista en rojo) y
    /// la notificación 10 s después. Dura hasta que se cierra el proceso.
    func simulateTomorrow() async {
        let simulated = SigningExpiry(expiresAt: .now.addingTimeInterval(SigningExpiry.reminderLead))
        expiry = simulated
        await Self.schedule(simulated, id: Self.debugNotificationID, after: 10)
    }
    #endif

    /// Sin categoría: no lleva "Responder". Al tocarla, el delegate ve un identificador que no es
    /// UUID y solo abre la app.
    private nonisolated static func schedule(_ expiry: SigningExpiry, id: String, after interval: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = SigningExpiry.reminderTitle
        content.body = expiry.reminderBody
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.app.error("No se pudo programar el aviso de vencimiento: \(error.localizedDescription, privacy: .public)")
        }
    }
}
