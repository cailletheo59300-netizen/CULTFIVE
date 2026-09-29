import SwiftUI
import CultFiveCore

/// Réglages : une vraie page Brainlix, ouverte depuis le Profil (pas une feuille). Tout s'enregistre tout de suite,
/// sans bouton « OK » : notifications et tranche d'âge partent au serveur une demi-seconde après le dernier changement,
/// apparence et vibrations restent sur l'appareil. Seul le pseudo se valide (il doit être libre).
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .light
    @AppStorage(GamePreferences.hapticsKey) private var haptics = true

    @State private var handle = ""
    @State private var handleStatus: HandleStatus?
    @State private var prefs = Prefs()
    @State private var loaded = false
    @State private var saved = false
    @State private var showAccount = false
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var error: String?

    private let ageRanges = ["13-17", "18-24", "25-34", "35-49", "50+"]

    /// Réglages enregistrés au serveur.
    private struct Prefs: Equatable {
        var notifDaily = true
        var notifReminder = true
        var notifTime = Date()
        var ageRange = ""
    }

    private enum HandleStatus: Equatable {
        case available, taken(String), saved
        var text: String {
            switch self {
            case .available: return "Disponible"
            case .taken(let reason): return reason
            case .saved: return "Enregistré"
            }
        }
        var ok: Bool { if case .taken = self { return false } else { return true } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                identity
                section("Apparence") { appearancePicker }
                section("Notifications",
                        footer: "Jamais plus de deux par jour, et aucune si ton \(Brand.dailyName) est déjà fait.") { notifications }
                section("Jeu") {
                    toggleRow("Vibrations", symbol: "iphone.radiowaves.left.and.right", tint: Color(hex: 0xF76707), isOn: $haptics)
                }
                section("Informations", footer: "Facultatif. Sert seulement à adapter les questions, jamais affiché.") { ageRow }
                section("Compte") { account }
                section("Aide & légal") { links }
                about
                if let error {
                    Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
        .clearsTabBar()
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.paper, for: .navigationBar)
        .overlay(alignment: .top) { savedToast }
        .onAppear(perform: populate)
        .task(id: handle) { await checkHandle() }
        .task(id: prefs) { await savePrefs() }
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

    // MARK: Blocs

    /// Carte d'identité : pseudo modifiable, type de compte.
    private var identity: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                Text(String(handle.prefix(1)).uppercased())
                    .font(.system(.title, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.popGradient, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.profile?.handle ?? "…").font(.cfTitle3).foregroundStyle(Color.ink).lineLimit(1)
                    Text(app.isAnonymous ? "Compte invité · sur cet iPhone seulement" : "Compte Apple · sauvegardé")
                        .font(.cfFootnote).foregroundStyle(app.isAnonymous ? Color.wrong : Color.inkSoft)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Pseudo").labelCaps()
                HStack(spacing: Space.s) {
                    TextField("Pseudo", text: $handle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(saveHandle)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                        .background(Color.paper, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                    if handleChanged {
                        Button("Enregistrer", action: saveHandle)
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                            .disabled(handleStatus?.ok == false)
                            .opacity(handleStatus?.ok == false ? 0.45 : 1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if let handleStatus {
                    Label(handleStatus.text, systemImage: handleStatus.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.cfFootnote.weight(.bold))
                        .foregroundStyle(handleStatus.ok ? Color.correct : Color.wrong)
                }
            }
        }
        .popCard()
        .animation(Motion.standard, value: handleChanged)
    }

    /// Trois vignettes : aperçu clair, sombre, moitié-moitié.
    private var appearancePicker: some View {
        HStack(spacing: 10) {
            ForEach(AppAppearance.allCases) { option in
                let on = appearance == option
                Button {
                    Haptics.selection()
                    withAnimation(Motion.standard) { appearance = option }
                } label: {
                    VStack(spacing: Space.s) {
                        AppearanceThumbnail(option: option)
                            .frame(height: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(on ? Color.brand : Color.hairline, lineWidth: on ? 2.5 : 1)
                            }
                        Text(option.title)
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .foregroundStyle(on ? Color.brand : Color.ink)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.row)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Space.m)
    }

    private var notifications: some View {
        VStack(spacing: 0) {
            toggleRow("\(Brand.dailyName) disponible", symbol: "bell.fill", tint: .brand, isOn: $prefs.notifDaily)
            if prefs.notifDaily {
                divider
                row("Heure", symbol: "clock.fill", tint: Color(hex: 0x1C7ED6)) {
                    DatePicker("Heure", selection: $prefs.notifTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            divider
            toggleRow("Rappel le soir si pas encore joué", symbol: "moon.fill", tint: Color(hex: 0x7048E8), isOn: $prefs.notifReminder)
        }
        .animation(Motion.standard, value: prefs.notifDaily)
    }

    private var ageRow: some View {
        row("Tranche d'âge", symbol: "person.fill", tint: Color(hex: 0x0CA678)) {
            Picker("Tranche d'âge", selection: $prefs.ageRange) {
                Text("Non précisée").tag("")
                ForEach(ageRanges, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .tint(Color.inkSoft)
        }
    }

    private var account: some View {
        VStack(spacing: 0) {
            if app.isAnonymous {
                actionRow("Créer mon compte", symbol: "person.badge.plus", tint: .brand) { showAccount = true }
            } else {
                actionRow("Se déconnecter", symbol: "rectangle.portrait.and.arrow.right", tint: Color.inkSoft) { confirmSignOut = true }
            }
            divider
            actionRow("Supprimer mon compte", symbol: "trash.fill", tint: .wrong, destructive: true) { confirmDelete = true }
        }
    }

    private var links: some View {
        VStack(spacing: 0) {
            linkRow("Aide", symbol: "questionmark.circle.fill", tint: Color(hex: 0x1C7ED6), url: Brand.supportURL)
            divider
            linkRow("Nous écrire", symbol: "envelope.fill", tint: Color(hex: 0xF76707),
                    url: URL(string: "mailto:\(Brand.supportEmail)")!, detail: Brand.supportEmail)
            divider
            linkRow("Confidentialité", symbol: "lock.fill", tint: Color(hex: 0x495057), url: Brand.privacyURL)
            divider
            linkRow("Conditions d'utilisation", symbol: "doc.text.fill", tint: Color(hex: 0x495057), url: Brand.termsURL)
            divider
            linkRow("Mentions légales", symbol: "building.columns.fill", tint: Color(hex: 0x495057), url: Brand.legalURL)
        }
    }

    private var about: some View {
        VStack(spacing: 6) {
            Leon(color: .brand, pose: .wave, animated: false)
                .frame(width: 72)
            Text(Brand.name).font(.cfTitle3).foregroundStyle(Color.ink)
            Text("Version \(version) · \(Brand.signature)")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
        .accessibilityElement(children: .combine)
    }

    private var savedToast: some View {
        Group {
            if saved {
                Label("Enregistré", systemImage: "checkmark")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.correct, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Space.xs)
            }
        }
        .animation(Motion.standard, value: saved)
        .allowsHitTesting(false)
    }

    // MARK: Briques

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps().padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            if let footer {
                Text(footer).font(.cfFootnote).foregroundStyle(Color.inkSoft).padding(.horizontal, 4)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 62)
    }

    private func icon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }

    private func row<Trailing: View>(_ title: String, symbol: String, tint: Color, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            icon(symbol, tint: tint)
            Text(title).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
            Spacer(minLength: Space.s)
            trailing()
        }
        .padding(.horizontal, Space.m)
        .frame(minHeight: 56)
    }

    private func toggleRow(_ title: String, symbol: String, tint: Color, isOn: Binding<Bool>) -> some View {
        row(title, symbol: symbol, tint: tint) {
            Toggle(title, isOn: isOn).labelsHidden().tint(Color.brand)
        }
    }

    private func actionRow(_ title: String, symbol: String, tint: Color, destructive: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon(symbol, tint: tint)
                Text(title).font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(destructive ? Color.wrong : Color.ink)
                Spacer(minLength: Space.s)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.inkSoft.opacity(0.6))
            }
            .padding(.horizontal, Space.m)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
    }

    private func linkRow(_ title: String, symbol: String, tint: Color, url: URL, detail: String? = nil) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                icon(symbol, tint: tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                    if let detail { Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft) }
                }
                Spacer(minLength: Space.s)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.bold)).foregroundStyle(Color.inkSoft.opacity(0.6))
            }
            .padding(.horizontal, Space.m)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
    }

    // MARK: Logique

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var handleChanged: Bool { handle != app.profile?.handle && handle.count >= 3 }

    private func populate() {
        guard !loaded, let profile = app.profile else { return }
        handle = profile.handle
        let parts = profile.notifDailyTime.split(separator: ":").compactMap { Int($0) }
        prefs = Prefs(notifDaily: profile.notifDaily, notifReminder: profile.notifReminder,
                      notifTime: Calendar.current.date(bySettingHour: parts.first ?? 8, minute: parts.count > 1 ? parts[1] : 30,
                                                       second: 0, of: Date()) ?? Date(),
                      ageRange: profile.ageRange ?? "")
        loaded = true
    }

    private func checkHandle() async {
        guard handleChanged else { if handleStatus != .saved { handleStatus = nil }; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled, let availability = try? await app.service.handleAvailable(handle) else { return }
        handleStatus = availability.available ? .available : .taken(availability.reason == "invalid"
            ? "3 à 20 caractères : lettres, chiffres ou _." : availability.reason == "not_allowed" ? "Ce pseudo n'est pas autorisé." : "Déjà pris.")
    }

    private func saveHandle() {
        guard handleChanged, handleStatus?.ok != false else { return }
        Task {
            do {
                app.profile = try await app.service.setHandle(handle)
                handleStatus = .saved
                error = nil
                Haptics.success()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    /// Enregistrement automatique, une demi-seconde après le dernier changement (pas à l'ouverture).
    private func savePrefs() async {
        guard loaded, let profile = app.profile else { return }
        let time = Calendar.current.dateComponents([.hour, .minute], from: prefs.notifTime)
        let timeText = String(format: "%02d:%02d", time.hour ?? 8, time.minute ?? 30)
        let unchanged = prefs.notifDaily == profile.notifDaily && prefs.notifReminder == profile.notifReminder
            && timeText == profile.notifDailyTime.prefix(5) && prefs.ageRange == (profile.ageRange ?? "")
        guard !unchanged else { return }
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        let fields: [String: JSONValue] = [
            "notif_daily": .bool(prefs.notifDaily),
            "notif_reminder": .bool(prefs.notifReminder),
            "notif_daily_time": .string(timeText),
            "age_range": prefs.ageRange.isEmpty ? .null : .string(prefs.ageRange),
        ]
        if prefs.notifDaily || prefs.notifReminder { _ = await NotificationScheduler.requestAuthorization() }
        do {
            let updated = try await app.service.updateProfile(fields)
            app.profile = updated
            error = nil
            await NotificationScheduler.refresh(profile: updated, dailyDone: app.daily?.state == .done)
            saved = true
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            saved = false
        } catch {
            self.error = "Réglage non enregistré. Vérifie ta connexion."
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

/// Vignette d'aperçu d'une apparence : une mini-carte et deux lignes, en clair, en sombre ou moitié-moitié.
private struct AppearanceThumbnail: View {
    let option: AppAppearance

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch option {
                case .light: mock(dark: false)
                case .dark: mock(dark: true)
                case .system:
                    mock(dark: false)
                    mock(dark: true).mask(alignment: .trailing) { Rectangle().frame(width: geo.size.width / 2) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func mock(dark: Bool) -> some View {
        let bg = Color(hex: dark ? 0x0E0D16 : 0xF6F5FB)
        let card = Color(hex: dark ? 0x1C1A2A : 0xFFFFFF)
        let ink = Color(hex: dark ? 0xF4F3FA : 0x1A1830)
        return ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(Color(hex: 0x6A4CFF)).frame(width: 22, height: 6)
                RoundedRectangle(cornerRadius: 4).fill(card).frame(height: 18)
                    .overlay(alignment: .leading) { Capsule().fill(ink.opacity(0.7)).frame(width: 26, height: 4).padding(.leading, 5) }
                Capsule().fill(ink.opacity(0.35)).frame(width: 34, height: 4)
            }
            .padding(9)
        }
    }
}
