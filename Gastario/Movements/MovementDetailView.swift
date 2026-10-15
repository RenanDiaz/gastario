import GastarioCore
import SwiftData
import SwiftUI
import UIKit

/// Detalle con edición, re-parseo y cuerpo crudo (SPEC Fase 4).
struct MovementDetailView: View {
    @Environment(\.modelContext) private var context
    let movement: Movement
    @State private var editing = false
    @State private var reparseResult: String?

    var body: some View {
        List {
            if movement.source == .yappy && movement.confirmation == nil {
                Section {
                    Label(
                        "Este Yappy no tiene confirmación: si se capturó dos veces, no se detecta el duplicado. Bórralo a mano si sobra.",
                        systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                LabeledContent("Monto", value: MovementPresentation.amountText(for: movement))
                LabeledContent("Tipo", value: movement.direction == .outflow ? "Salida" : "Entrada")
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
            } header: {
                Text("Movimiento")
            } footer: {
                if !movement.editedFields.isEmpty {
                    Text("Editado a mano: \(editedText). El re-parseo no lo cambia.")
                }
            }

            if let mapsURL {
                Section {
                    Link(destination: mapsURL) {
                        Label(movement.city ?? "Ver en Mapas", systemImage: "map")
                    }
                }
            }

            Section("Nota") {
                Text(movement.note ?? "Sin nota")
                    .foregroundStyle(movement.hasNote ? .primary : .secondary)
                if let notedAt = movement.notedAt {
                    LabeledContent("Anotada", value: MovementPresentation.timestampText(notedAt))
                }
            }

            Section("Captura") {
                LabeledContent("Fuente", value: sourceText)
                LabeledContent("Estado", value: movement.parseStatus.rawValue)
                if !movement.parseIssues.isEmpty {
                    LabeledContent(
                        "No se pudo leer",
                        value: movement.parseIssues.map(\.rawValue).sorted().joined(separator: ", "))
                }
                LabeledContent("Capturado", value: MovementPresentation.timestampText(movement.capturedAt))
                if movement.source != .manual {
                    Button("Re-parsear", systemImage: "arrow.clockwise") { reparse() }
                    if let reparseResult {
                        Text(reparseResult).foregroundStyle(.secondary)
                    }
                }
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
        .toolbar {
            Button("Editar") { editing = true }
        }
        .sheet(isPresented: $editing) {
            EditMovementView(movement: movement)
        }
    }

    private var sourceText: String {
        switch movement.source {
        case .card: "Tarjeta"
        case .yappy: "Yappy"
        case .manual: "Manual"
        }
    }

    private var editedText: String {
        movement.editedFields.map { field in
            switch field {
            case .amount: "monto"
            case .counterparty: "contraparte"
            case .occurredAt: "fecha"
            }
        }
        .sorted()
        .joined(separator: ", ")
    }

    private var mapsURL: URL? {
        guard let latitude = movement.latitude, let longitude = movement.longitude else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: movement.counterparty ?? "Pago"),
        ]
        return components?.url
    }

    /// Funciona en cualquier estado y respeta `editedFields` (`INTENT.md`, Re-parseo).
    private func reparse() {
        let changed = ReparseService().reparse(movement)
        try? context.save()
        reparseResult = changed ? "Actualizado con el parser actual." : "Sin cambios."
    }
}
