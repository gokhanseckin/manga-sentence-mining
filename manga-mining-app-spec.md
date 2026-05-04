# Manga Sentence Mining App — Specification

> iOS-only, solo, vibe-coded with Claude Code.
> Camera-based mining of sentences from printed manga, with Bayesian SRS and multiple-choice cloze-deletion questions.

---

## 0. Project Status (at-a-glance, current as of 2026-05-04)

This section is the first thing a fresh Claude Code session should read. It exists so context loss between sessions doesn't lose track of what's shipped vs. what's next.

| Phase | Status | Notes |
|---|---|---|
| Phase 0 — Prototype | **Shipped, in daily use** | Gemini 2.5 Flash whole-page OCR; camera + gallery import; sentence list; Keychain-stored API key |
| Phase 1 — MVP | **Shipped 2026-05-04** | Mecab-Swift + IPADIC tokenizer; cloze picking; Ebisu v2 SRS; MCQ quiz with furigana toggle; POS + length-similar distractors; due-count Home CTA; SRS settings |
| Phase 1 polish | **Shipped 2026-05-04** | Six post-MVP UX/quality fixes — see §2 "Phase 1 polish (shipped)" |
| Phase 2+ | **Not committed** | Menu of candidates in §2; nothing scheduled until real-use feedback drives a commitment |

**Tokenizer substitution:** The original Phase 1 plan called for Sudachi. No maintained Sudachi-on-Swift implementation exists, so `shinjukunian/Mecab-Swift` + bundled IPADIC was used instead (actor-isolated for Swift 6 strict concurrency). Functionally equivalent for this app's needs (surface, lemma, hiragana reading, POS).

**Spec gaps still open:**
- §6 Tokenization & Word Selection — implementation shipped; spec section now backfilled below.
- §9 Out of Scope — referenced by §1, §2, §8 but never written. Still open.

**Where the code lives:** `MangaMining/` (Models, OCR, Tokenizer, SRS, Review, Settings, Storage, Views). Generate Xcode project with `xcodegen generate`; iOS 26+, Swift 6, strict concurrency.

---

## 1. Overview & Goals

### What this is

A native iOS app for mining sentences from printed manga and learning Japanese vocabulary from them via Bayesian-scheduled multiple-choice cloze-deletion questions.

The user points the camera at a manga page (or imports one from the gallery), the app sends the page to a cloud VLM (Gemini 2.5 Flash) which returns each speech bubble as `{original Japanese, full hiragana reading, Turkish translation}`, the user picks which sentences to keep, and (from Phase 1) which words within those sentences to quiz. Every chosen word produces one quiz item: a sentence with that word blanked and four kanji answer options below it. A **furigana toggle button** is available on every question — tapping it reveals furigana on every kanji-bearing word currently visible (sentence context and answer options); tapping again hides them. It is the user's escape hatch when they know the word phonetically but cannot read its kanji.

### What this is not

- **Not a manga reader.** The camera is the input mechanism for sentence mining only. The app does not display, organize, or store manga as readable content.
- **Not a dictionary app.** Word-level translation lookups are out of scope for the MVP; sentence-level translation via the OCR VLM is the only translation pathway.
- **Not a generic OCR app.** The prompt is tuned for manga: speech bubbles, vertical Japanese reading order, onomatopoeia exclusion, manga-tone Turkish output.
- **Not a flashcard app.** The app uses SRS scheduling but has no flashcards. Every quiz item is a single multiple-choice cloze-deletion question — a sentence with one word blanked, four answer options below, and a tap-to-select interaction. There is no flip, no two-sided study surface, no self-rating ("again / hard / good / easy"), and no recall-then-reveal step. The schema entity is named `ClozeQuestion` rather than the SRS-conventional `Card` specifically to keep this distinction visible in code and to discourage drift back toward the flashcard mental model in future Claude Code sessions.

### Why it exists

Existing sentence-mining workflows for Japanese learners are desktop-bound (mokuro, ocr-reader, Yomitan), or assume digital sources. There is no good mobile workflow for someone reading a *physical* manga volume who wants to capture an interesting sentence in seconds and study it later.

Existing flashcard apps (Anki, Renshuu, Bunpo) use multi-grade self-rating SRS algorithms (SM-2, FSRS) that do not map cleanly to multiple-choice quiz outcomes. Multiple-choice produces clean binary signals (correct / incorrect) — exactly what Ebisu's Bayesian model is designed for.

This app combines mobile camera-based mining with multiple-choice + Ebisu in a single workflow. The furigana toggle gives a low-friction way to study real kanji-bearing sentences without bouncing to a dictionary every time a kanji is unfamiliar.

### Primary user

The developer (solo project). Native Turkish speaker, learning Japanese. The MVP target is "I actually use this to learn Japanese" rather than any external user count.

### Success criteria

The app succeeds when:

1. Capturing and saving a sentence from a real manga page takes under 30 seconds and produces clean, studyable text (Phase 0 success).
2. Daily review sessions feel habit-forming rather than chore-like, and the developer's Japanese reading comprehension on subsequent manga pages measurably improves over months of use (Phase 1+ success).

These are subjective, evaluated by the developer. There is no analytics dashboard, no retention metric, no A/B test.

### Build context

- **Platform:** iOS only, iOS 26+, native Swift / SwiftUI / SwiftData.
- **Development model:** solo, vibe-coded with Claude Code. This document exists primarily to give Claude Code the context to make consistent architectural choices across sessions.
- **Backend:** none. No VPS, no server, no auth. The OCR VLM call goes directly from the device using a user-supplied Gemini API key stored in Keychain. Provider is swappable via an `OCRProvider` protocol — Gemini Flash is the only implementation today; Qwen2.5-VL via Novita and DeepSeek are candidate additions.
- **Sync:** none in MVP. iCloud sync is a Phase 2 candidate, not a committed anchor — it ships if and when the developer actually wants multi-device support.

