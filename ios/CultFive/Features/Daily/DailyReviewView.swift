import SwiftUI
import CultFiveCore

/// Revue du 5 du jour : les réponses et les explications, après la tentative officielle uniquement.
struct DailyReviewView: View {
    let date: String?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ReviewItem] = []
    @State private var error: String?
    @State private var sharing: Question?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        ReviewRow(item: item, domainName: app.domainName(item.question.domainId)) {
                            sharing = item.question
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
            }
            .overlay {
                if items.isEmpty {
                    if let error {
                        Text(error).font(.cfBody).foregroundStyle(Color.inkSoft).padding()
                    } else {
                        ProgressView()
                    }
                }
            }
            .background(Color.paper)
            .navigationTitle("Mes réponses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .sheet(item: $sharing) { question in
            ShareSheetView(content: .question(question, date: date))
        }
        .task {
            do {
                items = try await app.service.dailyReview(date: date)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Revue indisponible."
            }
        }
    }
}

private struct ReviewRow: View {
    let item: ReviewItem
    let domainName: String
    var onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                DomainTag(domainId: item.question.domainId, name: domainName)
                Spacer()
                Label(item.isCorrect ? "Juste" : "Raté", systemImage: item.isCorrect ? "checkmark" : "xmark")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(item.isCorrect ? Color.correct : Color.wrong, in: Capsule())
            }
            Text(item.question.prompt).font(.cfTitle3).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let reveal = item.question.reveal {
                if let given = GivenText.describe(item.given, question: item.question), !item.isCorrect {
                    (Text("Ta réponse : ").foregroundStyle(Color.inkSoft) + Text(given).foregroundStyle(Color.wrong))
                        .font(.cfCallout)
                }
                if let answer = AnswerText.correct(for: item.question, answer: reveal.answer) {
                    (Text("Bonne réponse : ").foregroundStyle(Color.inkSoft) + Text(answer).bold().foregroundStyle(Color.ink))
                        .font(.cfCallout)
                } else if let order = reveal.answer.order, let items = item.question.payload.items {
                    Text(order.compactMap { id in items.first { $0.id == id }?.text }.joined(separator: " → "))
                        .font(.cfCallout).foregroundStyle(Color.ink)
                } else if let pairs = reveal.answer.pairs, let left = item.question.payload.left, let right = item.question.payload.right {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(left) { l in
                            Text("\(l.text ?? "") → \(right.first { $0.id == pairs[l.id] }?.text ?? "")")
                        }
                    }
                    .font(.cfCallout).foregroundStyle(Color.ink)
                }
                Text(reveal.explanation).font(.cfReading).foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let takeaway = reveal.takeaway {
                    Text(takeaway).font(.system(.callout, design: .rounded).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DomainPalette.color(item.question.domainId).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                }
            }
            if item.question.type == .mcq || item.question.type == .trueFalse {
                Button(action: onShare) {
                    Label("Défier mes amis avec cette question", systemImage: "paperplane.fill")
                }
                .buttonStyle(.textLink)
            }
        }
        .popCard()
    }
}

enum GivenText {
    static func describe(_ given: GivenAnswer?, question: Question) -> String? {
        guard let given else { return "pas de réponse" }
        switch given {
        case .option(let id):
            if question.type == .mapPick { return "un autre emplacement" }
            return question.payload.options?.first { $0.id == id }?.text
        case .bool(let value):
            return value ? "Vrai" : "Faux"
        case .number(let value):
            return NumberFormat.display(NSDecimalNumber(decimal: value).doubleValue)
        case .order, .pairs:
            return nil
        }
    }
}
