import Foundation
import MetricKit
import CultFiveCore

/// Plantages et blocages, relevés par iOS (MetricKit, aucun service tiers) et envoyés au serveur pour l'onglet Santé
/// de l'admin. iOS livre ces rapports au lancement suivant, au plus une fois par jour.
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    private let service: GameService

    init(service: GameService) {
        self.service = service
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit { MXMetricManager.shared.remove(self) }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            payload.crashDiagnostics?.forEach { send("crash", $0, extra: [
                "exception_type": $0.exceptionType.map { JSONValue.number($0.doubleValue) } ?? .null,
                "signal": $0.signal.map { JSONValue.number($0.doubleValue) } ?? .null,
                "reason": $0.terminationReason.map { JSONValue.string(String($0.prefix(300))) } ?? .null,
            ]) }
            payload.hangDiagnostics?.forEach { send("hang", $0, extra: [
                "duration_s": .number($0.hangDuration.converted(to: .seconds).value),
            ]) }
            payload.cpuExceptionDiagnostics?.forEach { send("cpu", $0, extra: [:]) }
            payload.diskWriteExceptionDiagnostics?.forEach { send("disk", $0, extra: [:]) }
        }
    }

    private func send(_ kind: String, _ diagnostic: MXDiagnostic, extra: [String: JSONValue]) {
        var payload = extra
        // Pile d'appels tronquée : assez pour trouver la cause, sans dépasser la taille acceptée par le serveur.
        let stack = String(decoding: diagnostic.callStackTreeIfAny ?? Data(), as: UTF8.self)
        if !stack.isEmpty { payload["stack"] = .string(String(stack.prefix(8000))) }
        let meta = diagnostic.metaData
        let service = self.service
        let appVersion = meta.applicationBuildVersion
        let osVersion = meta.osVersion
        Task.detached {
            try? await service.reportDiagnostic(kind: kind, payload: .object(payload), appVersion: appVersion, osVersion: osVersion)
        }
    }
}

private extension MXDiagnostic {
    /// Pile d'appels en JSON (plantages et blocages seulement).
    var callStackTreeIfAny: Data? {
        if let crash = self as? MXCrashDiagnostic { return crash.callStackTree.jsonRepresentation() }
        if let hang = self as? MXHangDiagnostic { return hang.callStackTree.jsonRepresentation() }
        if let cpu = self as? MXCPUExceptionDiagnostic { return cpu.callStackTree.jsonRepresentation() }
        if let disk = self as? MXDiskWriteExceptionDiagnostic { return disk.callStackTree.jsonRepresentation() }
        return nil
    }
}
