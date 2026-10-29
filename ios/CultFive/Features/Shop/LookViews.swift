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

/// « Mon look » : un aperçu de ton avatar dans un classement, puis les personnages, contours et titres. Ce que tu
/// possèdes se pose d'un appui ; le reste s'essaie dans l'aperçu et s'achète en dessous (D-120).
struct LookStudio: View {
    enum Tab: String, CaseIterable { case avatars = "Personnages", rings = "Contours", titles = "Titres" }

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .avatars
    /// Essai en cours (pas encore posé) : on voit comment ça rend.
    @State private var tryAnimal: AnimalAvatar?
    @State private var tryRing: AvatarRing??
    @State private var tryTitle: PlayerTitle??
    @State private var busy = false

    private var shop: ShopStore { app.shop }
    private var owned: Set<String> { Set(app.boutique?.looks ?? []) }
    private var handle: String { app.profile?.handle ?? "Toi" }

    private var shownAnimal: AnimalAvatar { tryAnimal ?? MyAvatar.shared.animal ?? .fallback(for: handle) }
    private var shownRing: AvatarRing? { tryRing ?? MyAvatar.shared.ring }
    private var shownTitle: PlayerTitle? { tryTitle ?? MyAvatar.shared.title }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    preview
                    Picker("Rubrique", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
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
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .background(Color.paper)
            .navigationTitle("Mon look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
        .task {
            await shop.loadProducts()
            await app.refreshBoutique()
        }
    }

    // MARK: Aperçu

    /// Ton avatar tel que les autres le verront : en tête d'un classement et dans une ligne ordinaire.
    private var preview: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.l) {
                VStack(spacing: 6) {
                    AnimalBadge(animal: shownAnimal, size: 92, decor: shownRing.map { .ring($0) } ?? .none)
                    Text(handle).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
                    if let title = shownTitle { PlayerTitleTag(title: title) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Au classement").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.7))
                    previewRow(rank: 1)
                    previewRow(rank: 14)
                }
            }
            if tryAnimal != nil || tryRing != nil || tryTitle != nil {
                Text("Essai : touche « Mettre » ou achète-le pour le garder.")
                    .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.sun)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func previewRow(rank: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(rank)").font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.8)).frame(width: 20)
            AnimalBadge(animal: shownAnimal, size: 34, decor: rank <= 10 ? .rank(rank) : (shownRing.map { .ring($0) } ?? .none))
            VStack(alignment: .leading, spacing: 2) {
                Text(handle).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(.white).lineLimit(1)
                if let title = shownTitle { PlayerTitleTag(title: title, compact: true) }
            }
        }
    }

    // MARK: Personnages

