import SwiftUI
import CultFiveCore

/// « Comment marche l'Elo » : le départ à 500, le placement, la difficulté en haut, la correction, le bouclier, les niveaux.
struct EloExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Ton Elo").font(.cfDisplay).padding(.top, Space.l)
                Text("Une note par domaine, qui se gagne partie après partie. Plus tu montes, plus elle est dure à garder.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                step(1, "Tout le monde part de 500",
                     "Dans chaque domaine, ton Elo part de 500. Pendant le placement, il peut gagner jusqu'à 150 points par partie : 800 au plus à la fin. Ensuite, +30 au plus par partie.") {
                    Text("500")
                        .font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.brand)
                }
                step(2, "20 réponses de placement",
                     "Chaque réponse classée du domaine remplit la barre, en partie de domaine comme en partie rapide. À 20, ton rang se dévoile.") {
                    PlacementBar(answered: 7, color: .brand, width: 64)
                }
                step(3, "Plus dur tout en haut",
                     "Au-dessus de 1 000, une victoire rapporte moins et une erreur coûte plus. Dès 1 200, les questions piquent davantage et une mauvaise partie peut coûter 80 points.") {
                    Image(systemName: "mountain.2.fill").font(.largeTitle).foregroundStyle(Color.brand)
                }
                step(4, "Seules les parties classées comptent",
                     "Une partie classée couvre tout le domaine. L'entraînement libre, les thèmes choisis et « Mes erreurs » ne changent pas ton Elo.") {
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Color.sun)
                }
                step(5, "Corrige tes erreurs",
                     "Après une partie, rejoue tes questions ratées : chaque bonne correction te rend l'Elo perdu, sans jamais dépasser ton Elo d'avant.") {
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.largeTitle).foregroundStyle(Color.brand)
                }
                step(6, "Le bouclier",
                     "Active-le avant de répondre (15 neurones ou un ticket) : si tu te trompes, tu as un 2e essai, pour la moitié des points. Il est consommé même si tu réponds juste.") {
                    Image(systemName: "shield.fill").font(.largeTitle).foregroundStyle(Color.sun)
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Les niveaux").font(.cfHeadline)
                    ForEach(CoteCULT.Rank.allCases.reversed(), id: \.self) { rank in
                        HStack {
                            RankEmblem(rank: rank).frame(width: 36, height: 36).accessibilityHidden(true)
                            Text(rank.name).font(.cfCallout.weight(.bold)).foregroundStyle(Color.ink)
                            Spacer()
                            Text(rank == .curious ? "moins de 600" : "dès \(CoteCULT.format(rank.floor))")
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
