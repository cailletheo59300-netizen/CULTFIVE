import SwiftUI
import CultFiveCore

/// Ouverture des coffres, en plein écran, à la chaîne. On touche le coffre : il tremble, s'ouvre dans un éclat,
/// puis son contenu apparaît ligne par ligne (graines, tickets, joker, objet pour Léon).
struct ChestOpeningView: View {
    let chests: [ChestRef]
    var onDone: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var contents: ChestContents?
    @State private var opening = false
    @State private var shake = 0.0
    @State private var burst = false
    @State private var revealed = 0
    @State private var error: String?

    private var chest: ChestRef? { chests.indices.contains(index) ? chests[index] : nil }
    private var isLast: Bool { index >= chests.count - 1 }

    var body: some View {
        ZStack {
            Color(hex: 0x1E1340).ignoresSafeArea()
            RadialGradient(colors: [glow.opacity(burst ? 0.55 : 0.25), .clear], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
                .animation(Motion.moment, value: burst)

            VStack(spacing: Space.l) {
                header
                Spacer(minLength: 0)
                if let chest {
                    Button { Task { await open() } } label: {
                        ChestView(tier: chest.tier, open: contents != nil)
                            .frame(maxWidth: contents == nil ? 230 : 150)
                            .rotationEffect(.degrees(sin(shake * .pi * 6) * (opening ? 6 : 0)))
                            .scaleEffect(burst ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(contents != nil || opening)
                    .accessibilityLabel(contents == nil ? "Ouvrir le \(chest.tier.title.lowercased())" : chest.tier.title)
                    .id(chest.id)
                    .transition(.scale.combined(with: .opacity))
                }
                if let contents { loot(contents) } else { hint }
                Spacer(minLength: 0)
                footer
            }
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Blocs

    private var glow: Color {
        switch chest?.tier {
        case .gold: return Color.sun
        case .silver: return Color(hex: 0xC5D3E8)
        default: return Color(hex: 0xFFB36B)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(chest?.tier.title ?? "").font(.system(.title, design: .rounded).weight(.black)).foregroundStyle(.white)
            Text(chest?.origin ?? "").font(.cfCallout).foregroundStyle(.white.opacity(0.7))
            if chests.count > 1 {
                Text("\(index + 1) sur \(chests.count)")
                    .font(.system(.footnote, design: .rounded).weight(.heavy)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .padding(.top, Space.l)
    }

    private var hint: some View {
        Text(opening ? "…" : "Touche le coffre pour l'ouvrir")
            .font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            .frame(minHeight: 140, alignment: .top)
    }

    private func loot(_ contents: ChestContents) -> some View {
        let rows = lootRows(contents)
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i < revealed {
                    HStack(spacing: 12) {
                        Text(row.icon).font(.title2)
                        Text(row.text).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.white.opacity(row.highlight ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                    .overlay {
                        if row.highlight {
                            RoundedRectangle(cornerRadius: Radius.s, style: .continuous).strokeBorder(Color.sun.opacity(0.8), lineWidth: 1.5)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minHeight: 140, alignment: .top)
        .accessibilityElement(children: .combine)
    }

    private struct LootRow { let icon: String; let text: String; var highlight = false }

    private func lootRows(_ contents: ChestContents) -> [LootRow] {
        var rows = [LootRow(icon: "🌱", text: "+\(contents.seeds) \(Brand.currencyPlural)")]
        if contents.tickets.fiftyFifty > 0 {
            rows.append(LootRow(icon: "🎟️", text: "\(contents.tickets.fiftyFifty) ticket\(contents.tickets.fiftyFifty > 1 ? "s" : "") 50/50"))
        }
        if contents.tickets.hint > 0 {
            rows.append(LootRow(icon: "💡", text: "\(contents.tickets.hint) ticket\(contents.tickets.hint > 1 ? "s" : "") indice"))
        }
        if contents.joker { rows.append(LootRow(icon: "🛡️", text: "1 joker de série")) }
        if let item = contents.item { rows.append(LootRow(icon: "✨", text: "Pour Léon : \(item.name)", highlight: true)) }
        return rows
    }

    private var footer: some View {
        VStack(spacing: Space.s) {
            if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
            if contents != nil {
                Button(isLast ? "Terminé" : "Coffre suivant") { next() }
                    .buttonStyle(InkButtonStyle(fill: Color.sun, text: Color(hex: 0x1E1340)))
            } else {
                Button("Plus tard") { onDone() }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: Actions

    private func open() async {
        guard let chest, contents == nil, !opening else { return }
        opening = true
        error = nil
        Haptics.soft()
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.6)) { shake = 1 }
        }
        let service = app.service
        async let result = service.openChest(chest.id)
        if !reduceMotion { try? await Task.sleep(nanoseconds: 650_000_000) }
        do {
            let opened = try await result
            SoundFX.play(.chest)
            Haptics.success()
            withAnimation(Motion.bounce) {
                contents = opened
                burst = true
            }
            let count = lootRows(opened).count
            for i in 1 ... count {
                if !reduceMotion { try? await Task.sleep(nanoseconds: 260_000_000) }
                withAnimation(Motion.standard) { revealed = i }
                if i == count, opened.item != nil { SoundFX.play(.reward) }
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Ouverture impossible. Réessaie."
        }
        opening = false
        shake = 0
    }

    private func next() {
        if isLast {
            onDone()
            return
        }
        withAnimation(Motion.standard) {
            index += 1
            contents = nil
            burst = false
            revealed = 0
        }
    }
}
