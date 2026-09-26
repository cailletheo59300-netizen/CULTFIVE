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
        .padding(.top, Space.s)
        .background(Color.paper.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline() }
    }

    private func item(_ tab: AppModel.Tab, title: String, symbol: String, selectedSymbol: String) -> some View {
        Button {
            guard selection != tab else { return }
            Haptics.selection()
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == tab ? selectedSymbol : symbol)
                    .font(.system(size: 19, weight: .medium))
                    .frame(height: 24)
                Text(title).font(.system(.caption2).weight(.semibold))
            }
            .foregroundStyle(selection == tab ? Color.ink : Color.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    /// Le « 5 » : pastille d'encre portant le trait de cinq, légèrement surélevée.
    private var centerItem: some View {
        Button {
            Haptics.soft()
            selection = .daily
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.inkFixed)
                        .frame(width: 64, height: 56)
                        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                    TallyMark(strokes: centerStrokes, onInk: true, lineWidth: 3)
                        .frame(width: 30)
                }
                .offset(y: -10)
                .padding(.bottom, -10)
                Text(daily?.state == .done ? "Fait" : Brand.dailyName)
                    .font(.system(.caption2).weight(.semibold))
                    .foregroundStyle(selection == .daily ? Color.ink : Color.inkSoft)
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
