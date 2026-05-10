# Japanese Sentence Mining

iOS-only sentence-mining app for Japanese learners. Scan printed pages — manga, novels, newspapers, textbooks, children's books — and turn the words into review cards.

## What v0.3.0 brings

- **Renamed** from "Manga Mining" to **Japanese Sentence Mining** (bundle id `com.gokhanseckin.universalsentencemining`).
- **Multi-format scanning.** Single-pass OCR auto-classifies each page as `manga` or `print` and adapts extraction (panel reading order vs paragraph flow, casual vs formal register).
- **Localized interface.** Picks up `Locale.preferredLanguages` at first run; user can change anytime in Settings. English is bundled; other languages are translated on demand by Gemini at onboarding (blocking) or in Settings, then cached on device. Per-key SHA-256 hashes invalidate stale translations on app updates.
- **Translation target = interface language.** One picker drives both. Existing cards keep the language they were created with (the picker only affects new captures).
- **Onboarding overhaul.** Three steps: pick language → welcome → enter Gemini API key with inline privacy note ("Pages you scan are sent to Google Gemini for OCR and translation. Images are not retained by Google per their API terms.").
- **iCloud sync via private CloudKit.** WordCards and SRS state sync across the user's devices. Source-sentence context is denormalized onto each card so the review screen works on a second device. Page image *bytes* stay device-local — only their paths sync, so pages captured on device A don't render their photo on device B (text and translation do). Toggle off/on in Settings.
- **Furigana button** on every screen that renders Japanese text. Per-screen, off by default; tokens are sourced from the existing Mecab-Swift + IPADIC tokenizer.

## Status

| Phase | Status |
|---|---|
| Phase 0 — Prototype | Shipped. Gemini 2.5 Flash whole-page OCR; camera + gallery import; capture preview + retake; sentence list with edit/delete; Keychain-stored API key. |
| Phase 1 — MVP | Shipped. Mecab-Swift + IPADIC tokenizer (actor-isolated); cloze picking; Ebisu v2 Bayesian SRS scheduled per lemma (`WordCard`); MCQ quiz with furigana toggle; POS + length-similar distractors; due-count Home CTA; SRS settings. |
| Phase 1 polish | Shipped. Drill button on sentence detail; inline + fullscreen source image with pinch-zoom; OCR retry; capture preview before mining; Mecab-authoritative readings. |
| **v0.3.0** | **In progress on `main`.** Rename, dual-prompt OCR with auto-detect, localization infra (interface + translation target tied), iCloud sync, per-screen furigana. |

## Requirements

- iOS 26+ (real device — camera-driven; simulator only works for gallery import)
- Xcode with iOS 26 SDK, Swift 6 strict concurrency
- `xcodegen` (Homebrew)
- A Gemini API key (entered during onboarding; stored in Keychain)
- Optional: an iCloud account for cross-device sync

## Setup

```bash
git clone https://github.com/gokhanseckin/manga-sentence-mining.git
cd manga-sentence-mining

brew install xcodegen
xcodegen generate
open JapaneseSentenceMining.xcodeproj
```

The Xcode project is generated from [project.yml](project.yml) and is gitignored. Re-run `xcodegen generate` whenever sources or settings change.

For iCloud sync, the CloudKit container `iCloud.com.gokhanseckin.universalsentencemining` must be created in your Apple Developer account and the team identifier filled into `project.yml` before signing.

## Layout

