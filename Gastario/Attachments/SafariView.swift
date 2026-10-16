import SafariServices
import SwiftUI

/// Abre un link adjunto dentro de la app (C14): no deja una pestaña en Safari por cada factura.
/// Solo acepta `http`/`https`; `AttachmentRules` ya lo garantiza al guardar.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.delegate = context.coordinator
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: { dismiss() })
    }

    /// "Listo" se cierra por SwiftUI; si lo cerrara el controlador, el binding quedaría en `true`.
    @MainActor
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        private let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismiss()
        }
    }
}
