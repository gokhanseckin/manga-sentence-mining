import Foundation
import IPADic
import Mecab_Swift

struct JapaneseToken: Sendable, Equatable {
    var surface: String
    var lemma: String
    var reading: String
    var partOfSpeech: String
    var range: Range<String.Index>
}

actor JapaneseTokenizer {
    static let shared = JapaneseTokenizer()

    private var tagger: Tokenizer?

    func tokenize(_ text: String) throws -> [JapaneseToken] {
        let tagger = try ensureTagger()
        let annotations = tagger.tokenize(text: text, transliteration: .hiragana)
        return annotations.map { ann in
            JapaneseToken(
                surface: ann.base,
                lemma: ann.dictionaryForm.isEmpty ? ann.base : ann.dictionaryForm,
                reading: ann.reading,
                partOfSpeech: String(describing: ann.partOfSpeech),
                range: ann.range
            )
        }
    }

    private func ensureTagger() throws -> Tokenizer {
        if let tagger { return tagger }
        let dictionary = IPADic()
        let tagger = try Tokenizer(dictionary: dictionary)
        self.tagger = tagger
        return tagger
    }
}
