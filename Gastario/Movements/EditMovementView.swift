import GastarioCore
import SwiftData
import SwiftUI

/// Edición a mano de monto, contraparte, fecha y nota. Solo aplica los campos que cambiaron:
/// cada uno pasa a `editedFields` y deja de ser un issue (`MovementEditor`).
struct EditMovementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let movement: Movement

    @State private var amountText: String
    @State private var counterparty: String
    @State private var occurredAt: Date
    @State private var note: String

    init(movement: Movement) {
        self.movement = movement
        _amountText = State(initialValue: movement.amount == 0 ? "" : AmountInput.text(movement.amount))
        _counterparty = State(initialValue: movement.counterparty ?? "")
        _occurredAt = State(initialValue: movement.occurredAt)
        _note = State(initialValue: movement.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if movement.parseStatus == .failed {
                    Section {
                        Text("Este movimiento no se pudo leer. Editarlo no lo marca como revisado: usa Re-parsear cuando mejore el parser, o bórralo si sobra.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Monto") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section("Contraparte") {
                    TextField("Comercio o persona", text: $counterparty)
                }
                Section("Fecha") {
                    DatePicker("Fecha", selection: $occurredAt)
                        .environment(\.timeZone, MovementPresentation.timeZone)
                }
                Section("Nota") {
                    TextField("¿En qué fue?", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!AmountInput.isValidOrEmpty(amountText))
                }
            }
        }
    }

    private func save() {
        if let amount = AmountInput.parse(amountText), amount != movement.amount {
            MovementEditor.setAmount(amount, on: movement)
        }
        if counterparty.trimmingCharacters(in: .whitespacesAndNewlines) != (movement.counterparty ?? "") {
            MovementEditor.setCounterparty(counterparty, on: movement)
        }
        if occurredAt != movement.occurredAt {
            MovementEditor.setOccurredAt(occurredAt, on: movement)
        }
        if note.trimmingCharacters(in: .whitespacesAndNewlines) != (movement.note ?? "") {
            MovementEditor.setNote(note, on: movement)
        }
        try? context.save()
        dismiss()
    }
}

/// Monto escrito a mano: acepta `3.80`, `$3.80` o `1,250.00` (mismo parser que la captura).
enum AmountInput {
    static func parse(_ text: String) -> Decimal? {
        guard let amount = AmountParser.parse(text), amount > 0 else { return nil }
        return amount
    }

    static func isValidOrEmpty(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty || parse(text) != nil
    }

    static func text(_ amount: Decimal) -> String {
        amount.formatted(
            .number.grouping(.never).precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX")))
    }
}
