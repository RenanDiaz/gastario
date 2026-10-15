#if DEBUG
import GastarioCore
import OSLog
import SwiftData
import SwiftUI

/// Menú de desarrollo: insertar movimientos de muestra y borrar todo (SPEC Fase 0).
struct DebugMenu: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Debug", systemImage: "ladybug") {
            Button("Insertar muestras", systemImage: "plus") { insertSamples() }
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
            context.delete(movement)
        }
        save()
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
