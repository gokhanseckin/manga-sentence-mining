# Manga Sentence Mining

iOS-only sentence-mining app for Japanese learners. Camera-based capture of printed manga, on-device OCR, multiple-choice cloze-deletion review with Bayesian SRS.

See [manga-mining-app-spec.md](manga-mining-app-spec.md) for the full spec.

## Status

**Phase 0 — Prototype.** Validates that camera → OCR → cleaned-sentence list works on real manga before any SRS infrastructure is built. No quizzing, no clozes, no LLM, no cloud.

Phase 0 scope:
- Camera capture of a printed manga page
- Apple Vision text-region detection + manga-ocr (ONNX) recognition
- Reading-order sort, sentence reconstruction, SFX/onomatopoeia filtering
- User picks which detected sentences to save
- SwiftData-backed reverse-chrono list, sentence edit/delete

## Requirements

- iOS 26+ (target device — camera + ONNX inference need a real iPhone)
- Xcode with iOS 26 SDK
- Homebrew tools: `xcodegen`

## Setup

```bash
git clone https://github.com/gokhanseckin/manga-sentence-mining.git
cd manga-sentence-mining

brew install xcodegen
./scripts/fetch-model.sh         # downloads ~250MB ONNX weights to MangaMining/Resources/
xcodegen generate
open MangaMining.xcodeproj
```

The Xcode project is generated from [project.yml](project.yml) and not checked in. Re-run `xcodegen generate` whenever sources or settings change.

The ONNX model weights are also not checked in (size). `scripts/fetch-model.sh` fetches them from the `mayocream/manga-ocr-onnx` Hugging Face repo.

## Layout

```
MangaMining/
├── MangaMiningApp.swift          @main, ModelContainer
├── Info.plist                    NSCameraUsageDescription
├── Models/                       SwiftData @Model: CapturedPage, Sentence
├── Storage/                      PhotoStore (JPEGs to documents dir)
├── OCR/                          Vision + manga-ocr pipeline
│   ├── OCRPipeline.swift         orchestrator
│   ├── TextRegionDetector.swift  Apple Vision bounding boxes
│   ├── MangaOCRRunner.swift      ONNX inference (stub; fill in on-device)
│   ├── ReadingOrder.swift        right→left, top→bottom sort
│   ├── SentenceReconstructor.swift  fold continuations
│   └── SFXFilter.swift           drop short katakana-only regions
├── Resources/                    bundled OCR weights (gitignored)
└── Views/                        SwiftUI screens
scripts/fetch-model.sh
project.yml                       XcodeGen spec
```

## Phase 0 verification

End-to-end checklist (spec §2 success criteria):

1. Capture a manga page with 3+ bubbles spanning a multi-bubble sentence on a physical iPhone running iOS 26+. Confirm the multi-bubble sentence reconstructs end-to-end.
2. Capture an action page with onomatopoeia (e.g. ドカン, ザワザワ). Confirm SFX is excluded from the candidate list.
3. Capture an intentionally blurry page. Confirm the "no text found" failure path.
4. Edit and delete saved sentences; confirm the deletion confirmation dialog fires.
5. Force-quit and reopen — confirm SwiftData persistence is intact.

Phase 0 success is qualitative — "the saved list contains studyable sentences, not OCR garbage."

## What's next

Phase 1 (MVP) adds Sudachi tokenization, cloze-deletion picking, multiple-choice quiz UI, and Ebisu Bayesian SRS. Schema migration is purely additive (`Cloze`, `ClozeQuestion`, `ReviewEvent` entities). See spec §2 for the phase split rationale.
