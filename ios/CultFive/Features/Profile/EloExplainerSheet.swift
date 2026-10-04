import SwiftUI
import CultFiveCore

/// « Comment marche l'Elo » : le départ à 1000, l'Elo provisoire, la correction, le bouclier, les niveaux.
struct EloExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Ton Elo").font(.cfDisplay).padding(.top, Space.l)
                Text("Une note par domaine, qui monte quand tu réussis des questions de ton niveau ou plus dures.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                step(1, "Tout le monde part de 1000",
                     "Ton Elo s'affiche dès ta 1re partie classée. Il bouge vite au début pour te trouver ta place (jusqu'à 120 points par partie), puis 40 points au plus.") {
                    Text("1000")
                        .font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.brand)
                }
                step(2, "Provisoire pendant 5 parties",
                     "Dans chaque domaine, chaque partie classée remplit un carré. Au 5e, ton Elo est confirmé et ton niveau se dévoile.") {
                    PlacementSquares(done: 3, color: .brand, size: 12)
                }
                step(3, "Seules les parties classées comptent",
                     "Une partie classée couvre tout le domaine. L'entraînement libre, les thèmes choisis et « Mes erreurs » ne changent pas ton Elo.") {
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Color.sun)
                }
                step(4, "Corrige tes erreurs",
                     "Après une partie, rejoue tes questions ratées : chaque bonne correction te rend l'Elo perdu, sans jamais dépasser ton niveau d'avant.") {
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.largeTitle).foregroundStyle(Color.brand)
                }
                step(5, "Le bouclier",
                     "Active-le avant de répondre (15 graines ou un ticket) : si tu te trompes, tu as un 2e essai, pour la moitié des points. Il est consommé même si tu réponds juste.") {
                    Image(systemName: "shield.fill").font(.largeTitle).foregroundStyle(Color.sun)
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Les niveaux").font(.cfHeadline)
                    ForEach(CoteCULT.Rank.allCases.reversed(), id: \.self) { rank in
                        HStack {
                            RankEmblem(rank: rank).frame(width: 36, height: 36).accessibilityHidden(true)
                            Text(rank.name).font(.cfCallout.weight(.bold)).foregroundStyle(Color.ink)
                            Spacer()
                            Text(rank == .curious ? "moins de 900" : "dès \(CoteCULT.format(rank.floor))")
                                .font(.cfFootnote).monospacedDigit().foregroundStyle(Color.inkSoft)
                        }
                    }
                }
                .popCard()

                Button("C'est compris") { dismiss() }.buttonStyle(.ink).padding(.top, Space.s)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .background(Color.paper)
        .presentationDragIndicator(.visible)
    }

    private func step<Art: View>(_ number: Int, _ title: String, _ detail: String, @ViewBuilder art: () -> Art) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            art().frame(width: 76, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(number). \(title)").font(.cfTitle3).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
