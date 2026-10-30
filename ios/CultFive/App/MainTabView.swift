import SwiftUI
import CultFiveCore

/// Navigation principale : Jouer · Album · 5 DU JOUR · Arène · Profil. Le 5 du jour est l'objet central.
/// Dans les builds de test, l'onglet Album s'ajoute à côté de Jouer (aperçu, collection simulée).
struct MainTabView: View {
    @Environment(AppModel.self) private var model
    /// Hauteur réelle de la barre flottante, mesurée (elle varie avec la taille du texte et l'appareil).
    @State private var barHeight: CGFloat = 70

    /// Espace à laisser sous le contenu : la barre, la bulle du 5 qui en dépasse, et de l'air.
    /// Une marge posée autour des onglets n'atteint pas les défilements (chaque onglet a sa pile de navigation) :
    /// la valeur passe par l'environnement et chaque page défilante l'applique elle-même (`clearsTabBar()`).
    private var clearance: CGFloat { barHeight + CultTabBar.bubbleOverflow + Space.m }

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            tab(PlayHomeView(), .play)
            tab(AlbumView(), .album)
            tab(DailyHomeView(), .daily)
            tab(FriendsView(), .friends)
            tab(ProfileView(), .profile)
        }
        .overlay(alignment: .bottom) {
            CultTabBar(selection: $model.tab, daily: model.daily, arenaAlert: model.arenaAlert,
                       albumAlert: AlbumStore.shared.claimableCount > 0) { model.reselect($0) }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
        }
        // Réseau coupé : un petit bandeau en haut, les écrans gardent ce qu'ils affichaient.
        .overlay(alignment: .top) {
            if model.networkTrouble { NetworkBanner() }
        }
        // Visite guidée d'un écran (première visite, ou bouton « ? »).
        .overlay { TourOverlay() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environment(\.tabBarClearance, clearance)
        .fullScreenCover(isPresented: Binding(get: { model.chestQueue != nil }, set: { if !$0 { model.chestQueue = nil } })) {
            ChestOpeningView(chests: model.chestQueue ?? []) {
                model.chestQueue = nil
                Task {
                    await model.refreshProfile()
                    // Un coffre peut donner des tickets de pochette, une carte ou un jeton Prestige.
                    await AlbumStore.shared.refresh()
                }
            }
        }
        .sheet(isPresented: $model.showPassPlus) { PassPlusView() }
        .fullScreenCover(isPresented: $model.showShop) { ShopView(focus: model.shopFocus) }
        .sheet(isPresented: $model.showNoAdsPrompt) { NoAdsPrompt() }
        // « Marre des pubs ? » attend que la partie soit refermée (rien de présenté au-dessus des onglets).
        .task(id: model.pendingNoAdsPrompt) {
            guard model.pendingNoAdsPrompt else { return }
            for _ in 0..<600 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if Self.nothingPresented {
                    model.pendingNoAdsPrompt = false
                    model.showNoAdsPrompt = true
                    return
                }
            }
            model.pendingNoAdsPrompt = false
        }
        .task {
            await model.refreshProgression()
            await model.refreshBoutique()
            await AlbumStore.shared.refresh()
            model.promoteSeasonIfNeeded()
        }
    }

    /// Aucun écran présenté au-dessus des onglets (partie, feuille, pub).
    private static var nothingPresented: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return window?.rootViewController?.presentedViewController == nil
    }

    private func tab(_ content: some View, _ tag: AppModel.Tab) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
            .tag(tag)
    }
}

struct CultTabBar: View {
    @Binding var selection: AppModel.Tab
    let daily: DailyStatus?
    /// Pastille rouge sur l'Arène : un résultat de duel ou les récompenses du lundi à voir.
    var arenaAlert = false
    /// Pastille rouge sur l'Album : des cadeaux du pass à récupérer (D-118).
    var albumAlert = false
    /// Onglet touché alors qu'il est déjà ouvert : retour à sa page de départ.
    var onReselect: (AppModel.Tab) -> Void = { _ in }

