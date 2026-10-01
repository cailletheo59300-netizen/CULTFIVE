import SwiftUI
import CultFiveCore

/// Cible d'un signalement : un joueur (pseudo, comportement) ou une ligue (nom).
struct ReportTarget: Identifiable {
    enum Kind: String { case user, league }
    let id = UUID()
    let kind: Kind
    let targetId: UUID
    let name: String
}

/// Signaler un joueur ou une ligue. Le signalement arrive dans l'admin ; l'auteur n'en sait rien.
struct ReportSheet: View {
    let target: ReportTarget

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "name"
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?

    private var reasons: [(String, String)] {
        target.kind == .league
            ? [("name", "Nom de la ligue offensant"), ("other", "Autre problème")]
            : [("name", "Pseudo offensant"), ("behavior", "Comportement abusif"), ("cheating", "Triche"), ("other", "Autre problème")]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Motif", selection: $reason) {
                        ForEach(reasons, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(target.kind == .league ? "Signaler la ligue « \(target.name) »" : "Signaler \(target.name)")
                }
                Section {
                    TextField("Précisions (facultatif)", text: $note, axis: .vertical).lineLimit(2...5)
                } footer: {
                    Text("Notre équipe examine chaque signalement. \(target.kind == .user ? "Tu peux aussi bloquer ce joueur depuis son profil." : "")")
                }
                if let error { Text(error).foregroundStyle(Color.wrong) }
            }
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { send() }.disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() {
        busy = true
        Task {
            do {
                try await app.service.reportContent(kind: target.kind.rawValue, target: target.targetId, reason: reason,
                                                    note: note.isEmpty ? nil : note)
                app.show("Merci, ton signalement a été envoyé.")
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Envoi impossible."
            }
            busy = false
        }
    }
}
