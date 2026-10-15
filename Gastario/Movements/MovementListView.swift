import GastarioCore
import SwiftData
import SwiftUI

/// Lista de solo lectura, agrupada por día en Panamá (SPEC Fase 0).
struct MovementListView: View {
    @Query(sort: \Movement.occurredAt, order: .reverse) private var movements: [Movement]

    var body: some View {
        NavigationStack {
            List {
                ForEach(MovementPresentation.groupedByDay(movements, date: \.occurredAt)) { group in
                    Section(MovementPresentation.dayTitle(group.day)) {
                        ForEach(group.items) { movement in
                            MovementRow(movement: movement)
                        }
                    }
                }
            }
            .overlay {
                if movements.isEmpty {
                    ContentUnavailableView("Sin movimientos", systemImage: "tray")
                }
            }
            .navigationTitle("Gastario")
            #if DEBUG
            .toolbar { DebugMenu() }
            #endif
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
