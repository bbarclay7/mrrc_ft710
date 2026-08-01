import SwiftUI
import Security
import UIKit

@main
struct FT710MobileApp: App {
    @AppStorage("serverHost") private var savedHost: String = "radio.vlsc.net:8888"
    @State private var isLoggedIn: Bool = false
    @State private var viewModel: RadioViewModel?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if isLoggedIn, let vm = viewModel {
                ContentView()
                    .environmentObject(vm)
                    .preferredColorScheme(.dark)
                    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
                    // Mobile equivalent of the web app's pagehide/beforeunload PTT
                    // safety layers: a backgrounded app can never receive the
                    // touch-up that would normally release PTT, so force it here.
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active { vm.setPTT(false) }
                    }
            } else {
                LoginView { host, pass in
                    savedHost = host
                    savePassword(pass, for: host)
                    let vm = RadioViewModel(serverHost: host, password: pass)
                    viewModel = vm
                    isLoggedIn = true
                    vm.powerOnAsync()
                }
                .preferredColorScheme(.dark)
                .onAppear {
                    if !savedHost.isEmpty, let pass = loadPassword(for: savedHost) {
                        let vm = RadioViewModel(serverHost: savedHost, password: pass)
                        viewModel = vm
                        isLoggedIn = true
                        vm.powerOnAsync()
                    }
                }
            }
        }
    }

    // MARK: - Keychain

    private let keychainAccount = "ft710_mobile"

    private func savePassword(_ pass: String, for host: String) {
        guard !pass.isEmpty else { return }
        // Match query for delete/add must only contain identifying attributes —
        // kSecValueData doesn't belong here. Including it used to mean the delete
        // could fail to find the existing item, and the follow-up add's result
        // was never checked, so a stale password silently stuck around forever.
        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(matchQuery as CFDictionary)

        var addQuery = matchQuery
        addQuery[kSecValueData as String] = pass.data(using: .utf8)!
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain save failed: \(status)")
        }
    }

    private func loadPassword(for host: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
