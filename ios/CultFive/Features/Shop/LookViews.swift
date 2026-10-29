import SwiftUI
import CultFiveCore

// Look du joueur (D-120) : contours d'avatar, titres sous le pseudo, avatars premium, et décorations gagnées au
// classement (couronne du 1er, contours argent et bronze, flamme du top 10). Tout ce qui est payant se voit avant
// d'être acheté, posé sur ton propre avatar.

/// Ce qui entoure un avatar : rien, un contour acheté, ou la décoration d'un rang.
enum AvatarDecor: Equatable {
    case none
    case ring(AvatarRing)
    case rank(Int)
}

/// Le contour autour d'un avatar (même taille que le disque ; la couronne du 1er dépasse au-dessus).
struct ContourRing: View {
    let decor: AvatarDecor
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var width: CGFloat { max(2.5, size * 0.085) }

    var body: some View {
        switch decor {
        case .none:
            EmptyView()
        case .rank(let rank):
            rankRing(rank)
        case .ring(let ring):
            contour(ring)
        }
    }

    @ViewBuilder private func rankRing(_ rank: Int) -> some View {
        switch rank {
        case 1:
            ZStack(alignment: .top) {
                spinning(AngularGradient(colors: Self.gold + [Self.gold[0]], center: .center), period: 6)
                    .shadow(color: Color(hex: 0xFFC933).opacity(0.7), radius: size * 0.08)
                Image("arena_crown").resizable().scaledToFit()
                    .frame(width: size * 0.62)
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(-8))
            }
        case 2:
            Circle().strokeBorder(AngularGradient(colors: [Color(hex: 0xF4F7FB), Color(hex: 0xA9B4C2), Color(hex: 0xF4F7FB), Color(hex: 0x8D99A8), Color(hex: 0xF4F7FB)],
                                                  center: .center), lineWidth: width)
        case 3:
            Circle().strokeBorder(AngularGradient(colors: [Color(hex: 0xF0B07A), Color(hex: 0xA0582A), Color(hex: 0xF0B07A), Color(hex: 0x8A4A22), Color(hex: 0xF0B07A)],
                                                  center: .center), lineWidth: width)
        default:
            Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xFFD23F), Color(hex: 0xFF6B2C), Color(hex: 0xE03131)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: width * 0.8)
                .shadow(color: Color(hex: 0xFF6B2C).opacity(0.5), radius: size * 0.05)
        }
    }

    @ViewBuilder private func contour(_ ring: AvatarRing) -> some View {
        switch ring {
        case .neon:
            Circle().strokeBorder(AngularGradient(colors: [Color(hex: 0x00E5FF), Color(hex: 0xFF2BD6), Color(hex: 0x00E5FF)], center: .center),
                                  lineWidth: width)
                .shadow(color: Color(hex: 0x00E5FF).opacity(0.9), radius: size * 0.08)
                .shadow(color: Color(hex: 0xFF2BD6).opacity(0.6), radius: size * 0.12)
        case .gold:
            Circle().strokeBorder(AngularGradient(colors: Self.gold + [Self.gold[0]], center: .center), lineWidth: width * 1.15)
                .shadow(color: Color(hex: 0xFFC933).opacity(0.5), radius: size * 0.05)
        case .rainbow:
            spinning(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red], center: .center), period: 3)
        case .prestige:
            ZStack {
                spinning(AngularGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFC933), Color(hex: 0x7B5CFF), Color(hex: 0xFFC933), Color(hex: 0xFFF3B0)],
                                         center: .center), period: 4)
                    .shadow(color: Color(hex: 0xFFC933).opacity(0.8), radius: size * 0.1)
                Sparkles(size: size)
            }
        case .welcome:
            Circle().strokeBorder(AngularGradient(colors: [Color(hex: 0x3DDBD9), Color.sun, Color(hex: 0xFF7AB6), Color(hex: 0x3DDBD9)], center: .center),
                                  lineWidth: width)
        }
    }

    /// Contour qui tourne doucement (immobile si « Réduire les animations »).
    private func spinning(_ gradient: AngularGradient, period: Double) -> some View {
        Circle().strokeBorder(gradient, lineWidth: width * 1.1)
            .phaseAnimator(reduceMotion ? [0.0] : [0.0, 360.0]) { view, angle in
                view.rotationEffect(.degrees(angle))
            } animation: { angle in angle == 0 ? .linear(duration: 0) : .linear(duration: period) }
    }

    static let gold = [Color(hex: 0xFFF3B0), Color(hex: 0xFFC933), Color(hex: 0xC98A1B), Color(hex: 0xFFE680)]
}

