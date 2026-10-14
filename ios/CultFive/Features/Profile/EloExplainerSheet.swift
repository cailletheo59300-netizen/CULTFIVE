import SwiftUI
import CultFiveCore

/// « Comment marche l'Elo » : le départ à 500, le placement, la correction, le bouclier, les niveaux.
struct EloExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Ton Elo").font(.cfDisplay).padding(.top, Space.l)
                Text("Une note par domaine, qui monte quand tu réussis des questions de ton niveau ou plus dures.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                step(1, "Tout le monde part de 500",
                     "Dans chaque domaine, ton Elo part de 500 et monte vers ton vrai niveau pendant tes 2 premières parties classées (20 réponses). Ensuite, il bouge de 40 points au plus par partie.") {
                    Text("500")
                        .font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.brand)
                }
                step(2, "2 parties de placement",
                     "Chaque partie classée du domaine remplit un carré ; les parties rapides comptent aussi, question par question. Au 2e, ton Elo a rejoint ton vrai niveau et ton rang se dévoile.") {
                    PlacementSquares(done: 1, color: .brand, size: 12)
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
