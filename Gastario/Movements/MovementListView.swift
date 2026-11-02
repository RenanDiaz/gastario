import GastarioCore
import SwiftData
import SwiftUI
import UserNotifications

/// Lista agrupada por día en Panamá, con resumen del mes, filtros, entrada manual y borrado
/// (SPEC Fase 4), más búsqueda y período (Fase 4a).
struct MovementListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Movement.occurredAt, order: .reverse) private var movements: [Movement]
    @State private var filter: MovementFilter = .all
    // Fase 4a: no se persisten; al relanzar, "Todo" y sin búsqueda.
    @State private var searchText = ""
    @State private var period: DatePeriod = .all
    @State private var showingRangeSheet = false
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @State private var pendingDeletion: Movement?
    @State private var path: [Movement] = []
    private let router = NotificationRouter.shared

    var body: some View {
        NavigationStack(path: $path) {
            // Período y búsqueda definen lo que estoy viendo; el segmentado filtra encima y sus
            // cuentas son sobre esto (Fase 4a).
            let now = Date.now
            let search = MovementSearch(text: searchText)
            let scoped = movements.filter { inScope($0, search: search, now: now) }
            let visible = scoped.filter(matchesFilter)
            List {
                // Fase 7b (C18): con menos de 48 h para que venza la firma.
                SigningExpiryBanner { showingSettings = true }
                Section {
                    SummaryView(movements: movements, period: period, now: now)
                }
                Section {
                    Picker("Filtro", selection: $filter) {
                        ForEach(MovementFilter.allCases) { filter in
                            Text("\(filter.title) (\(count(filter, in: scoped)))").tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if !search.isEmpty && !visible.isEmpty {
                    Section {
                        SearchTotalsView(movements: visible)
                    }
                }
                if visible.isEmpty {
                    Group {
                        if search.isEmpty {
                            ContentUnavailableView(emptyTitle(scopeIsEmpty: scoped.isEmpty), systemImage: "tray")
                        } else {
                            ContentUnavailableView.search(text: searchText.trimmingCharacters(in: .whitespaces))
                        }
                    }
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
            .searchable(text: $searchText, prompt: "Comercio, nota o monto")
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
                ToolbarItem(placement: .topBarTrailing) {
                    periodMenu
                }
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
            .sheet(isPresented: $showingRangeSheet) {
                DateRangeSheet(current: period) { period = $0 }
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

    /// Menú de período. El ícono se rellena cuando no es "Todo"; el resumen dice cuál es.
    private var periodMenu: some View {
        Menu {
            Picker("Período", selection: Binding(
                get: { period.kind },
                set: { kind in
                    switch kind {
                    case .all: period = .all
                    case .thisMonth: period = .thisMonth
                    case .previousMonth: period = .previousMonth
                    case .range: showingRangeSheet = true
                    }
                })
            ) {
                ForEach(DatePeriod.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Período", systemImage: period == .all ? "calendar" : "calendar.badge.checkmark")
        }
    }

    private func inScope(_ movement: Movement, search: MovementSearch, now: Date) -> Bool {
        period.contains(movement.occurredAt, now: now)
            && search.matches(
                fields: [
                    movement.counterparty, movement.note, movement.yappyMessage,
                    movement.cardName, movement.city,
                ],
                amount: movement.amount)
    }

    private func matchesFilter(_ movement: Movement) -> Bool {
        filter.matches(hasNote: movement.hasNote, status: movement.parseStatus)
    }

    private func count(_ filter: MovementFilter, in scoped: [Movement]) -> Int {
        scoped.count { filter.matches(hasNote: $0.hasNote, status: $0.parseStatus) }
    }

    private func emptyTitle(scopeIsEmpty: Bool) -> String {
        if scopeIsEmpty && period != .all { return "Sin movimientos en este período" }
        return switch filter {
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

/// Salidas, entradas y neto del período (C19). Con "Todo", el mes en curso en Panamá (C9). La
/// búsqueda y el segmentado no lo cambian: recibe todos los movimientos.
struct SummaryView: View {
    let movements: [Movement]
    let period: DatePeriod
    let now: Date

    var body: some View {
        let shown = period == .all ? DatePeriod.thisMonth : period
        let summary = shown.interval(now: now).map {
            MovementPresentation.summary(
                movements, in: $0, amount: \.amount, direction: \.direction, occurredAt: \.occurredAt)
        } ?? MonthlySummary()
        VStack(alignment: .leading, spacing: 8) {
            Text(shown.title(now: now))
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

/// Totales de lo visible con búsqueda activa (Fase 4a): "¿cuánto gasté en Super 99?".
struct SearchTotalsView: View {
    let movements: [Movement]

    var body: some View {
        let totals = MovementPresentation.totals(movements, amount: \.amount, direction: \.direction)
        let count = movements.count == 1 ? "1 movimiento" : "\(movements.count) movimientos"
        Text("\(count) · Salidas \(MovementPresentation.currencyText(totals.outflow)) · Entradas \(MovementPresentation.currencyText(totals.inflow))")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
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
