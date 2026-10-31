import Foundation
import Testing
@testable import GastarioCore

/// SPEC Fase 7b (C18): fecha de vencimiento del perfil y cuándo avisar.
struct SigningExpiryTests {
    private static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    /// Imita `embedded.mobileprovision`: bytes DER de la firma CMS, el plist en claro y más DER.
    private static func profile(plist: String) -> Data {
        var data = Data([0x30, 0x82, 0x0B, 0x3C, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02, 0xA0])
        data.append(Data(plist.utf8))
        data.append(Data([0xA0, 0x82, 0x03, 0x3C, 0x30, 0x82, 0x00, 0xFF]))
        return data
    }

    private static func plist(_ body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \(body)
        </dict>
        </plist>
        """
    }

    @Test func leeLaFechaDelPerfil() {
        let data = Self.profile(plist: Self.plist("""
            <key>AppIDName</key><string>XC com renandiaz Gastario</string>
            <key>CreationDate</key><date>2026-10-22T23:02:11Z</date>
            <key>ExpirationDate</key><date>2026-10-29T23:02:11Z</date>
            <key>Name</key><string>iOS Team Provisioning Profile: com.renandiaz.Gastario</string>
            """))
        #expect(ProvisioningProfile.expirationDate(fromProfile: data) == Self.date("2026-10-29T23:02:11Z"))
    }

    @Test(arguments: [
        "sin xml",
        "sin cierre",
        "sin fecha",
        "fecha como texto",
        "vacío",
    ])
    func perfilIlegibleEsNil(caso: String) {
        let data: Data = switch caso {
        case "sin xml":
            Self.profile(plist: "<plist><dict><key>ExpirationDate</key><date>2026-10-29T23:02:11Z</date></dict></plist>")
        case "sin cierre":
            Self.profile(plist: "<?xml version=\"1.0\"?><plist><dict><key>ExpirationDate</key><date>2026-10-29T23:02:11Z</date></dict>")
        case "sin fecha":
            Self.profile(plist: Self.plist("<key>Name</key><string>Perfil</string>"))
        case "fecha como texto":
            Self.profile(plist: Self.plist("<key>ExpirationDate</key><string>2026-10-29</string>"))
        default:
            Data()
        }
        #expect(ProvisioningProfile.expirationDate(fromProfile: data) == nil)
    }

    @Test func urgenteConMenosDe48Horas() {
        let now = Self.date("2026-10-31T12:00:00Z")
        let hour: TimeInterval = 60 * 60
        #expect(SigningExpiry(expiresAt: now.addingTimeInterval(48 * hour - 60)).isUrgent(now: now))
        #expect(!SigningExpiry(expiresAt: now.addingTimeInterval(48 * hour)).isUrgent(now: now))
        #expect(SigningExpiry(expiresAt: now.addingTimeInterval(-hour)).isUrgent(now: now))
    }

    @Test func avisoUnDiaAntes() {
        let now = Self.date("2026-10-31T12:00:00Z")
        let expiry = SigningExpiry(expiresAt: Self.date("2026-11-03T12:00:00Z"))
        #expect(expiry.reminderDate(now: now) == Self.date("2026-11-02T12:00:00Z"))
    }

    /// Con menos de 24 h ya pasó la hora del aviso: no se programa uno atrasado.
    @Test func sinAvisoAtrasado() {
        let now = Self.date("2026-10-31T12:00:00Z")
        let expiry = SigningExpiry(expiresAt: Self.date("2026-11-01T11:00:00Z"))
        #expect(expiry.reminderDate(now: now) == nil)
    }

    /// 03:30 del 5/11 en UTC es el 4/11 a las 10:30 p. m. en Panamá.
    @Test func textosEnPanama() {
        let expiry = SigningExpiry(expiresAt: Self.date("2026-11-05T03:30:00Z"))
        #expect(expiry.settingsText.hasPrefix("La app vence el 4 nov"))
        #expect(expiry.settingsText.contains("10:30"))
        #expect(expiry.reminderBody.hasPrefix("Vence el 4 nov"))
        #expect(expiry.reminderBody.hasSuffix(": reinstálala desde Xcode para no perder capturas."))
    }
}
