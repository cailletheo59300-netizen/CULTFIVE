import SwiftUI
import CultFiveCore

// Jeu entre amis (D-112) : défier un ami en un appui (7 questions, 25 s), ce qui se passe entre nous (étiquette dans
// le classement des amis), la carte d'invitation quand on n'a pas encore d'amis, et l'historique de tous les duels entre amis.
// Les duels entre amis ne rapportent pas de points de la semaine : ils se jouent pour l'honneur, et l'historique les garde.

// MARK: - Ce qui se passe avec un ami

/// L'étiquette d'un ami : un défi qui m'attend, ou le score des 30 derniers jours.
struct FriendDuelBadge: Equatable {
    enum Tone { case action, ahead, behind, even }

    let text: String
    let tone: Tone

    var color: Color {
        switch tone {
        case .action: return .brand
        case .ahead: return .correct
        case .behind: return Color(hex: 0xF76707)
        case .even: return .inkSoft
        }
    }

    /// `duels` : la liste « duels_mine » (30 derniers jours, sans l'Arène).
    static func make(friend: UUID, duels: [Duel]) -> FriendDuelBadge? {
        let ours = duels.filter { $0.opponent?.id == friend }
        if let waiting = ours.first(where: { $0.myTurn }) {
            if !waiting.iAmChallenger && waiting.me.answered == 0 { return FriendDuelBadge(text: "t'a défié !", tone: .action) }
            return FriendDuelBadge(text: "à toi de jouer", tone: .action)
        }
        let done = ours.filter(\.isFinished)
        guard !done.isEmpty else { return nil }
        let wins = done.filter { $0.winner == "me" }.count
        let losses = done.filter { $0.winner == "opponent" }.count
        if wins > losses { return FriendDuelBadge(text: "\(wins)–\(losses) pour toi", tone: .ahead) }
        if losses > wins { return FriendDuelBadge(text: "\(wins)–\(losses)", tone: .behind) }
        return FriendDuelBadge(text: "\(wins)–\(losses)", tone: .even)
    }
}

// MARK: - Carte « Invite un ami »

/// Quand on n'a pas encore d'amis : une grande carte pour en faire venir (lien d'invitation, pseudo, défi par lien).
struct InviteFriendsCard: View {
    let code: String?
    let onAdd: () -> Void
    let onLinkDuel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Joue contre tes amis").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                    Text("Ton ami reçoit 100 \(Brand.currencyPlural) en arrivant, toi 150 quand il joue son 1er \(Brand.dailyName).")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: -14) {
                    Leon(color: .sun, pose: .wave).frame(width: 58)
                    Leon(color: Color(hex: 0xFF8FB1), pose: .curious).frame(width: 58)
                }
                .accessibilityHidden(true)
            }
            if let code {
                ShareLink(item: Brand.inviteURL(code: code),
                          message: Text("Viens me défier sur \(Brand.name) ! 7 questions, 25 s chacune : on verra qui en sait le plus.")) {
                    Label("Inviter un ami", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.sun)
            }
            HStack(spacing: 10) {
                Button(action: onAdd) {
                    Label("Par pseudo", systemImage: "magnifyingglass").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SmallPillStyle(fill: .white.opacity(0.14), text: .white))
                Button(action: onLinkDuel) {
                    Label("Défi par lien", systemImage: "link").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SmallPillStyle(fill: .white.opacity(0.14), text: .white))
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(hex: 0x5B3BF5), Color(hex: 0x3A1FB8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.3), radius: 14, y: 8)
    }
}

// MARK: - Page « Contre un ami »

