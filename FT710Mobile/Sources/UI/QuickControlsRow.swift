import SwiftUI

/// Single-row selector controls: Mode · Band · Filter · ATT · IPO
/// Each button opens a Menu (native dropdown) listing every option, rather
/// than cycling one step per tap — a step is fine when there are 2-3
/// choices, but band/mode/filter lists are long enough that stepping
/// through them one at a time is tedious.
struct QuickControlsRow: View {
    @EnvironmentObject var viewModel: RadioViewModel

    // MARK: - Mode

    private var modeIndex: Int {
        RadioState.uiModes.firstIndex(of: viewModel.state.modeName) ?? 1
    }

    // MARK: - Band

    private var bandIndex: Int {
        RadioState.bands.firstIndex(where: {
            $0.start <= viewModel.state.activeFreq && viewModel.state.activeFreq <= $0.end
        }) ?? 5
    }

    // MARK: - Filter

    private var filterWidths: [(Int, Int)] {
        RadioState.filterWidthsForMode(viewModel.state.modeName)
    }

    private var filterIndex: Int {
        // 优先按当前 CAT 索引定位；如果当前索引不在精选列表里，再用带宽值回退匹配
        if let pos = filterWidths.firstIndex(where: { $0.0 == viewModel.state.filterWidth }) {
            return pos
        }
        guard let hz = viewModel.state.filterHz else { return 0 }
        return filterWidths.firstIndex(where: { $0.1 == hz }) ?? 0
    }

    // MARK: - ATT (CAT index: 0=OFF, 1=6dB, 2=12dB, 3=18dB)

    private let attValues: [Int] = [0, 1, 2, 3]
    private let attLabels = ["ATT OFF", "ATT 6dB", "ATT 12dB", "ATT 18dB"]

    private var attIndex: Int {
        attValues.firstIndex(of: viewModel.state.attenuator) ?? 0
    }

    // MARK: - IPO (preamp: 0=OFF, 1=AMP1, 2=AMP2)

    private let ipoValues: [Int] = [0, 1, 2]
    private let ipoLabels = ["IPO OFF", "IPO AMP1", "IPO AMP2"]

    private var ipoIndex: Int {
        ipoValues.firstIndex(of: viewModel.state.preamp) ?? 0
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            SelectorButton(
                label: viewModel.state.modeDisplay,
                color: .radioAccent,
                optionLabels: RadioState.uiModes,
                onSelect: { i in viewModel.setMode(RadioState.uiModes[i]) }
            ).equatable()
            SelectorButton(
                label: RadioState.bands[bandIndex].name,
                color: .radioAccent,
                optionLabels: RadioState.bands.map(\.name),
                onSelect: { i in viewModel.setBand(RadioState.bands[i].defaultFreq) }
            ).equatable()
            SelectorButton(
                label: formatFilter(),
                color: .radioAccent,
                optionLabels: filterWidths.map { $0.1 >= 1000 ? "\($0.1/1000)k" : "\($0.1)" },
                onSelect: { i in viewModel.setFilter(filterWidths[i].0) }
            ).equatable()
            SelectorButton(
                label: attLabels[attIndex],
                color: attValues[attIndex] == 0 ? .radioMuted : .radioAccent,
                optionLabels: attLabels,
                onSelect: { i in viewModel.setAttenuator(attValues[i]) }
            ).equatable()
            SelectorButton(
                label: ipoLabels[ipoIndex],
                color: ipoValues[ipoIndex] == 0 ? .radioMuted : .radioAccent,
                optionLabels: ipoLabels,
                onSelect: { i in viewModel.setPreamp(ipoValues[i]) }
            ).equatable()
        }
        .padding(.horizontal, 6)
    }

    private func formatFilter() -> String {
        guard let hz = viewModel.state.filterHz else { return "—" }
        return hz >= 1000 ? "\(hz/1000)k" : "\(hz)"
    }
}

// MARK: - Selector Button (native Menu dropdown)

/// Equatable so `.equatable()` can skip rebuilding this view's body — and
/// therefore the Menu's presented content — when nothing it actually
/// displays has changed. Without this, QuickControlsRow re-renders every
/// time ANY @Published field on the shared RadioState changes (S-meter and
/// frequency update many times a second from CAT polling), which tears
/// down and rebuilds an OPEN Menu's content mid-tap: the first couple of
/// taps land on a menu item that's about to be replaced, and the menu
/// eventually closes on whichever selection wins that race — exactly the
/// "first taps do nothing, then it picks something almost at random"
/// behavior reported in testing. onSelect and color are deliberately
/// excluded from equality: closures aren't Equatable, and color is always
/// a pure function of the same index that produces the label, so label
/// alone is enough to detect a real change.
struct SelectorButton: View, Equatable {
    let label: String
    let color: Color
    let optionLabels: [String]
    let onSelect: (Int) -> Void

    static func == (lhs: SelectorButton, rhs: SelectorButton) -> Bool {
        lhs.label == rhs.label && lhs.optionLabels == rhs.optionLabels
    }

    var body: some View {
        Menu {
            ForEach(optionLabels.indices, id: \.self) { i in
                Button(optionLabels[i]) { onSelect(i) }
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(color)
                .cornerRadius(6)
        }
    }
}
