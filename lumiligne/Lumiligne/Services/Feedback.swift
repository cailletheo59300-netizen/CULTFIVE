import AVFoundation
import UIKit

/// Vibrations (retour haptique).
@MainActor
final class Haptics {
    var enabled = true
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func tap() { guard enabled else { return }; soft.impactOccurred(intensity: 0.5) }
    func gem() { guard enabled else { return }; light.impactOccurred() }
    func link() { guard enabled else { return }; medium.impactOccurred(intensity: 0.8) }
    func success() { guard enabled else { return }; notification.notificationOccurred(.success) }
    func error() { guard enabled else { return }; notification.notificationOccurred(.error) }
}

/// Sons du jeu, fabriqués par le code (aucun fichier audio). Notes douces, gamme pentatonique : rien ne sonne faux.
/// Respecte le bouton silencieux de l'iPhone et laisse la musique du joueur continuer (catégorie « ambient »).
@MainActor
final class SoundPlayer {
    enum Sound: Hashable {
        /// Croix : petit clic.
        case cross
        /// Gemme posée : la note dépend du numéro de la zone (la chaîne monte comme une mélodie).
        case gem(Int)
        /// Deux gemmes reliées par le rayon.
        case link(Int)
        case error
        case hint
        /// Grille finie : arpège qui monte.
        case win
    }

    var enabled = true
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ready = false

    /// Gamme pentatonique (do, ré, mi, sol, la) sur deux octaves.
    private static let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.5, 1174.7, 1318.5, 1568.0, 1760.0]

    func play(_ sound: Sound) {
        guard enabled else { return }
        prepare()
        guard ready, let buffer = buffer(for: sound) else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func prepare() {
        guard !ready else {
            if !engine.isRunning { try? engine.start() }
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.5
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    private func note(_ index: Int) -> Double { Self.scale[min(max(index, 0), Self.scale.count - 1)] }

    private func buffer(for sound: Sound) -> AVAudioPCMBuffer? {
        if let cached = buffers[sound] { return cached }
        let made: AVAudioPCMBuffer?
        switch sound {
        case .cross:
            made = tone([(1800, 1500, 0.035)], volume: 0.18)
        case .gem(let zone):
            let f = note(zone)
            made = tone([(f, f, 0.22)], volume: 0.4, bell: true)
        case .link(let zone):
            let f = note(zone + 1)
            made = tone([(f, f, 0.09), (f * 1.5, f * 1.5, 0.22)], volume: 0.32, bell: true)
        case .error:
            made = tone([(220, 180, 0.18)], volume: 0.35)
        case .hint:
            made = tone([(1046.5, 1568, 0.16)], volume: 0.3, bell: true)
        case .win:
            made = tone([(523.25, 523.25, 0.1), (659.25, 659.25, 0.1), (783.99, 783.99, 0.1), (1046.5, 1046.5, 0.12),
                         (1318.5, 1318.5, 0.45)], volume: 0.4, bell: true)
        }
        buffers[sound] = made
        return made
    }

    /// Suite de notes (fréquence de départ, d'arrivée, durée en secondes), attaque rapide et chute douce.
    /// `bell` ajoute des harmoniques de clochette (son de cristal pour les gemmes).
    private func tone(_ notes: [(Double, Double, Double)], volume: Double, bell: Bool = false) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = notes.reduce(0) { $0 + Int($1.2 * rate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(total)
        var offset = 0
        var phase = 0.0
        for (start, end, duration) in notes {
            let count = Int(duration * rate)
            for i in 0..<count {
                let t = Double(i) / Double(count)
                let frequency = start + (end - start) * t
                phase += 2 * .pi * frequency / rate
                let envelope = min(1, t * 40) * pow(1 - t, bell ? 3 : 2)
                var sample = sin(phase) * 0.75 + sin(phase * 2) * 0.18
                if bell { sample += sin(phase * 3.01) * 0.1 + sin(phase * 4.2) * 0.05 }
                data[offset + i] = Float(sample * envelope * volume)
            }
            offset += count
        }
        return buffer
    }
}
