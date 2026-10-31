#if DEBUG
import GastarioCore
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

/// Menú de desarrollo: insertar movimientos de muestra, borrar todo (SPEC Fase 0) y programar una
/// notificación de prueba para reproducir el toque (C15) sin capturar nada.
struct DebugMenu: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Debug", systemImage: "ladybug") {
            Button("Insertar muestras", systemImage: "plus") { insertSamples() }
            Button("Notificación de prueba en 5 s", systemImage: "bell") { scheduleTestNotification() }
            Button("Borrar todo", systemImage: "trash", role: .destructive) { deleteAll() }
        }
    }

    private func insertSamples() {
        let now = Date.now
        let hour: TimeInterval = 3600

        let card = Movement(
            source: .card, direction: .outflow, amount: Decimal(string: "3.80")!,
            counterparty: "SUPER 99", occurredAt: now.addingTimeInterval(-1 * hour))
        card.cardName = "Visa"

        let partialCard = Movement(
            source: .card, direction: .outflow, amount: 0, counterparty: "FARMACIA EJEMPLO",
            occurredAt: now.addingTimeInterval(-3 * hour), parseStatus: .partial, parseIssues: [.amount])

        let sent = Movement(
            source: .yappy, direction: .outflow, amount: Decimal(string: "40.00")!,
            counterparty: "Ana Morales", occurredAt: now.addingTimeInterval(-26 * hour))
        sent.note = "Cuerdas"
        sent.notedAt = now

        let received = Movement(
            source: .yappy, direction: .inflow, amount: Decimal(string: "1250.00")!,
            counterparty: "Luis Herrera", occurredAt: now.addingTimeInterval(-50 * hour))

        let failed = Movement(
            source: .yappy, direction: .outflow, amount: 0, occurredAt: now.addingTimeInterval(-51 * hour),
            parseStatus: .failed, parseIssues: [.direction, .amount, .counterparty])

        let manual = Movement(
            source: .manual, direction: .outflow, amount: Decimal(string: "12.50")!,
            counterparty: "Taxi", occurredAt: now.addingTimeInterval(-75 * hour))

        for movement in [card, partialCard, sent, received, failed, manual] {
            context.insert(movement)
        }
        save()
    }

    private func deleteAll() {
        // Uno por uno y no `delete(model:)`: el borrado en lote no aplica la cascada a los adjuntos.
        let movements = (try? context.fetch(FetchDescriptor<Movement>())) ?? []
        for movement in movements {
            SharedCaptureLog.log.record(.deleted(movement, from: .debug))
            context.delete(movement)
        }
        save()
    }

    /// Programa en 5 s la notificación del movimiento más reciente, con el mismo identificador,
    /// categoría y texto que la real (título con "[Prueba] "). Da tiempo a ir al inicio o cerrar
    /// la app desde el switcher antes de que llegue. No crea ni modifica movimientos.
    private func scheduleTestNotification() {
        var descriptor = FetchDescriptor<Movement>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let movement = try? context.fetch(descriptor).first else {
            Logger.app.error("Notificación de prueba: no hay movimientos")
            return
        }
        let id = movement.id.uuidString
        let text = NotificationText.build(for: movement)
        Task { await Self.schedule(id: id, text: text) }
    }

    /// `nonisolated` y `async`, como en `NotificationService`: el completion handler del centro
    /// llega desde otro hilo.
    private nonisolated static func schedule(id: String, text: NotificationText) async {
        let content = UNMutableNotificationContent()
        content.title = "[Prueba] " + text.title
        content.body = text.body
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.category
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.app.info("Notificación de prueba programada: \(id, privacy: .public)")
        } catch {
            Logger.app.error("Notificación de prueba: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Logger.app.error("No se pudo guardar: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
