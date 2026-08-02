import SwiftUI
import UIKit

@main
struct FT710MobileApp: App {
    @AppStorage("serverHost") private var savedHost: String = "radio.vlsc.net:8888"
    // Plain @AppStorage, not Keychain: the user doesn't consider this
    // password worth protecting, and Keychain's query-matching semantics
    // already caused one real bug in this app's history (a delete query
    // that wrongly included kSecValueData, silently leaving stale
    // passwords stuck). Auto-login reads this directly — never re-shows
    // LoginView, never re-populates a SecureField — so iOS's own "save
    // password?" banner (a separate system from this) should only ever
    // appear on the very first manual login, not every launch.
    @AppStorage("savedPassword") private var savedPassword: String = ""
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
                        if phase != .active {
                            vm.setPTT(false)
                            // Tuner Assist's 5s window has no other recovery path if
                            // the app backgrounds mid-run — without this it can leave
                            // the button (and the radio's power) stuck for the session.
                            vm.finishTunerAssist()
                        }
                    }
            } else {
                LoginView { host, pass in
                    savedHost = host
                    savedPassword = pass
                    let vm = RadioViewModel(serverHost: host, password: pass)
                    vm.onAuthFailure = { [self] in
                        savedPassword = ""
                        isLoggedIn = false
                    }
                    viewModel = vm
                    isLoggedIn = true
                    vm.powerOnAsync()
                }
                .preferredColorScheme(.dark)
                .onAppear {
                    if !savedHost.isEmpty, !savedPassword.isEmpty {
                        let vm = RadioViewModel(serverHost: savedHost, password: savedPassword)
                        vm.onAuthFailure = { [self] in
                            savedPassword = ""
                            isLoggedIn = false
                        }
                        viewModel = vm
                        isLoggedIn = true
                        vm.powerOnAsync()
                    }
                }
            }
        }
    }
}
