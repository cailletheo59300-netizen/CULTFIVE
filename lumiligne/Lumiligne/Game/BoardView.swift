import SwiftUI
import LumiCore

/// La grille : zones de couleur, croix, gemmes, rayon entre les gemmes reliées, éclat des zones résolues.
/// Un appui fait défiler vide → croix → gemme ; un glissé du doigt pose des croix sur les cases vides traversées.
struct BoardView: View {
    let session: GameSession
    let palette: Palette
    let showSymbols: Bool

    @State private var dragStart: Int?
    @State private var dragMoved = false

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let board = session.board
            let n = board.size
            let cell = side / CGFloat(n)
            ZStack(alignment: .topLeading) {
                ZoneLayer(layout: board.layout, resolved: board.resolvedZones, palette: palette, showSymbols: showSymbols)
                FlashLayer(layout: board.layout, zone: session.flashZone, token: session.flashToken)
                MarksLayer(session: session, palette: palette, cell: cell)
                BeamLayer(board: board, solved: session.solved, palette: palette, cell: cell)
                HighlightLayer(cells: session.highlight, token: session.highlightToken, size: n, palette: palette)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.line, lineWidth: 3))
            .contentShape(Rectangle())
            .gesture(drag(cellSize: cell, n: n))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Grille de \(n) sur \(n)")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drag(cellSize: CGFloat, n: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let cell = index(at: value.location, cellSize: cellSize, n: n) else { return }
                guard let start = dragStart else {
                    dragStart = cell
                    dragMoved = false
                    return
                }
                if cell != start, !dragMoved {
                    dragMoved = true
                    session.stroke(start)
                }
                if dragMoved { session.stroke(cell) }
            }
            .onEnded { _ in
                if let start = dragStart, !dragMoved {
                    session.tap(start)
                } else if dragMoved {
                    session.endStroke()
                }
                dragStart = nil
                dragMoved = false
            }
    }

    private func index(at point: CGPoint, cellSize: CGFloat, n: Int) -> Int? {
        guard cellSize > 0, point.x >= 0, point.y >= 0 else { return nil }
        let column = Int(point.x / cellSize), row = Int(point.y / cellSize)
        guard row < n, column < n else { return nil }
        return row * n + column
    }
}

/// Fond : couleurs des zones, traits fins entre les cases, traits épais entre les zones, numéros et symboles.
private struct ZoneLayer: View {
    let layout: LumiCore.Layout
    let resolved: [Bool]
    let palette: Palette
    let showSymbols: Bool

    var body: some View {
        Canvas { context, size in
            let n = layout.size
            let c = size.width / CGFloat(n)
            for cell in 0..<layout.cellCount {
                let rect = CGRect(x: CGFloat(layout.column(cell)) * c, y: CGFloat(layout.row(cell)) * c, width: c, height: c)
                let zone = layout.zones[cell]
                context.fill(Path(rect), with: .color(palette.zone(zone)))
                if resolved[zone] {
                    context.fill(Path(rect), with: .color(Color.white.opacity(palette.dark ? 0.1 : 0.28)))
                }
            }
            var thin = Path()
            for k in 1..<n {
                let p = CGFloat(k) * c
                thin.move(to: CGPoint(x: p, y: 0)); thin.addLine(to: CGPoint(x: p, y: size.height))
                thin.move(to: CGPoint(x: 0, y: p)); thin.addLine(to: CGPoint(x: size.width, y: p))
            }
            context.stroke(thin, with: .color(palette.line.opacity(0.22)), lineWidth: 1)
            var thick = Path()
            for cell in 0..<layout.cellCount {
                let r = layout.row(cell), col = layout.column(cell)
                if col < n - 1, layout.zones[cell] != layout.zones[cell + 1] {
                    let x = CGFloat(col + 1) * c
                    thick.move(to: CGPoint(x: x, y: CGFloat(r) * c)); thick.addLine(to: CGPoint(x: x, y: CGFloat(r + 1) * c))
                }
                if r < n - 1, layout.zones[cell] != layout.zones[cell + n] {
                    let y = CGFloat(r + 1) * c
                    thick.move(to: CGPoint(x: CGFloat(col) * c, y: y)); thick.addLine(to: CGPoint(x: CGFloat(col + 1) * c, y: y))
                }
            }
            context.stroke(thick, with: .color(palette.line), style: StrokeStyle(lineWidth: max(2.5, c * 0.075), lineCap: .round))
            let ink = palette.dark ? Color.white.opacity(0.85) : Color.black.opacity(0.6)
            for zone in 0..<n {
                let cell = layout.labelCell(of: zone)
                let point = CGPoint(x: CGFloat(layout.column(cell)) * c + c * 0.1, y: CGFloat(layout.row(cell)) * c + c * 0.06)
                context.draw(Text("\(zone + 1)").font(Fonts.number(max(10, c * 0.22), .heavy)).foregroundStyle(ink),
                             at: point, anchor: .topLeading)
            }
            if showSymbols {
                for cell in 0..<layout.cellCount {
                    let center = CGPoint(x: (CGFloat(layout.column(cell)) + 0.5) * c, y: (CGFloat(layout.row(cell)) + 0.75) * c)
                    context.draw(Text(Image(systemName: Palette.symbol(layout.zones[cell])))
                        .font(.system(size: max(7, c * 0.16))).foregroundStyle(ink.opacity(0.45)), at: center)
                }
            }
        }
    }
}

/// Éclat d'une zone quand elle reçoit sa gemme.
private struct FlashLayer: View {
    let layout: LumiCore.Layout
    let zone: Int?
    let token: Int
    @State private var opacity = 0.0

