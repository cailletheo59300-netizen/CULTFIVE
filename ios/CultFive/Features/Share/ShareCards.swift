import SwiftUI
import CultFiveCore

/// Contenu partageable. Chaque carte est pensée pour les stories (9:16) : lisible en un coup d'œil, sans gros filigrane.
enum ShareContent {
    case daily(DailyResult, handle: String)
    case profile(Profile, skills: [SkillSummary])
}

enum ShareTemplate: String, CaseIterable, Identifiable {
    case ink, paper, tally
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ink: return "Encre"
        case .paper: return "Papier"
        case .tally: return "Trait"
        }
    }
}

struct ShareSheetView: View {
    let content: ShareContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var template: ShareTemplate = .ink
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.l) {
                card
                    .frame(width: 270, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                    .accessibilityElement(children: .combine)

                Picker("Modèle", selection: $template) {
                    ForEach(ShareTemplate.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Space.gutter)

                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview(Brand.name, image: rendered)) {
                        Text("Partager l'image")
                    }
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

    @ViewBuilder private var card: some View {
        switch content {
        case .daily(let result, let handle):
            DailyShareCard(result: result, handle: handle, template: template)
        case .profile(let profile, let skills):
            ProfileShareCard(profile: profile, skills: skills, template: template)
        }
    }

    /// Rendu 1080 × 1920 (base 270 × 480 × 4).
    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 270, height: 480))
        renderer.scale = 4
        if let image = renderer.uiImage {
            rendered = Image(uiImage: image)
        }
    }
}

private struct CardPalette {
    let background: Color
    let text: Color
    let soft: Color
    let accent: Color

    init(_ template: ShareTemplate) {
        switch template {
        case .ink, .tally:
            background = .inkFixed; text = .paperFixed; soft = Color.paperFixed.opacity(0.55); accent = .chloro
        case .paper:
            background = .paperFixed; text = .inkFixed; soft = Color.inkFixed.opacity(0.55); accent = .inkFixed
        }
    }
}

struct DailyShareCard: View {
    let result: DailyResult
    let handle: String
    let template: ShareTemplate

    var body: some View {
        let palette = CardPalette(template)
        ZStack(alignment: .topLeading) {
            palette.background
            VStack(alignment: .leading, spacing: 14) {
                Text(Brand.name).font(.system(size: 13, weight: .black, design: .serif)).tracking(2.5).foregroundStyle(palette.text)
                Text(DateText.long(result.date)).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).tracking(1)
                    .foregroundStyle(palette.soft)
                Spacer()
                if template == .tally {
                    TallyMark(results: result.answers.map(\.isCorrect), onInk: true, lineWidth: 9)
                        .frame(width: 190)
                    Text("\(result.score)/5").font(.system(size: 44, weight: .bold, design: .serif)).foregroundStyle(palette.accent)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(result.score)").font(.system(size: 140, weight: .bold, design: .serif))
                            .foregroundStyle(template == .paper ? palette.text : palette.accent)
                        Text("/5").font(.system(size: 44, weight: .semibold, design: .serif)).foregroundStyle(palette.soft)
                    }
                    TallyMark(results: result.answers.map(\.isCorrect), onInk: template != .paper, lineWidth: 5).frame(width: 84)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    if let top = result.percentile?.top {
                        Text("TOP \(top) %").font(.system(size: 26, weight: .bold, design: .serif)).foregroundStyle(palette.text)
                    }
                    HStack(spacing: 14) {
                        Label(DurationFormat.clock(milliseconds: result.totalMs), systemImage: "stopwatch")
                        Label("\(result.streak) j", systemImage: "flame.fill")
                    }
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.text)
                }
                HStack {
                    Text(handle).font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(Brand.dailyName).font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(palette.soft)
            }
            .padding(24)
        }
    }
}

struct ProfileShareCard: View {
    let profile: Profile
    let skills: [SkillSummary]
    let template: ShareTemplate

    var body: some View {
        let palette = CardPalette(template)
        let top = skills.filter { $0.answered > 0 }.sorted { $0.level > $1.level }.prefix(5)
        ZStack(alignment: .topLeading) {
            palette.background
            VStack(alignment: .leading, spacing: 16) {
                Text(Brand.name).font(.system(size: 13, weight: .black, design: .serif)).tracking(2.5).foregroundStyle(palette.text)
                Spacer()
                Leon(color: top.first.map { DomainPalette.color($0.domainId) } ?? .chloro, pose: .proud).frame(width: 110)
                Text(profile.handle).font(.system(size: 30, weight: .bold, design: .serif)).foregroundStyle(palette.text)
                Text("Ce que je sais").font(.system(size: 10, weight: .semibold)).textCase(.uppercase).tracking(1).foregroundStyle(palette.soft)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(top)) { skill in
                        HStack {
                            Circle().fill(DomainPalette.color(skill.domainId)).frame(width: 7, height: 7)
                            Text(skill.name).font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(skill.level)").font(.system(size: 16, weight: .bold, design: .serif)).monospacedDigit()
                        }
                        .foregroundStyle(palette.text)
                    }
                }
                Spacer()
                HStack(spacing: 14) {
                    Label("\(profile.streak) j", systemImage: "flame.fill")
                    Label("\(profile.questionsAnswered)", systemImage: "checkmark.circle")
                }
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(palette.soft)
            }
            .padding(24)
        }
    }
}