/// Page « Contre un ami » (plein écran, D-114) : 1. le format (Arène ou libre, avec ses réglages), 2. l'ami à défier
/// (un bouton « Défier » sous chaque avatar), puis « Ajouter un ami par son pseudo » en grand et « Défier par lien ».
struct FriendChallengeSheet: View {
    let friends: [Friend]
    let duels: [Duel]
    /// Duel créé : la page se ferme, l'écran appelant l'ouvre.
    let onCreated: (Duel) -> Void
    let onAddFriend: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var settings = DuelSettings.arena
    @State private var busy: UUID?
    @State private var linkBusy = false
    @State private var error: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contre un ami").font(.cfDisplay)
                        Text("Pas de points de la semaine : juste l'honneur, et votre historique.")
                            .font(.cfCallout).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        step(1, "Choisis le format")
                        DuelFormatPicker(settings: $settings)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        step(2, "Choisis ton ami")
                        if friends.isEmpty {
                            Text("Pas encore d'amis ici : ajoute-les par leur pseudo, juste en dessous.")
                                .font(.cfCallout).foregroundStyle(Color.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Touche « Défier » : ton ami reçoit le défi tout de suite.")
                                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(friends) { friend in friendCard(friend) }
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            onAddFriend()
                        } label: {
                            Text("Ajouter un ami par son pseudo").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ink)
                        Button { create(friend: nil) } label: {
                            HStack(spacing: 8) {
                                if linkBusy { ProgressView().controlSize(.small) }
                                Text("Défier par lien")
                            }
                            .font(.system(.callout, design: .rounded).weight(.black))
                            .foregroundStyle(Color.brand)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(Capsule().strokeBorder(Color.brand.opacity(0.35), lineWidth: 1.5))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.row)
                        .disabled(busy != nil || linkBusy)
                        Text("Avec le lien, tu joues d'abord, puis tu l'envoies à qui tu veux.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                }
                .padding(Space.gutter)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    private func step(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.brand, in: Circle())
            Text(title).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// Carte d'un ami : son avatar, son pseudo, et un vrai bouton « Défier ».
    private func friendCard(_ friend: Friend) -> some View {
        let badge = FriendDuelBadge.make(friend: friend.id, duels: duels)
        return Button { create(friend: friend.id) } label: {
            VStack(spacing: 8) {
                ArenaAvatar(handle: friend.handle, size: 62, ring: badge?.tone == .action ? Color.brand : nil, avatar: friend.avatar)
                Text(friend.handle).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                ZStack {
                    if busy == friend.id {
                        ProgressView().tint(.white)
                    } else {
                        Text("Défier").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Color.brand, in: Capsule())
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(badge?.tone == .action ? Color.brand.opacity(0.5) : Color.hairline, lineWidth: 1.5))
        }
        .buttonStyle(.row)
        .disabled(busy != nil || linkBusy)
        .accessibilityLabel("Défier \(friend.handle)")
    }

    private func create(friend: UUID?) {
        error = nil
        if let friend { busy = friend } else { linkBusy = true }
        Task {
            do {
                let duel = try await app.service.duelCreate(friend: friend, settings: settings)
                Haptics.soft()
                onCreated(duel)
            } catch {
                self.error = error.userMessage("Impossible de lancer le duel.")
            }
            busy = nil
            linkBusy = false
        }
    }
}

// MARK: - Face-à-face (profil d'un ami)

/// Bilan entre deux amis : les deux joueurs face à face, le score des victoires, une barre de partage, puis les chiffres.
struct HeadToHeadCard: View {
    let me: String
    let friend: String
    var friendAvatar: JSONValue? = nil
    let h: FriendProfile.HeadToHead

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Face-à-face").labelCaps()
                Spacer()
                if h.played > 0 {
                    Text("\(h.played) duel\(h.played > 1 ? "s" : "")").font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            HStack(alignment: .center, spacing: 0) {
                player(me, avatarMe: true, wins: h.wins, leads: h.wins > h.losses)
                VStack(spacing: 2) {
                    Text("\(h.wins) – \(h.losses)")
                        .font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color.ink)
                    Text(h.draws > 0 ? "\(h.draws) égalité\(h.draws > 1 ? "s" : "")" : "victoires")
                        .font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                }
                .frame(minWidth: 110)
                player(friend, avatarMe: false, wins: h.losses, leads: h.losses > h.wins)
            }
            if h.played == 0 {
                Text("Pas encore de duel terminé entre vous. Lance le premier !")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            } else {
                shareBar
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    if let mine = h.myRate, let theirs = h.theirRate {
                        stat("Bonnes réponses", "\(mine) % · \(theirs) %")
                    }
                    if let streak = h.streak, streak.count >= 2 {
                        stat("Série en cours", streak.who == "me" ? "\(streak.count) pour toi" : "\(streak.count) pour \(friend)")
                    }
                    if let best = h.myBest { stat("Ton record", "\(best.score)/\(best.total)") }
                    stat("Questions jouées", "\(h.questions)")
                }
            }
        }
        .popCard(padding: 16, radius: 22)
        .accessibilityElement(children: .combine)
    }

