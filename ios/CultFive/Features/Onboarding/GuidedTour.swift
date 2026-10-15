import SwiftUI

/// Visites guidées : à la première visite d'un écran (5 du jour, Jouer, Album, Pass, Amis), Léon explique en quelques
/// étapes à quoi il sert. On peut passer, et la revoir avec le bouton « ? » de l'écran. Vue une fois par appareil.
enum TourID: String, CaseIterable {
    case daily, play, album, pass, friends

    struct Step {
        let title: String
        let text: String
        let symbol: String
    }

    var steps: [Step] {
        switch self {
        case .daily:
            return [
                Step(title: "Le 5 du jour", text: "Chaque jour, 5 questions : calcul, français, géographie, histoire et une surprise. Les mêmes pour tout le monde.",
                     symbol: "5.circle.fill"),
                Step(title: "Ta série", text: "Elle monte chaque jour où tu fais le 5 du jour. Un joker la protège si tu oublies un jour.",
                     symbol: "flame.fill"),
                Step(title: "Les défis", text: "Les défis du jour, de la semaine et de la saison rapportent des neurones et des points de pass. Touche un défi pour aller le faire.",
                     symbol: "checklist"),
                Step(title: "Ton sac", text: "En haut, le sac garde tes neurones, tes tickets, tes jokers et tes coffres à ouvrir.",
                     symbol: "bag.fill"),
            ]
        case .play:
            return [
                Step(title: "Partie rapide", text: "10 questions de tous les domaines, pour jouer tout de suite.",
                     symbol: "bolt.fill"),
                Step(title: "Par domaine", text: "Touche un domaine : partie classée (ton Elo bouge) ou entraînement (rien ne bouge, tu choisis les thèmes).",
                     symbol: "square.grid.3x3.fill"),
                Step(title: "Ton Elo", text: "Un Elo par domaine. Les 20 premières réponses servent à te placer, ensuite il monte quand tu réussis des questions difficiles.",
                     symbol: "chart.line.uptrend.xyaxis"),
                Step(title: "Tes erreurs", text: "« Revoir mes erreurs » te repose les questions ratées pour que tu les retiennes.",
                     symbol: "arrow.uturn.backward"),
            ]
        case .album:
            return [
                Step(title: "Ton album", text: "Des centaines de cartes à collectionner, rangées par domaine et par page.",
                     symbol: "books.vertical.fill"),
                Step(title: "Domaines et pages", text: "Les onglets de couleur changent de domaine, ceux du dessus changent de page. Glisse pour tourner les feuillets.",
                     symbol: "rectangle.stack.fill"),
                Step(title: "Les filtres", text: "Montre seulement les cartes qui te manquent, celles que tu as, les brillantes, ou une rareté.",
                     symbol: "line.3.horizontal.decrease.circle.fill"),
                Step(title: "Comptoir et pass", text: "Le Comptoir vend des pochettes (neurones ou tickets). Le pass donne des récompenses en jouant.",
                     symbol: "ticket.fill"),
                Step(title: "La légende", text: "Touche les couleurs sous le classeur pour comprendre les cases, les raretés et les états des cartes.",
                     symbol: "info.circle.fill"),
            ]
        case .pass:
            return [
                Step(title: "Le pass de saison", text: "Tes défis te donnent des points. Chaque palier atteint débloque une récompense.",
                     symbol: "flag.checkered"),
                Step(title: "Deux pistes", text: "La piste gratuite est pour tout le monde. La piste Pass+ (payante, pour la saison) enlève toutes les pubs et ajoute des récompenses.",
                     symbol: "crown.fill"),
                Step(title: "Récupérer", text: "Touche un palier atteint pour prendre sa récompense. Après le palier 30, des coffres en plus.",
                     symbol: "gift.fill"),
            ]
        case .friends:
            return [
                Step(title: "Tes amis", text: "Ajoute tes amis avec leur pseudo ou un lien d'invitation.",
                     symbol: "person.2.fill"),
                Step(title: "Les duels", text: "Les mêmes questions pour vous deux : le meilleur score gagne.",
                     symbol: "bolt.horizontal.fill"),
                Step(title: "Les ligues", text: "Un classement entre amis : crée une ligue ou rejoins-en une avec son code.",
                     symbol: "trophy.fill"),
            ]
        }
    }
}