    /// La bulle du 5 dépasse de la barre : décalage de 22 pt, moins la marge intérieure de 6 pt.
    static let bubbleOverflow: CGFloat = 16

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            item(.play, title: "Jouer", symbol: "shuffle", selectedSymbol: "shuffle")
            item(.album, title: "Album", symbol: "books.vertical", selectedSymbol: "books.vertical.fill", badge: albumAlert)
            centerItem
            item(.friends, title: "Arène", symbol: "trophy", selectedSymbol: "trophy.fill", badge: arenaAlert)
            item(.profile, title: "Profil", symbol: "person.crop.circle", selectedSymbol: "person.crop.circle.fill")
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, 6)
        .background(Color.paperRaised, in: Capsule())
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.12), radius: 18, y: 8)
        .padding(.horizontal, Space.m)
        .padding(.bottom, 4)
        .background(alignment: .bottom) {
            // Fondu sous la barre flottante pour que le contenu ne s'y heurte pas.
            LinearGradient(colors: [Color.paper.opacity(0), Color.paper], startPoint: .top, endPoint: .bottom)
                .frame(height: 70)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private func item(_ tab: AppModel.Tab, title: String, symbol: String, selectedSymbol: String, badge: Bool = false) -> some View {
        Button {
            guard selection != tab else { return onReselect(tab) }
            Haptics.selection()
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selection == tab ? selectedSymbol : symbol)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .frame(height: 24)
                    .symbolEffect(.bounce, value: selection == tab)
                    .overlay(alignment: .topTrailing) {
                        if badge && selection != tab {
                            Circle().fill(Color.wrong).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.paperRaised, lineWidth: 2))
                                .offset(x: 6, y: -2)
                                .accessibilityHidden(true)
                        }
                    }
                Text(title).font(.system(.caption2, design: .rounded).weight(.heavy))
            }
            .foregroundStyle(selection == tab ? Color.brand : Color.inkSoft.opacity(0.8))
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    /// Le « 5 » : bulle violette portant le trait de cinq, qui dépasse de la barre.
    private var centerItem: some View {
        Button {
            Haptics.soft()
            if selection == .daily { onReselect(.daily) }
            selection = .daily
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Color.popGradient)
                        .frame(width: 62, height: 62)
                        .overlay(Circle().stroke(Color.paperRaised, lineWidth: 4))
                        .shadow(color: Color.brand.opacity(0.4), radius: 10, y: 5)
                    TallyMark(strokes: centerStrokes, onInk: true, lineWidth: 3.5)
                        .frame(width: 28)
                }
                .offset(y: -22)
                .padding(.bottom, -22)
                Text(daily?.state == .done ? "Fait" : Brand.dailyName)
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(selection == .daily ? Color.brand : Color.inkSoft.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(daily?.state == .done ? "5 du jour, terminé aujourd'hui" : "5 du jour")
        .accessibilityAddTraits(selection == .daily ? .isSelected : [])
    }

    private var centerStrokes: [TallyStroke] {
        guard let daily else { return [.correct, .correct, .correct, .correct, .ready] }
        switch daily.state {
        case .available: return [.correct, .correct, .correct, .correct, .ready]
        case .inProgress, .done: return daily.answers.map { $0 ? .correct : .wrong }
        }
    }
}

/// « Connexion difficile » : discret, avec « Réessayer » ; disparaît dès qu'une requête passe.
struct NetworkBanner: View {
    @Environment(AppModel.self) private var app
    @State private var retrying = false

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 14, weight: .bold)).accessibilityHidden(true)
            Text("Connexion difficile").font(.system(.footnote, design: .rounded).weight(.heavy))
            Button {
                retrying = true
                Task {
                    await app.retryNetwork()
                    retrying = false
                }
            } label: {
                if retrying {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Text("Réessayer").font(.system(.footnote, design: .rounded).weight(.black)).underline()
                }
            }
            .buttonStyle(.plain)
            .disabled(retrying)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.inkFixed.opacity(0.88), in: Capsule())
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

extension EnvironmentValues {
    /// Hauteur occupée par la barre d'onglets flottante au-dessus de la zone sûre (0 hors des onglets).
    @Entry var tabBarClearance: CGFloat = 0
}

extension View {
    /// À poser sur le défilement de chaque page affichée sous la barre d'onglets (onglets et pages poussées).
    func clearsTabBar() -> some View { modifier(TabBarClearance()) }
}

private struct TabBarClearance: ViewModifier {
    @Environment(\.tabBarClearance) private var clearance

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, clearance, for: .scrollContent)
    }
}
