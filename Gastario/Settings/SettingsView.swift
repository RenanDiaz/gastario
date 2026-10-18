import GastarioCore
import SwiftData
import SwiftUI

/// Ajustes: re-parseo (Fase 4) y respaldo (Fase 5).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var reparseResult: String?
    @State private var lastExportAt: Date?
    @State private var lastExportError: String?
    @State private var exporting = false
    @State private var exportMessage: String?
    @State private var shareURL: URL?

    private var backup: BackupService { SharedModelContainer.backup }

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

                Section {
                    LabeledContent(
                        "Último respaldo",
                        value: lastExportAt.map(MovementPresentation.timestampText) ?? "Nunca")
                    if let lastExportError {
                        Text("El último intento falló: \(lastExportError)")
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task { await exportNow() }
                    } label: {
                        if exporting {
                            ProgressView()
                        } else {
                            Label("Exportar ahora", systemImage: "icloud.and.arrow.up")
                        }
                    }
                    .disabled(exporting)
                    if let exportMessage {
                        Text(exportMessage).foregroundStyle(.secondary)
                    }
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("Compartir CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                    #if DEBUG
                    Button("Simular 8 días sin export", systemImage: "clock.arrow.circlepath") {
                        backup.state.lastExportAt = Date.now.addingTimeInterval(-8 * 24 * 60 * 60)
                        loadBackupState()
                    }
                    #endif
                } header: {
                    Text("Respaldo")
                } footer: {
                    Text("Cada 7 días se guarda el CSV completo en iCloud Drive → Gastario, al capturar un movimiento o al abrir la app. Los adjuntos no se exportan.")
                }
            }
            .onAppear(perform: loadBackupState)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func loadBackupState() {
        lastExportAt = backup.state.lastExportAt
        lastExportError = backup.state.lastExportError
    }

    /// AC-11: fuerza el export a iCloud y ofrece compartir el mismo archivo.
    private func exportNow() async {
        exporting = true
        let result = await backup.export()
        shareURL = result.localURL
        exportMessage = result.error == nil
            ? "Guardado en iCloud Drive → Gastario."
            : "No se pudo guardar en iCloud. Puedes compartir el archivo."
        loadBackupState()
        exporting = false
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
