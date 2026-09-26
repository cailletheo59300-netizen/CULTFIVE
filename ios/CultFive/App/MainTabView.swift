import SwiftUI
import CultFiveCore

/// Navigation principale : Jouer · 5 DU JOUR · Amis · Profil. Le 5 du jour est l'objet central.
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            PlayHomeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppModel.Tab.play)
            DailyHomeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppModel.Tab.daily)
            FriendsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppModel.Tab.friends)
            ProfileView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppModel.Tab.profile)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CultTabBar(selection: $model.tab, daily: model.daily)
        }
    }
}

struct CultTabBar: View {
    @Binding var selection: AppModel.Tab
    let daily: DailyStatus?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            item(.play, title: "Jouer", symbol: "shuffle", selectedSymbol: "shuffle")
            centerItem
            item(.friends, title: "Amis", symbol: "person.2", selectedSymbol: "person.2.fill")
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

    private func item(_ tab: AppModel.Tab, title: String, symbol: String, selectedSymbol: String) -> some View {
        Button {
            guard selection != tab else { return }
            Haptics.selection()
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selection == tab ? selectedSymbol : symbol)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .frame(height: 24)
                    .symbolEffect(.bounce, value: selection == tab)
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