```
JapaneseSentenceMining/
├── JapaneseSentenceMiningApp.swift  @main, RootView routes to onboarding or HomeView
├── Info.plist                       Camera + Photos usage descriptions
├── JapaneseSentenceMining.entitlements  CloudKit container
├── Models/                          SwiftData @Model entities (CloudKit-friendly: defaults on every field, no .unique constraints)
│   ├── CapturedPage.swift           One scan; documentType (manga|print) populated from OCR
│   ├── Sentence.swift               Extracted sentence; translation + translationLanguage; modifiedAt
│   ├── Cloze.swift                  Picked word position in a sentence
│   ├── WordCard.swift               Per-lemma SRS unit; language tag; sourceSnapshots blob (denormalized for sync)
│   ├── ReviewEvent.swift            Append-only first-attempt log
│   ├── DocumentType.swift           manga | print | unknown
│   └── SourceSnapshot.swift         Codable struct embedded in WordCard for review-context
├── OCR/
│   ├── OCRProvider.swift            protocol → OCRResult { documentType, sentences }
│   ├── GeminiFlashProvider.swift    Single-pass dual-prompt; targetLanguage parameter; auto-classifies documentType
│   └── OCRPipeline.swift            Orientation normalize → provider → Mecab reading fill
├── Tokenizer/
│   └── JapaneseTokenizer.swift      Mecab-Swift + IPADIC actor
├── Localization/
│   ├── BaseStrings.swift            English source dict + translator-comments per key
│   ├── LocalizationStore.swift      @Observable runtime resolver; per-key SHA-256 invalidation
│   ├── InterfaceTranslator.swift    Gemini-based one-shot translator for unbundled languages
│   └── SupportedLanguage.swift      Bundled set: en, fr, es, it, tr, ko, zh-Hans
├── SRS/
│   ├── Ebisu.swift                  Ebisu v2
│   ├── SchedulingService.swift      Sets WordCard.language from settings.interfaceLanguage at creation
│   └── SentenceAutoLinker.swift     Bidirectional lemma → cloze auto-linking
├── Review/                          (unchanged)
├── Storage/
│   ├── PhotoStore.swift             JPEG to documents/captures/, optional Photos save
│   └── AppModelContainer.swift      Single ModelContainer; CloudKit private DB if user opted in
├── Settings/
│   ├── SettingsStore.swift          interfaceLanguage, hasCompletedOnboarding, iCloudSyncEnabled
│   └── KeychainStore.swift
└── Views/
    ├── HomeView.swift               Capture / Gallery / Saved / Clozed words / Review CTA
    ├── OnboardingFlowView.swift     3-step: language → welcome → API key
    ├── JapaneseText.swift           JP text view + FuriganaToggleButton
    ├── CameraView.swift, CapturePreviewView.swift, ProcessingView.swift, …  (unchanged)
project.yml                          XcodeGen spec
docs/plans/v0.3.0-plan.md            Locked decisions + architecture for this release
```

## Known limitations

- **Bundled non-English UI translations**: the localization infrastructure is in place and English is the source. The 6 other "bundled" languages (fr/es/it/tr/ko/zh-Hans) are populated at runtime on first use via the `InterfaceTranslator` (i.e. they hit Gemini once per device, then cache). A build-time pre-translation script will land later.
- **Page image sync**: photos remain device-local. WordCard review context (text + reading + translation) is denormalized onto the card so reviews work on a second device, but the original photo doesn't transfer.
- **Locale change applies to new captures only**: existing WordCards/Sentences keep their original `language` tag. Switching interface language doesn't retranslate old material.
- **App icon**: placeholder. Custom icon ships in a follow-up.

## End-to-end verification

1. **Onboarding.** Fresh install → language picker pre-selects from device locale → welcome → API key with privacy note. Picking an unbundled language triggers a blocking Gemini translation step after API key entry. Failure falls back to English.
2. **Capture.** Shoot a manga page; `documentType` saved as `manga`. Shoot a newspaper; `documentType` saved as `print`. UI ordering reflects each.
3. **Mecab readings.** Compound `心臓` saves as しんぞう (dictionary-grounded), not character-by-character.
4. **Furigana button.** Toolbar toggle on review/sentence/word screens reveals kana above kanji per-token.
5. **iCloud sync.** Two devices on the same iCloud, fresh installs: clozing a word on A shows the WordCard on B within ~30s with source-sentence context preserved (text/translation, no image).
6. **Locale change.** Settings → Language → switch to a non-bundled code → block on translation → app text swaps. Existing cards retain their original-language translations.

See [docs/plans/v0.3.0-plan.md](docs/plans/v0.3.0-plan.md) for the locked design decisions backing this release.