### Reading guide for the rest of this document

- Section 2 (Release Phases) is the spine. Every other section's scope is partitioned by phase.
- Sections 7 (Cloze Question Model & SRS) and 8 (Data Model) are the most decision-dense. Most other sections cross-reference them.
- Section 5 (OCR Pipeline) documents the shipped Gemini Flash architecture and the `OCRProvider` seam for future providers.
- Section 9 (Out of Scope) is load-bearing. It exists to prevent scope creep during vibe-coded sessions; consult it when in doubt about whether a feature belongs in the current phase.

---

## 2. Release Phases

The app ships in two phases plus a candidate-driven post-MVP. Each phase is shipped and used before the next is started. The split exists to derisk the hardest unknown — whether camera-based mining of real manga produces sentences worth studying — before any SRS infrastructure is built.

### Phase 0 — Prototype (shipped)

**Goal:** validate that camera → cleaned, translated sentences works on real manga, before investing in SRS.

**Status:** complete and in daily use by the developer. Quality on real pages is ~95%; remaining errors are paraphrasing nudges from the VLM rather than OCR misreads.

**In scope (shipped):**

- Camera capture of a printed manga page using `.builtInTripleCamera` / `.builtInDualWideCamera` so iOS auto-switches to ultra-wide for macro distances (matches the system Camera app on Pro models)
- "Open from gallery" import via `PhotosPicker` for shots taken with the system Camera app
- Optional "Save photos to camera roll" toggle in Settings (off by default; add-only Photos auth requested on first save)
- Whole-page OCR via Gemini 2.5 Flash as a cloud VLM. One HTTPS call per page returns a JSON array of `{text, reading, translationTr, bbox}` per speech bubble
- Settings screen with provider picker (single option today: Gemini Flash) and Keychain-backed API key entry
- Sentence-level translation **happens in the same OCR call** — original Japanese, full hiragana reading, and Turkish translation are produced together. No separate LLM translation pass.
- User picks which detected sentences to save (sentence-level only — no word selection); each row shows original / hiragana / Turkish, all editable
- Flat list of saved sentences with original + Turkish translation; detail view shows all three lines
- Local storage only

**Anti-goals (explicitly NOT in Phase 0):**

- No word-level selection or cloze marking
- No quiz, no SRS, no Ebisu
- No distractors
- No iCloud sync
- No JMdict, no KANJIDIC, no Sudachi tokenization
- No "mark as known" or any review actions
- No on-device OCR fallback (manga-ocr ONNX runtime was removed when the VLM proved better)

**Success criteria (met):**

- Sentences in vertical-text bubbles are read in correct top-right → bottom-left order
- Onomatopoeia / sound effects are reliably skipped (the prompt instructs the VLM to drop pure SFX bubbles like ドン, ガーン, ボッ)
- Hiragana reading and Turkish translation are usable as study material out of the box

### Phase 1 — MVP

**Status:** complete and in daily use by the developer as of 2026-05-04.

**Goal:** add the SRS-driven learning loop on top of Phase 0's mining.

**Adds on top of Phase 0 (shipped):**

- ~~Sudachi~~ Mecab-Swift + IPADIC on-device tokenization of saved sentences (actor-isolated; see §0 for substitution rationale)
- User picks the cloze word per sentence
- One cloze question per cloze (kanji answer options)
- Ebisu Bayesian SRS, one posterior per cloze question (closed-form GB1 binary update)
- Multiple-choice quiz interface
- Distractors drawn from the user's own mined-word pool, filtered by part-of-speech and similar surface-form length, with widening fallback when the pool is small
- "Mark as known" toggle to exclude a cloze question from review
- Furigana toggle button on every question

Translation already exists from Phase 0; no new translation work in Phase 1. Still local storage only.

### Phase 1 polish (shipped 2026-05-04)

These features were added on top of Phase 1 in response to real-use feedback during the MVP's first day. They are not in the original Phase 1 plan but are now part of the shipped app. They are documented here so future Claude Code sessions don't try to add them again or roll them back.

| PR | Feature | Why |
|---|---|---|
| #10 | "Quiz these clozes" drill button on sentence detail | Default Ebisu prior schedules new clozes 24h out; first-time users had no way to test the loop until tomorrow. Drill bypasses the due filter for one sentence's questions; first-attempt logging still applies. |
| #11 | Captured source image inline in sentence detail + fullscreen viewer | `CapturedPage` already stored the photo; no UI exposed it. Users wanted to see the source page when reviewing a sentence. Hidden gracefully when the file is missing. |
| #12 | Retry button on OCR failure view | Gemini 503s would force the user back to home and require re-shooting. Retry re-runs the pipeline against the same on-disk image. Failure body is now scrollable so long error JSON doesn't push buttons off-screen. |
| #13 | Capture preview screen with "Mine sentences" / "Retake" | Standard mobile photo-validation flow. Shutter no longer triggers OCR directly — user confirms first. Camera-roll save also moves to the Mine-sentences moment so retakes don't pollute the user's Photos library. |
| #14 | Pinch-zoom + fit-to-screen for image previews | The SwiftUI `ScrollView + scaledToFit` combo rendered images at intrinsic size. Both capture preview and sentence-detail fullscreen viewer now use a `UIScrollView`-based `ZoomableImageView` (aspect-fit + pinch + double-tap toggle). |
| #15 | Mecab override of LLM sentence reading on save | Gemini occasionally produces wrong readings on kanji compounds (e.g. 心臓 → こころぞう instead of しんぞう). Mecab + IPADIC is dictionary-grounded and gets these right; it now becomes the authoritative reading source on save, falling back to the LLM-supplied reading only if the user manually edited it before Save. |

