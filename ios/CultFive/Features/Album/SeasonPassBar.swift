import SwiftUI
import CultFiveCore

/// Barre du pass de saison, toute la largeur, au-dessus des défis de l'accueil (D-074). Palier en cours, jauge vers
/// le suivant, et une pastille quand des récompenses attendent. Un appui ouvre le pass.
struct SeasonPassBar: View {
    let store: AlbumStore
    var onOpen: () -> Void

    var body: some View {
        if store.season.season != nil {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text("PALIER").font(.system(size: 9, weight: .black, design: .rounded)).tracking(0.6)
                            .foregroundStyle(.white.opacity(0.75))
                        Text("\(store.tier)").font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(Color.sun)
                    }
                    .frame(width: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Pass de saison").font(.system(.subheadline, design: .rounded).weight(.black))
                                .foregroundStyle(.white)
                            Spacer(minLength: 4)
                            if let progress = store.tierProgress {
                                Text("\(progress.points)/\(progress.total) pts")
                                    .font(.system(.caption, design: .rounded).weight(.heavy)).monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.8))
                            } else {
                                Text("Terminé").font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(Color.sun)
                            }
                        }
                        GeometryReader { proxy in
                            let ratio = store.tierProgress.map { CGFloat($0.points) / CGFloat($0.total) } ?? 1
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.2))
                                Capsule().fill(Color.sun).frame(width: max(8, proxy.size.width * min(ratio, 1)))
                            }
                        }
                        .frame(height: 8)
                    }
                    if store.claimableCount > 0 {
                        Text("\(store.claimableCount)")
                            .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(Color(hex: 0x1E1340))
                            .frame(minWidth: 30, minHeight: 30)
                            .background(Color.sun, in: Circle())
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "gift.fill").font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.white).offset(x: 4, y: -4)
                            }
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .shadow(color: Color(hex: 0x3A1FB8).opacity(0.25), radius: 10, y: 5)
            }
            .buttonStyle(.row)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Ouvre le pass de saison")
        }
    }

    private var accessibilityText: String {
        var text = "Pass de saison, palier \(store.tier) sur \(store.tiers)"
        if let progress = store.tierProgress { text += ", \(progress.points) points sur \(progress.total)" }
        if store.claimableCount > 0 { text += ", \(store.claimableCount) récompenses à réclamer" }
        return text
    }
}