    var body: some View {
        Canvas { context, size in
            guard let zone else { return }
            let c = size.width / CGFloat(layout.size)
            var path = Path()
            for cell in layout.cellsOfZone[zone] {
                path.addRect(CGRect(x: CGFloat(layout.column(cell)) * c, y: CGFloat(layout.row(cell)) * c, width: c, height: c))
            }
            context.fill(path, with: .color(.white))
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .onChange(of: token) {
            opacity = 0.65
            withAnimation(.easeOut(duration: 0.55)) { opacity = 0 }
        }
    }
}

/// Croix et gemmes.
private struct MarksLayer: View {
    let session: GameSession
    let palette: Palette
    let cell: CGFloat

    var body: some View {
        let board = session.board
        let layout = board.layout
        let auto = session.autoCrosses ? board.autoCrosses : Array(repeating: false, count: layout.cellCount)
        let bad = board.conflicts
        let links = board.links
        ForEach(0..<layout.cellCount, id: \.self) { index in
            let zone = layout.zones[index]
            let lit = session.solved || (zone > 0 && links[zone - 1]) || (zone < links.count && links[zone])
            CellMark(mark: board.marks[index], auto: auto[index], zone: zone, bad: bad[index], lit: lit,
                     palette: palette, size: cell)
                .frame(width: cell, height: cell)
                .position(x: (CGFloat(layout.column(index)) + 0.5) * cell, y: (CGFloat(layout.row(index)) + 0.5) * cell)
        }
        .allowsHitTesting(false)
    }
}

private struct CellMark: View {
    let mark: Mark
    let auto: Bool
    let zone: Int
    let bad: Bool
    let lit: Bool
    let palette: Palette
    let size: CGFloat

    var body: some View {
        ZStack {
            if mark == .gem {
                GemView(palette: palette, color: palette.zone(zone), number: zone + 1, size: size, lit: lit && !bad, bad: bad)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .modifier(Shake(active: bad))
            } else if mark == .cross || auto {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle((palette.dark ? Color.white : Color.black).opacity(mark == .cross ? 0.55 : 0.22))
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: mark)
        .animation(.easeOut(duration: 0.2), value: auto)
    }
}

/// Petite secousse d'une gemme en erreur.
private struct Shake: ViewModifier {
    let active: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: active, initial: true) { _, now in
                guard now else { return }
                withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) { offset = 4 }
                Task {
                    try? await Task.sleep(for: .seconds(0.26))
                    withAnimation(.easeOut(duration: 0.08)) { offset = 0 }
                }
            }
    }
}

/// Le rayon : un trait lumineux entre chaque paire de gemmes reliées. Il se dessine quand le lien apparaît.
/// Grille finie : le rayon parcourt toute la chaîne, de la gemme 1 à la dernière.
private struct BeamLayer: View {
    let board: Board
    let solved: Bool
    let palette: Palette
    let cell: CGFloat

    struct LinkID: Hashable {
        let zone: Int
        let from: Int
        let to: Int
    }

    var body: some View {
        let gems = board.gems
        let links = board.links
        let ids = links.indices.compactMap { k -> LinkID? in
            guard links[k], let a = gems[k], let b = gems[k + 1] else { return nil }
            return LinkID(zone: k, from: a, to: b)
        }
        ZStack {
            ForEach(ids, id: \.self) { link in
                BeamSegment(from: center(link.from), to: center(link.to), color: palette.beam, width: cell * 0.09)
            }
            if solved {
                ChainSweep(points: board.grid.solution.map(center), color: palette.beam, width: cell * 0.16,
                           duration: Double(board.size) * 0.12)
            }
        }
        .allowsHitTesting(false)
    }

    private func center(_ index: Int) -> CGPoint {
        CGPoint(x: (CGFloat(board.layout.column(index)) + 0.5) * cell, y: (CGFloat(board.layout.row(index)) + 0.5) * cell)
    }
}

private struct BeamSegment: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let width: CGFloat
    @State private var progress: CGFloat = 0

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .trim(from: 0, to: progress)
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .shadow(color: color.opacity(0.9), radius: width * 1.2)
        .onAppear { withAnimation(.easeOut(duration: 0.35)) { progress = 1 } }
    }
}

/// Grande traînée lumineuse qui parcourt toute la chaîne à la victoire, puis respire doucement.
private struct ChainSweep: View {
    let points: [CGPoint]
    let color: Color
    let width: CGFloat
    let duration: Double
    @State private var progress: CGFloat = 0
    @State private var glow = false

    var body: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        .trim(from: 0, to: progress)
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        .shadow(color: color, radius: glow ? width * 2.2 : width)
        .shadow(color: .white.opacity(0.6), radius: width * 0.3)
        .onAppear {
            withAnimation(.easeInOut(duration: duration)) { progress = 1 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(duration)) { glow = true }
        }
    }
}

/// Cases montrées par un indice : contour qui pulse.
private struct HighlightLayer: View {
    let cells: [Int]
    let token: Int
    let size: Int
    let palette: Palette
    @State private var pulse = false

    var body: some View {
        GeometryReader { geometry in
            let c = geometry.size.width / CGFloat(size)
            ForEach(cells, id: \.self) { cell in
                RoundedRectangle(cornerRadius: c * 0.14, style: .continuous)
                    .stroke(palette.dark ? Color.white : palette.text, lineWidth: max(2.5, c * 0.08))
                    .frame(width: c - 4, height: c - 4)
                    .position(x: (CGFloat(cell % size) + 0.5) * c, y: (CGFloat(cell / size) + 0.5) * c)
                    .opacity(pulse ? 1 : 0.35)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: token, initial: true) {
            pulse = false
            withAnimation(.easeInOut(duration: 0.45).repeatCount(5, autoreverses: true)) { pulse = true }
        }
    }
}
