import GastarioCore
import SwiftData
import SwiftUI
import UserNotifications

/// Lista agrupada por día en Panamá, con resumen del mes, filtros, entrada manual y borrado
/// (SPEC Fase 4).
struct MovementListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Movement.occurredAt, order: .reverse) private var movements: [Movement]
    @State private var filter: MovementFilter = .all
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @State private var pendingDeletion: Movement?
    @State private var path: [Movement] = []
    private let router = NotificationRouter.shared

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Fase 7b (C18): con menos de 48 h para que venza la firma.
                SigningExpiryBanner { showingSettings = true }
                Section {
                    MonthlySummaryView(movements: movements)
                }
                Section {
                    Picker("Filtro", selection: $filter) {
                        ForEach(MovementFilter.allCases) { filter in
                            Text("\(filter.title) (\(count(filter)))").tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                let visible = movements.filter(matchesFilter)
                if visible.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: "tray")
                        .listRowBackground(Color.clear)
                }
                ForEach(MovementPresentation.groupedByDay(visible, date: \.occurredAt)) { group in
                    Section(MovementPresentation.dayTitle(group.day)) {
                        ForEach(group.items) { movement in
                            NavigationLink(value: movement) {
                                MovementRow(movement: movement)
                            }
                            .swipeActions {
                                Button("Borrar", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = movement
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gastario")
            .navigationDestination(for: Movement.self) { movement in
                MovementDetailView(movement: movement)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ajustes", systemImage: "gearshape") { showingSettings = true }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    DebugMenu()
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button("Agregar", systemImage: "plus") { showingManualEntry = true }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .confirmationDialog(
                "¿Borrar este movimiento?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { movement in
                Button("Borrar", role: .destructive) { delete(movement) }
            } message: { _ in
                Text("También se borran sus adjuntos. No se puede deshacer.")
            }
        }
        .task(id: router.movementToOpen) { openFromNotification() }
    }

    /// C15: reemplaza la navegación por el detalle del movimiento tocado y cierra lo que esté
    /// abierto encima de la lista.
    private func openFromNotification() {
        guard let id = router.movementToOpen else { return }
        router.movementToOpen = nil
        var descriptor = FetchDescriptor<Movement>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let movement = try? context.fetch(descriptor).first else { return }
        showingManualEntry = false
        showingSettings = false
        pendingDeletion = nil
        router.noteToEdit = movement.id
        path = [movement]
    }

    private func matchesFilter(_ movement: Movement) -> Bool {
        filter.matches(hasNote: movement.hasNote, status: movement.parseStatus)
    }

    private func count(_ filter: MovementFilter) -> Int {
        movements.count { filter.matches(hasNote: $0.hasNote, status: $0.parseStatus) }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "Sin movimientos"
        case .noNote: "Todo tiene nota"
        case .needsReview: "Nada que revisar"
        }
    }

    /// AC-15: la cascada borra los adjuntos. La notificación ya entregada se retira para que no
    /// quede una pregunta sobre un movimiento que no existe.
    private func delete(_ movement: Movement) {
        let id = movement.id.uuidString
        // Bitácora (Fase 7a): distingue "lo borré" de "se perdió".
        SharedCaptureLog.log.record(.deleted(movement, from: .list))
        context.delete(movement)
        try? context.save()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}

/// Totales del mes en curso en Panamá: salidas, entradas y neto (SPEC §2, C9).
struct MonthlySummaryView: View {
    let movements: [Movement]

    var body: some View {
        let now = Date.now
        let summary = MovementPresentation.monthlySummary(
            movements, containing: now, amount: \.amount, direction: \.direction, occurredAt: \.occurredAt)
        VStack(alignment: .leading, spacing: 8) {
            Text(MovementPresentation.monthTitle(now))
                .font(.headline)
            HStack(alignment: .firstTextBaseline) {
                total("Salidas", summary.outflow, color: .primary)
                Spacer()
                total("Entradas", summary.inflow, color: .green)
                Spacer()
                total("Neto", summary.net, color: summary.net < 0 ? .red : .green)
            }
        }
        .padding(.vertical, 4)
    }

    private func total(_ title: String, _ amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(MovementPresentation.currencyText(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

struct MovementRow: View {
    let movement: Movement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(movement.counterparty ?? "Sin contraparte")
                    .foregroundStyle(movement.counterparty == nil ? .secondary : .primary)
                HStack(spacing: 6) {
                    if !movement.hasNote {
                        Label("Sin nota", systemImage: "text.bubble")
                            .foregroundStyle(.orange)
                    }
                    if movement.needsReview {
                        Label("Requiere revisión", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            }
            Spacer()
            Text(MovementPresentation.amountText(for: movement))
                .monospacedDigit()
                .foregroundStyle(movement.direction == .inflow ? Color.green : Color.primary)
        }
    }

    private var sourceSymbol: String {
        switch movement.source {
        case .card: "creditcard"
        case .yappy: "iphone.gen3"
        case .manual: "pencil"
        }
    }
}
