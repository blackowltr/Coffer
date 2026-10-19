import SwiftUI

/// Şifreli arşivler için parola sorma diyaloğu (Keychain & Touch ID destekli)
public struct PasswordPromptDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveName: String
    @Binding public var isPresented: Bool
    public let onConfirmPassword: (String, Bool) -> Void

    @State private var password: String = ""
    @State private var saveToKeychain: Bool = true
    @State private var showPlainPassword: Bool = false

    public init(
        archiveName: String,
        isPresented: Binding<Bool>,
        onConfirmPassword: @escaping (String, Bool) -> Void
    ) {
        self.archiveName = archiveName
        self._isPresented = isPresented
        self.onConfirmPassword = onConfirmPassword
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(settings.accentColorChoice.color)

            VStack(spacing: 4) {
                Text("Parola Korumalı Arşiv")
                    .font(.headline)

                Text("'\(archiveName)' içeriğini açmak için lütfen parolayı girin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                if showPlainPassword {
                    TextField("Parola", text: $password)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Parola", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: { showPlainPassword.toggle() }) {
                    Image(systemName: showPlainPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Toggle("Bu parolayı macOS Keychain (Anahtar Zinciri) içinde sakla", isOn: $saveToKeychain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Button("İptal") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Tamam") {
                    isPresented = false
                    onConfirmPassword(password, saveToKeychain)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }
}
