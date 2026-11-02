import GastarioCore
import SwiftUI

/// Hoja de "Rango…" (SPEC Fase 4a): días completos en Panamá, ambos incluidos.
struct DateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var from: Date
    @State private var to: Date
    let onApply: (DatePeriod) -> Void

    /// Con un rango activo lo precarga; si no, el mes en curso.
    init(current: DatePeriod, onApply: @escaping (DatePeriod) -> Void) {
        let now = Date.now
        if case .range(let from, let to) = current {
            _from = State(initialValue: from)
            _to = State(initialValue: to)
        } else {
            let month = DatePeriod.thisMonth.interval(now: now)
            _from = State(initialValue: month?.start ?? now)
            // El final del mes es el primer instante del siguiente: el último día es uno antes.
            _to = State(initialValue: month.map { $0.end.addingTimeInterval(-1) } ?? now)
        }
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Desde", selection: $from, displayedComponents: .date)
                DatePicker("Hasta", selection: $to, in: from..., displayedComponents: .date)
            }
            .environment(\.timeZone, MovementPresentation.timeZone)
            .onChange(of: from) { _, newValue in
                if to < newValue { to = newValue }
            }
            .navigationTitle("Rango")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onApply(.range(from: from, to: to))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
