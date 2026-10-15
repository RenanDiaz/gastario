import GastarioCore
import SwiftData
import SwiftUI

/// Entrada manual (AC-14): efectivo, tarjeta física o un tap que no disparó la automatización.
/// No pasa por `CaptureService`, así que no notifica.
struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var amountText = ""
    @State private var direction: Direction = .outflow
    @State private var counterparty = ""
    @State private var occurredAt = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $direction) {
                        Text("Gasto").tag(Direction.outflow)
                        Text("Ingreso").tag(Direction.inflow)
                    }
                    .pickerStyle(.segmented)
                    TextField("Monto", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Comercio o persona", text: $counterparty)
                    DatePicker("Fecha", selection: $occurredAt)
                        .environment(\.timeZone, MovementPresentation.timeZone)
                }
                Section("Nota") {
                    TextField("¿En qué fue? (opcional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(AmountInput.parse(amountText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let amount = AmountInput.parse(amountText) else { return }
        context.insert(Movement.manual(
            amount: amount, direction: direction, counterparty: counterparty,
            occurredAt: occurredAt, note: note))
        try? context.save()
        dismiss()
    }
}
