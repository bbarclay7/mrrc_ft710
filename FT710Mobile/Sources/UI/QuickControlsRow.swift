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
                options: RadioState.uiModes.map { mode in
                    (label: mode, action: { viewModel.setMode(mode) })
                }
            )
            SelectorButton(
                label: RadioState.bands[bandIndex].name,
                color: .radioAccent,
                options: RadioState.bands.map { band in
                    (label: band.name, action: { viewModel.setBand(band.defaultFreq) })
                }
            )
            SelectorButton(
                label: formatFilter(),
                color: .radioAccent,
                options: filterWidths.map { idx, hz in
                    (label: hz >= 1000 ? "\(hz/1000)k" : "\(hz)", action: { viewModel.setFilter(idx) })
                }
            )
            SelectorButton(
                label: attLabels[attIndex],
                color: attValues[attIndex] == 0 ? .radioMuted : .radioAccent,
                options: attValues.indices.map { i in
                    (label: attLabels[i], action: { viewModel.setAttenuator(attValues[i]) })
                }
            )
            SelectorButton(
                label: ipoLabels[ipoIndex],
                color: ipoValues[ipoIndex] == 0 ? .radioMuted : .radioAccent,
                options: ipoValues.indices.map { i in
                    (label: ipoLabels[i], action: { viewModel.setPreamp(ipoValues[i]) })
                }
            )
        }
        .padding(.horizontal, 6)
    }

    private func formatFilter() -> String {
        guard let hz = viewModel.state.filterHz else { return "—" }
        return hz >= 1000 ? "\(hz/1000)k" : "\(hz)"
    }
}

// MARK: - Selector Button (native Menu dropdown)

struct SelectorButton: View {
    let label: String
    let color: Color
    let options: [(label: String, action: () -> Void)]

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].label, action: options[i].action)
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
