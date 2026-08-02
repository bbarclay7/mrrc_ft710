import SwiftUI

/// Main container — tabs for RX, DSP, and Settings.
struct ContentView: View {
    @EnvironmentObject var viewModel: RadioViewModel
    @State private var selectedTab = 0
    @State private var tuneStep: Int = 1000  // Hz, matches web default
    @State private var storeArmed = false
    @State private var memPage = 0

    var body: some View {
        ZStack {
            Color.radioBg.ignoresSafeArea()
            if !viewModel.state.powerOn { offState }
            else { onState }
            
            // Error alert overlay
            ErrorAlertView(
                showError: $viewModel.showErrorAlert,
                title: viewModel.errorTitle,
                message: viewModel.errorMessage,
                actionTitle: viewModel.errorActionTitle
            )
        }
    }

    private var offState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56, weight: .thin)).foregroundColor(.radioAccent)
            Text("FT-710").font(.title.weight(.semibold)).foregroundColor(.radioText)
            Text("Remote Control").font(.subheadline).foregroundColor(.radioMuted)
            if let err = viewModel.state.connectionError {
                Text(err).font(.caption).foregroundColor(.radioRed).padding(.horizontal)
            }
            Button(action: { viewModel.powerOnAsync() }) {
                Label("连接电台", systemImage: "power").font(.headline).foregroundColor(.black)
                    .frame(maxWidth: 240).frame(height: 50)
                    .background(Color.radioAccent).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
    }

    private var onState: some View {
        VStack(spacing: 0) {
            // Fixed header (frequency + status), like the web header bar
            HeaderView().padding(.horizontal, 10).padding(.top, 2).background(Color.radioBg)

            // Compact single-screen layout, no scrolling
            ZStack(alignment: .bottom) {
                VStack(spacing: 4) {
                    // ── FFT + Waterfall / Spectrum ──
                    VStack(spacing: 0) {
                        FFTLineView()
                            .frame(height: 66)
                        WaterfallView(tuneStep: tuneStep)
                            .frame(height: 67)
                    }
                    .frame(height: 133)
                    .padding(.horizontal, 6)

                    // ── S-meter ──
                    SMeterView()

                    // ── Multi-meter (always visible) ──
                    MeterBarView()

                    // ── Quick controls row (Mode·Band·Filter·ATT·IPO) ──
                    QuickControlsRow()

                    // ── User-configurable slider slots (Settings → Main Screen) ──
                    MainScreenSlotsView()

                    // ── DSP toggles ──
                    HStack(spacing: 4) {
                        Button(action: { viewModel.setNoiseReduction(!viewModel.state.noiseReduction) }) {
                            Text("NR").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.noiseReduction ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.noiseReduction ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setNoiseBlanker(!viewModel.state.noiseBlanker) }) {
                            Text("NB").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.noiseBlanker ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.noiseBlanker ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setAutoNotch(!viewModel.state.autoNotch) }) {
                            Text("AN").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.autoNotch ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.autoNotch ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setCompressor(!viewModel.state.compressor) }) {
                            Text("COMP").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.compressor ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.compressor ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setTuner(viewModel.state.tunerStatus == 1 ? 0 : 1) }) {
                            Text("ATU").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.tunerStatus == 1 ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.tunerStatus == 1 ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                    }.padding(.horizontal, 6)

                    // ── Volume slider (slim) ──
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.audioPlayback.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                            .font(.system(size: 10)).foregroundColor(.radioMuted)
                        Slider(value: Binding(
                            get: { Double(viewModel.audioPlayback.appVolume) },
                            set: { viewModel.audioPlayback.appVolume = Float($0) }
                        ), in: 0...1)
                            .tint(.radioAccent)
                    }.padding(.horizontal, 12)

                    // ── Tuning controls (matches web: ◀◀ ◀ [step] ▶ ▶▶) ──
                    HStack(spacing: 12) {
                        // Fast left (-5× step)
                        Button(action: { viewModel.stepFrequency(up: false, step: tuneStep * 5) }) {
                            Image(systemName: "chevron.left.2")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.radioAccent)
                                .frame(width: 44, height: 38).background(Color.radioSurface).cornerRadius(4)
                        }
                        // Slow left (-1× step)
                        Button(action: { viewModel.stepFrequency(up: false, step: tuneStep) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.radioAccent)
                                .frame(width: 44, height: 38).background(Color.radioSurface).cornerRadius(4)
                        }
                        // Step selector — tap to pick a step size directly
                        Menu {
                            ForEach([10, 100, 250, 1000, 5000, 10000, 25000, 50000, 100000, 1000000], id: \.self) { step in
                                Button(stepLabel(step)) { tuneStep = step }
                            }
                        } label: {
                            Text(stepLabel(tuneStep))
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                                .foregroundColor(.radioAccent)
                                .frame(width: 74, height: 38).background(Color.radioAccent.opacity(0.2)).cornerRadius(4)
                        }
                        // Slow right (+1× step)
                        Button(action: { viewModel.stepFrequency(up: true, step: tuneStep) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.radioAccent)
                                .frame(width: 44, height: 38).background(Color.radioSurface).cornerRadius(4)
                        }
                        // Fast right (+5× step)
                        Button(action: { viewModel.stepFrequency(up: true, step: tuneStep * 5) }) {
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.radioAccent)
                                .frame(width: 44, height: 38).background(Color.radioSurface).cornerRadius(4)
                        }
                    }.padding(.horizontal, 6)

                    // ── VFO buttons ──
                    HStack(spacing: 4) {
                        Button(action: { viewModel.setVFO("A") }) {
                            Text("VFO-A").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.activeVFO == "A" ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.activeVFO == "A" ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setVFO("B") }) {
                            Text("VFO-B").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.activeVFO == "B" ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.activeVFO == "B" ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setVFO(viewModel.state.activeVFO == "A" ? "B" : "A") }) {
                            Text("A=B").font(.system(size: 11, weight: .bold))
                                .foregroundColor(.radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(Color.radioSurface)
                                .cornerRadius(4)
                        }
                        Button(action: { viewModel.setSplit(!viewModel.state.split) }) {
                            Text("SPLIT").font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.state.split ? .black : .radioMuted)
                                .frame(maxWidth: .infinity).frame(height: 28)
                                .background(viewModel.state.split ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                    }.padding(.horizontal, 6)

                    // ── Memory channels grid ──
                    // Tap an M-button to recall. To store, tap STO first
                    // (arms store-mode like a calculator's memory key), then
                    // tap the M-button to save the current VFO/mode/filter
                    // into it. A long-press-to-store design was tried first
                    // and dropped: three different gesture approaches all
                    // still let the plain tap fire on finger-up regardless
                    // of hold duration. A real Button + a separate
                    // arm/disarm step has no such ambiguity.
                    //
                    // 12 slots total, paged 6 at a time (M1-6, M7-12, ...) —
                    // < and > page between them. MEM_CHANNEL_COUNT is a pure
                    // software limit (an array size in config.py), not a
                    // radio hardware constraint, so this can grow further
                    // just by bumping that constant and channelCount below.
                    let pageCount = (MemoryChannelsManager.channelCount + 5) / 6
                    HStack(spacing: 6) {
                        Text("MEMORY").font(.system(size: 9, weight: .bold)).foregroundColor(.radioMuted)
                        if pageCount > 1 {
                            Button(action: { memPage = max(0, memPage - 1) }) {
                                Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(memPage == 0 ? .radioMuted.opacity(0.3) : .radioAccent)
                            }.disabled(memPage == 0)
                            Text("M\(memPage*6+1)-\(min(memPage*6+6, MemoryChannelsManager.channelCount))")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.radioMuted)
                            Button(action: { memPage = min(pageCount - 1, memPage + 1) }) {
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(memPage == pageCount - 1 ? .radioMuted.opacity(0.3) : .radioAccent)
                            }.disabled(memPage == pageCount - 1)
                        }
                        Spacer()
                        Button(action: { storeArmed.toggle() }) {
                            Text("STO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(storeArmed ? .black : .radioAccent)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(storeArmed ? Color.radioAccent : Color.radioSurface)
                                .cornerRadius(4)
                        }
                    }.padding(.horizontal, 6)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(0..<6, id: \.self) { slot in
                            let index = memPage * 6 + slot
                            Button(action: {
                                guard index < MemoryChannelsManager.channelCount else { return }
                                if storeArmed {
                                    viewModel.saveMemory(index)
                                    storeArmed = false
                                } else {
                                    viewModel.recallMemory(index)
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Text("M\(index + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(.radioAccent)
                                    if let channel = viewModel.memoryChannels[index] {
                                        Text(channel.freqDisplay).font(.system(size: 10, design: .monospaced)).foregroundColor(Color.radioText)
                                    }
                                }.frame(maxWidth: .infinity).frame(height: 40)
                                    .background(storeArmed ? Color.radioAccent.opacity(0.25) : Color.radioSurface).cornerRadius(4)
                            }
                            .opacity(index < MemoryChannelsManager.channelCount ? 1 : 0)
                            .disabled(index >= MemoryChannelsManager.channelCount)
                        }
                    }.padding(.horizontal, 6)

                    Spacer(minLength: 0)
                }
                .background(Color.radioBg)

                // ── Fixed PTT footer (2× height for easy operation) ──
                VStack(spacing: 0) {
                    if viewModel.state.txStatus > 0 {
                        Rectangle().fill(Color.red.opacity(0.08)).frame(height: 8)
                    }
                    HStack(spacing: 8) {
                        // PTT: press-and-hold — touch down TX, release RX
                        Text(viewModel.state.txStatus > 0 ? "● TX ●" : "PTT")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 96)
                            .background(viewModel.state.txStatus > 0 ? Color.red : Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if viewModel.state.txStatus == 0 { viewModel.setPTT(true) }
                                    }
                                    .onEnded { _ in
                                        if viewModel.state.txStatus > 0 { viewModel.setPTT(false) }
                                    }
                            )
                        Button(action: { viewModel.toggleTuner() }) {
                            Text("TUNE").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
                                .frame(width: 80, height: 96).background(Color.yellow).cornerRadius(8)
                        }
                        Button(action: { viewModel.toggleRecording() }) {
                            Text("REC").font(.system(size: 18, weight: .bold))
                                .foregroundColor(viewModel.audioCapture.isRecording ? .red : .radioText)
                                .frame(width: 80, height: 96).background(Color.radioSurface).cornerRadius(8)
                        }
                        Button(action: { viewModel.runTunerAssist() }) {
                            Image(systemName: viewModel.state.tunerAssistRunning ? "hourglass" : "dial.low")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(viewModel.state.tunerAssistRunning ? .radioMuted : .radioAccent)
                                .frame(width: 56, height: 96).background(Color.radioSurface).cornerRadius(8)
                        }
                        .disabled(viewModel.state.tunerAssistRunning)
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.radioBg.opacity(0.97))
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.showSettings },
            set: { viewModel.state.showSettings = $0 }
        )) {
            SettingsView()
        }
    }

    /// Format step size label: 10→"10Hz", 1000→"1kHz", 1000000→"1MHz", etc.
    private func stepLabel(_ hz: Int) -> String {
        if hz >= 1_000_000 {
            return "\(hz / 1_000_000)MHz"
        } else if hz >= 1000 {
            return "\(hz / 1000)kHz"
        }
        return "\(hz)Hz"
    }
}

// MARK: - PTT Bar (reused from reference with minor adaptations)

struct PTTBar: View {
    let pressing: Bool; let txLevel: Float; let txPower: Float
    let onPress: () -> Void; let onRelease: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if pressing {
                HStack(spacing: 8) {
                    Text(String(format: "%.0fW", txPower)).font(.caption.monospaced().bold()).foregroundColor(.radioRed)
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.radioRed)
                                .frame(width: max(6, CGFloat(txLevel * 3) * 200), height: 6)
                        }
                }.padding(.horizontal, 40)
            }
            Button(action: {}) {
                Text(pressing ? "● TX ●" : "PTT")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(pressing ? .black : Color.red)
                    .frame(maxWidth: 320).frame(height: 84)
                    .background(pressing ? Color.red : Color.red.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(PTTPressStyle(onPress: onPress, onRelease: onRelease))
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Color.radioBg.opacity(0.97))
    }
}

struct PTTPressStyle: ButtonStyle {
    let onPress: () -> Void; let onRelease: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, p in if p { onPress() } else { onRelease() } }
    }
}
