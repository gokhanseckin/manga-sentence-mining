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

        // Common (additional)
        Entry(key: "common.delete", value: "Delete", comment: "Generic destructive delete button label."),
        Entry(key: "common.edit", value: "Edit", comment: "Generic edit button label."),
        Entry(key: "common.back", value: "Back", comment: "Generic back-navigation button label."),
        Entry(key: "common.retry", value: "Retry", comment: "Generic retry button label."),

        // Sentence detail screen
        Entry(key: "sentenceDetail.title", value: "Sentence", comment: "Navigation title for the sentence detail screen."),
        Entry(key: "sentenceDetail.section.original", value: "Original (日本語)", comment: "Form section header showing the original Japanese sentence. Keep the parenthetical hint in Japanese kanji."),
        Entry(key: "sentenceDetail.section.reading", value: "Reading (ひらがな)", comment: "Form section header showing the hiragana reading of the sentence. Keep the parenthetical hint in Japanese hiragana."),
        Entry(key: "sentenceDetail.section.translationGeneric", value: "Translation", comment: "Form section header for the translation when the language name is unavailable."),
        Entry(key: "sentenceDetail.section.translationNamed", value: "Translation (%@)", comment: "Form section header for the translation including the localized language name. %@ is the language name (e.g. 'Turkish')."),
        Entry(key: "sentenceDetail.section.captured", value: "Captured", comment: "Form section header above the captured-photo metadata (date and source image)."),
        Entry(key: "sentenceDetail.section.clozes", value: "Clozes", comment: "Form section header for the cloze-picking action."),
        Entry(key: "sentenceDetail.pickClozes", value: "Pick clozes", comment: "Button to open the cloze picker for a sentence with no clozes yet."),
        Entry(key: "sentenceDetail.pickMoreClozes", value: "Pick more clozes", comment: "Button to open the cloze picker for a sentence that already has some clozes."),
        Entry(key: "sentenceDetail.clozes.editLocked", value: "Editing the sentence is locked while clozes exist.", comment: "Footer note explaining why the sentence text cannot be edited once clozes have been picked from it."),
        Entry(key: "sentenceDetail.section.pickedWords", value: "Picked words (%@)", comment: "Form section header listing words clozed from this sentence. %@ is the count."),
        Entry(key: "sentenceDetail.quizClozes", value: "Quiz these clozes", comment: "Button to start a review session limited to the clozes from this sentence."),
        Entry(key: "sentenceDetail.delete", value: "Delete sentence", comment: "Destructive button label that deletes the sentence."),
        Entry(key: "sentenceDetail.deleteConfirm.title", value: "Delete this sentence?", comment: "Confirmation dialog title shown before deleting a sentence."),
        Entry(key: "sentenceDetail.clozeMeta", value: "%@ · %@ · %@", comment: "Metadata line under a cloze surface form: lemma, reading, part-of-speech. The three %@ are inserted in that order."),
        Entry(key: "sentenceDetail.field.original.placeholder", value: "Original", comment: "Placeholder for the original-sentence text field while editing."),
        Entry(key: "sentenceDetail.field.reading.placeholder", value: "Reading", comment: "Placeholder for the reading text field while editing."),
        Entry(key: "sentenceDetail.field.translation.placeholder", value: "Translation", comment: "Placeholder for the translation text field while editing."),

        // Saved sentences screen
        Entry(key: "savedSentences.title", value: "Saved sentences", comment: "Navigation title for the list of all saved sentences."),
        Entry(key: "savedSentences.empty.title", value: "No sentences yet", comment: "Empty-state title when no sentences have been captured."),
        Entry(key: "savedSentences.empty.body", value: "Capture a manga page from the home screen.", comment: "Empty-state body encouraging the user to capture their first page."),

        // Settings (additional)
        Entry(key: "settings.section.ocrProvider", value: "OCR provider", comment: "Settings section header for the OCR provider picker."),
        Entry(key: "settings.providerPicker", value: "Provider", comment: "Picker label for choosing which OCR provider to use."),
        Entry(key: "settings.saveToCameraRoll", value: "Save photos to camera roll", comment: "Toggle row that copies captured pages to the iOS Photos library."),
        Entry(key: "settings.saveToCameraRoll.footer", value: "When enabled, captured pages are also saved to your iOS Photos library.", comment: "Footer note explaining the camera-roll toggle."),
        Entry(key: "settings.section.review", value: "Review", comment: "Settings section header for review-related options."),
        Entry(key: "settings.review.footer", value: "Ebisu priors apply to newly picked clozes only. Existing scheduled questions keep their current state.", comment: "Footer note clarifying that review priors only affect new clozes. 'Ebisu' is the SRS algorithm name."),
        Entry(key: "settings.sessionSize.label", value: "Session size: %@", comment: "Stepper label showing the current review session size. %@ is the number."),
        Entry(key: "settings.review.alpha", value: "Initial α", comment: "Label for the initial Ebisu alpha parameter (Greek letter alpha)."),
        Entry(key: "settings.review.beta", value: "Initial β", comment: "Label for the initial Ebisu beta parameter (Greek letter beta)."),
        Entry(key: "settings.review.tHours", value: "Initial t (hours)", comment: "Label for the initial Ebisu time parameter, in hours."),
        Entry(key: "settings.section.apiKey", value: "API key", comment: "Settings section header for the API key entry row."),
        Entry(key: "settings.apiKey.field.placeholder", value: "%@ key", comment: "Secure-field placeholder for the API key, where %@ is the provider's display name (e.g. 'Gemini')."),
        Entry(key: "settings.apiKey.save", value: "Save key", comment: "Button to save the entered API key to the keychain."),
        Entry(key: "settings.apiKey.saved", value: "Saved", comment: "Transient label shown after the API key was successfully saved."),
        Entry(key: "settings.apiKey.remove", value: "Remove saved key", comment: "Destructive button label to remove the saved API key from the keychain."),
        Entry(key: "settings.apiKey.footer", value: "Keys are stored in the iOS Keychain on this device only.", comment: "Footer note explaining where the API key is stored."),

        // Candidate picker (after OCR)
        Entry(key: "candidatePicker.title", value: "Pick sentences", comment: "Navigation title for the screen where the user picks which OCR'd sentences to keep."),
        Entry(key: "candidatePicker.footer", value: "Edit any line before saving. Unselected items are discarded.", comment: "Footer note explaining the candidate-picker screen."),
        Entry(key: "candidatePicker.field.original.placeholder", value: "Original (日本語)", comment: "Placeholder for the original sentence field in the candidate picker. Keep the parenthetical Japanese hint."),
        Entry(key: "candidatePicker.field.reading.placeholder", value: "Reading (ひらがな)", comment: "Placeholder for the reading field in the candidate picker. Keep the parenthetical hiragana hint."),
        Entry(key: "candidatePicker.field.translation.placeholder", value: "Translation", comment: "Placeholder for the translation field in the candidate picker."),

        // Capture preview
        Entry(key: "capturePreview.mine", value: "Mine sentences", comment: "Primary button on the capture preview screen that runs OCR on the photo."),
        Entry(key: "capturePreview.retake", value: "Retake", comment: "Button on the capture preview that discards the photo and reopens the camera."),

        // Word detail screen
        Entry(key: "wordDetail.partOfSpeech", value: "Part of speech", comment: "Label for the grammatical part of speech of a word card (noun, verb, etc.)."),
        Entry(key: "wordDetail.due", value: "Due", comment: "Label for when the next review of this word is due."),
        Entry(key: "wordDetail.sentencesCount", value: "Sentences", comment: "Label for the count of sentences linked to this word card."),
        Entry(key: "wordDetail.sentencesValue", value: "%@ active · %@ excluded", comment: "Value showing how many linked sentences are active vs excluded from review. Both %@ are counts."),
        Entry(key: "wordDetail.aggregate", value: "Aggregate", comment: "Label for the aggregated correct-answer ratio across all sentences for this word."),
        Entry(key: "wordDetail.aggregateValue", value: "%@/%@ correct", comment: "Aggregated review stats: correct over total. Both %@ are integers."),
        Entry(key: "wordDetail.firstClozed", value: "First clozed", comment: "Label for the date the user first turned this word into a cloze card."),
        Entry(key: "wordDetail.markKnown", value: "Mark as known", comment: "Toggle to mark the word as already-known so it stops appearing in reviews."),
        Entry(key: "wordDetail.drill", value: "Drill this word", comment: "Button that starts a review session limited to this word."),
        Entry(key: "wordDetail.section.sentences", value: "Sentences", comment: "Form section header for the list of sentences containing this word."),
        Entry(key: "wordDetail.noSentences", value: "No sentences linked.", comment: "Placeholder shown when no sentences are linked to this word card."),
        Entry(key: "wordDetail.delete", value: "Delete cloze", comment: "Destructive button to delete this word card and all its review history."),
        Entry(key: "wordDetail.deleteConfirm.title", value: "Delete this clozed word?", comment: "Confirmation dialog title before deleting a word card."),
        Entry(key: "wordDetail.deleteConfirm.message", value: "Removes %@ from clozed words and clears its review history. The sentences themselves stay.", comment: "Confirmation dialog message before deleting a word card. %@ is the word's lemma (dictionary form)."),
        Entry(key: "wordDetail.askThisSentence", value: "Ask this sentence", comment: "Toggle (accessibility label) controlling whether a specific sentence is asked during reviews of this word."),
        Entry(key: "wordDetail.attempts", value: "%@/%@ correct", comment: "Per-sentence review stats: correct over total attempts. Both %@ are integers."),

        // Clozed words list screen
        Entry(key: "clozedWords.title", value: "Clozed words (%@)", comment: "Navigation title for the list of all clozed word cards. %@ is the count."),
        Entry(key: "clozedWords.empty.title", value: "No clozed words yet", comment: "Empty-state title when no word cards exist."),
        Entry(key: "clozedWords.empty.body", value: "Pick clozes from a sentence to start tracking words.", comment: "Empty-state body for the clozed-words list."),
        Entry(key: "clozedWords.sort", value: "Sort", comment: "Toolbar picker label for sorting the clozed-words list."),
        Entry(key: "clozedWords.sort.recentlyAdded", value: "Recently added", comment: "Sort option: list newly added word cards first."),
        Entry(key: "clozedWords.sort.dueSoonest", value: "Due soonest", comment: "Sort option: list word cards whose next review is soonest first."),
        Entry(key: "clozedWords.known", value: "Known", comment: "Small badge shown next to a word marked as known."),
        Entry(key: "clozedWords.dueIn", value: "Will be due in %@", comment: "Subtitle showing when a word card is next due. %@ is a human-readable duration like '3 days 4 hours'."),
        Entry(key: "clozedWords.stats.singular", value: "%@/%@ correct · %@ sentence", comment: "Stats line for a word card linked to exactly 1 sentence. The three %@ are: correct count, total count, sentence count (always 1)."),
        Entry(key: "clozedWords.stats.plural", value: "%@/%@ correct · %@ sentences", comment: "Stats line for a word card linked to multiple sentences. The three %@ are: correct count, total count, sentence count."),

        // Cloze picker
        Entry(key: "clozePicker.title", value: "Pick clozes", comment: "Navigation title of the cloze picker (tokenized-words selection screen)."),
        Entry(key: "clozePicker.tokenizing", value: "Tokenizing…", comment: "Progress label shown while the Japanese tokenizer is splitting the sentence into words."),
        Entry(key: "clozePicker.error.title", value: "Couldn't tokenize", comment: "Error title shown when tokenization fails."),
        Entry(key: "clozePicker.instructions", value: "Tap each word you want to quiz. Already-clozed words are dimmed.", comment: "Instructions shown above the tappable word chips on the cloze picker."),
        Entry(key: "clozePicker.saveWithCount", value: "Save (%@)", comment: "Confirmation button label when the user has selected one or more words. %@ is the selection count."),

        // Processing screen (errors)
        Entry(key: "processing.error.noTextDefault", value: "No text found.", comment: "Fallback message shown on the failure screen if no specific error is available."),
        Entry(key: "processing.error.loadPhoto", value: "Couldn't load captured photo from disk.", comment: "Error shown when the captured photo file cannot be read from disk."),
        Entry(key: "processing.error.noText", value: "No text found. Try re-shooting.", comment: "Error shown when OCR returns no sentences. Suggests the user retake the photo."),
        Entry(key: "processing.error.readImage", value: "Couldn't read the image.", comment: "Error shown when the OCR provider could not decode the image data."),
        Entry(key: "processing.error.ocrFailed", value: "OCR failed: %@", comment: "Generic OCR failure message. %@ is the underlying error description from the OS or provider."),
        Entry(key: "processing.openSettings", value: "Open Settings", comment: "Button shown on the OCR failure screen when the API key is missing — opens the Settings sheet."),
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
