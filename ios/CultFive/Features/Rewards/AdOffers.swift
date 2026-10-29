import SwiftUI
import CultFiveCore

/// Pubs récompensées : toujours proposées, jamais imposées. La récompense vient du serveur, après la confirmation de
/// Google ; ces vues ne font qu'afficher l'offre et le résultat.

/// Carte « une pub pour… », avec son icône 3D.
struct AdOfferCard<Icon: View>: View {
    @ViewBuilder let icon: Icon
    let title: String
    let detail: String
    let button: String
    let action: () async -> Void

    @Environment(AppModel.self) private var app
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                icon.frame(width: 48, height: 48).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.cfHeadline).foregroundStyle(Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                Task {
                    busy = true
                    await action()
                    busy = false
                }
            } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().controlSize(.small) }
                    Label(app.noAds ? "Récupérer sans pub" : button, systemImage: app.adSymbol)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ink)
            .disabled(busy)
            PassPlusUpsell(origin: "ad_offer")
        }
        .popCard()
        .accessibilityElement(children: .contain)
    }
}

/// Un coffre en bois offert par jour contre une pub (il peut monter de rang à l'ouverture).
struct FreeChestOffer: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if (app.adStatus?.freeChest ?? 0) > 0 {
            AdOfferCard(icon: { ChestView(tier: .wood) }, title: "Coffre offert",
                        detail: app.noAds ? "Un coffre en bois par jour, offert sans pub. Il peut monter de rang à l'ouverture !"
                                          : "Un coffre en bois par jour contre une courte pub. Il peut monter de rang à l'ouverture !",
                        button: "Regarder une pub") {
                do {
                    guard let reward = try await app.watchAd(.freeChest), let id = reward.chestId else { return }
                    await app.refreshProgression()
                    app.openChests(app.progression?.chests.filter { $0.id == id })
                } catch {
                    app.show(error, "Pub indisponible pour l'instant.")
                }
            }
        }
    }
}

/// Série perdue depuis moins de 48 h : une pub la sauve (une fois par mois).
struct StreakRescueOffer: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let streak = app.adStatus?.streakRescue {
            AdOfferCard(icon: { GameIcon.flameOff.image }, title: "Sauve ta série de \(streak) jours",
                        detail: app.noAds ? "Tu l'as perdue il y a moins de 48 h. Sans pub, elle repart comme si de rien n'était. Une fois par mois."
                                          : "Tu l'as perdue il y a moins de 48 h. Une courte pub et elle repart, comme si de rien n'était. Une fois par mois.",
                        button: "Sauver ma série") {
                do {
                    guard let reward = try await app.watchAd(.streakRescue) else { return }
                    Haptics.success()
                    let days = reward.streak ?? streak
                    app.show("Série sauvée : \(days) jour\(days > 1 ? "s" : "") !")
                    await app.refreshDaily()
                } catch {
                    app.show(error, "Pub indisponible pour l'instant.")
                }
            }
        }
    }
}

/// « Doubler mes graines » en fin de partie : proposé seulement si le serveur l'accepte (partie de moins d'1 h,
/// graines gagnées, pas déjà doublée, 3 par jour).
struct DoubleSeedsButton: View {
    /// « play:<id> » ou « daily:<id> ».
    let ref: String
    var onInk = false

    @Environment(AppModel.self) private var app
    @State private var available = false
    @State private var busy = false
    @State private var gained: Int?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let gained {
                Label("+\(Brand.currency(gained)) \(app.noAds ? "sans pub" : "grâce à la pub")", systemImage: "checkmark.circle.fill")
                    .font(.cfCallout.weight(.bold))
                    .foregroundStyle(onInk ? Color.sun : Color.correct)
                    .transition(.scale.combined(with: .opacity))
            } else if available {
                Button { Task { await run() } } label: {
                    HStack(spacing: 8) {
                        if busy { ProgressView().controlSize(.small) }
                        Label("Doubler mes neurones", systemImage: app.adSymbol)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(onInk ? InkButtonStyle.sun : InkButtonStyle.ink)
                .disabled(busy)
            }
            if let error {
                Text(error).font(.cfFootnote).foregroundStyle(onInk ? Color.white.opacity(0.8) : Color.wrong)
            }
        }
        .task(id: ref) {
            available = (try? await app.service.adCan(.doubleSeeds, ref: ref)) != nil
        }
    }

    private func run() async {
        busy = true
        defer { busy = false }
        error = nil
        do {
            guard let reward = try await app.watchAd(.doubleSeeds, ref: ref) else { return }
            Haptics.success()
            withAnimation(Motion.bounce) { gained = reward.seeds ?? 0 }
        } catch {
            self.error = error.userMessage("Pub indisponible pour l'instant.")
        }
    }
}

/// Petit lien sous une offre de pub : « Retirer les pubs » (ouvre la boutique ; rien si les pubs sont déjà retirées).
struct PassPlusUpsell: View {
    let origin: String
    var onInk = false

    @Environment(AppModel.self) private var app

    var body: some View {
        if !app.noAds && app.api != nil {
            Button {
                Haptics.selection()
                app.openShop(from: origin)
            } label: {
                Label("Retirer les pubs", systemImage: "nosign")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(onInk ? Color.sun : Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
        }
    }
}