These polish items do not modify any spec invariant — the entity model, SRS math, lapse-requeue semantics, and immutability rules from §3, §7, §8 are untouched.

### Phase 2+ — Candidates (no committed scope)

The MVP ends with Phase 1. What ships next depends on what the developer actually wants after using the MVP. None of the following are committed:

- iCloud sync via private CloudKit
- JMdict / KANJIDIC bundled, used for higher-quality distractors (similar stroke count, similar reading length)
- JMdict Turkish gloss layer (LLM-pre-translated at build time, bundled)
- Additional `OCRProvider` implementations: Qwen2.5-VL via Novita, DeepSeek vision (the protocol seam already exists in `MangaMining/OCR/OCRProvider.swift`)
- Apple Vision OCR as a selectable on-device alternative engine (for offline use)
- OCR re-processing flow (re-run a different provider on a saved page)
- Per-word furigana ruby annotations layered on the original `text` (Phase 0 ships sentence-level hiragana only)
- Panel grouping in storage (bbox y-position can derive panels later if useful)
- Audio / TTS
- Anki export
- Time-weighted scoring (fast/slow/wrong buckets feeding Ebisu's noisy-binary update)

When a Phase 2 feature is committed, this section is updated with its scope.

### Phase 0 schema scope

Phase 0's schema contains only `CapturedPage` and `Sentence` (the latter with optional `reading` and `translationTr` fields populated from the VLM response). The Phase 1 entities (`Cloze`, `ClozeQuestion`, `ReviewEvent`) are added via SwiftData's lightweight migration when Phase 1 begins. Adding new entities is a trivial migration that does not touch existing rows, so this is not a "data migration" risk in any meaningful sense.

### UI polish baseline

"Clean but minimal" applies as the baseline for all phases: SwiftUI defaults, system fonts, intentional spacing and colors, no animations, no custom branding. Polish is not scoped until explicitly raised.

### Phase boundaries are hard

Any feature touching SRS state, word-level data, distractors, or review actions belongs to Phase 1 or later. If a feature feels SRS-adjacent during Phase 0 (e.g. "mark this sentence as already known"), it is deferred to MVP rather than added inline.

---

## 3. User Flows

This section describes the user-visible behavior of every flow in the app — what the user does and what state changes result. Screen layouts and component-level UI are deferred to Section 4.

Flows are grouped by phase introduction. A flow listed under Phase 0 also applies in Phase 1+ unless explicitly extended.

### Mining (Phase 0+)

#### Capture and save sentences

The core Phase 0 loop. The user shoots one printed manga page at a time, or imports one from the gallery. There is no batch-shooting mode and no queue of unprocessed pages — each page is processed and resolved before the next is taken.

1. From the home screen, the user either taps **Capture** to open the in-app camera, or **Open from gallery** to pick a photo via `PhotosPicker`.
2. For capture: the user frames a manga page and triggers the shutter. The camera uses `.builtInTripleCamera` / `.builtInDualWideCamera` so iOS auto-switches to the ultra-wide constituent at macro distances. The shot opens fullscreen in `CapturePreviewView` with **Mine sentences** (primary) and **Retake** (secondary) buttons (Phase 1 polish, PR #13). On Mine sentences the photo is written to the documents directory and a `CapturedPage` row is created; if the "Save photos to camera roll" setting is on, the photo is also written to the Photos library at this moment (so retaken shots never end up in the user's library). On Retake the camera reopens with no side effects.
3. For gallery import: the picked image is written to the documents directory the same way (never re-saved back to the gallery, regardless of the camera-roll toggle). A `CapturedPage` row is created.
4. The OCR pipeline (Section 5) runs on the image. The user sees a progress indicator while it runs.
5. The pipeline emits a list of bubble candidates, each with original Japanese text, full hiragana reading, and Turkish translation. SFX bubbles are already filtered out by the prompt.
6. The user is presented with the candidate list. Each row shows the three lines (original / hiragana / Turkish), all editable, with a per-row toggle. Unpicked candidates are discarded.
7. On confirm, one `Sentence` row is created per picked candidate, persisting all three fields. The user returns to the home screen.

The user may now process the next page, browse saved sentences, or close the app. In Phase 0, this is the entire user loop.

#### Capture failure recovery

The user-facing handling of OCR failures (no text regions detected, nonsense OCR per region, photo too blurry, etc.) is owned by Section 5.6 and resolved during Phase 0 prototyping rather than committed here.

What this section commits to is independent of how failures are surfaced: the photo is retained on the `CapturedPage` regardless of whether any sentences were saved, and re-shooting creates a new `CapturedPage` rather than replacing the previous one.

#### Browse saved sentences

Reachable from the home screen via a "Saved sentences" entry. Shows all `Sentence` rows in reverse chronological order by `created_at`, with original Japanese as the primary line and Turkish translation as the secondary line in each row. There is no folder, tag, manga, or volume grouping in the MVP — Section 8 deliberately omits a `Manga` entity.

Tapping a sentence opens a detail view showing all three lines (original / hiragana / Turkish), source page reference, timestamp, and (Phase 1+) any clozes and their cloze questions.

#### Edit sentence text, reading, and translation

From the sentence detail view, the user can edit `Sentence.text`, `Sentence.reading`, and `Sentence.translationTr` **only when no `Cloze` rows reference the sentence.** Once any cloze has been picked, the edit action is hidden and all three fields become immutable.

This rule eliminates the split-state problem of "existing cloze questions display old text vs. new text" without snapshotting sentence text on `Cloze`. If the user wants to change the text after clozing, the recourse is to delete the cloze questions, edit, then re-pick clozes.

#### Delete sentence

From the sentence detail view, the user can delete a sentence. Deletion is hard-delete and **cascades to all dependent `Cloze`, `ClozeQuestion`, and `ReviewEvent` rows.** A confirmation dialog warns the user when dependent rows exist.

The semantic is: deleting a sentence means "I'm done studying this entirely." If the user wants to keep studying clozes from a sentence, they don't delete it. Soft-delete machinery is not used.

### Cloze picking (Phase 1+)

> Translation already happens in Phase 0 as part of the OCR call. There is no separate translation flow in Phase 1.

#### Pick clozes from a saved sentence

Cloze picking is a separate task initiated from the sentence detail view, never as part of capture.

1. From sentence detail, the user opens the cloze-picking action.
2. The sentence is tokenized via Sudachi (Section 6). Each token is rendered as a tap target with its surface form.
3. The user taps one or more tokens to mark them as cloze positions. There is no upper bound on clozes per sentence.
4. On confirm, one `Cloze` row is created per marked position, and one `ClozeQuestion` row is created per `Cloze` (per Section 7).

#### Add more clozes later

The user can return to the cloze-picking action on a sentence that already has clozes. Existing cloze positions are visible (and not re-tappable), and additional tokens can be marked. This produces new `Cloze` and `ClozeQuestion` rows alongside the existing ones; existing cloze questions are unaffected and retain their SRS state.

There is no flow to "remove" a cloze in the MVP. To stop reviewing a cloze question, the user marks it known (Section 7) or deletes the cloze question (below).

### Review (Phase 1+)

#### Starting a session

The home screen (Phase 1+) shows a single "Review (N due)" button. N is the count of cloze questions meeting the due query in Section 8. Tapping it starts a session of up to `session_size` unique cloze questions (default 15, max 50).

#### Cloze question interaction

The mechanics of one quiz item — its question state, feedback state, and posterior update — are governed by Section 7. User-facing behaviors layered on top:

- **Answer reveal.** The user taps one of four answer options. Tapping commits the answer and reveals the result in a single action: the screen transitions from the question state to the feedback state, showing correctness and the unblanked sentence. There is no separate reveal step.
- **Furigana toggle.** A button visible on every question (in both question and feedback states) toggles furigana visibility. Tap shows furigana on every kanji-bearing word currently on screen — both in the surrounding sentence and on the four answer options. Tap again hides them. The toggle state is per-question and resets when advancing to the next question; it is not persisted.
- **Known toggle.** A switch on the question view marks the cloze question as known or returns it to active SRS. Toggling to known excludes the question from future review pools. Toggling back to unknown restores it to active SRS using its existing Ebisu state. The same toggle is reachable from the question list inside sentence detail with identical behavior.
- **Advancing.** The feedback state has a "next" action that advances to the next question in the session.

#### Delete cloze question

From the sentence detail's question list, the user can delete an individual cloze question. Tapping delete shows a confirmation dialog. On confirm:

- The `ClozeQuestion` row is hard-deleted.
- All `ReviewEvent` rows referencing this cloze question are cascade-deleted.
- The source `Sentence` and `Cloze` are unaffected. The `Cloze` remains and the user can re-create a question for it later from the cloze-picking flow.

Cloze question deletion is the only way to permanently remove a cloze question from active scheduling without leaving behind dormant SRS state. Marking the cloze question known is the non-destructive alternative.

#### Lapse re-queue

Per Section 7, a cloze question is re-asked within the same session only if the user got it wrong on a previous attempt in that session. The user experiences this as: a correct answer advances them to the next question; a wrong answer sends the current cloze question to the back of the session queue.

The session counter shown to the user counts unique cloze questions remaining and decrements only on correct answers. A wrong answer does not change the counter.

There is no round-break screen and no opt-out from the re-queue.

#### Mid-session abandon

If the user closes or kills the app before the session completes, no resumable-session state is preserved. Cloze questions already answered have their Ebisu posteriors updated immediately at answer time. Cloze questions not yet asked simply remain in the due pool — on the next session they are evaluated alongside all other due cloze questions.

A session abandoned partway through ends without consequence beyond what has already been logged: any cloze questions lapsed in that session and queued for re-ask are simply lost. The first-attempt result has already been logged and applied to Ebisu at the time it happened.

#### All-caught-up state

When the due query returns zero cloze questions, the home screen replaces the "Review (N due)" button with an "All caught up — mine more sentences" CTA that opens the camera.

### App-level

#### First launch (Phase 0)

The app opens to a home screen with **Capture**, **Open from gallery**, and **Saved sentences** entries plus a settings gear. No onboarding, no walkthrough. A Gemini API key is required for OCR — the user is expected to discover this on their first capture: the OCR call returns an "API key missing" failure view with an "Open Settings" button that takes them to the key entry field.

This lazy "discover via the failure view" pattern is intentional. It avoids a forced onboarding screen for users who just want to look around, and treats the Settings → API key flow as the canonical onboarding path.

#### First launch (Phase 1)

No additional API-key setup beyond Phase 0 — the same Gemini key already covers everything.

#### Settings

Reachable from the home screen via the gear icon. Phase 0 settings:

- **OCR provider** — picker (single option today: Gemini 2.5 Flash; the protocol allows future providers without UI changes)
- **API key** — `SecureField` for the active provider's key, stored in iOS Keychain (`kSecClassGenericPassword`, account `gemini_api_key`, accessible after first unlock). Includes a "Remove saved key" action.
- **Save photos to camera roll** — toggle, off by default. When on, captured pages are also written to the Photos library (add-only auth, requested on first save). Gallery imports are never re-saved.

Phase 1 will add: session size, Ebisu prior values. The settings screen is utilitarian: a flat `Form` with current values and inline editors.

### Phase scope summary

| Flow | Phase 0 | Phase 1 |
|---|---|---|
| Capture and save sentences | yes | yes |
| Capture failure recovery | yes | yes |
| Browse saved sentences | yes | yes |
| Edit sentence text (only when un-clozed) | yes | yes |
| Delete sentence (cascading) | yes | yes |
| Pick clozes / add more clozes | — | yes |
| Translation (now part of OCR) | yes | yes |
| Start review session | — | yes |
| Cloze question interaction (answer, furigana toggle, known toggle) | — | yes |
| Delete cloze question | — | yes |
| Lapse re-queue | — | yes |
| Mid-session abandon | — | yes |
| All-caught-up state | — | yes |
| First-launch onboarding | discover-via-failure-view for API key | same as Phase 0 |
| Settings | provider, API key, camera-roll toggle | + session size + Ebisu priors |

### Cross-references

- **Cloze question mechanics** (question state, feedback state, known toggle, lapse re-queue logic) are detailed in Section 7.
- **Schema** for sentences, clozes, cloze questions, and review events is in Section 8.
- **OCR pipeline failure modes** are detailed in Section 5.6.
- **Tokenization** behavior is detailed in Section 6 (TBD).

---

## 4. Screens & UI

Use this for phase 0. fFetch this design file, read its readme, and implement the relevant aspects of the design. https://api.anthropic.com/v1/design/h/GdbDE_Mr0sww5beMoeHmHQ?open_file=Manga+Mining.html
This is html but you'll build a native app and implement similar design . You can be flexible about design and 80-90% compliance to these designs are enough. 

---

## 5. OCR Pipeline

> **Status:** resolved. Phase 0 ships with a single-call cloud VLM pipeline. The earlier on-device manga-ocr (ONNX Runtime) approach was prototyped, found insufficient on real pages, and removed.

### Architecture

```
UIImage
  └─ OCRPipeline.process(image:)
       └─ image.normalizedOrientation()
       └─ provider.recognize(image:)         // OCRProvider protocol
            └─ GeminiFlashProvider           // only impl today
                 ├─ downscale to longEdge ≤ 1568 px, JPEG q=0.85
                 ├─ POST gemini-2.5-flash:generateContent
                 │     responseMimeType: application/json
                 │     temperature: 0
                 │     responseSchema: array of {text, reading, translationTr, bbox}
                 └─ decode → [SentenceCandidate]
```

`SentenceCandidate` carries `text` (original Japanese), `reading` (full hiragana of the same sentence), `translationTr` (Turkish), and `sourceRegions: [CGRect]` denormalized into image-pixel space.

### Provider seam

`OCRProvider` is a one-method protocol:

```swift
protocol OCRProvider: Sendable {
    func recognize(image: UIImage) async throws -> [SentenceCandidate]
}
```

`OCRProviderKind` is the user-facing enum (`.geminiFlash` today). `SettingsStore.makeProvider()` builds the active concrete provider by reading the API key from Keychain. Adding Qwen2.5-VL (Novita) or DeepSeek means writing a new struct conforming to `OCRProvider` and adding a case to `OCRProviderKind` — no caller changes.

### Prompt design (the load-bearing part)

The Gemini prompt instructs the model to:

- Transcribe `text` **exactly as printed**, character-for-character — no rephrasing, no particle normalization, no grammar fixes
- Produce `reading` as the same sentence rewritten entirely in hiragana, preserving punctuation and word order
- Produce `translationTr` as natural conversational Turkish, preserving manga tone (interjections, particle nuance)
- Provide `bbox` as `[x, y, w, h]` normalized 0–1
- Order entries top-right → bottom-left for vertical Japanese, top-left → bottom-right for horizontal
- Skip pure SFX bubbles (ドン, ガーン, ボッ, バン, ぐいっ, etc.)

Combined with `temperature: 0` and Gemini's native JSON-mode `responseSchema`, this produces verbatim output ~95% of the time on real manga pages. Remaining errors are paraphrasing nudges, not OCR misreads.

### Reading override on save (Phase 1 polish)

The LLM-supplied `reading` is **not the source of truth** in storage. On save (in `CandidatePickerView.commit`), `JapaneseTokenizer.hiraganaReading(of:)` regenerates the sentence reading from Mecab + IPADIC and overwrites the LLM value before the `Sentence` row is inserted.

This was added because Gemini occasionally produces character-by-character kun-yomi readings on kanji compounds that take on-yomi (e.g. 心臓 → こころぞう instead of しんぞう). Mecab is dictionary-grounded and gets these right.

The override is skipped if the user manually edited the reading line in the picker UI before tapping Save — their edit is treated as authoritative.

### Failure modes

| Condition | UX |
|---|---|
| API key missing or empty | Failure view with key icon, "Add your Gemini API key in Settings" message, "Open Settings" button + "Back" button |
| HTTP non-2xx from Gemini | Failure view with the HTTP status code and a body snippet |
| Malformed JSON / empty candidates | Failure view with the malformed-JSON error |
| Empty bubble list (blank page) | Failure view "No text found. Try re-shooting." |
| Couldn't load the captured photo | Failure view "Couldn't load captured photo from disk." |

In every case the `CapturedPage` row and its photo file are retained — the failure view's "Back" returns the user to the home screen without deleting anything. All non-API-key failures additionally surface a **Retry** button (Phase 1 polish, PR #12) that re-runs the pipeline against the same on-disk image without requiring re-shoot.

### Cost / latency observability

`GeminiFlashProvider` logs `usageMetadata.{prompt,candidates,total}TokenCount` to the console after each successful call. This is the per-page cost signal the developer uses to eyeball $/page during real use. There is no in-app cost UI.

### Cross-references

- The `CapturedPage` schema (Section 8) retains the photo regardless of OCR outcome.
- The Settings screen (Section 3) holds the API key and the provider picker.
- The `Sentence` schema (Section 8) stores all three VLM-produced fields directly.

---

## 6. Tokenization & Word Selection

> **Status:** shipped in Phase 1.

### Engine choice

`shinjukunian/Mecab-Swift` (SwiftPM, master branch) wrapping the MeCab C++ engine, with the bundled `IPADic` library product as the dictionary. This was substituted for the originally-planned Sudachi because no maintained Sudachi-on-Swift implementation exists as of 2026; Lindera has no Swift bindings; Apple's `NLTagger` provides Japanese tokenization but no readings or lemmas.

IPADIC is older than Unidic but adequate for manga vocabulary, and it ships *inside* the Mecab-Swift package — no manual resource bundling, no separate ~50 MB asset to ship.

### Concurrency model

`MangaMining/Tokenizer/JapaneseTokenizer.swift` is a Swift `actor` because MeCab itself is thread-unsafe. The tagger is initialized lazily on first call. The actor is exposed via `JapaneseTokenizer.shared` because actors cannot conform to `Observable` for SwiftUI's `.environment(_:)` API.

```swift
struct JapaneseToken: Sendable, Equatable {
    var surface: String       // word as it appears in text
    var lemma: String         // dictionary form; falls back to surface if empty
    var reading: String       // hiragana (transliterated from IPADIC's katakana)
    var partOfSpeech: String  // "noun" / "verb" / "particle" / etc.
    var range: Range<String.Index>  // position in the source string
}

actor JapaneseTokenizer {
    static let shared: JapaneseTokenizer
    func tokenize(_ text: String) throws -> [JapaneseToken]
    func hiraganaReading(of text: String) throws -> String
}
```

`hiraganaReading(of:)` joins per-token readings to produce a sentence-level hiragana string, falling back to the surface form for punctuation / unknown tokens. This is used by `CandidatePickerView` to override the LLM-supplied sentence reading on save (see §5 "Reading override on save").

### Cloze picking flow

Per spec §3 "Pick clozes from a saved sentence":

1. From sentence detail, the user opens `ClozePickerView`.
2. The view tokenizes `sentence.text` once via `JapaneseTokenizer.shared`.
3. Each token is rendered as a tap-target chip in a wrapping `FlowLayout` (`MangaMining/Views/FlowLayout.swift`).
4. Tokens whose character range overlaps an existing `Cloze` are dimmed and disabled; remaining tokens toggle on/off when tapped.
5. On confirm, one `Cloze` row is created per selected token. `start_offset`/`end_offset` are character distances from `text.startIndex` to the token's `range.lowerBound`/`upperBound`. `lemma`, `reading`, `part_of_speech`, `surface_form` come straight from the token.
6. Each new `Cloze` is immediately routed through `SchedulingService.createInitialQuestion(for:in:settings:)` to materialize its `ClozeQuestion`.

### Distractor selection

Per `MangaMining/Review/AnswerOptionsBuilder.swift`, applied at quiz-time (not at cloze-pick time):

1. **Candidate pool** = all `Cloze` rows across the whole library where `lemma != target.lemma`, deduped by `surfaceForm` (so the same word doesn't appear twice in one question).
2. **Filter by POS:** `partOfSpeech == target.partOfSpeech`.
3. **Filter by length:** `abs(surface.count - target.surface.count) <= 1`.
4. **Pick 3** at random from what survives.
5. **Widening fallback** if fewer than 3 survive: relax the length filter, then the POS filter, then fall back to any other cloze.
6. **Combine with the correct answer; shuffle.**

JMdict is explicitly NOT used — distractors come exclusively from the user's own mined-word pool. JMdict-based distractors remain a Phase 2 candidate per §2, to be promoted only if the mined-pool quality proves insufficient in real use.

### Why a tokenizer is needed at all

Worth stating explicitly because the LLM call already returns a hiragana reading: cloze picking requires (a) word-boundary detection in unspaced Japanese text so each token is a tap target, (b) per-word lemmas so distractors don't show the same word in three conjugations, (c) per-word readings for furigana ruby on individual kanji words (the LLM gives a sentence-level blob), and (d) part-of-speech tags for distractor filtering. The LLM cannot replace this without per-word boundary annotations on every page, which would multiply OCR latency and cost.

---

## 7. Cloze Question Model & SRS Algorithm

### Terminology: cloze question, not flashcard

SRS literature commonly uses "card" for any scheduled study unit. This app deliberately does not. The schema entity is `ClozeQuestion`, and the prose throughout this document uses "cloze question" or simply "question" for an instance of it. The rename forces the schema, the UI, and the code Claude Code generates across sessions to model what the app actually is — multiple-choice cloze-deletion questions — rather than what its SRS heritage suggests.

A `ClozeQuestion` is a sentence with one word blanked, four answer options below, and a tap-to-select interaction. The two screens involved are the **question state** (before the user taps an answer) and the **feedback state** (after). When the user taps an answer option, the answer is revealed automatically — there is no separate flip step, no recall-then-reveal pattern, and no two-sided surface.

When writing user-facing copy or new prose, prefer "question" or "cloze question" over any flashcard-derived vocabulary.

### Cloze question model

A cloze question is uniquely identified by `(sentence_id, cloze_position)`. Each `Cloze` produces exactly one `ClozeQuestion`. A sentence with three picked clozes produces three cloze questions. Each quiz question shows exactly one cloze blanked, even when the underlying sentence contains multiple cloze positions.

### Question state

The sentence is shown with the target word replaced by a blank. Four answer options are presented below the sentence, all written in kanji (or kana when the word's natural form is kana). The user picks the option whose word fits the blank.

A **furigana toggle button** is rendered on every question. Tapping it toggles furigana visibility on every kanji-bearing word currently on screen — both in the surrounding sentence and on the four answer options. Tapping again hides them. The toggle state is per-question and resets when advancing to the next question; it is not persisted on `ClozeQuestion`, in `UserDefaults`, or anywhere else.

The button serves as the user's escape hatch when they know the word phonetically but cannot read its kanji. It does not affect scoring or scheduling: a correct answer is correct regardless of whether furigana was used.

### Feedback state

After the user answers:

- The full sentence is shown unblanked, with the target word visible in its correct form
- The user's answer is highlighted (success color if correct, failure color if wrong)
- The cached Turkish LLM translation of the full sentence is shown if available; otherwise just the sentence
- A "next" action advances to the next question in the session

### SRS algorithm: Ebisu

Ebisu is chosen over SM-2 and FSRS because:

- Its Bayesian model handles binary multiple-choice outcomes natively, without requiring multi-grade input (e.g. Anki's "again / hard / good / easy")
- It exposes "probability of recall now" as a continuous value, which is the right primitive for ordering due cloze questions by most-overdue first

#### Initial prior

New cloze questions start with the Beta prior `(α=3, β=3, t=24h)` — meaning "approximately 50% recall probability at 24 hours from now, with moderate uncertainty." The prior is a tunable value surfaced in settings.

#### Scoring

Binary: the user's answer is either correct or incorrect. The result drives Ebisu's standard binary posterior update.

Response time is recorded on `ReviewEvent` for future analysis but does not currently affect the posterior. Time-weighted scoring (fast/slow/wrong buckets feeding Ebisu's noisy-binary update) is a Phase 2 candidate; it requires real-use data to tune the noise parameters and is not worth implementing speculatively.

#### "Known" lane

The user can mark any cloze question as **known** via a toggle. When `is_known = true`, the question is excluded from the due query and never appears in review sessions. Toggling back to unknown restores it to active SRS using its existing Ebisu state — the state was never modified while the question was in the known lane, so no snapshot is required.

This is a simple "stop reviewing this" switch, not a second SRS lane. There is no maintenance schedule, no auto-return on failure (because the question isn't being reviewed while known), and no separate scheduler.

### Quiz session

#### Composition

Each session draws cloze questions where:

```
is_known == false AND next_review_at <= now()
```

ordered by `next_review_at ASC` (most-overdue first).

Never-reviewed questions enter this pool naturally: their initial prior places `next_review_at` at 24h after creation, so they appear in the next session that starts ≥24h after the cloze was picked.

There is no separate "new question" pool, no `is_introduced` flag, and no per-session new-question cap. If a mining burst produces more new questions than the user wants in one session, the standard `session_size` cap handles it — the most-overdue questions are drawn first and the rest wait.

#### Session size

User-configurable in settings. Default: **15 cloze questions.** Hard maximum: **50** to prevent burnout sessions. Minimum: 1.

If fewer cloze questions are due than the configured session size, the session is shorter.

#### Lapse re-queue within a session

Each unique cloze question in a session must be answered correctly once before the session is considered complete. A wrong answer does not advance the user past the cloze question — the cloze question is sent to the back of the session queue and re-asked later in the same session.

- **First attempt:** logged to `ReviewEvent` and used to update the cloze question's Ebisu posterior. This is the only attempt that affects scheduling.
- **Re-queued attempts (after a lapse):** session-local UI state only. Not logged to `ReviewEvent`, not used to update Ebisu. The cloze question has already been scheduled as a failed recall on the first attempt; the re-queue exists purely for in-session retention reinforcement.
- **Repeated lapses:** if a re-queued cloze question is also answered incorrectly, it goes to the back of the queue again. There is no upper bound on lapses per cloze question per session — the loop continues until the user answers correctly.

A perfect session of N unique cloze questions comprises exactly N questions. The session counter visible to the user reflects unique cloze questions remaining (N at session start) and decrements only on correct first-attempt answers; lapses do not decrement it.

#### Empty session

When zero cloze questions are due, the app shows an "all caught up" state. The user does not see ahead-of-schedule reviews unless they explicitly opt into an early-review mode (not in MVP).

### Cross-references

- **Distractor generation** is detailed in Section 6.
- **`ClozeQuestion` and SRS state persistence schema** is detailed in Section 8.

---

## 8. Data Model & Storage

### Persistence framework

**SwiftData** on iOS 26+. Integrates natively with SwiftUI, supports lightweight migrations.

GRDB / direct SQLite is not used for app data. App preferences are stored in `UserDefaults`, not SwiftData. The Keychain holds the LLM API key.

### CloudKit-readiness

**Not enforced as a day-0 constraint.** Required fields, sensible defaults, and natural FKs are used throughout. If iCloud sync is wanted later (Phase 2 candidate), the entry point is "audit the schema for CloudKit compatibility, write the migration." This is a real but routine task and frees Phase 0/1 from a tax that may never pay off on a single-device project.

### Schema entities

#### `CapturedPage`

One camera capture.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `captured_at` | `Date` | |
| `photo_relative_path` | `String` | Path under app's documents directory |

Future `ocr_engine_used` and `ocr_raw_output` fields are added in Phase 2 if and when a second OCR engine is introduced. Not bundled in MVP.

#### `Sentence`

The mining unit. Many-to-one with `CapturedPage`.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `text` | `String` | Original Japanese as transcribed by the OCR VLM. Immutable once any `Cloze` references the sentence (per Section 3). |
| `reading` | `String?` | Full hiragana of the same sentence, produced by the OCR VLM in the same call. Immutable once any `Cloze` references the sentence. |
| `translationTr` | `String?` | Turkish translation, produced by the OCR VLM in the same call. Immutable once any `Cloze` references the sentence. |
| `capturedPage` | `CapturedPage?` | SwiftData relationship to source page |
| `createdAt` | `Date` | |

No `Manga` / `Series` / `Volume` entity. Sentences are source-independent. `created_at` and `captured_page_id` are the only grouping signals.

Deletion is hard-delete and cascades to dependent `Cloze`, `ClozeQuestion`, and `ReviewEvent` rows.

#### `Cloze` (Phase 1+)

A specific word position within a sentence the user has marked for quizzing. One sentence can have many.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `sentence_id` | `UUID` | FK to `Sentence` |
| `start_offset` | `Int` | Character index in `Sentence.text` |
| `end_offset` | `Int` | Character index in `Sentence.text` |
| `surface_form` | `String` | The word as it appears in the sentence |
| `lemma` | `String` | Dictionary form from Sudachi |
| `reading` | `String` | Hiragana reading from Sudachi |
| `part_of_speech` | `String` | From Sudachi; used for distractor selection |
| `created_at` | `Date` | |

Added in Phase 1 via lightweight migration.

#### `ClozeQuestion` (Phase 1+)

One MCQ cloze-deletion question, scheduled via Ebisu. Each `Cloze` produces exactly one `ClozeQuestion`. The entity is named `ClozeQuestion` rather than the SRS-conventional `Card` to keep the data model honest about what the app does.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `cloze_id` | `UUID` | FK to `Cloze` |
| `ebisu_alpha` | `Double` | Current Beta posterior parameter |
| `ebisu_beta` | `Double` | Current Beta posterior parameter |
| `ebisu_t_hours` | `Double` | Current time horizon in hours |
| `next_review_at` | `Date` | Materialized due time, recomputed after each review |
| `last_reviewed_at` | `Date?` | Null until first review |
| `is_known` | `Bool` | True excludes from review pool |

Added in Phase 1 via lightweight migration.

#### `ReviewEvent` (Phase 1+)

Append-only log. Cascade-deleted on `ClozeQuestion` deletion.

Only first attempts are logged. Re-queued attempts within a session are session-local UI state and are not persisted.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `cloze_question_id` | `UUID` | FK to `ClozeQuestion` |
| `reviewed_at` | `Date` | |
| `was_correct` | `Bool` | |
| `response_time_ms` | `Int` | Recorded for future analysis; does not affect Ebisu in MVP |
| `ebisu_alpha_before` | `Double` | |
| `ebisu_beta_before` | `Double` | |
| `ebisu_t_hours_before` | `Double` | |
| `ebisu_alpha_after` | `Double` | |
| `ebisu_beta_after` | `Double` | |
| `ebisu_t_hours_after` | `Double` | |

Retained forever. Estimated growth at heavy use (~50 reviews/day) is ~18k rows/year — well within SQLite limits.

### Settings storage

Preferences live in `UserDefaults`, not SwiftData. A SwiftData entity for ~5 scalar values is overkill.

| Key | Type | Default | Phase | Notes |
|---|---|---|---|---|
| `ocr_provider_kind` | `String` | `"geminiFlash"` | 0 | Raw value of `OCRProviderKind` |
| `save_to_camera_roll` | `Bool` | `false` | 0 | Camera-roll save toggle |
| `session_size` | `Int` | 15 | 1 | Max 50, min 1 |
| `ebisu_default_alpha` | `Double` | 3.0 | 1 | |
| `ebisu_default_beta` | `Double` | 3.0 | 1 | |
| `ebisu_default_t_hours` | `Double` | 24.0 | 1 | |

**Keychain entries** (separate from `UserDefaults`):

| Service | Account | Phase | Notes |
|---|---|---|---|
| `com.gokhanseckin.mangamining` | `gemini_api_key` | 0 | `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock` |

Future provider keys will be additional accounts under the same service (`qwen_novita_api_key`, `deepseek_api_key`, etc.) — see `OCRProviderKind.keychainAccount`.

### Storage of non-SwiftData assets

| Asset | Where | Phase |
|---|---|---|
| Captured manga photos | App's documents directory, referenced by relative path | Phase 0+ |
| Optional duplicate of captured photo | iOS Photos library (when `save_to_camera_roll == true`) | Phase 0+ |
| Gemini API key | iOS Keychain | Phase 0+ |

JMdict and KANJIDIC are not bundled in MVP. They are Phase 2 candidates if and when distractor quality from the mined-word pool proves insufficient.

### Indexes and query patterns

The hot query is "what cloze questions are due now?" Phase 1 implementation reads `ClozeQuestion` rows with:

```
is_known == false AND next_review_at <= now()
```

ordered by `next_review_at ASC`.

`next_review_at` is a materialized field, not computed live from `(alpha, beta, t)` on every query. It is recomputed and written back after each review event.

Recommended SwiftData indexes:

- `ClozeQuestion.next_review_at`
- `ClozeQuestion.is_known`
- `ReviewEvent.cloze_question_id`
- `ReviewEvent.reviewed_at`
- `Sentence.created_at`
- `Cloze.sentence_id`

### Cross-references

- **Why** these fields exist (e.g., the binary `is_known` flag) is detailed in Section 7.
- **What gets bundled when** is summarized in Section 2's phase scope.

---


