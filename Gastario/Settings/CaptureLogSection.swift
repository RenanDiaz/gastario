import GastarioCore
import SwiftUI

/// Ajustes → Bitácora de captura (SPEC Fase 7a): invocaciones que no terminaron, borrados y
/// el botón para compartir los archivos.
struct CaptureLogSection: View {
    @State private var summary: CaptureLogSummary?
    @State private var files: [URL] = []

    private static let window: TimeInterval = 30 * 24 * 60 * 60

    var body: some View {
        Section {
            if let summary {
                let since = Date.now.addingTimeInterval(-Self.window)
                let recent = summary.invocations(from: since, to: .distantFuture)
                let incomplete = recent.filter { !$0.isComplete }
                LabeledContent("Capturas (30 días)", value: "\(recent.count)")
                LabeledContent("Sin terminar", value: "\(incomplete.count)")
                    .foregroundStyle(incomplete.isEmpty ? Color.primary : Color.red)
                ForEach(incomplete.reversed()) { invocation in
                    IncompleteInvocationRow(invocation: invocation)
                }
                let deletions = summary.deletions.filter { $0.t >= since }
                if !deletions.isEmpty {
                    DisclosureGroup("Borrados (\(deletions.count))") {
                        ForEach(Array(deletions.reversed().enumerated()), id: \.offset) { _, deletion in
                            DeletionRow(event: deletion)
                        }
                    }
                }
                if summary.unreadableLines > 0 {
                    Text("\(summary.unreadableLines) líneas ilegibles").foregroundStyle(.secondary)
                }
            }
            if !files.isEmpty {
                ShareLink(items: files) {
                    Label("Compartir bitácora", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Bitácora de captura")
        } footer: {
            Text("Cada pago o Yappy que llega deja un rastro paso a paso, fuera de la base de datos. Si una captura se pierde, dice dónde se detuvo. Se guardan 3 meses.")
        }
        .onAppear(perform: load)
    }

    private func load() {
        let log = SharedCaptureLog.log
        summary = CaptureLogReader.summarize(log.lines())
        files = log.files()
    }
}

private struct IncompleteInvocationRow: View {
    let invocation: CaptureInvocation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body)
            Text(MovementPresentation.timestampText(invocation.startedAt))
                .font(.caption).foregroundStyle(.secondary)
            Text(invocation.errorMessage ?? invocation.stage.title)
                .font(.caption).foregroundStyle(.red)
            if invocation.pidChanged {
                Text("El proceso se relanzó a mitad de la captura").font(.caption).foregroundStyle(.orange)
            }
        }
    }

    /// Lo que llegó de Atajos, crudo: es lo que hay que buscar en el estado de cuenta.
    private var title: String {
        guard let received = invocation.received else { return "Captura" }
        if let inputs = received.inputs {
            let merchant = inputs.merchant.flatMap { $0.isEmpty ? nil : $0 } ?? "(sin comercio)"
            let amount = inputs.amount.flatMap { $0.isEmpty ? nil : $0 } ?? "(sin monto)"
            return "Tarjeta · \(merchant) · \(amount)"
        }
        return "Yappy · \(received.contentLength ?? 0) caracteres"
    }
}

private struct DeletionRow: View {
    let event: CaptureLogEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(event.counterparty ?? "(sin contraparte)") · $\(event.amount ?? "?")")
            Text("Borrado \(MovementPresentation.timestampText(event.t))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
