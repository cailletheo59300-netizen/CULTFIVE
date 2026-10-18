import SwiftUI
import CultFiveCore

/// « Mon sac » : tout ce que le joueur possède, au même endroit. Graines, tickets d'aide, jokers de série,
/// coffres à ouvrir et objets de Léon. S'ouvre depuis les graines de la barre du haut.
struct BagView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var progression: ProgressionOverview? { app.progression }
    private var seeds: Int { app.profile?.seeds ?? progression?.seeds ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    seedsCard
                    section("Tickets d'aide")
                    row(icon: GameIcon.ticketFifty.image, title: "Ticket 50/50", detail: "Retire deux mauvaises réponses, sans neurones",
                        value: "\(min(progression?.tickets.fiftyFifty ?? 0, 5))/5")
                    row(icon: GameIcon.ticketHint.image, title: "Ticket indice", detail: "Un indice ou une seconde chance, sans neurones",
                        value: "\(min(progression?.tickets.hint ?? 0, 5))/5")
                    section("Série")
                    row(icon: GameIcon.joker.image, title: "Jokers de série", detail: "Sauvent ta série si tu rates un jour (2 au plus)",
                        value: "\(app.profile?.streakFreezes ?? progression?.streakFreezes ?? 0)/2")
                    if let chests = progression?.chests, !chests.isEmpty {
                        section("À ouvrir")
                        chestsRow(chests)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .background(Color.paper)
            .navigationTitle("Mon sac")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { CloseCircle() }
                        .accessibilityLabel("Fermer")
                }
            }
            .task { await app.refreshProfile() }
        }
    }

    private var seedsCard: some View {
        HStack(spacing: 14) {
            SeedIcon().frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(seeds) \(seeds > 1 ? Brand.currencyPlural : Brand.currencySingular)")
                    .font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("Pour les aides en partie et l'album")
                    .font(.cfFootnote).foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
        .padding(.top, Space.s)
    }

    private func section(_ title: String) -> some View {
        Text(title).labelCaps().padding(.top, 8).padding(.horizontal, 4)
    }

    private func row(icon: some View, title: String, detail: String, value: String) -> some View {
        HStack(spacing: 14) {
            icon.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cfHeadline).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(value).font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(Color.ink)
        }
        .popCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func chestsRow(_ chests: [ChestRef]) -> some View {
        let best = chests.map(\.tier).max { $0.rank < $1.rank } ?? .wood
        return HStack(spacing: 14) {
            ChestView(tier: best).frame(width: 56, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(chests.count > 1 ? "\(chests.count) coffres" : "1 coffre").font(.cfHeadline).foregroundStyle(Color.ink)
                Text("Neurones, tickets, jokers, cartes de l'album…").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            Spacer(minLength: 0)
            Button("Ouvrir") {
                dismiss()
                // Les coffres s'ouvrent en plein écran depuis l'app : on ferme d'abord le sac.
                Task {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    app.openChests()
                }
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).frame(minHeight: 40)
            .background(Color.brand, in: Capsule())
        }
        .popCard(padding: 14)
    }
}
