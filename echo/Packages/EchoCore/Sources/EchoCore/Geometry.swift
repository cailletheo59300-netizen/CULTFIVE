import Foundation

/// Point ou déplacement dans l'arène (unités logiques, voir `Tuning.arena`).
public struct Vec2: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, k: Double) -> Vec2 { Vec2(a.x * k, a.y * k) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    /// Le même vecteur, raccourci à `maxLength` s'il est plus long.
    public func limited(to maxLength: Double) -> Vec2 {
        let l = length
        return l > maxLength && l > 0 ? self * (maxLength / l) : self
    }
}

public enum Geometry {
    /// Distance entre un point et le segment [a, b]. Sert aux collisions « continues » : un déplacement rapide ne peut
    /// pas traverser un fantôme entre deux images.
    public static func distance(from p: Vec2, toSegment a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let ap = p - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSquared))
        return p.distance(to: a + ab * t)
    }
}