    private var avatars: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            grid(AnimalAvatar.free, owned: { _ in true })
            HStack {
                Text("Premium").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                Spacer()
                if !AnimalAvatar.premium.allSatisfy({ owned.contains("avatar.\($0.rawValue)") }) {
                    buyChip("Les 4 · \(shop.price(.avatars) ?? "…")", product: .avatars)
                }
            }
            grid(AnimalAvatar.premium, owned: { owned.contains("avatar.\($0.rawValue)") })
            let exclusives = AnimalAvatar.exclusive.filter { owned.contains("avatar.\($0.rawValue)") }
            if !exclusives.isEmpty {
                Text("Exclusifs").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                grid(exclusives, owned: { _ in true })
            }
        }
    }

    private func grid(_ list: [AnimalAvatar], owned: @escaping (AnimalAvatar) -> Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
            ForEach(list, id: \.self) { animal in
                let has = owned(animal)
                let on = MyAvatar.shared.animal == animal
                Button {
                    Haptics.selection()
                    if has {
                        tryAnimal = nil
                        Task { await app.setAvatar(animal) }
                    } else {
                        withAnimation(Motion.bounce) { tryAnimal = animal }
                    }
                } label: {
                    VStack(spacing: 4) {
                        AnimalBadge(animal: animal, size: 64, ring: on ? Color.brand : (tryAnimal == animal ? Color.sun : nil))
                            .overlay(alignment: .topTrailing) {
                                if !has { Image(systemName: "lock.fill").font(.system(size: 10, weight: .black)).foregroundStyle(Color.inkFixed)
                                    .padding(4).background(Color.sun, in: Circle()) }
                            }
                        Text(animal.name).font(.system(size: 11, weight: on ? .black : .bold, design: .rounded))
                            .foregroundStyle(on ? Color.brand : Color.ink).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                        if !has, let product = ShopProduct.avatar(animal) {
                            buyChip(shop.price(product) ?? "…", product: product, small: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.row)
                .accessibilityLabel(animal.name + (has ? "" : ", à acheter"))
            }
        }
    }

    // MARK: Contours et titres

    private var rings: some View {
        let list = AvatarRing.forSale + AvatarRing.allCases.filter { !AvatarRing.forSale.contains($0) && owned.contains("ring.\($0.rawValue)") }
        return VStack(spacing: 10) {
            lookRow(name: "Aucun", has: true, on: MyAvatar.shared.ring == nil, art: AnyView(AnimalBadge(animal: shownAnimal, size: 48)),
                    product: nil, onTry: { tryRing = .some(nil) }, onWear: { wear(kind: "ring", value: nil) })
            ForEach(list, id: \.self) { ring in
                lookRow(name: "Contour \(ring.name)", has: owned.contains("ring.\(ring.rawValue)"), on: MyAvatar.shared.ring == ring,
                        art: AnyView(AnimalBadge(animal: shownAnimal, size: 48, decor: .ring(ring))),
                        product: ShopProduct.ring(ring), onTry: { tryRing = .some(ring) },
                        onWear: { wear(kind: "ring", value: ring.rawValue) })
            }
            Text("Au classement, le 1er, le 2e, le 3e et le top 10 gagnent leur propre décoration : couronne, argent, bronze, flamme.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titles: some View {
        let list = PlayerTitle.forSale + PlayerTitle.allCases.filter { !PlayerTitle.forSale.contains($0) && owned.contains("title.\($0.rawValue)") }
        return VStack(spacing: 10) {
            lookRow(name: "Aucun", has: true, on: MyAvatar.shared.title == nil, art: AnyView(Image(systemName: "textformat").font(.title2).foregroundStyle(Color.inkSoft)),
                    product: nil, onTry: { tryTitle = .some(nil) }, onWear: { wear(kind: "title", value: nil) })
            ForEach(list, id: \.self) { title in
                lookRow(name: title.text, has: owned.contains("title.\(title.rawValue)"), on: MyAvatar.shared.title == title,
                        art: AnyView(PlayerTitleTag(title: title)), product: ShopProduct.title(title),
                        onTry: { tryTitle = .some(title) }, onWear: { wear(kind: "title", value: title.rawValue) })
            }
        }
    }

    private func lookRow(name: String, has: Bool, on: Bool, art: AnyView, product: ShopProduct?,
                         onTry: @escaping () -> Void, onWear: @escaping () -> Void) -> some View {
        HStack(spacing: Space.m) {
            art.frame(width: 110, height: 52)
            Text(name).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
            Spacer(minLength: 4)
            if on {
                Label("Porté", systemImage: "checkmark").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.correct)
            } else if has {
                Button("Mettre") { Haptics.selection(); onWear() }
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .buttonStyle(.borderedProminent).tint(Color.brand)
                    .disabled(busy)
            } else if let product {
                Button("Essayer") { Haptics.selection(); withAnimation(Motion.bounce) { onTry() } }
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .buttonStyle(.bordered).tint(Color.brand)
                buyChip(shop.price(product) ?? "…", product: product)
            }
        }
        .padding(10)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }

    // MARK: Prestige

    @ViewBuilder private var prestigeCard: some View {
        if !owned.contains("ring.prestige") {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: -14) {
                    AnimalBadge(animal: .tut, size: 70, decor: .ring(.prestige))
                    AnimalBadge(animal: .athena, size: 70, decor: .ring(.prestige))
                }
                Text("Pack Prestige").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                Text("Tout le look : les 4 avatars premium, les 3 contours et les 3 titres. En plus, des exclusifs introuvables ailleurs : Toutânkhamon, Athéna, le contour Prestige animé et le titre « Légende ».")
                    .font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                PlayerTitleTag(title: .legend)
                BuyButton(title: "Le Pack Prestige", price: shop.price(.prestige), busy: shop.purchasing == .prestige, enabled: !shop.busy) {
                    buy(.prestige)
                }
            }
            .padding(Space.l)
            .background(PassPlusFill(), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(Color(hex: 0xFFC933), lineWidth: 2))
        }
    }

    // MARK: Actions

    private func buyChip(_ text: String, product: ShopProduct, small: Bool = false) -> some View {
        Button { buy(product) } label: {
            Group {
                if shop.purchasing == product { ProgressView().controlSize(.mini).tint(Color.inkFixed) } else { Text(text) }
            }
            .font(.system(size: small ? 11 : 13, weight: .black, design: .rounded))
            .foregroundStyle(Color.inkFixed)
            .padding(.horizontal, small ? 8 : 12).padding(.vertical, small ? 3 : 6)
            .background(Color.sun, in: Capsule())
        }
        .buttonStyle(.row)
        .disabled(shop.busy)
    }

    private func buy(_ product: ShopProduct) {
        Task {
            if await shop.purchase(product) {
                Haptics.success()
                await app.refreshBoutique()
                app.show("C'est à toi ! Touche « Mettre » pour le porter.")
            }
        }
    }

    private func wear(kind: String, value: String?) {
        busy = true
        Task {
            await app.setLook(kind: kind, value: value)
            if kind == "ring" { tryRing = nil } else { tryTitle = nil }
            busy = false
        }
    }
}
