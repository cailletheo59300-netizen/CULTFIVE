import SwiftUI
import CultFiveCore

/// Contenu partageable. Chaque carte est pensée pour les stories (9:16) : lisible en un coup d'œil, colorée, sans gros filigrane.
enum ShareContent {
    case daily(DailyResult, handle: String)
    case profile(Profile, skills: [SkillSummary])
    /// Une question du Daily, sans la réponse : « Et toi, tu aurais trouvé ? »
    case question(Question, date: String?)

    /// Nom court pour le journal d'usage.
    var kind: String {
        switch self {
        case .daily: return "daily"
        case .profile: return "profile"
        case .question: return "question"
        }
    }
}

enum ShareTemplate: String, CaseIterable, Identifiable {
    case violet, sun, white
    var id: String { rawValue }
    var title: String {
        switch self {
        case .violet: return "Violet"
        case .sun: return "Soleil"
        case .white: return "Blanc"
        }
    }
}

struct ShareSheetView: View {
    let content: ShareContent

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var template: ShareTemplate = .violet
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.l) {
                card
                    .frame(width: 270, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.25), radius: 20, y: 10)
                    .accessibilityElement(children: .combine)

                HStack(spacing: Space.s) {
                    ForEach(ShareTemplate.allCases) { option in
                        Button {
                            Haptics.selection()
                            template = option
                        } label: {
                            Circle()
                                .fill(swatch(option))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(Color.hairline, lineWidth: option == .white ? 1.5 : 0))
                                .padding(4)
                                .overlay(Circle().strokeBorder(template == option ? Color.brand : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.row)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(template == option ? .isSelected : [])
                    }
                }

                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview(Brand.name, image: rendered)) {
                        Label("Partager l'image", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { app.track("share", ["what": content.kind]) })
                    .buttonStyle(.ink)
                    .padding(.horizontal, Space.gutter)
                }
            }
            .padding(.vertical, Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.paper)
            .navigationTitle("Partager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .task(id: template) { render() }
        }
    }

    private func swatch(_ template: ShareTemplate) -> AnyShapeStyle {
        switch template {
        case .violet: return AnyShapeStyle(Color.popGradient)
        case .sun: return AnyShapeStyle(Color.sun)
        case .white: return AnyShapeStyle(Color.paperFixed)
        }
    }

    @ViewBuilder private var card: some View {
        switch content {
        case .daily(let result, let handle):
            DailyShareCard(result: result, handle: handle, template: template)
        case .profile(let profile, let skills):
            ProfileShareCard(profile: profile, skills: skills, template: template)
        case .question(let question, let date):
            QuestionShareCard(question: question, date: date, template: template)
        }
    }

    /// Rendu 1080 × 1920 (base 270 × 480 × 4).
    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 270, height: 480).environment(\.colorScheme, .light))
        renderer.scale = 4
        if let image = renderer.uiImage {
            rendered = Image(uiImage: image)
        }
    }
}

/// Couleurs d'une carte selon le modèle. Couleurs fixes : la carte est identique en mode clair ou sombre.
private struct CardPalette {
    let background: AnyShapeStyle
    let text: Color
    let soft: Color
    /// Chiffre héros.
    let accent: Color
    /// Fond des pastilles.
    let chip: Color
    let onInk: Bool
    let leon: Color

    init(_ template: ShareTemplate) {
        let deep = Color(hex: 0x3A1FB8)
        switch template {
        case .violet:
            background = AnyShapeStyle(Color.popGradient); text = .white; soft = .white.opacity(0.7)
            accent = .sun; chip = .white.opacity(0.16); onInk = true; leon = .sun
        case .sun:
            background = AnyShapeStyle(Color.sun); text = .inkFixed; soft = Color.inkFixed.opacity(0.6)
            accent = deep; chip = Color.inkFixed.opacity(0.08); onInk = false; leon = Color(hex: 0x6A4CFF)
        case .white:
            background = AnyShapeStyle(Color.paperFixed); text = .inkFixed; soft = Color.inkFixed.opacity(0.55)
            accent = Color(hex: 0x6A4CFF); chip = Color(hex: 0x6A4CFF).opacity(0.1); onInk = false; leon = Color(hex: 0x6A4CFF)
        }
    }
}

/// Bandeau haut commun : marque + date.
private struct CardHeader: View {
    let palette: CardPalette
    var date: String?

    var body: some View {
        HStack {
            Text(Brand.name).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(palette.text)
            Spacer()
            if let date {
                Text(DateText.long(date)).font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(palette.chip, in: Capsule())
            }
        }
    }
}

private struct CardChip: View {
    let text: String
    let symbol: String
    let palette: CardPalette

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(palette.chip, in: Capsule())
    }
}

struct DailyShareCard: View {
    let result: DailyResult
    let handle: String
    let template: ShareTemplate

