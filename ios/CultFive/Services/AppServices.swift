import Foundation
import UIKit
import CryptoKit
import UserNotifications
import CultFiveCore

/// Lecture de la configuration (ios/Config/*.xcconfig → Info.plist). Aucune clé secrète : la clé anon est publique par nature.
enum AppConfig {
    static var backend: BackendConfig? {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !rawURL.isEmpty, !key.isEmpty, !rawURL.contains("$("),
              let url = URL(string: rawURL) else { return nil }
        return BackendConfig(url: url, anonKey: key)
    }
}

/// Empreinte d'appareil pour l'anti-abus du parrainage : hachée, jamais l'identifiant brut.
enum DeviceIdentity {
    @MainActor static var hash: String {
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let digest = SHA256.hash(data: Data("cultfive:\(vendor)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Petit cache disque JSON (référentiel, pack de secours hors-ligne). Évite les re-téléchargements inutiles.
struct DiskCache {
    private let directory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("cultfive", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    func load<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("\(key).json")) else { return nil }
        return try? SupabaseAPI.decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }

    func remove(_ key: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(key).json"))
    }

    static var queueURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("pending-attempts.json")
    }
}

/// Notifications locales, raisonnables : un rappel « Daily disponible » à l'heure choisie,
/// et un rappel en fin de journée seulement si le Daily n'est pas fait. Rien d'autre.
enum NotificationScheduler {
    private static let dailyId = "daily-available"
    private static let reminderId = "daily-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// À appeler au lancement, au retour au premier plan et après chaque Daily.
    static func refresh(profile: Profile, dailyDone: Bool) async {
        let center = UNUserNotificationCenter.current()
        guard await isAuthorized() else { return }
        center.removePendingNotificationRequests(withIdentifiers: [dailyId, reminderId])

        if profile.notifDaily {
            let parts = profile.notifDailyTime.split(separator: ":").compactMap { Int($0) }
            var time = DateComponents()
            time.hour = parts.first ?? 8
            time.minute = parts.count > 1 ? parts[1] : 30
            let content = UNMutableNotificationContent()
            content.title = "Ton \(Brand.dailyName) est prêt."
            content.body = "Cinq questions, cinq minutes. Et toi, tu sais quoi ?"
            content.sound = .default
            // Déclencheur répétitif : si le Daily du jour est déjà fait, on décale au lendemain.
            if dailyDone, let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                var next = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                next.hour = time.hour
                next.minute = time.minute
                try? await center.add(UNNotificationRequest(identifier: dailyId, content: content,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: next, repeats: false)))
            } else {
                try? await center.add(UNNotificationRequest(identifier: dailyId, content: content,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)))
            }
        }

        if profile.notifReminder && !dailyDone {
            var evening = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            evening.hour = 20
            evening.minute = 30
            if let date = Calendar.current.date(from: evening), date > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Ta série t'attend"
                content.body = profile.streak > 1
                    ? "\(profile.streak) jours d'affilée. Le \(Brand.dailyName) prend cinq minutes."
                    : "Le \(Brand.dailyName) prend cinq minutes."
                content.sound = .default
                try? await center.add(UNNotificationRequest(identifier: reminderId, content: content,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: evening, repeats: false)))
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
