import GastarioCore
import SwiftUI
import UIKit

/// Detalle de solo lectura con el cuerpo crudo. Es el primer pedazo de la vista de la Fase 4
/// (SPEC, Fase 4): sirve para diagnosticar capturas y para conseguir fixtures reales.
struct MovementDetailView: View {
    let movement: Movement

    var body: some View {
        List {
            Section("Movimiento") {
                LabeledContent("Monto", value: MovementPresentation.amountText(for: movement))
                LabeledContent("Contraparte", value: movement.counterparty ?? "—")
                if let message = movement.yappyMessage, !message.isEmpty {
                    LabeledContent("Mensaje", value: message)
                }
                if let confirmation = movement.confirmation {
                    LabeledContent("Confirmación", value: confirmation)
                }
                if let cardName = movement.cardName {
                    LabeledContent("Tarjeta", value: cardName)
                }
                LabeledContent("Fecha", value: MovementPresentation.timestampText(movement.occurredAt))
            }

            Section("Nota") {
                Text(movement.note ?? "Sin nota")
                    .foregroundStyle(movement.hasNote ? .primary : .secondary)
                if let notedAt = movement.notedAt {
                    LabeledContent("Anotada", value: MovementPresentation.timestampText(notedAt))
                }
            }

            Section("Captura") {
                LabeledContent("Fuente", value: movement.source.rawValue)
                LabeledContent("Estado", value: movement.parseStatus.rawValue)
                if !movement.parseIssues.isEmpty {
                    LabeledContent(
                        "No se pudo leer",
                        value: movement.parseIssues.map(\.rawValue).sorted().joined(separator: ", "))
                }
                LabeledContent("Capturado", value: MovementPresentation.timestampText(movement.capturedAt))
            }

            if let raw = movement.rawContent ?? movement.rawInputs {
                Section {
                    Button("Copiar", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = raw
                    }
                    Text(raw)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                } header: {
                    Text(movement.rawContent != nil ? "Cuerpo crudo" : "Datos recibidos")
                } footer: {
                    Text("\(raw.count) caracteres")
                }
            }
        }
        .navigationTitle(movement.counterparty ?? "Movimiento")
        .navigationBarTitleDisplayMode(.inline)
    }
}
