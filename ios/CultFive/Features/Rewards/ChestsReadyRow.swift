import SwiftUI
import CultFiveCore

/// « 3 coffres à ouvrir » sur l'accueil (D-074) : le plus beau coffre en attente, le nombre, et un bouton qui les
/// ouvre tous à la suite. Rien quand le sac est vide.
struct ChestsReadyRow: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let chests = app.progression?.chests ?? []
        if !chests.isEmpty {
            let best = chests.map(\.tier).max { rank($0) < rank($1) } ?? .wood
            Button { app.openChests() } label: {
                HStack(spacing: 12) {
                    ChestView(tier: best).frame(width: 44, height: 44)
                    Text(chests.count > 1 ? "\(chests.count) coffres à ouvrir" : "1 coffre à ouvrir")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(Color.ink)
                    Spacer(minLength: 4)
                    Text("Ouvrir")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(Color(hex: 0x1E1340))
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .background(Color.sun, in: Capsule())
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
            .buttonStyle(.row)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chests.count > 1 ? "\(chests.count) coffres à ouvrir" : "1 coffre à ouvrir")
            .accessibilityHint("Les ouvre à la suite")
        }
    }

    private func rank(_ tier: ChestTier) -> Int { ChestTier.allCases.firstIndex(of: tier) ?? 0 }
}
