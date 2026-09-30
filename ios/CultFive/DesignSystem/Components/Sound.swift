import AVFoundation
import SwiftUI

/// Sons discrets, synthétisés au lancement (aucun fichier audio). Catégorie « ambiante » : respectent le mode silencieux
/// de l'iPhone et se mélangent à la musique en cours. Coupables dans Réglages → Jeu → Sons.
@MainActor
enum SoundFX {
    enum Cue: CaseIterable {
        case correct, wrong, chest, reward

        /// Notes (fréquence en Hz, durée en secondes).
        var notes: [(Double, Double)] {
            switch self {
            case .correct: return [(1046.5, 0.07), (1318.5, 0.11)]
            case .wrong: return [(311.1, 0.09), (233.1, 0.16)]
            case .chest: return [(523.3, 0.06), (659.3, 0.06), (784.0, 0.06), (1046.5, 0.18)]
            case .reward: return [(784.0, 0.08), (1046.5, 0.08), (1568.0, 0.22)]
            }
        }

        var volume: Float { self == .wrong ? 0.16 : 0.22 }
    }

    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private static var ready = false

    static func play(_ cue: Cue) {
        guard GamePreferences.soundsEnabled else { return }
        guard prepare(), let buffer = buffers[cue] else { return }
        player.volume = cue.volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private static func prepare() -> Bool {
        if ready {
            if !engine.isRunning { try? engine.start() }
            return engine.isRunning
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            for cue in Cue.allCases { buffers[cue] = synthesize(cue, format: format) }
            try engine.start()
            ready = true
            return true
        } catch {
            return false
        }
    }

    /// Sinusoïde douce, attaque et extinction courtes (pas de clic), un soupçon d'harmonique pour le timbre.
    private static func synthesize(_ cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = cue.notes.reduce(0) { $0 + $1.1 }
        let frames = AVAudioFrameCount(rate * total)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var offset = 0
        for (frequency, duration) in cue.notes {
            let count = Int(rate * duration)
            for i in 0 ..< count where offset + i < Int(frames) {
                let t = Double(i) / rate
                let attack = min(1, t / 0.008)
                let release = min(1, (duration - t) / 0.04)
                let envelope = max(0, min(attack, release))
                let wave = sin(2 * .pi * frequency * t) + 0.18 * sin(4 * .pi * frequency * t)
                samples[offset + i] = Float(wave * envelope * 0.6)
            }
            offset += count
        }
        return buffer
    }
}

/// Retour d'une réponse : vibration et son, selon les réglages.
@MainActor
enum Feedback {
    static func answer(_ correct: Bool) {
        if correct { Haptics.success() } else { Haptics.error() }
        SoundFX.play(correct ? .correct : .wrong)
    }
}