    private func player(_ handle: String, avatarMe: Bool, wins: Int, leads: Bool) -> some View {
        VStack(spacing: 6) {
            ArenaAvatar(handle: handle, size: 54, ring: leads ? ArenaPalette.gold : nil, me: avatarMe,
                        avatar: avatarMe ? nil : friendAvatar)
                .overlay(alignment: .top) {
                    if leads { ArenaCrown(size: 22).offset(y: -14) }
                }
            Text(avatarMe ? "Toi" : handle).font(.system(.footnote, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Part des victoires de chacun (les égalités au milieu, en gris).
    private var shareBar: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(h.played, 1))
            HStack(spacing: 3) {
                if h.wins > 0 { Capsule().fill(ArenaPalette.me).frame(width: proxy.size.width * CGFloat(h.wins) / total) }
                if h.draws > 0 { Capsule().fill(Color.hairline).frame(width: proxy.size.width * CGFloat(h.draws) / total) }
                if h.losses > 0 { Capsule().fill(ArenaPalette.them) }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
            Text(value).font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Historique

/// Une ligne d'historique : l'adversaire, la date et le format, le score, une pastille de résultat.
struct DuelHistoryRow: View {
    let duel: Duel
    /// Dans le profil d'un ami : la date à la place du pseudo.
    var showsOpponent = true

    var body: some View {
        HStack(spacing: 12) {
            ArenaAvatar(handle: duel.opponent?.handle ?? "?", size: 40, avatar: duel.opponent?.avatar)
                .opacity(showsOpponent ? 1 : 0)
                .frame(width: showsOpponent ? 40 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(showsOpponent ? (duel.opponent?.handle ?? "Défi par lien") : DuelText.day(duel))
                    .font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink).lineLimit(1)
                Text(showsOpponent ? "\(DuelText.day(duel)) · \(DuelText.format(duel))" : DuelText.format(duel))
                    .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 6)
            if duel.isFinished {
                Text("\(duel.me.score) – \(duel.opponent?.score ?? 0)")
                    .font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(Color.ink)
            }
            pill
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var pill: some View {
        let (text, fill, ink): (String, Color, Color) = {
            switch duel.winner {
            case "me": return ("Gagné", Color.correct, .white)
            case "opponent": return ("Perdu", Color.wrong.opacity(0.14), .wrong)
            case "draw": return ("Égalité", Color.hairline, .inkSoft)
            default:
                if duel.myTurn { return ("À jouer", Color.brand, .white) }
                if duel.status == "expired" { return ("Expiré", Color.hairline, .inkSoft) }
                return ("En cours", Color.brand.opacity(0.12), .brand)
            }
        }()
        return Text(text)
            .font(.system(.caption, design: .rounded).weight(.black))
            .foregroundStyle(ink)
            .frame(minWidth: 62, minHeight: 26)
            .background(fill, in: Capsule())
    }
}

/// Tous les duels entre amis terminés : le bilan, les adversaires les plus fréquents, puis les duels mois par mois.
struct DuelHistoryView: View {
    @Environment(AppModel.self) private var app
    @State private var duels: [Duel] = []
    @State private var summary: DuelHistory.Summary?
    @State private var next: String?
    @State private var loaded = false
    @State private var loadingMore = false
    @State private var error: String?
    @State private var opened: DuelLaunch?
    @State private var rematchError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Historique").font(.cfDisplay).padding(.top, Space.s)
                if !loaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Space.xl)
                } else if let error, duels.isEmpty {
                    RetryMessage(text: error) { Task { await load() } }
                } else if duels.isEmpty {
                    empty
                } else {
                    if let summary = summary ?? localSummary { summaryCard(summary) }
                    if let rivals = summary?.rivals, !rivals.isEmpty { rivalsBlock(rivals) }
                    ForEach(months) { month in
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text(month.title).labelCaps()
                            VStack(spacing: 0) {
                                ForEach(Array(month.duels.enumerated()), id: \.element.id) { index, duel in
                                    if index > 0 { Hairline().padding(.leading, 64) }
                                    Button { opened = DuelLaunch(id: duel.id) } label: { DuelHistoryRow(duel: duel) }
                                        .buttonStyle(.row)
                                }
                            }
                            .popCard(padding: 0, radius: 20)
                        }
                    }
                    if next != nil {
                        Button { Task { await loadMore() } } label: {
                            HStack(spacing: 8) {
                                if loadingMore { ProgressView().controlSize(.small) }
                                Text("Voir les duels plus anciens")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TextLinkStyle())
                        .disabled(loadingMore)
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .clearsTabBar()
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { await load() } }
        .refreshable { await load() }
        .fullScreenCover(item: $opened, onDismiss: { Task { await load() } }) { launch in
            DuelSessionView(duelId: launch.id)
        }
    }

    private func load() async {
        do {
            let page = try await app.service.duelsHistory(before: nil)
            duels = page.duels
            summary = page.summary
            next = page.next
            error = nil
        } catch {
            self.error = error.userMessage("Historique indisponible.")
        }
        loaded = true
    }

    private func loadMore() async {
        guard let cursor = next, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let page = try? await app.service.duelsHistory(before: cursor) {
            let known = Set(duels.map(\.id))
            duels += page.duels.filter { !known.contains($0.id) }
            next = page.next
        }
    }

    /// Bilan calculé sur la liste quand le serveur n'en donne pas (mode démo).
    private var localSummary: DuelHistory.Summary? {
        let done = duels.filter(\.isFinished)
        guard !done.isEmpty else { return nil }
        return DuelHistory.Summary(played: done.count, wins: done.filter { $0.winner == "me" }.count,
                                   losses: done.filter { $0.winner == "opponent" }.count,
                                   draws: done.filter { $0.winner == "draw" }.count)
    }

    private struct Month: Identifiable {
        let title: String
        var duels: [Duel]
        var id: String { title }
    }

    private var months: [Month] {
        var result: [Month] = []
        for duel in duels {
            let title = DuelText.month(duel)
            if let last = result.indices.last, result[last].title == title {
                result[last].duels.append(duel)
            } else {
                result.append(Month(title: title, duels: [duel]))
            }
        }
        return result
    }

    private var empty: some View {
        VStack(spacing: Space.m) {
            Leon(color: .brand, pose: .curious).frame(width: 110)
            Text("Pas encore de duel terminé").font(.cfTitle3)
            Text("Défie un ami : chaque duel terminé s'ajoute ici, avec le score et la date.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.l)
    }

    private func summaryCard(_ s: DuelHistory.Summary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.played)").font(.system(size: 40, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text("duel\(s.played > 1 ? "s" : "") entre amis").font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(.white.opacity(0.8))
            }
            HStack(spacing: 10) {
                tally("Victoires", s.wins, color: Color.sun)
                tally("Égalités", s.draws, color: .white.opacity(0.85))
                tally("Défaites", s.losses, color: Color(hex: 0xFF9E7A))
            }
            if s.played > 0 {
                Text("\(Int((Double(s.wins) * 100 / Double(s.played)).rounded())) % de victoires")
                    .font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ArenaPalette.night, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tally(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rivalsBlock(_ rivals: [DuelHistory.Rival]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Tes rivaux").labelCaps()
            HStack(spacing: 10) {
                ForEach(rivals) { rival in
                    VStack(spacing: 6) {
                        ArenaAvatar(handle: rival.handle, size: 46, avatar: rival.avatar)
                        Text(rival.handle).font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(rival.wins) – \(rival.losses)").font(.system(.footnote, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(rival.wins > rival.losses ? Color.correct : rival.wins < rival.losses ? Color(hex: 0xF76707) : .inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
                ForEach(0..<max(0, 3 - rivals.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
            }
        }
    }
}

/// Tous nos duels avec un ami (« Voir plus » de son profil) : une vraie page, du plus récent au plus ancien.
struct FriendDuelsPage: View {
    let handle: String
    let duels: [Duel]
    @State private var opened: DuelLaunch?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Contre \(handle)").font(.cfDisplay).padding(.top, Space.s)
                VStack(spacing: 0) {
                    ForEach(Array(duels.enumerated()), id: \.element.id) { index, duel in
                        if index > 0 { Hairline().padding(.leading, 12) }
                        Button { opened = DuelLaunch(id: duel.id) } label: { DuelHistoryRow(duel: duel, showsOpponent: false) }
                            .buttonStyle(.row)
                    }
                }
                .popCard(padding: 0, radius: 20)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .clearsTabBar()
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $opened) { launch in DuelSessionView(duelId: launch.id) }
    }
}
