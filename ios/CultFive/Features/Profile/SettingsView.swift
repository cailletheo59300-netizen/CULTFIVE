import SwiftUI
import CultFiveCore

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""
    @State private var handleStatus: String?
    @State private var notifDaily = true
    @State private var notifReminder = true
    @State private var notifTime = Date()
    @State private var ageRange = ""
    @State private var showAccount = false
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var error: String?

    private let ageRanges = ["13-17", "18-24", "25-34", "35-49", "50+"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Pseudo") {
                    TextField("Pseudo", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let handleStatus {
                        Text(handleStatus).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Button("Enregistrer le pseudo") { saveHandle() }
                        .disabled(handle == app.profile?.handle || handle.count < 3)
                }

                Section {
                    Toggle("\(Brand.dailyName) disponible", isOn: $notifDaily)
                    if notifDaily {
                        DatePicker("Heure", selection: $notifTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Rappel le soir si pas encore joué", isOn: $notifReminder)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Jamais plus de deux par jour, et aucune si ton \(Brand.dailyName) est déjà fait.")
                }

                Section("Tranche d'âge (facultatif)") {
                    Picker("Âge", selection: $ageRange) {
                        Text("Non précisé").tag("")
                        ForEach(ageRanges, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Compte") {
                    if app.isAnonymous {
                        Button("Créer mon compte") { showAccount = true }
                    } else {
                        Button("Se déconnecter") { confirmSignOut = true }
                    }
                    Button("Supprimer mon compte", role: .destructive) { confirmDelete = true }
                }

                Section {
                    Link("Confidentialité", destination: Brand.privacyURL)
                    Link("Conditions d'utilisation", destination: Brand.termsURL)
                    Link("Nous écrire", destination: URL(string: "mailto:\(Brand.supportEmail)")!)
                } footer: {
                    Text("\(Brand.name) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · \(Brand.signature)")
                }

                if let error {
                    Text(error).foregroundStyle(Color.wrong)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { save(); dismiss() }
                }
            }
            .onAppear(perform: populate)
            .task(id: handle) { await checkHandle() }
            .sheet(isPresented: $showAccount) { AccountSheet() }
            .confirmationDialog("Supprimer ton compte ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer définitivement", role: .destructive) { deleteAccount() }
            } message: {
                Text("Progression, série, amis, ligues et \(Brand.currencyPlural) seront effacés. C'est irréversible.")
            }
            .confirmationDialog("Se déconnecter ?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Se déconnecter") {
                    Task { await app.signOut() }
                    dismiss()
                }
            }
        }
    }

    private func populate() {
        guard let profile = app.profile else { return }
        handle = profile.handle
        notifDaily = profile.notifDaily
        notifReminder = profile.notifReminder
        ageRange = profile.ageRange ?? ""
        let parts = profile.notifDailyTime.split(separator: ":").compactMap { Int($0) }
        notifTime = Calendar.current.date(bySettingHour: parts.first ?? 8, minute: parts.count > 1 ? parts[1] : 30, second: 0, of: Date()) ?? Date()
    }

    private func checkHandle() async {
        guard handle != app.profile?.handle, handle.count >= 3 else { handleStatus = nil; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled, let availability = try? await app.service.handleAvailable(handle) else { return }
        handleStatus = availability.available ? "Disponible" : (availability.reason == "invalid"
            ? "3 à 20 caractères : lettres, chiffres ou _." : availability.reason == "not_allowed" ? "Ce pseudo n'est pas autorisé." : "Déjà pris.")
    }

    private func saveHandle() {
        Task {
            do {
                app.profile = try await app.service.setHandle(handle)
                handleStatus = "Enregistré"
                Haptics.success()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    private func save() {
        let time = Calendar.current.dateComponents([.hour, .minute], from: notifTime)
        let fields: [String: JSONValue] = [
            "notif_daily": .bool(notifDaily),
            "notif_reminder": .bool(notifReminder),
            "notif_daily_time": .string(String(format: "%02d:%02d", time.hour ?? 8, time.minute ?? 30)),
            "age_range": ageRange.isEmpty ? .null : .string(ageRange),
        ]
        Task {
            if notifDaily || notifReminder { _ = await NotificationScheduler.requestAuthorization() }
            if let profile = try? await app.service.updateProfile(fields) {
                app.profile = profile
                await NotificationScheduler.refresh(profile: profile, dailyDone: app.daily?.state == .done)
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await app.deleteAccount()
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Suppression impossible. Réessaie."
            }
        }
    }
}
