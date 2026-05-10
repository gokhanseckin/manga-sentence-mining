import CryptoKit
import Foundation

/// All user-visible strings, in English. Comments are sent to the LLM
/// translator alongside the source text so it can render an accurate
/// translation that preserves the button's intent.
enum BaseStrings {

    struct Entry: Sendable {
        let key: String
        let value: String
        let comment: String
    }

    static let entries: [Entry] = [
        // App identity
        Entry(key: "app.name", value: "Japanese Sentence Mining", comment: "App display name. Keep proper-noun-like; avoid translating 'Japanese' literally if the language uses a localized name for the language Japanese."),
        Entry(key: "app.tagline", value: "Capture printed Japanese pages and turn them into review cards.", comment: "Short marketing tagline shown on the home screen below the app name."),

        // Home screen
        Entry(key: "home.review.due", value: "Review (%@ due)", comment: "Button label on the home screen showing how many cards are due. The %@ placeholder is replaced by a number."),
        Entry(key: "home.review.allCaughtUp", value: "All caught up — mine more sentences", comment: "Hint shown when no cards are due. Encourages the user to capture more pages."),
        Entry(key: "home.capture.button", value: "Capture", comment: "Button label that opens the camera to scan a new page."),
        Entry(key: "home.gallery.button", value: "Open from gallery", comment: "Button label that opens the photo library to pick an existing image."),
        Entry(key: "home.savedSentences", value: "Saved sentences", comment: "Button to view all previously captured sentences."),
        Entry(key: "home.clozedWords", value: "Clozed words (%@)", comment: "Button to view all word cards. %@ is replaced by the count of active cards."),

        // Settings
        Entry(key: "settings.title", value: "Settings", comment: "Settings screen title."),
        Entry(key: "settings.language", value: "Language", comment: "Settings row that opens the language picker. This language affects both the app interface and the translation language for captured sentences."),
        Entry(key: "settings.iCloudSync", value: "Sync with iCloud", comment: "Toggle row for enabling iCloud sync of word cards across devices."),
        Entry(key: "settings.iCloudSync.description", value: "Sync your word cards across your devices using your iCloud account.", comment: "Explanation under the iCloud sync toggle."),
        Entry(key: "settings.apiKey", value: "Gemini API Key", comment: "Settings row to enter or update the Gemini API key."),
        Entry(key: "settings.cameraRoll", value: "Save captures to Photos", comment: "Toggle row for saving scanned page photos to the user's photo library."),
        Entry(key: "settings.sessionSize", value: "Review session size", comment: "Setting controlling how many cards are shown in a single review session."),

        // Review
        Entry(key: "review.title", value: "Review", comment: "Navigation title of the review/quiz screen."),
        Entry(key: "review.checkAnswer", value: "Check answer", comment: "Button to submit the user's answer in a review quiz."),
        Entry(key: "review.next", value: "Next", comment: "Button to proceed to the next review card."),
        Entry(key: "review.skip", value: "Skip", comment: "Button to skip the current review card without answering."),
        Entry(key: "review.correct", value: "Correct", comment: "Feedback shown when the user answers correctly."),
        Entry(key: "review.incorrect", value: "Incorrect", comment: "Feedback shown when the user answers incorrectly."),
        Entry(key: "review.completed", value: "Session complete", comment: "Title shown at the end of a review session."),
        Entry(key: "review.remaining", value: "%@ left", comment: "Counter showing remaining cards in the current review session. %@ is replaced by a number."),
        Entry(key: "review.knownToggle", value: "Known", comment: "Toggle on the review screen to mark the current card as 'already known'."),
        Entry(key: "review.allCaughtUp.title", value: "All caught up", comment: "Title shown on the review screen when there are no due cards."),
        Entry(key: "review.allCaughtUp.body", value: "Mine more sentences to grow the review pool.", comment: "Body shown when there are no due cards."),

        // Onboarding
        Entry(key: "onboarding.language.title", value: "Choose your language", comment: "Onboarding screen title for the language picker."),
        Entry(key: "onboarding.language.body", value: "We'll translate sentences into this language and show the app in it. You can change this later in Settings.", comment: "Explanation below the language picker on onboarding."),
        Entry(key: "onboarding.language.continue", value: "Continue", comment: "Button advancing past the language picker."),
        Entry(key: "onboarding.welcome.title", value: "Welcome", comment: "Onboarding welcome screen title."),
        Entry(key: "onboarding.welcome.body", value: "Capture pages from manga, novels, newspapers, or any printed Japanese text. We'll extract sentences, translate them, and turn the words into review cards.", comment: "Onboarding welcome screen body text."),
        Entry(key: "onboarding.welcome.continue", value: "Get started", comment: "Button to advance past the welcome screen."),
        Entry(key: "onboarding.apiKey.title", value: "Add your Gemini API Key", comment: "Onboarding screen title for entering the API key."),
        Entry(key: "onboarding.apiKey.body", value: "Bring your own Google Gemini API key to power OCR and translation.", comment: "Explanation on the API key onboarding screen."),
        Entry(key: "onboarding.apiKey.placeholder", value: "Paste your API key", comment: "Placeholder text inside the API key text field."),
        Entry(key: "onboarding.apiKey.privacy", value: "Pages you scan are sent to Google Gemini for OCR and translation. Images are not retained by Google per their API terms.", comment: "Privacy disclosure shown on the API key onboarding screen."),
        Entry(key: "onboarding.apiKey.continue", value: "Save and continue", comment: "Button to save the API key and finish onboarding."),

        // Processing (OCR pipeline)
        Entry(key: "processing.readingPage", value: "Reading the page…", comment: "Status shown with a spinner while the app OCRs and translates a captured page."),

        // Translation in progress
        Entry(key: "translation.inProgress.title", value: "Translating interface…", comment: "Title shown while the app translates its interface to a non-bundled language at onboarding."),
        Entry(key: "translation.inProgress.body", value: "This usually takes a few seconds.", comment: "Body shown below the translation-in-progress title."),
        Entry(key: "translation.failed.title", value: "Translation failed", comment: "Title of the error shown when interface translation fails."),
        Entry(key: "translation.failed.body", value: "We couldn't translate the interface. The app will continue in English. You can retry in Settings.", comment: "Body of the translation failure error."),
        Entry(key: "translation.failed.retry", value: "Retry", comment: "Button to retry interface translation."),
        Entry(key: "translation.failed.continueEnglish", value: "Continue in English", comment: "Button to dismiss the translation failure and use English."),

        // Common
        Entry(key: "common.cancel", value: "Cancel", comment: "Generic cancel button label."),
        Entry(key: "common.save", value: "Save", comment: "Generic save button label."),
        Entry(key: "common.done", value: "Done", comment: "Generic done/close button label."),

        // Furigana
        Entry(key: "furigana.show", value: "Show furigana", comment: "Button label to reveal kana readings above kanji."),
        Entry(key: "furigana.hide", value: "Hide furigana", comment: "Button label to remove kana readings above kanji."),

        // Document type
        Entry(key: "documentType.manga", value: "Manga", comment: "Label for manga-format documents (comics with panels and speech bubbles)."),
        Entry(key: "documentType.print", value: "Print", comment: "Label for non-manga printed documents (novels, newspapers, textbooks, children's books)."),
        Entry(key: "documentType.unknown", value: "Unknown", comment: "Label shown when the document type hasn't been classified yet."),

        // Errors
        Entry(key: "error.apiKey.missing", value: "Add your Gemini API key in Settings to recognize text.", comment: "Error shown when the user attempts OCR without configuring an API key."),
        Entry(key: "error.network", value: "Network error. Check your connection and try again.", comment: "Generic network error message."),
    ]

    static let lookup: [String: Entry] = {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0) })
    }()

    /// Stable hash of an entry's English source. Translation files store the
    /// hash they were generated from; on app update, mismatches trigger a
    /// targeted re-translation of just the changed keys.
    static func sourceHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
