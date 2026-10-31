import AVFoundation
import UIKit

/// Vibrations (retour haptique).
@MainActor
final class Haptics {
    var enabled = true
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func tap() { guard enabled else { return }; lightGenerator.impactOccurred(intensity: 0.6) }
    func light() { guard enabled else { return }; lightGenerator.impactOccurred() }
    func medium() { guard enabled else { return }; mediumGenerator.impactOccurred() }
    func success() { guard enabled else { return }; notification.notificationOccurred(.success) }
    func error() { guard enabled else { return }; notification.notificationOccurred(.error) }
}

/// Sons du jeu, fabriqués par le code (aucun fichier audio à produire). Respecte le bouton silencieux de l'iPhone et
/// laisse la musique du joueur continuer (catégorie « ambient »).
@MainActor
final class SoundPlayer {
    enum Sound: Hashable {
        /// Orbe attrapé : la note monte à chaque orbe de la manche.
        case orb(Int)
        case roundClear
        case nearMiss
        /// Fantôme pâle absorbé : glissando grave vers l'aigu.
        case absorb
        case death
    }

    var enabled = true
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ready = false

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
        for _ in 0..<5 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.55
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    private func buffer(for sound: Sound) -> AVAudioPCMBuffer? {
        if let cached = buffers[sound] { return cached }
        let made: AVAudioPCMBuffer?
        switch sound {
        case .orb(let index):
            let base = 660.0 * pow(1.26, Double(min(index, 4)))
            made = tone([(base, base * 1.02, 0.12)], volume: 0.5)
        case .roundClear:
            made = tone([(523, 523, 0.08), (659, 659, 0.08), (784, 784, 0.08), (1046, 1046, 0.18)], volume: 0.45)
        case .nearMiss:
            made = tone([(1400, 2200, 0.09)], volume: 0.3)
        case .absorb:
            made = tone([(220, 880, 0.16), (880, 1320, 0.1)], volume: 0.5)
        case .death:
            made = tone([(330, 70, 0.45)], volume: 0.6, noise: 0.35)
        }
        buffers[sound] = made
        return made
    }

    /// Suite de notes (fréquence de départ, d'arrivée, durée en secondes), avec une attaque et une chute douces.
    private func tone(_ notes: [(Double, Double, Double)], volume: Double, noise: Double = 0) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = notes.reduce(0) { $0 + Int($1.2 * rate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(total)
        var offset = 0
        var phase = 0.0
        var random = SystemRandomNumberGenerator()
        for (start, end, duration) in notes {
            let count = Int(duration * rate)
            for i in 0..<count {
                let t = Double(i) / Double(count)
                let frequency = start + (end - start) * t
                phase += 2 * .pi * frequency / rate
                let envelope = min(1, t * 25) * pow(1 - t, 2)
                var sample = sin(phase) * 0.8 + sin(phase * 2) * 0.2
                if noise > 0 { sample = sample * (1 - noise) + Double.random(in: -1...1, using: &random) * noise }
                data[offset + i] = Float(sample * envelope * volume)
            }
            offset += count
        }
        return buffer
    }
}
