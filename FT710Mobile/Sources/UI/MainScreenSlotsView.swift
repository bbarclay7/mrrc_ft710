import SwiftUI

/// User-toggleable controls on the main screen (Settings → Main Screen turns
/// each on/off), so frequently-touched knobs like RF Power or Squelch don't
/// require opening Settings every time. Plain per-control visibility — no
/// slot assignment, so there's no way for the same control to show twice.
struct MainScreenSlotsView: View {
    @AppStorage("mainScreenShow_rfPower") private var showRFPower = true
    @AppStorage("mainScreenShow_squelch") private var showSquelch = true
    @AppStorage("mainScreenShow_rfGain") private var showRFGain = true
    @AppStorage("mainScreenShow_scopeSpan") private var showScopeSpan = true
    @AppStorage("mainScreenShow_waterfallOffset") private var showWaterfallOffset = false

    private var visibleControls: [RadioState.MainScreenControl] {
        [
            showRFPower ? .rfPower : nil,
            showSquelch ? .squelch : nil,
            showRFGain ? .rfGain : nil,
            showScopeSpan ? .scopeSpan : nil,
            showWaterfallOffset ? .waterfallOffset : nil,
        ].compactMap { $0 }
    }

    var body: some View {
        if !visibleControls.isEmpty {
            VStack(spacing: 6) {
                ForEach(visibleControls) { control in
                    MainScreenSlotRow(control: control)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct MainScreenSlotRow: View {
    @EnvironmentObject var viewModel: RadioViewModel
    let control: RadioState.MainScreenControl

    var body: some View {
        HStack {
            Text(control.label).font(.caption).foregroundColor(.radioMuted).frame(width: 62, alignment: .leading)
            slider
            Text(valueLabel).font(.caption.monospaced()).foregroundColor(.radioAccent).frame(width: 54, alignment: .trailing)
        }
    }

    @ViewBuilder private var slider: some View {
        switch control {
        case .rfPower:
            Slider(value: Binding(
                get: { Double(viewModel.state.rfPower) },
                set: { viewModel.setRFPower(Int($0)) }
            ), in: 5...100, step: 5).tint(.radioRed)
        case .squelch:
            Slider(value: Binding(
                get: { Double(viewModel.state.squelch) },
                set: { viewModel.setSquelch(Int($0)) }
            ), in: 0...50, step: 1).tint(.radioAccent)
        case .rfGain:
            Slider(value: Binding(
                get: { Double(viewModel.state.rfGain) },
                set: { viewModel.setRFGain(Int($0)) }
            ), in: 0...255, step: 5).tint(.radioAccent)
        case .scopeSpan:
            Slider(value: Binding(
                get: { Double(viewModel.state.scopeSpan) },
                set: { viewModel.setScopeSpan(Int($0)) }
            ), in: 0...9, step: 1).tint(.radioAccent)
        case .waterfallOffset:
            Slider(value: Binding(
                get: { Double(viewModel.spectrumProc.userOffset) },
                set: { viewModel.spectrumProc.userOffset = Float($0) }
            ), in: -40...40, step: 1).tint(.radioAccent)
        }
    }

    private var valueLabel: String {
        switch control {
        case .rfPower: return "\(viewModel.state.rfPower)W"
        case .squelch: return "\(viewModel.state.squelch)"
        case .rfGain: return "\(viewModel.state.rfGain)"
        case .scopeSpan: return RadioState.scopeSpanLabels[viewModel.state.scopeSpan] ?? "?"
        case .waterfallOffset: return "\(Int(viewModel.spectrumProc.userOffset))"
        }
    }
}
