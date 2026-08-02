import SwiftUI

/// Top header: status dots + VFO A/B + S-meter reading + power toggle.
struct HeaderView: View {
    @EnvironmentObject var viewModel: RadioViewModel
    @State private var showFreqEntry = false
    @State private var freqEntryText = ""

    var body: some View {
        VStack(spacing: 2) {
            // Row 1: Status + meters (1.5× size)
            HStack(spacing: 12) {
                Text(viewModel.state.sUnit)
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.radioGreen)

                wsDot(viewModel.state.ctrlConnected, "C")
                wsDot(viewModel.state.spectrumConnected, "S")
                wsDot(viewModel.state.audioRXConnected, "R")
                wsDot(viewModel.state.audioTXConnected, "T")

                if viewModel.state.tunerStatus == 2 {
                    Text("TUNE").font(.system(size: 18, weight: .bold)).foregroundColor(.radioAccent)
                }

                if viewModel.state.serialConnected {
                    Circle().fill(Color.green).frame(width: 9, height: 9)
                }

                Spacer()

                // Settings gear button
                Button(action: { viewModel.state.showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.radioMuted)
                }

                // VFO A/B toggle
                HStack(spacing: 0) {
                    Button("A") { viewModel.setVFO("A") }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.state.activeVFO == "A" ? .black : .radioMuted)
                        .frame(width: 42, height: 36)
                        .background(viewModel.state.activeVFO == "A" ? Color.radioAccent : Color.radioSurface)
                    Button("B") { viewModel.setVFO("B") }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.state.activeVFO == "B" ? .black : .radioMuted)
                        .frame(width: 42, height: 36)
                        .background(viewModel.state.activeVFO == "B" ? Color.radioAccent : Color.radioSurface)
                }.cornerRadius(5)

                // Power toggle
                Button(action: {
                    viewModel.state.powerOn ? viewModel.powerOff() : viewModel.powerOnAsync()
                }) {
                    Image(systemName: viewModel.state.powerOn ? "power.circle.fill" : "power.circle")
                        .font(.title3).foregroundColor(viewModel.state.powerOn ? .green : .radioMuted)
                }
            }

            // Row 2: Frequency display (fills row) — tap to enter directly
            FrequencyDisplayView(freqHz: viewModel.state.activeFreq)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    freqEntryText = ""
                    showFreqEntry = true
                }
                .alert("Enter Frequency (kHz)", isPresented: $showFreqEntry) {
                    TextField("14074", text: $freqEntryText)
                        .keyboardType(.numberPad)
                    Button("Set") {
                        if let khz = Int(freqEntryText) {
                            viewModel.setFrequency(khz * 1000)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

            // Row 3: UTC clock (left) + band name (right)
            HStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.utcTimeString(context.date))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.radioMuted)
                }
                Spacer()
                Text(viewModel.state.bandName)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.radioAccent)
            }.padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }

    private func wsDot(_ on: Bool, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(on ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(.radioMuted)
        }
    }

    private static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private static let weekdayAbbrevs = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private static func utcTimeString(_ date: Date) -> String {
        let c = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date)
        let day = weekdayAbbrevs[c.weekday ?? 0]
        return String(format: "%@ %04d-%02d-%02d %02d:%02d:%02dZ",
                       day, c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}
