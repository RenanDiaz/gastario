import GastarioCore
import SwiftData
import SwiftUI

/// Ajustes (esqueleto de la Fase 4). La Fase 5 agrega el export y el respaldo.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var reparseResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Re-parsear todo", systemImage: "arrow.clockwise") { reparseAll() }
                    if let reparseResult {
                        Text(reparseResult).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Vuelve a leer con el parser actual los movimientos que requieren revisión. No toca notas, adjuntos ni lo editado a mano.")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    /// AC-17.
    private func reparseAll() {
        do {
            let changed = try ReparseService().reparseAll(in: context)
            reparseResult = changed == 1 ? "1 movimiento actualizado." : "\(changed) movimientos actualizados."
        } catch {
            reparseResult = "No se pudo re-parsear: \(error.localizedDescription)"
        }
    }
}
