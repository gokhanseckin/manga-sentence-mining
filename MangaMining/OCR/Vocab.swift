import Foundation

/// One-line-per-token vocab from `vocab.txt`. Token id == line index.
/// First five tokens are special: [PAD], [UNK], [CLS], [SEP], [MASK].
/// IDs 5–999 are <unused0>…<unused994>. Everything else is real content.
struct Vocab: Sendable {
    private let tokens: [String]

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let raw = String(data: data, encoding: .utf8) else {
            print("[Vocab] FAILED to decode \(url.lastPathComponent) (\(data.count) bytes) as UTF-8")
            throw NSError(domain: "Vocab", code: 1, userInfo: [NSLocalizedDescriptionKey: "vocab is not utf-8"])
        }
        // Trailing newline produces an empty last entry; drop it.
        var lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let last = lines.last, last.isEmpty { lines.removeLast() }
        self.tokens = lines
        let sample912 = lines.indices.contains(912) ? lines[912] : "<missing>"
        let sample860 = lines.indices.contains(860) ? lines[860] : "<missing>"
        print("[Vocab] loaded \(lines.count) tokens from \(url.lastPathComponent) "
              + "(file=\(data.count)B, str=\(raw.count) chars). "
              + "id 912=\"\(sample912)\" id 860=\"\(sample860)\"")
    }

    var size: Int { tokens.count }

    /// Returns the unfiltered token string at this ID, for diagnostics.
    func rawToken(_ id: Int) -> String? {
        guard id >= 0, id < tokens.count else { return nil }
        return tokens[id]
    }

    /// Returns the token string for an ID, or nil if the ID is out of range or special.
    /// Strips the BERT `##` continuation prefix when present so decoded text reads cleanly.
    func render(_ id: Int) -> String? {
        guard id >= 0, id < tokens.count else { return nil }
        let raw = tokens[id]
        if raw.hasPrefix("[") || raw.hasPrefix("<unused") || raw.isEmpty { return nil }
        if raw.hasPrefix("##") { return String(raw.dropFirst(2)) }
        return raw
    }
}
