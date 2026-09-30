import SwiftUI
import CultFiveCore

/// Toutes les étapes de l'arbre et les formes de Léon : ce qui est atteint en couleur, le reste en silhouette.
struct TreeStagesSheet: View {
    let tree: TreeState

    private struct Stage: Identifiable {
        let id: Int
        let stage: Int
        let fruits: Int
        let name: String
        let threshold: Int
        let reward: String
        let form: String?
    }

    private var stages: [Stage] {
        let forms = [1: "form_baby", 3: "form_young", 5: "form_adult", 6: "form_sage"]
        let formNames = ["form_baby": "Léon bébé", "form_young": "Léon jeune", "form_adult": "Léon adulte", "form_sage": "Léon sage"]
        var list = (1 ... 6).map { stage in
            Stage(id: stage, stage: stage, fruits: 0, name: TreeState.stageName(stage), threshold: TreeState.stageThresholds[stage - 1],
                  reward: [stage > 1 ? "Coffre en or" : nil, forms[stage].flatMap { formNames[$0] }].compactMap { $0 }.joined(separator: " · "),
                  form: forms[stage])
        }
        let fruitNames = ["Couronne de feuilles", "Monocle", "Cape étoilée", "Léon doré"]
        for fruit in 1 ... 4 {
            list.append(Stage(id: 6 + fruit, stage: 6, fruits: fruit, name: fruit == 1 ? "1er fruit" : "\(fruit)e fruit",
                              threshold: 9000 + TreeState.fruitStep * fruit, reward: fruitNames[fruit - 1], form: nil))
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("L'arbre et Léon").font(.cfDisplay).padding(.top, Space.l)
                Text("Chaque étape donne un coffre en or. Léon change de forme avec l'arbre, puis l'arbre porte des fruits rares.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(stages) { stage in
                    let reached = tree.points >= stage.threshold
                    HStack(spacing: Space.m) {
                        ZStack(alignment: .bottomLeading) {
                            LeonTreeView(stage: stage.stage, fruits: stage.fruits).frame(width: 76, height: 76)
                            if let form = stage.form {
                                Leon(color: .brand, pose: .rest, curl: 0.4, animated: false, outfit: LeonOutfit(form: form))
                                    .frame(width: 36)
                            }
                        }
                        .saturation(reached ? 1 : 0)
                        .opacity(reached ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.name).font(.cfTitle3).foregroundStyle(reached ? Color.ink : Color.inkSoft)
                            Text(stage.threshold == 0 ? "Au départ" : "\(stage.threshold) \(Brand.currencyPlural)")
                                .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft).monospacedDigit()
                            if !stage.reward.isEmpty {
                                Text(stage.reward).font(.cfFootnote).foregroundStyle(reached ? Color.correct : Color.inkSoft)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: reached ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(reached ? Color.correct : Color.hairline)
                            .font(.title3)
                    }
                    .padding(10)
                    .background(stage.stage == tree.stage && stage.fruits == tree.fruits ? Color.brand.opacity(0.08) : Color.paperRaised,
                                in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(reached ? "atteint" : "à venir")
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .background(Color.paper)
        .presentationDragIndicator(.visible)
    }
}
