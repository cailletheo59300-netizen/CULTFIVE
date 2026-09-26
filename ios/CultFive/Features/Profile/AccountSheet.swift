import SwiftUI
import AuthenticationServices
import CryptoKit
import CultFiveCore

/// Création / connexion de compte : Sign in with Apple ou code par e-mail.
/// Depuis un compte anonyme, la progression est conservée (liaison d'identité côté Supabase).
struct AccountSheet: View {
    var onDone: (() -> Void)? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var nonce = ""
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isConversion = true
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("Ton compte").font(.cfDisplay)
                    Text("Garde ta progression, ta série et tes amis sur tous tes appareils.")
                        .font(.cfReading).foregroundStyle(Color.inkSoft)

                    SignInWithAppleButton(.continue) { request in
                        nonce = Nonce.random()
                        request.requestedScopes = [.email]
                        request.nonce = Nonce.sha256(nonce)
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s, style: .continuous))

                    HStack {
                        Hairline()
                        Text("ou").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        Hairline()
                    }

                    emailBlock

                    if let error {
                        Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                    }
                    if busy { ProgressView() }
                }
                .padding(Space.gutter)
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var emailBlock: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            TextField("ton@email.fr", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.cfTitle3)
                .padding(.vertical, Space.s)
                .overlay(alignment: .bottom) { Hairline(color: .ink) }
                .disabled(codeSent)
            if codeSent {
                TextField("Code à 6 chiffres", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.title2, design: .monospaced))
                    .padding(.vertical, Space.s)
                    .overlay(alignment: .bottom) { Hairline(color: .ink) }
                Button("Valider le code") { verify() }
                    .buttonStyle(.ink)
                    .disabled(code.count < 6 || busy)
                Button("Changer d'e-mail") { codeSent = false; code = "" }.buttonStyle(.textLink)
            } else {
                Button("Recevoir un code") { sendCode() }
                    .buttonStyle(.ink)
                    .disabled(!email.contains("@") || busy)
                if !isConversion {
                    Text("Connexion à un compte existant : la progression de cet appareil ne sera pas reprise.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            if case .failure(let failure) = result, (failure as? ASAuthorizationError)?.code != .canceled {
                error = "Connexion Apple impossible."
            }
            return
        }
        run { _ = try await app.api?.signInWithApple(idToken: token, nonce: nonce) }
    }

    private func sendCode() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        busy = true
        error = nil
        Task {
            do {
                try await app.api?.sendEmailCode(email: address, convertAnonymous: isConversion)
                codeSent = true
            } catch let failure as BackendError where failure.code == "email_exists" || failure.code == "email_address_exists" {
                // Déjà un compte : on bascule en connexion simple.
                isConversion = false
                do {
                    try await app.api?.sendEmailCode(email: address, convertAnonymous: false)
                    codeSent = true
                } catch {
                    self.error = (error as? LocalizedError)?.errorDescription
                }
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription
            }
            busy = false
        }
    }

    private func verify() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        run { _ = try await app.api?.verifyEmailCode(email: address, code: code, isConversion: isConversion) }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do {
                try await action()
                await app.refreshProfile()
                await app.claimPendingInviteIfPossible()
                Haptics.success()
                onDone?()
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Échec de la connexion."
            }
            busy = false
        }
    }
}

enum Nonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