    var body: some View {
        let palette = CardPalette(template)
        ZStack {
            Rectangle().fill(palette.background)
            Circle().fill(palette.text.opacity(0.06)).frame(width: 260).offset(x: 110, y: -170)
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(palette: palette, date: result.date)
                Spacer()
                Leon(color: palette.leon, pose: result.score >= 4 ? .proud : (result.score >= 2 ? .wave : .sad), animated: false)
                    .frame(width: 120)
                Text(Brand.dailyName.uppercased()).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1)
                    .foregroundStyle(palette.soft)
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("\(result.score)").font(.system(size: 120, weight: .black, design: .rounded))
                        .foregroundStyle(palette.accent)
                    Text("/5").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(palette.soft)
                }
                .padding(.vertical, -18)
                TallyMark(results: result.answers.map(\.isCorrect), onInk: palette.onInk, lineWidth: 6).frame(width: 78)
                // Classement sur sa propre ligne : trois pastilles ne tenaient pas sur la largeur de la carte.
                if let top = result.percentile?.top {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill")
                        Text(result.percentile?.source == .estimate ? "Top \(top) % (estimation)" : "Top \(top) % des joueurs du jour")
                    }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.top, 6)
                }
                Spacer()
                HStack(spacing: 6) {
                    CardChip(text: DurationFormat.clock(milliseconds: result.totalMs), symbol: "stopwatch.fill", palette: palette)
                    CardChip(text: "\(result.streak) j", symbol: "flame.fill", palette: palette)
                }
                HStack {
                    Text(Brand.onboardingHook).font(.system(size: 12, weight: .heavy, design: .rounded))
                    Spacer()
                    Text(handle).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(palette.soft)
                }
                .foregroundStyle(palette.text)
            }
            .padding(22)
        }
    }
}

/// Profil : radar des connaissances + meilleurs domaines.
struct ProfileShareCard: View {
    let profile: Profile
    let skills: [SkillSummary]
    let template: ShareTemplate

    var body: some View {
        let palette = CardPalette(template)
        let top = skills.filter { $0.answered > 0 }.sorted { ($0.rating.placed ? 1 : 0, $0.level) > ($1.rating.placed ? 1 : 0, $1.level) }.prefix(3)
        ZStack {
            Rectangle().fill(palette.background)
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(palette: palette)
                Text(profile.handle).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(palette.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let global = CoteCULT.global(skills), global.placed {
                    Text("Elo \(global.formatted) · \(global.rank.name)")
                        .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(palette.accent)
                }
                Text("Mon radar de culture").font(.system(size: 11, weight: .heavy, design: .rounded)).textCase(.uppercase)
                    .foregroundStyle(palette.soft)
                KnowledgeRadar(axes: skills.map { KnowledgeRadar.Axis(domainId: $0.domainId, level: $0.answered > 0 ? Double($0.level) : 0) },
                               fill: palette.accent, grid: palette.text.opacity(0.18))
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(top)) { skill in
                        HStack(spacing: 8) {
                            Image(systemName: DomainPalette.symbol(skill.domainId))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DomainPalette.onColor(skill.domainId))
                                .frame(width: 22, height: 22)
                                .background(DomainPalette.color(skill.domainId), in: Circle())
                            Text(skill.name).font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                            Text(skill.rating.placed ? skill.rating.formatted : "—")
                                .font(.system(size: 16, weight: .black, design: .rounded)).monospacedDigit()
                        }
                        .foregroundStyle(palette.text)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    CardChip(text: "\(profile.streak) j", symbol: "flame.fill", palette: palette)
                    CardChip(text: "\(profile.questionsAnswered)", symbol: "checkmark.circle.fill", palette: palette)
                }
            }
            .padding(22)
        }
    }
}

/// Une question du jour, sans la réponse. Le défi lancé aux amis.
struct QuestionShareCard: View {
    let question: Question
    let date: String?
    let template: ShareTemplate

    var body: some View {
        let palette = CardPalette(template)
        let color = DomainPalette.color(question.domainId)
        ZStack {
            Rectangle().fill(palette.background)
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(palette: palette, date: date)
                Spacer(minLength: 0)
                Text("Tu aurais trouvé ?").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(palette.accent)
                DomainTag(domainId: question.domainId, name: DomainPalette.fallbackName(question.domainId))
                if let shape = question.payload.shape {
                    CountryShapeView(shape: shape, color: color).frame(height: 110)
                }
                Text(question.prompt)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                options(palette: palette, color: color)
                Spacer(minLength: 0)
                HStack(alignment: .center) {
                    Leon(color: palette.leon, pose: .curious, animated: false).frame(width: 64)
                    Text("La réponse est dans \(Brand.name).").font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.text)
                }
            }
            .padding(22)
        }
    }

    @ViewBuilder private func options(palette: CardPalette, color: Color) -> some View {
        switch question.type {
        case .mcq:
            VStack(spacing: 7) {
                ForEach(Array((question.payload.options ?? []).prefix(4).enumerated()), id: \.offset) { index, option in
                    HStack(spacing: 8) {
                        Text(["A", "B", "C", "D"][index]).font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                            .frame(width: 22, height: 22)
                            .background(color.opacity(0.15), in: Circle())
                        Text(option.text ?? "").font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.inkFixed).lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(Color.paperFixed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        case .trueFalse:
            HStack(spacing: 8) {
                ForEach(["Vrai", "Faux"], id: \.self) { title in
                    Text(title).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Color.inkFixed)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.paperFixed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        default:
            EmptyView()
        }
    }
}
