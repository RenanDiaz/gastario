import GastarioCore
import SwiftUI

/// Ajustes → Firma (SPEC Fase 7b, C18): cuándo vence la app, en rojo con menos de 48 h. Sin
/// perfil no aparece, salvo en `DEBUG`, para poder simular.
struct SigningExpirySection: View {
    private let reminder = SigningExpiryReminder.shared

    var body: some View {
        if showsSection {
            Section {
                if let expiry = reminder.expiry {
                    Text(expiry.settingsText)
                        .foregroundStyle(expiry.isUrgent(now: .now) ? Color.red : Color.primary)
                }
                #if DEBUG
                Button("Simular vencimiento mañana", systemImage: "clock.badge.exclamationmark") {
                    Task { await reminder.simulateTomorrow() }
                }
                #endif
            } header: {
                Text("Firma")
            } footer: {
                Text(reminder.expiry == nil
                    ? "Esta instalación no trae perfil de aprovisionamiento: no vence."
                    : "Con una cuenta gratis la app vence 7 días después de instalarla desde Xcode. Vencida no abre, y los atajos no pueden guardar capturas.")
            }
        }
    }

    private var showsSection: Bool {
        #if DEBUG
        true
        #else
        reminder.expiry != nil
        #endif
    }
}

/// Aviso arriba de la lista con menos de 48 h para el vencimiento: Ajustes solo se ve si se abre.
/// Tocarlo abre Ajustes.
struct SigningExpiryBanner: View {
    let openSettings: () -> Void
    private let reminder = SigningExpiryReminder.shared

    var body: some View {
        if let expiry = reminder.expiry, expiry.isUrgent(now: .now) {
            Section {
                Button(action: openSettings) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expiry.settingsText).font(.headline)
                            Text(SigningExpiry.reinstallHint).font(.subheadline)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
}
