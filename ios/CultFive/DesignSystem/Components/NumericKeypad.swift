import SwiftUI
import CultFiveCore

/// Pavé numérique interne (questions de calcul). Pas de clavier iOS : pas de fautes de format, retour haptique à chaque touche.
struct NumericKeypad: View {
    @Binding var entry: NumericEntry
    var onSubmit: () -> Void

    private let decimalSeparator = Locale.current.decimalSeparator ?? ","
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    var body: some View {
        VStack(spacing: Space.s) {
            Hairline()
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(1...9, id: \.self) { digit in
                    key(Text("\(digit)"), label: "\(digit)") { entry.append(digit: digit) }
                }
                if entry.allowNegative {
                    key(Text("±"), label: "Changer le signe") { entry.toggleSign() }
                } else {
                    key(Text(decimalSeparator), label: "Virgule") { entry.appendDecimalSeparator() }
                }
                key(Text("0"), label: "0") { entry.append(digit: 0) }
                key(Image(systemName: "delete.left"), label: "Effacer") { entry.backspace() }
            }
            HStack(spacing: Space.s) {
                if entry.allowNegative {
                    Button {
                        entry.appendDecimalSeparator()
                        Haptics.soft()
                    } label: {
                        Text(decimalSeparator)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(Color.ink)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.row)
                    .accessibilityLabel("Virgule")
                }
                Button("Valider", action: onSubmit)
                    .buttonStyle(.ink)
                    .disabled(entry.value == nil)
            }
            .padding(.horizontal, Space.gutter)
        }
    }

    private func key(_ content: some View, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.soft()
        } label: {
            content
                .font(.system(.title, design: .serif).weight(.regular))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.row)
        .accessibilityLabel(label)
    }
}

/// Zone d'affichage de la saisie (grand chiffre, curseur, unité).
struct NumericDisplay: View {
    let entry: NumericEntry
    var unit: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(entry.isEmpty ? "?" : entry.display(decimalSeparator: Locale.current.decimalSeparator ?? ","))
                .numeral(size: 52, weight: .semibold)
                .foregroundStyle(entry.isEmpty ? Color.inkSoft.opacity(0.4) : Color.ink)
                .contentTransition(.numericText())
                .animation(Motion.press, value: entry)
            if let unit {
                Text(unit).font(.cfTitle3).foregroundStyle(Color.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel(entry.isEmpty ? "Aucune saisie" : "Saisie : \(entry.display())")
    }
}