/// Petites étoiles qui scintillent autour du contour Prestige.
private struct Sparkles: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * .pi / 2 + .pi / 4
                Image(systemName: "sparkle")
                    .font(.system(size: max(6, size * 0.14), weight: .black))
                    .foregroundStyle(Color(hex: 0xFFF3B0))
                    .offset(x: cos(angle) * size * 0.52, y: sin(angle) * size * 0.52)
                    .phaseAnimator(reduceMotion ? [1.0] : [0.3, 1.0]) { view, o in view.opacity(o).scaleEffect(o) }
                        animation: { _ in .easeInOut(duration: 0.9 + Double(i) * 0.2) }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Titre sous le pseudo : un petit ruban doré (Légende : violet et or).
struct PlayerTitleTag: View {
    let title: PlayerTitle
    var compact = false

    var body: some View {
        Text(title.text.uppercased())
            .font(.system(size: compact ? 8 : 10, weight: .black, design: .rounded))
            .tracking(0.6)
            .lineLimit(1)
            .foregroundStyle(title == .legend ? Color.white : Color.inkFixed)
            .padding(.horizontal, compact ? 5 : 7)
            .padding(.vertical, compact ? 1 : 2)
            .background(title == .legend ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)], startPoint: .leading, endPoint: .trailing))
                                         : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE680), Color(hex: 0xF2B705)], startPoint: .leading, endPoint: .trailing)),
                        in: Capsule())
            .overlay(Capsule().strokeBorder(title == .legend ? Color(hex: 0xFFC933) : .clear, lineWidth: 1))
            .accessibilityLabel("Titre : \(title.text)")
    }
}

extension PlayerTitle {
    /// Titre d'un avatar reçu du serveur, ou le mien.
    @MainActor
    static func of(_ avatar: JSONValue?, me: Bool) -> PlayerTitle? {
        if let title = PlayerTitle(avatar) { return title }
        return me ? MyAvatar.shared.title : nil
    }
}

// MARK: - Mon look

/// « Mon look » : ton avatar en grand tel que les autres le verront, trois rubriques (Personnage, Contour, Titre),
/// des cartes à toucher. Ce que tu possèdes se pose d'un appui ; le reste s'essaie, et une barre en bas propose de
/// l'acheter (D-120).
struct LookStudio: View {
    enum Tab: String, CaseIterable { case avatars = "Personnage", rings = "Contour", titles = "Titre" }

    var startTab: Tab = .avatars

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .avatars
    /// Essai en cours (pas encore à toi) : on voit comment ça rend.
    @State private var trial: Trial?
    @State private var busy = false

    enum Trial: Equatable {
        case animal(AnimalAvatar), ring(AvatarRing), title(PlayerTitle)
    }

    private var shop: ShopStore { app.shop }
    private var owned: Set<String> { Set(app.boutique?.looks ?? []) }
    private var handle: String { app.profile?.handle ?? "Toi" }

