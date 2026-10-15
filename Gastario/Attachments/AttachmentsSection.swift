import GastarioCore
import PhotosUI
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Adjuntos de un movimiento: foto, PDF, link o QR de factura (SPEC Fase 6). Vive solo en el
/// detalle: el camino de captura no sabe que existen (principio 4).
struct AttachmentsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    let movement: Movement

    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingPDFImporter = false
    @State private var showingLinkPrompt = false
    @State private var linkText = ""
    @State private var showingScanner = false
    @State private var previewURL: URL?
    @State private var errorMessage: String?
    @State private var working = false

    var body: some View {
        Section {
            ForEach(movement.attachments.sorted { $0.addedAt < $1.addedAt }) { attachment in
                Button { open(attachment) } label: {
                    AttachmentRow(attachment: attachment)
                }
                .swipeActions {
                    Button("Borrar", systemImage: "trash", role: .destructive) { delete(attachment) }
                }
            }
            Menu {
                Button("Foto de la galería", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Tomar foto", systemImage: "camera") { showingCamera = true }
                }
                Button("PDF", systemImage: "doc.richtext") { showingPDFImporter = true }
                Button("Link", systemImage: "link") {
                    linkText = ""
                    showingLinkPrompt = true
                }
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    Button("Escanear QR de factura", systemImage: "qrcode.viewfinder") { showingScanner = true }
                }
            } label: {
                if working {
                    ProgressView()
                } else {
                    Label("Agregar adjunto", systemImage: "paperclip")
                }
            }
            .disabled(working)
        } header: {
            Text("Adjuntos")
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await addPhoto(item) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                Task { await addCameraImage(image) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            addPDF(result)
        }
        .alert("Agregar link", isPresented: $showingLinkPrompt) {
            TextField("https://…", text: $linkText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancelar", role: .cancel) {}
            Button("Agregar") { addLink() }
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView { payload in
                showingScanner = false
                addQR(payload)
            }
            .ignoresSafeArea()
        }
        .alert(
            errorMessage ?? "",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .quickLookPreview($previewURL)
    }

    // MARK: - Agregar

    private func addPhoto(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "No se pudo leer la foto."
            return
        }
        await addImage(data)
    }

    private func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 1) else {
            errorMessage = "No se pudo leer la foto."
            return
        }
        working = true
        defer { working = false }
        await addImage(data)
    }

    /// Comprime fuera del main actor: una foto de 48 MP tarda.
    private func addImage(_ data: Data) async {
        let jpeg = await Task.detached { ImageCompressor.jpegData(from: data) }.value
        guard let jpeg else {
            errorMessage = "El archivo no es una imagen."
            return
        }
        insert(Attachment(kind: .image, data: jpeg, filename: "Foto-\(Self.stamp()).jpg"))
    }

    /// El PDF se copia tal cual (C8) dentro de la app; el original puede desaparecer.
    private func addPDF(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "No se pudo leer el PDF."
            return
        }
        insert(Attachment(kind: .pdf, data: data, filename: url.lastPathComponent))
    }

    private func addLink() {
        guard let url = AttachmentRules.link(from: linkText, allowMissingScheme: true) else {
            errorMessage = "Ese link no es válido. Usa una dirección http o https."
            return
        }
        insert(Attachment(kind: .link, url: url))
    }

    /// C7: un QR sin URL se rechaza.
    private func addQR(_ payload: String) {
        guard let url = AttachmentRules.link(from: payload) else {
            errorMessage = AttachmentRules.qrNotALinkMessage
            return
        }
        insert(Attachment(kind: .link, url: url, filename: "Factura electrónica"))
    }

    private func insert(_ attachment: Attachment) {
        movement.attachments.append(attachment)
        try? context.save()
    }

    // MARK: - Ver y borrar

    private func open(_ attachment: Attachment) {
        if let url = attachment.url {
            openURL(url)
            return
        }
        guard let data = attachment.data else { return }
        let name = attachment.filename ?? "\(attachment.id.uuidString).\(attachment.kind == .pdf ? "pdf" : "jpg")"
        let directory = FileManager.default.temporaryDirectory.appending(path: attachment.id.uuidString)
        let fileURL = directory.appending(path: name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            previewURL = fileURL
        } catch {
            errorMessage = "No se pudo abrir el adjunto."
        }
    }

    /// El archivo externo (`externalStorage`) se borra con el registro.
    private func delete(_ attachment: Attachment) {
        context.delete(attachment)
        try? context.save()
    }

    private static func stamp() -> String {
        var style = Date.VerbatimFormatStyle(
            format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
            timeZone: MovementPresentation.timeZone, calendar: Calendar(identifier: .gregorian))
        style.locale = Locale(identifier: "en_US_POSIX")
        return Date.now.formatted(style)
    }
}

private struct AttachmentRow: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var symbol: String {
        switch attachment.kind {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .link: "link"
        }
    }

    private var title: String {
        attachment.filename ?? attachment.url?.host() ?? "Adjunto"
    }

    private var subtitle: String {
        if let url = attachment.url { return url.absoluteString }
        let size = ByteCountFormatter.string(fromByteCount: Int64(attachment.data?.count ?? 0), countStyle: .file)
        return "\(size) · \(MovementPresentation.timestampText(attachment.addedAt))"
    }
}
