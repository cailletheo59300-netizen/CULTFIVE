import SwiftUI
import CultFiveCore

/// Revue du 5 du jour : les réponses et les explications, après la tentative officielle uniquement.
struct DailyReviewView: View {
    let date: String?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ReviewItem] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        ReviewRow(item: item, domainName: app.domainName(item.question.domainId))
                        Hairline()
                    }
                }
                .padding(.bottom, Space.xl)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                DomainTag(domainId: item.question.domainId, name: domainName)
                Spacer()
                Label(item.isCorrect ? "Juste" : "Raté", systemImage: item.isCorrect ? "checkmark" : "xmark")
                    .font(.system(.footnote).weight(.bold))
                    .foregroundStyle(item.isCorrect ? Color.correct : Color.wrong)
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
                Text(reveal.explanation).font(.cfBodySerif).foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let takeaway = reveal.takeaway {
                    HStack(alignment: .top, spacing: Space.s) {
                        Rectangle().fill(DomainPalette.color(item.question.domainId)).frame(width: 3)
                        Text(takeaway).font(.system(.callout).weight(.medium))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Space.gutter)
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