    private var shownAnimal: AnimalAvatar {
        if case .animal(let a) = trial { return a }
        return MyAvatar.shared.animal ?? .fallback(for: handle)
    }
    private var shownRing: AvatarRing? {
        if case .ring(let r) = trial { return r }
        return MyAvatar.shared.ring
    }
    private var shownTitle: PlayerTitle? {
        if case .title(let t) = trial { return t }
        return MyAvatar.shared.title
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                preview
                tabs
                switch tab {
                case .avatars: avatars
                case .rings: rings
                case .titles: titles
                }
                prestigeCard
                if let error = shop.errorMessage {
                    Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                }
            }
            .padding(Space.gutter)
            .padding(.bottom, trial == nil ? 0 : 90)
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background(Color.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) { trialBar }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(.black.opacity(0.25), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(Space.gutter + 8)
        }
        .presentationDetents([.large])
        .onAppear { tab = startTab }
        .task {
            await shop.loadProducts(force: true)
            await app.refreshBoutique()
        }
    }

    // MARK: Aperçu

    /// Ton avatar en grand, puis en tête d'un classement et dans une ligne ordinaire.
    private var preview: some View {
        VStack(spacing: Space.m) {
            Text("MON LOOK")
                .font(.system(.title, design: .rounded).weight(.black)).tracking(1)
                .foregroundStyle(.white)
            AnimalBadge(animal: shownAnimal, size: 120, decor: shownRing.map { .ring($0) } ?? .none)
                .animation(Motion.bounce, value: shownAnimal)
            VStack(spacing: 6) {
                Text(handle).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white).lineLimit(1)
                if let title = shownTitle { PlayerTitleTag(title: title) }
            }
            HStack(spacing: Space.s) {
                previewRow(rank: 1)
                previewRow(rank: 14)
            }
            Text("Choisis ton personnage, ton contour et ton titre")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(Space.m)
        .padding(.top, Space.s)
        .frame(maxWidth: .infinity)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func previewRow(rank: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(rank)").font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
            AnimalBadge(animal: shownAnimal, size: 30, decor: rank <= 10 ? .rank(rank) : (shownRing.map { .ring($0) } ?? .none))
            VStack(alignment: .leading, spacing: 1) {
                Text(handle).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                if let title = shownTitle { PlayerTitleTag(title: title, compact: true) }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
    }

    // MARK: Rubriques

    /// Trois grandes rubriques illustrées.
    private var tabs: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases, id: \.self) { item in
                let on = tab == item
                Button {
                    Haptics.selection()
                    withAnimation(Motion.standard) { tab = item }
                } label: {
                    VStack(spacing: 6) {
                        tabArt(item).frame(height: 50)
                        Text(item.rawValue)
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundStyle(on ? .white : Color.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(on ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color.paperRaised),
                                in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(on ? Color.clear : Color.hairline, lineWidth: 1.5))
                    .scaleEffect(on ? 1.03 : 1)
                }
                .buttonStyle(.row)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func tabArt(_ item: Tab) -> some View {
        switch item {
        case .avatars: AnimalBadge(animal: .galileo, size: 46)
        case .rings: AnimalBadge(animal: shownAnimal, size: 46, decor: .ring(.rainbow))
        case .titles: PlayerTitleTag(title: .genie).padding(.top, 12)
        }
    }

    // MARK: Personnages

    private var avatars: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            sectionTitle("Gratuits")
            avatarGrid(AnimalAvatar.free)
            HStack {
                sectionTitle("Premium")
                Spacer()
                if !AnimalAvatar.premium.allSatisfy({ owned.contains("avatar.\($0.rawValue)") }) {
                    HStack(spacing: 6) {
                        Text("Les 4").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                        PricePill(product: .avatars) { buy(.avatars) }
                    }
                }
            }
            avatarGrid(AnimalAvatar.premium)
            let exclusives = AnimalAvatar.exclusive.filter { owned.contains("avatar.\($0.rawValue)") }
            if !exclusives.isEmpty {
                sectionTitle("Exclusifs")
                avatarGrid(exclusives)
            }
        }
    }

    private func avatarGrid(_ list: [AnimalAvatar]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(list, id: \.self) { animal in
                avatarCard(animal)
            }
        }
    }

    private func avatarCard(_ animal: AnimalAvatar) -> some View {
        let has = animal.isFree || owned.contains("avatar.\(animal.rawValue)")
        let on = MyAvatar.shared.animal == animal
        let trying = trial == .animal(animal)
        return Button {
            Haptics.selection()
            if has {
                trial = nil
                Task { await app.setAvatar(animal) }
            } else {
                withAnimation(Motion.bounce) { trial = .animal(animal) }
            }
        } label: {
            VStack(spacing: 6) {
                AnimalBadge(animal: animal, size: 76)
                Text(animal.name)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                status(has: has, on: on, product: ShopProduct.avatar(animal))
            }
            .padding(.vertical, 10).padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(on ? Color.brand : trying ? Color.sun : Color.hairline, lineWidth: on || trying ? 3 : 1.5))
        }
        .buttonStyle(.row)
        .accessibilityLabel(animal.name + (has ? "" : ", à acheter"))
    }

    /// Sous une carte : « Porté », « Mettre », ou le prix.
    @ViewBuilder private func status(has: Bool, on: Bool, product: ShopProduct?) -> some View {
        if on {
            Label("Porté", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(Color.correct)
                .lineLimit(1)
        } else if has {
            Text("Mettre")
                .font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(Color.brand)
                .lineLimit(1)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "lock.fill").font(.system(size: 9, weight: .black))
                Text(product.flatMap { shop.price($0) } ?? "Essayer")
                    .font(.system(size: 12, weight: .black, design: .rounded)).monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(Color.inkFixed)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.sun, in: Capsule())
        }
    }

    // MARK: Contours et titres

    private var rings: some View {
        let list = AvatarRing.forSale + AvatarRing.allCases.filter { !AvatarRing.forSale.contains($0) && owned.contains("ring.\($0.rawValue)") }
        return VStack(alignment: .leading, spacing: Space.m) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                lookCard(name: "Aucun", has: true, on: MyAvatar.shared.ring == nil, trying: false, product: nil,
                         art: AnyView(AnimalBadge(animal: shownAnimal, size: 64))) { wear(kind: "ring", value: nil) }
                ForEach(list, id: \.self) { ring in
                    lookCard(name: ring.name, has: owned.contains("ring.\(ring.rawValue)"), on: MyAvatar.shared.ring == ring,
                             trying: trial == .ring(ring), product: ShopProduct.ring(ring),
                             art: AnyView(AnimalBadge(animal: shownAnimal, size: 64, decor: .ring(ring)))) {
                        if owned.contains("ring.\(ring.rawValue)") { wear(kind: "ring", value: ring.rawValue) }
                        else { withAnimation(Motion.bounce) { trial = .ring(ring) } }
                    }
                }
            }
            earnedRanks
        }
    }

    /// Les décorations qui se gagnent au classement (jamais à vendre).
    private var earnedRanks: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            sectionTitle("À gagner au classement")
            HStack(spacing: 0) {
                ForEach([1, 2, 3, 7], id: \.self) { rank in
                    VStack(spacing: 6) {
                        AnimalBadge(animal: shownAnimal, size: 54, decor: .rank(rank))
                            .padding(.top, rank == 1 ? 18 : 0)
                        Text(rank == 7 ? "Top 10" : "\(rank)\(rank == 1 ? "er" : "e")")
                            .font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, Space.s)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
    }

    private var titles: some View {
        let list = PlayerTitle.forSale + PlayerTitle.allCases.filter { !PlayerTitle.forSale.contains($0) && owned.contains("title.\($0.rawValue)") }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            lookCard(name: "Aucun", has: true, on: MyAvatar.shared.title == nil, trying: false, product: nil,
                     art: AnyView(Text(handle).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink))) {
                wear(kind: "title", value: nil)
            }
            ForEach(list, id: \.self) { title in
                lookCard(name: title.text, has: owned.contains("title.\(title.rawValue)"), on: MyAvatar.shared.title == title,
                         trying: trial == .title(title), product: ShopProduct.title(title),
                         art: AnyView(VStack(spacing: 4) {
                             Text(handle).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink).lineLimit(1)
                             PlayerTitleTag(title: title)
                         })) {
                    if owned.contains("title.\(title.rawValue)") { wear(kind: "title", value: title.rawValue) }
                    else { withAnimation(Motion.bounce) { trial = .title(title) } }
                }
            }
        }
    }

    private func lookCard(name: String, has: Bool, on: Bool, trying: Bool, product: ShopProduct?, art: AnyView,
                          action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 8) {
                art.frame(height: 74)
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                status(has: has, on: on, product: product)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(on ? Color.brand : trying ? Color.sun : Color.hairline, lineWidth: on || trying ? 3 : 1.5))
        }
        .buttonStyle(.row)
        .disabled(busy)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink).lineLimit(1)
    }

    // MARK: Barre d'essai

    /// En bas pendant un essai : ce que tu essaies, et « Acheter ».
    @ViewBuilder private var trialBar: some View {
        if let trial, let product = product(for: trial) {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu essaies").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.7))
                    Text(name(of: trial)).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                Button("Annuler") { withAnimation(Motion.standard) { self.trial = nil } }
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.85))
                PricePill(product: product, big: true) { buy(product) }
            }
            .padding(.horizontal, Space.m).padding(.vertical, 12)
            .background(Color.ink, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func product(for trial: Trial) -> ShopProduct? {
        switch trial {
        case .animal(let a): return ShopProduct.avatar(a)
        case .ring(let r): return ShopProduct.ring(r)
        case .title(let t): return ShopProduct.title(t)
        }
    }

    private func name(of trial: Trial) -> String {
        switch trial {
        case .animal(let a): return a.name
        case .ring(let r): return "Contour \(r.name)"
        case .title(let t): return "Titre « \(t.text) »"
        }
    }

    // MARK: Prestige

    /// Le Pack Prestige montré en images : tout ce qu'il contient.
    @ViewBuilder private var prestigeCard: some View {
        if !owned.contains("ring.prestige") {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Text("PACK PRESTIGE")
                        .font(.system(.title2, design: .rounded).weight(.black)).tracking(0.5)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color.sun], startPoint: .top, endPoint: .bottom))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Text("TOUT INCLUS")
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.5)
                        .foregroundStyle(Color.inkFixed)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.sun, in: Capsule())
                }
                prestigeRow("6 personnages") {
                    ForEach(AnimalAvatar.premium + [.tut, .athena], id: \.self) { animal in
                        AnimalBadge(animal: animal, size: 44, decor: animal == .tut || animal == .athena ? .ring(.prestige) : .none)
                    }
                }
                prestigeRow("4 contours") {
                    ForEach(AvatarRing.forSale + [.prestige], id: \.self) { ring in
                        AnimalBadge(animal: shownAnimal, size: 44, decor: .ring(ring))
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("4 titres").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.75))
                    FlowLayout(spacing: 6) {
                        ForEach(PlayerTitle.forSale + [.legend], id: \.self) { PlayerTitleTag(title: $0) }
                    }
                }
                BuyButton(title: "Tout débloquer", price: shop.price(.prestige), busy: shop.purchasing == .prestige, enabled: !shop.busy) {
                    buy(.prestige)
                }
                Text("Toutânkhamon, Athéna, le contour Prestige et le titre « Légende » sont introuvables ailleurs.")
                    .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)
            .background(PassPlusFill(), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(Color(hex: 0xFFC933), lineWidth: 2))
            .shadow(color: Color(hex: 0x2A1490).opacity(0.35), radius: 16, y: 8)
        }
    }

    private func prestigeRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 6) { content() }
                .padding(.top, 2)
        }
    }

    // MARK: Actions

    private func buy(_ product: ShopProduct) {
        Task {
            if await shop.purchase(product) {
                Haptics.success()
                await app.refreshBoutique()
                // Ce qui était à l'essai (et vient d'être acheté) est posé tout de suite.
                let bought: Trial? = trial.flatMap { tried in
                    if self.product(for: tried) == product || product == .prestige { return tried }
                    if product == .avatars, case .animal(let a) = tried, AnimalAvatar.premium.contains(a) { return tried }
                    return nil
                }
                switch bought {
                case .animal(let a): await app.setAvatar(a)
                case .ring(let r): await app.setLook(kind: "ring", value: r.rawValue)
                case .title(let t): await app.setLook(kind: "title", value: t.rawValue)
                case nil: break
                }
                trial = nil
                app.show("C'est à toi !")
            }
        }
    }

    private func wear(kind: String, value: String?) {
        busy = true
        trial = nil
        Task {
            await app.setLook(kind: kind, value: value)
            busy = false
        }
    }
}