@MainActor
@Observable
final class TourCenter {
    static let shared = TourCenter()

    private(set) var active: TourID?
    var step = 0

    /// Pas de visite pendant les captures d'écran automatiques (mode démo lancé sur un écran précis).
    private var disabled: Bool { ProcessInfo.processInfo.arguments.contains("-demoScreen") }

    private func key(_ id: TourID) -> String { "tour.seen.\(id.rawValue)" }

    /// Première visite de l'écran : la visite démarre (un instant après, le temps que l'écran s'installe).
    func firstVisit(_ id: TourID) {
        guard !disabled, !UserDefaults.standard.bool(forKey: key(id)) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard active == nil, !UserDefaults.standard.bool(forKey: key(id)) else { return }
            start(id)
        }
    }

    /// Bouton « ? » : revoir la visite.
    func start(_ id: TourID) {
        step = 0
        withAnimation(Motion.standard) { active = id }
    }

    func next() {
        guard let active else { return }
        if step + 1 < active.steps.count {
            withAnimation(Motion.standard) { step += 1 }
        } else {
            finish()
        }
    }

    func finish() {
        if let active { UserDefaults.standard.set(true, forKey: key(active)) }
        withAnimation(Motion.standard) { active = nil }
    }
}

extension View {
    /// Lance la visite guidée de cet écran à sa première apparition.
    func guidedTour(_ id: TourID) -> some View {
        onAppear { TourCenter.shared.firstVisit(id) }
    }
}

/// Le petit « ? » d'un écran : revoir sa visite guidée.
struct TourButton: View {
    let id: TourID
    var tint: Color = .brand

    var body: some View {
        Button {
            Haptics.selection()
            TourCenter.shared.start(id)
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Aide : revoir la visite de cet écran")
    }
}

/// La visite en cours, par-dessus l'écran : Léon, l'étape, « Passer » et « Suivant ».
struct TourOverlay: View {
    @State private var tours = TourCenter.shared

    var body: some View {
        if let id = tours.active {
            let steps = id.steps
            let step = steps[min(tours.step, steps.count - 1)]
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { tours.next() }
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(alignment: .center, spacing: Space.m) {
                        Leon(color: .brand, pose: tours.step == 0 ? .wave : .curious, curl: 0.4)
                            .frame(width: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Label(step.title, systemImage: step.symbol)
                                .font(.cfHeadline)
                                .foregroundStyle(Color.brand)
                            Text(step.text)
                                .font(.cfBody)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .id(tours.step)
                    .transition(.opacity)
                    HStack(spacing: Space.s) {
                        HStack(spacing: 5) {
                            ForEach(steps.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == tours.step ? Color.brand : Color.hairline)
                                    .frame(width: i == tours.step ? 16 : 6, height: 6)
                            }
                        }
                        .accessibilityLabel("Étape \(tours.step + 1) sur \(steps.count)")
                        Spacer(minLength: Space.s)
                        if tours.step + 1 < steps.count {
                            Button("Passer") { tours.finish() }
                                .buttonStyle(.textLink)
                        }
                        Button(tours.step + 1 < steps.count ? "Suivant" : "C'est compris !") { tours.next() }
                            .buttonStyle(.sun)
                            .fixedSize()
                    }
                }
                .padding(Space.l)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
                .padding(.horizontal, Space.m)
                .padding(.bottom, Space.xl)
            }
            .transition(.opacity)
            .accessibilityAddTraits(.isModal)
        }
    }
}
