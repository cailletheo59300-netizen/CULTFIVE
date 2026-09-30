import SwiftUI
import CultFiveCore

/// « Comment marche l'Elo » : le placement en 5 parties, le départ à 1000, les rangs.
struct EloExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Ton Elo").font(.cfDisplay).padding(.top, Space.l)
                Text("Une note par domaine, qui monte quand tu réussis des questions de ton niveau ou plus dures.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                step(1, "5 parties pour ton rang",
                     "Dans chaque domaine, joue 5 parties classées (10 questions chacune). Chaque partie remplit un carré ; au 5e, ton rang se dévoile.") {
                    PlacementSquares(done: 3, color: .brand, size: 12)
                }
                step(2, "Tout le monde part de 1000",
                     "Pendant le placement, ton Elo bouge vite pour te trouver ta place (jusqu'à 120 points par partie). Ensuite, 40 points au plus par partie.") {
                    Text("1000")
                        .font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.brand)
                }
                step(3, "Seules les parties classées comptent",
                     "Une partie classée couvre tout le domaine. L'entraînement libre, les thèmes choisis et « Mes erreurs » ne changent pas ton Elo.") {
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Color.sun)
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Les rangs").font(.cfHeadline)
                    ForEach(CoteCULT.Rank.allCases.reversed(), id: \.self) { rank in
                        HStack {
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
