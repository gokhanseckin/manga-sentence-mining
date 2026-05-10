import SwiftUI

/// Renders Japanese text with an optional per-token furigana annotation.
/// Tokenization runs on first toggle-on per sentence and the result is
/// cached for the lifetime of the view.
///
/// Ruby is rendered as a VStack of (kana, surface) per kanji-bearing token
/// so we don't depend on the iOS-version-specific RubyAnnotation
/// AttributedString API. Pure-kana tokens render inline without a stack.
struct JapaneseText: View {
    let text: String
    @Binding var showFurigana: Bool
    var font: Font = .body

    @State private var tokens: [JapaneseToken] = []
    @State private var hasTokenized = false
    @State private var isTokenizing = false

    var body: some View {
        Group {
            if showFurigana, hasTokenized {
                FuriganaFlow(tokens: tokens, font: font)
            } else {
                Text(text).font(font)
            }
        }
        .task(id: showFurigana) {
            guard showFurigana, !hasTokenized, !isTokenizing else { return }
            await tokenize()
        }
    }

    private func tokenize() async {
        isTokenizing = true
        defer { isTokenizing = false }
        if let tokens = try? await JapaneseTokenizer.shared.tokenize(text) {
            self.tokens = tokens
            self.hasTokenized = true
        }
    }
}

private struct FuriganaFlow: View {
    let tokens: [JapaneseToken]
    let font: Font

    var body: some View {
        FlowLayout(spacing: 2) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                VStack(spacing: 0) {
                    Text(shouldAnnotate(token) ? katakanaToHiragana(token.reading) : " ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(token.surface).font(font)
                }
            }
        }
    }

    private func shouldAnnotate(_ token: JapaneseToken) -> Bool {
        let reading = token.reading
        guard !reading.isEmpty, reading != "*" else { return false }
        return token.surface.unicodeScalars.contains { CharacterSet.jpKanji.contains($0) }
    }

    private func katakanaToHiragana(_ s: String) -> String {
        String(s.unicodeScalars.map { scalar -> Character in
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = Unicode.Scalar(scalar.value - 0x60) {
                return Character(converted)
            }
            return Character(scalar)
        })
    }
}

private extension CharacterSet {
    static let jpKanji: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: Unicode.Scalar(0x4E00)!...Unicode.Scalar(0x9FFF)!)
        set.insert(charactersIn: Unicode.Scalar(0x3400)!...Unicode.Scalar(0x4DBF)!)
        return set
    }()
}

/// Toggle button for furigana display. Used as a toolbar accessory next to
/// any JapaneseText view.
struct FuriganaToggleButton: View {
    @Binding var showFurigana: Bool
    @Environment(LocalizationStore.self) private var loc

    var body: some View {
        Button {
            showFurigana.toggle()
        } label: {
            Image(systemName: showFurigana ? "textformat.alt" : "textformat")
                .accessibilityLabel(showFurigana ? loc.t("furigana.hide") : loc.t("furigana.show"))
        }
    }
}
