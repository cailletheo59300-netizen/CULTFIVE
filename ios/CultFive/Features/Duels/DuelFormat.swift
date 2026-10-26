import SwiftUI
import CultFiveCore

// Choix du format d'un duel entre amis (D-114) : deux grandes cartes, « Format Arène » (7 questions, 25 s, tous les
// domaines) et « Format libre » (on règle tout : nombre de questions, chrono, domaines, difficulté). Les réglages du
// format libre s'ouvrent juste dessous. Les mêmes briques (FormSection, ChoiceChip, BigChoiceCard) servent aux autres
// pages de réglages (nouvelle ligue).

/// Une section de réglages : un titre, une phrase d'aide, des pastilles.
struct FormSection<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                if let detail {
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FlowLayout(spacing: 8) { content }
        }
        .popCard(padding: 16, radius: 22)
    }
}

/// Pastille de choix : pleine quand elle est choisie, à la couleur donnée (domaines) ou à la couleur de la marque.
struct ChoiceChip: View {
    let title: String
    let on: Bool
    var tint: Color = .brand
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.bounce) { action() }
        } label: {
            Text(title)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(on ? Color.white : Color.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(on ? tint : Color.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Color.clear : tint.opacity(0.25), lineWidth: 1.5))
                .scaleEffect(on ? 1.03 : 1)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Grande carte de choix (format du duel, format de ligue) : titre, deux lignes, coche quand elle est choisie.
struct BigChoiceCard: View {
    let title: String
    let lines: [String]
    let on: Bool
    var colors: [Color] = [Color(hex: 0x6A4CFF), Color(hex: 0x3A1FB8)]
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.bounce) { action() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.system(.headline, design: .rounded).weight(.black))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    ZStack {
                        Circle().strokeBorder(on ? Color.white : Color.inkSoft.opacity(0.35), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if on {
                            Circle().fill(Color.white).frame(width: 12, height: 12)
                        }
                    }
                }
                ForEach(lines, id: \.self) { line in
                    Text(line).font(.system(.footnote, design: .rounded).weight(.bold))
                        .opacity(on ? 0.85 : 0.7)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(on ? Color.white : Color.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                             : AnyShapeStyle(Color.paperRaised))
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? Color.clear : Color.hairline, lineWidth: 1.5))
            .shadow(color: (colors.last ?? .brand).opacity(on ? 0.3 : 0), radius: 10, y: 6)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Le format d'un duel entre amis : Format Arène ou Format libre (avec tous ses réglages).
struct DuelFormatPicker: View {
    @Binding var settings: DuelSettings
    @Environment(AppModel.self) private var app
    @State private var free = false
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                BigChoiceCard(title: "Format Arène", lines: ["7 questions", "25 s chacune"], on: !free) {
                    free = false
                    settings = .arena
                }
                BigChoiceCard(title: "Format libre", lines: ["Tu choisis tout", "questions, chrono…"], on: free,
                              colors: [Color(hex: 0xFF7AB6), Color(hex: 0xA34DFF)]) {
                    free = true
                }
            }
            if free {
                VStack(spacing: 12) {
                    FormSection(title: "Questions") {
                        ForEach(DuelSettings.counts, id: \.self) { n in
                            ChoiceChip(title: "\(n)", on: settings.count == n) { settings.count = n }
                        }
                    }
                    FormSection(title: "Chrono", detail: settings.timer ? "25 secondes par question : il faut aller vite."
                                                                        : "Pas de chrono : chacun prend son temps.") {
                        ChoiceChip(title: "25 s par question", on: settings.timer) { settings.timer = true }
                        ChoiceChip(title: "Sans chrono", on: !settings.timer) { settings.timer = false }
                    }
                    FormSection(title: "Domaines", detail: settings.domains.isEmpty ? "Un peu de tout." : nil) {
                        ChoiceChip(title: "Tous", on: settings.domains.isEmpty) { settings.domains = [] }
                        ForEach(app.domains, id: \.id) { domain in
                            ChoiceChip(title: domain.name, on: settings.domains.contains(domain.id),
                                       tint: DomainPalette.color(domain.id)) {
                                if let index = settings.domains.firstIndex(of: domain.id) {
                                    settings.domains.remove(at: index)
                                } else {
                                    settings.domains.append(domain.id)
                                }
                            }
                        }
                    }
                    FormSection(title: "Difficulté", detail: settings.difficulty == .auto ? "Auto : calée sur vos deux niveaux, pour un duel serré." : nil) {
                        ForEach(DuelDifficulty.allCases, id: \.self) { level in
                            ChoiceChip(title: level.title, on: settings.difficulty == level) { settings.difficulty = level }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            free = !settings.isArena
        }
    }
}
