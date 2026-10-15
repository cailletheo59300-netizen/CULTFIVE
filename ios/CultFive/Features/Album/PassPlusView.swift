import SwiftUI
import CultFiveCore

/// Écran du Pass+ : d'abord « plus de pub pendant toute la saison », ensuite la piste payante du pass.
/// Paiement unique pour la saison en cours (abonnement non renouvelable) : rien ne se renouvelle tout seul.
struct PassPlusView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store = AlbumStore.shared

    private var passPlus: PassPlusStore { app.passPlus }
    private var active: Bool { app.noAds || store.passPlusActive }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                noAdsCard
                trackCard
                buyArea
                legal
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
        }
        .background(Color.paper.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(Space.m)
        }
        .task {
            await passPlus.loadProduct()
            await store.refresh()
        }
    }

    // MARK: - En-tête

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            TrackBadge(paid: true)
            Text("Pass+")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(seasonLine)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.sun)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .background(PassPlusFill(), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(CardRarity.legend.border, lineWidth: 2))
        .shadow(color: Color(hex: 0x2A1490).opacity(0.3), radius: 16, y: 8)
    }

    private var seasonLine: String {
        guard let season = store.season.season else { return "Pour toute une saison" }
        return "\(season.name) · jusqu'au \(Self.day(season.endsOn))"
    }

    /// « 28 mars » à partir de « 2027-03-28 ».
    static func day(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "fr_FR")
        output.dateFormat = "d MMMM"
        return output.string(from: date)
    }

    // MARK: - Plus de pub (l'essentiel)

    private var noAdsCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                Image(systemName: "nosign")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color.brand)
                    .frame(width: 56, height: 56)
                    .background(Color.brand.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plus aucune pub")
                        .font(.cfHeadline).foregroundStyle(Color.ink)
                    Text("Pendant toute la saison")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
            }
            benefit("Plus de pub entre les parties.")
            benefit("Tous les bonus sans vidéo : pochette gratuite, neurones doublés, coffre offert, coffre boosté, « Corrige tes erreurs », série sauvée.")
        }
        .popCard(padding: Space.l)
    }

    // MARK: - Piste du pass

    private var trackCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Image(systemName: "crown.fill").foregroundStyle(Color(hex: 0xE9B949))
                Text("Et toute la piste Pass+").font(.cfTitle3).foregroundStyle(Color.ink)
            }
            benefit("3 jetons Prestige et 3 coffrets de catégorie (tu choisis le domaine et vois les cartes avant).")
            benefit("Cadres, finitions, dos de cartes, couvertures, socles, titres, autocollants.")
            benefit("Au palier 30 : dos Feuille d'or et cadre animé.")
            benefit("Déjà avancé dans le pass ? Tu récupères d'un coup tous les paliers atteints.")
        }
        .popCard(padding: Space.l)
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct)
            Text(text).font(.cfBody).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Achat

    @ViewBuilder private var buyArea: some View {
        VStack(spacing: Space.s) {
            if active {
                Label("Ton Pass+ est actif", systemImage: "checkmark.seal.fill")
                    .font(.cfHeadline)
                    .foregroundStyle(Color.correct)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.correct.opacity(0.12), in: Capsule())
            } else if app.passPlusForSale {
                Button {
                    Task {
                        if await passPlus.purchase() {
                            Haptics.success()
                            app.show("Pass+ activé : plus de pub !")
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if passPlus.purchasing { ProgressView().controlSize(.small).tint(Color.inkFixed) }
                        Text(passPlus.price.map { "Activer le Pass+ · \($0)" } ?? "Activer le Pass+")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.sun)
                .disabled(passPlus.purchasing)
            } else {
                Text("Le Pass+ n'est pas encore en vente pour cette saison.")
                    .font(.cfHeadline)
                    .foregroundStyle(Color.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            if let error = passPlus.errorMessage {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong).multilineTextAlignment(.center)
            }
            Button("Restaurer mes achats") { Task { await passPlus.restore() } }
                .buttonStyle(.textLink)
                .disabled(passPlus.purchasing)
        }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paiement unique pour la saison en cours, sans abonnement : rien ne se renouvelle tout seul. Le Pass+ est lié à ton compte \(Brand.name).")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.m) {
                Link("Conditions", destination: Brand.termsURL)
                Link("Confidentialité", destination: Brand.privacyURL)
            }
            .font(.cfFootnote.weight(.bold))
            .tint(Color.brand)
        }
    }
}
