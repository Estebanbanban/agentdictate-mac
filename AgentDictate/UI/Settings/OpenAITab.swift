import SwiftUI

struct OpenAITab: View {
    @State private var apiKey: String = ""
    @State private var revealed = false
    @State private var saveMessage: String?
    @State private var keychainError: String?

    private let keychain = KeychainStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CortanaHeader(title: "OpenAI")
            CortanaPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API KEY")
                        .font(CortanaTheme.Font.display(11))
                        .tracking(2)
                        .foregroundStyle(CortanaTheme.Color.cyanSoft)
                    HStack(spacing: 8) {
                        Group {
                            if revealed {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(CortanaTheme.Font.mono(13))
                        .padding(8)
                        .background(CortanaTheme.Color.bgDeep.opacity(0.7))
                        .overlay(
                            Rectangle()
                                .stroke(CortanaTheme.Color.cyan.opacity(0.35), lineWidth: 1)
                        )
                        Button {
                            revealed.toggle()
                        } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    HStack {
                        Button("Save to Keychain") { save() }
                            .buttonStyle(.borderedProminent)
                        Button("Clear") { clear() }
                        Spacer()
                        if let saveMessage {
                            Text(saveMessage)
                                .font(CortanaTheme.Font.body(11))
                                .foregroundStyle(CortanaTheme.Color.cyanSoft)
                        }
                        if let keychainError {
                            Text(keychainError)
                                .font(CortanaTheme.Font.body(11))
                                .foregroundStyle(CortanaTheme.Color.danger)
                        }
                    }
                }
            }
            CortanaPanel {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KEY HANDLING")
                        .font(CortanaTheme.Font.display(11))
                        .tracking(2)
                        .foregroundStyle(CortanaTheme.Color.cyanSoft)
                    Text("The API key is stored in the macOS Keychain (service `com.luzivog.agentdictate`). It is never written to UserDefaults or anywhere on disk in plaintext.")
                        .font(CortanaTheme.Font.body(12))
                        .foregroundStyle(CortanaTheme.Color.textDim)
                }
            }
            Spacer()
        }
        .onAppear(perform: load)
    }

    private func load() {
        do {
            apiKey = try keychain.get(KeychainStore.openAIKeyAccount) ?? ""
        } catch {
            keychainError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try keychain.set(apiKey, for: KeychainStore.openAIKeyAccount)
            saveMessage = "Saved"
            keychainError = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveMessage = nil }
        } catch {
            keychainError = error.localizedDescription
        }
    }

    private func clear() {
        do {
            try keychain.delete(KeychainStore.openAIKeyAccount)
            apiKey = ""
            saveMessage = "Cleared"
            keychainError = nil
        } catch {
            keychainError = error.localizedDescription
        }
    }
}
