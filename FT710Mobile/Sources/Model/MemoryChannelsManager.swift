import Foundation

/// Manages FT-710 memory channels. Slot count must match the server's
/// MEM_CHANNEL_COUNT (config.py) — currently 12, named M1-M12.
/// Loaded on connect via fullState, updated via broadcast.
@MainActor
final class MemoryChannelsManager: ObservableObject {
    static let channelCount = 12

    @Published var channels: [MemoryChannel?] = Array(repeating: nil, count: channelCount)

    struct MemoryChannel: Codable, Identifiable, Equatable {
        var id: Int { index }
        let index: Int
        var name: String
        var freq: Int
        var mode: String
        var filterWidth: Int

        var freqDisplay: String {
            String(format: "%d.%03d.%03d", freq / 1_000_000, (freq % 1_000_000) / 1000, freq % 1000)
        }
    }

    /// Elements are `Any`, not `[String: Any]`: the server's array always
    /// mixes populated slots (dictionaries) with empty ones (JSON null).
    /// Casting straight to `[[String: Any]]` requires every single element
    /// to be a dictionary — one `null` anywhere in the array fails the
    /// whole cast, silently dropping every saved channel. That's exactly
    /// what made saved memories look like they never persisted: it only
    /// ever "worked" when literally all slots happened to be full.
    func loadFromServer(_ raw: [Any]) {
        channels = Array(repeating: nil, count: Self.channelCount)
        for (i, element) in raw.enumerated() where i < Self.channelCount {
            guard let item = element as? [String: Any], let freq = item["freq"] as? Int else { continue }
            channels[i] = MemoryChannel(
                index: i,
                name: item["name"] as? String ?? "M\(i+1)",
                freq: freq,
                mode: item["mode"] as? String ?? "USB",
                filterWidth: item["filter_width"] as? Int ?? 5
            )
        }
    }

    func storeFrequency(_ index: Int, freq: Int, mode: String, filterWidth: Int) {
        guard index >= 0, index < Self.channelCount else { return }
        let name = "M\(index + 1)"
        channels[index] = MemoryChannel(index: index, name: name, freq: freq, mode: mode, filterWidth: filterWidth)
    }
}
