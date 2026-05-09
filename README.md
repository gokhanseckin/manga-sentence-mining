# Manga Sentence Mining

iOS-only sentence-mining app for Japanese learners. Camera-based capture of printed manga, cloud OCR + Turkish translation in one call, on-device tokenization, multiple-choice cloze-deletion review with Bayesian SRS scheduled per lemma.

See [manga-mining-app-spec.md](manga-mining-app-spec.md) for the full spec.

## Status

| Phase | Status |
|---|---|
| Phase 0 — Prototype | **Shipped, in daily use.** Gemini 2.5 Flash whole-page OCR; camera + gallery import; capture preview + retake; sentence list with edit/delete; Keychain-stored API key. |
| Phase 1 — MVP | **Shipped.** Mecab-Swift + IPADIC tokenizer (actor-isolated); cloze picking; Ebisu v2 Bayesian SRS scheduled per lemma (`WordCard`); MCQ quiz with furigana toggle; POS + length-similar distractors; due-count Home CTA; SRS settings. |
| Phase 1 polish | **Shipped.** Drill button on sentence detail; inline + fullscreen source image with pinch-zoom; OCR retry; capture preview before mining; Mecab-authoritative readings (LLM `reading` field dropped from prompt). |
| Phase 2+ | **Not committed.** Candidate menu in spec §2 (iCloud sync, JMdict-based distractors, additional OCR providers, on-device Vision OCR, audio/TTS, Anki export, time-weighted scoring). |

## Requirements

- iOS 26+ (real device — camera-driven; simulator only works for gallery import)
- Xcode with iOS 26 SDK, Swift 6 strict concurrency
- `xcodegen` (Homebrew)
- A Gemini API key (entered in Settings on first run; stored in Keychain)

## Setup

```bash
git clone https://github.com/gokhanseckin/manga-sentence-mining.git
cd manga-sentence-mining

brew install xcodegen
xcodegen generate
open MangaMining.xcodeproj
```

The Xcode project is generated from [project.yml](project.yml) and is gitignored. Re-run `xcodegen generate` whenever sources or settings change.

On first launch, OCR fails with "Add your Gemini API key in Settings"; tap **Open Settings**, paste the key, then return and Mine.

## Layout

```
MangaMining/
├── MangaMiningApp.swift          @main, ModelContainer, lemma-migration guard
├── Info.plist                    Camera + Photos usage descriptions
├── Models/                       SwiftData @Model entities
│   ├── CapturedPage.swift        One camera capture
│   ├── Sentence.swift            Mined sentence (text / reading / Turkish)
│   ├── Cloze.swift               Picked word position in a sentence
│   ├── WordCard.swift            Per-lemma SRS unit (Ebisu state + due time)
│   ├── ClozeQuestion.swift       Legacy per-cloze SRS row, kept for migration only
│   ├── ReviewEvent.swift         Append-only first-attempt log
│   └── LemmaMigration.swift      One-shot collapse: ClozeQuestion → WordCard
├── OCR/
│   ├── OCRProvider.swift         protocol + OCRProviderKind enum
│   ├── GeminiFlashProvider.swift Gemini 2.5 Flash, JSON-schema response, retries 429/5xx
│   └── OCRPipeline.swift         Orientation normalize → provider → Mecab reading fill
├── Tokenizer/
│   └── JapaneseTokenizer.swift   Mecab-Swift + IPADIC actor (tokenize, hiraganaReading)
├── SRS/
│   ├── Ebisu.swift               Ebisu v2 (Beta prior, moment-matched binary update)
│   ├── SchedulingService.swift   getOrCreateWordCard, recordFirstAttempt
│   └── SentenceAutoLinker.swift  Bidirectional lemma → cloze auto-linking
├── Review/
│   ├── ReviewSession.swift       @Observable @MainActor queue, lapse re-queue
│   ├── ReviewView.swift          Question/feedback UI, furigana toggle, known toggle
│   ├── AnswerOption.swift
│   └── AnswerOptionsBuilder.swift POS + |Δlen|≤1 filter, widening fallback
├── Storage/
│   └── PhotoStore.swift          JPEG to documents/captures/, optional Photos save
├── Settings/
│   ├── SettingsStore.swift       @Observable, UserDefaults-backed
│   └── KeychainStore.swift       kSecClassGenericPassword wrapper
└── Views/                        SwiftUI screens
    ├── HomeView.swift            Capture / Gallery / Saved / Clozed words / Review CTA
    ├── CameraView.swift          AVCaptureSession w/ macro auto-switch on Pro models
    ├── CapturePreviewView.swift  Mine / Retake confirmation + ZoomableImageView
    ├── ProcessingView.swift      OCR progress + failure handling
    ├── CandidatePickerView.swift Editable picked-sentence list
    ├── SavedSentencesView.swift  Reverse-chrono list
    ├── SentenceDetailView.swift  Read/edit, image preview, cloze picker, drill
    ├── ClozePickerView.swift     Token chips in FlowLayout, overlap-aware selection
    ├── ClozedWordsListView.swift WordCard list, recently-added / due-soonest sort
    ├── WordDetailView.swift      Per-lemma stats, sentence list, drill, delete
    ├── SettingsView.swift        Provider, API key, camera-roll, session size, Ebisu priors
    ├── FlowLayout.swift          Custom Layout for wrapping token chips
    └── DueDescription.swift      "X days Y hours" formatting
project.yml                       XcodeGen spec
```

## End-to-end verification

1. **Capture.** Shoot a manga page on a real device. Confirm preview + retake works; tapping Mine triggers OCR.
2. **OCR.** Confirm bubbles come back ordered correctly (vertical: top-right → bottom-left), with Turkish translations, SFX bubbles excluded.
3. **Mecab readings.** Confirm a kanji compound like 心臓 saves as しんぞう (Mecab-correct), not こころぞう (LLM-character-by-character).
4. **Cloze pick.** Open a saved sentence → Pick clozes → tap one or more tokens → Save. Confirm a `WordCard` appears under "Clozed words".
5. **Auto-link.** Mine a new sentence containing an already-clozed lemma. Confirm a `Cloze` is created automatically and the sentence appears under the WordCard's sentence list.
6. **Review.** With at least one due card, tap the Review CTA. Confirm MCQ shows the sentence with the target word ◯-blanked, four options with optional furigana ruby, correct/wrong feedback, lapse re-queue on wrong answers, Ebisu posterior updated only on first attempt.
7. **Drill.** Use "Quiz these clozes" on a freshly-clozed sentence to bypass the 24h due wait.
8. **Persistence.** Force-quit and reopen — sentences, cards, and Ebisu state survive.
