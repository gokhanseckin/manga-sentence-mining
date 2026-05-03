# Manga Sentence Mining App — Specification

> iOS-only, solo, vibe-coded with Claude Code.
> Camera-based mining of sentences from printed manga, with Bayesian SRS and multiple-choice cloze-deletion questions.

---

## 1. Overview & Goals

### What this is

A native iOS app for mining sentences from printed manga and learning Japanese vocabulary from them via Bayesian-scheduled multiple-choice cloze-deletion questions.

The user points the camera at a manga page, the app OCRs the page, the user picks which sentences to save, and (from Phase 1) which words within those sentences to quiz. Every chosen word produces one quiz item: a sentence with that word blanked and four kanji answer options below it. A **furigana toggle button** is available on every question — tapping it reveals furigana on every kanji-bearing word currently visible (sentence context and answer options); tapping again hides them. It is the user's escape hatch when they know the word phonetically but cannot read its kanji.

### What this is not

- **Not a manga reader.** The camera is the input mechanism for sentence mining only. The app does not display, organize, or store manga as readable content.
- **Not a dictionary app.** Word-level translation lookups are out of scope for the MVP; sentence-level translation via LLM is the only translation pathway.
- **Not a generic OCR app.** The pipeline is tuned for manga: speech bubble reconstruction, onomatopoeia filtering, vertical Japanese typography.
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
- **Backend:** none. No VPS, no server, no auth. LLM API calls go directly from the device using a user-supplied API key stored in Keychain.
- **Sync:** none in MVP. iCloud sync is a Phase 2 candidate, not a committed anchor — it ships if and when the developer actually wants multi-device support.

### Reading guide for the rest of this document

- Section 2 (Release Phases) is the spine. Every other section's scope is partitioned by phase.
- Sections 7 (Cloze Question Model & SRS) and 8 (Data Model) are the most decision-dense. Most other sections cross-reference them.
- Section 5 (OCR Pipeline) is intentionally a list of unresolved questions to be answered during Phase 0 prototyping rather than upfront.
- Section 9 (Out of Scope) is load-bearing. It exists to prevent scope creep during vibe-coded sessions; consult it when in doubt about whether a feature belongs in the current phase.

---

## 2. Release Phases

The app ships in two phases plus a candidate-driven post-MVP. Each phase is shipped and used before the next is started. The split exists to derisk the hardest unknown — whether camera-based mining of real manga produces sentences worth studying — before any SRS infrastructure is built.

### Phase 0 — Prototype

**Goal:** validate that camera → cleaned sentences works on real manga, before investing in SRS.

**In scope:**

- Camera capture of a printed manga page
- Whole-page OCR via manga-ocr (ONNX Runtime)
- Sentence reconstruction across multiple speech bubbles
- Onomatopoeia / sound-effect filtering (not saved as sentences)
- User picks which detected sentences to save (sentence-level only — no word selection)
- Flat list of saved sentences with timestamp and source page reference
- Local storage only

**Anti-goals (explicitly NOT in Phase 0):**

- No word-level selection or cloze marking
- No quiz, no SRS, no Ebisu
- No distractors
- No iCloud sync
- No JMdict, no KANJIDIC, no Sudachi tokenization
- No "mark as known" or any review actions

**Success criteria (qualitative, evaluated by feel on real manga):**

- Sentences that span multiple bubbles are reconstructed start-to-end
- Onomatopoeia and sound effects are reliably distinguished from dialogue and excluded from the saved list
- The saved list contains studyable sentences, not OCR garbage

When the developer is satisfied with these on real pages, Phase 0 is done. There is no measurable gate.

### Phase 1 — MVP

**Goal:** add the SRS-driven learning loop on top of Phase 0's mining.

**Adds on top of Phase 0:**

- Sudachi on-device tokenization of saved sentences
- User picks the cloze word per sentence
- One cloze question per cloze (kanji answer options)
- Ebisu Bayesian SRS, one posterior per cloze question
- Multiple-choice quiz interface
- Distractors drawn from the user's own mined-word pool, filtered by part-of-speech and similar surface-form length
- "Mark as known" toggle to exclude a cloze question from review
- Furigana toggle button on every question
- Optional per-sentence translation via single hardcoded LLM provider, cached on the sentence

Still local storage only.

### Phase 2+ — Candidates (no committed scope)

The MVP ends with Phase 1. What ships next depends on what the developer actually wants after using the MVP. None of the following are committed:

- iCloud sync via private CloudKit
- JMdict / KANJIDIC bundled, used for higher-quality distractors (similar stroke count, similar reading length)
- JMdict Turkish gloss layer (LLM-pre-translated at build time, bundled)
- Apple Vision OCR as a selectable alternative engine (for menus, signs, real-world text)
- Cloud LLM OCR (Claude / DeepSeek vision) as a selectable alternative engine (for handwritten text, low-quality scans)
- Multi-provider LLM dropdown for translation
- OCR re-processing flow (re-run OCR on a saved page with a different engine)
- Audio / TTS
- Anki export
- Time-weighted scoring (fast/slow/wrong buckets feeding Ebisu's noisy-binary update)

When a Phase 2 feature is committed, this section is updated with its scope.

### Phase 0 schema scope

Phase 0's schema contains only `CapturedPage` and `Sentence`. The Phase 1 entities (`Cloze`, `ClozeQuestion`, `ReviewEvent`) are added via SwiftData's lightweight migration when Phase 1 begins. Adding new entities is a trivial migration that does not touch existing rows, so this is not a "data migration" risk in any meaningful sense.

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

The core Phase 0 loop. The user shoots one printed manga page at a time. There is no batch-shooting mode and no queue of unprocessed pages — each capture is processed and resolved before the next is taken.

1. From the home screen, the user opens the camera.
2. The user frames a manga page and triggers the shutter. The photo is written to the documents directory and a `CapturedPage` row is created.
3. The OCR pipeline (Section 5) runs on the photo. The user sees a progress indicator while it runs.
4. The pipeline emits a list of reconstructed sentence candidates with onomatopoeia / SFX already filtered out.
5. The user is presented with the candidate list and multi-selects which to keep. Unpicked candidates are discarded.
6. On confirm, one `Sentence` row is created per picked candidate. The user returns to the home screen.

The user may now shoot the next page, browse saved sentences, or close the app. In Phase 0, this is the entire user loop.

#### Capture failure recovery

The user-facing handling of OCR failures (no text regions detected, nonsense OCR per region, photo too blurry, etc.) is owned by Section 5.6 and resolved during Phase 0 prototyping rather than committed here.

What this section commits to is independent of how failures are surfaced: the photo is retained on the `CapturedPage` regardless of whether any sentences were saved, and re-shooting creates a new `CapturedPage` rather than replacing the previous one.

#### Browse saved sentences

Reachable from the home screen via a "Saved sentences" entry. Shows all `Sentence` rows in reverse chronological order by `created_at`. There is no folder, tag, manga, or volume grouping in the MVP — Section 8 deliberately omits a `Manga` entity.

Tapping a sentence opens a detail view showing the full text, source page reference, timestamp, and (Phase 1+) any clozes and their cloze questions.

#### Edit sentence text

From the sentence detail view, the user can edit `Sentence.text` **only when no `Cloze` rows reference it.** Once any cloze has been picked from a sentence, the edit action is hidden in the detail view and `Sentence.text` becomes immutable.

This rule eliminates the split-state problem of "existing cloze questions display old text vs. new text" without snapshotting sentence text on `Cloze`. If the user wants to change the text after clozing, the recourse is to delete the cloze questions, edit, then re-pick clozes.

#### Delete sentence

From the sentence detail view, the user can delete a sentence. Deletion is hard-delete and **cascades to all dependent `Cloze`, `ClozeQuestion`, and `ReviewEvent` rows.** A confirmation dialog warns the user when dependent rows exist.

The semantic is: deleting a sentence means "I'm done studying this entirely." If the user wants to keep studying clozes from a sentence, they don't delete it. Soft-delete machinery is not used.

### Cloze picking and translation (Phase 1+)

#### Pick clozes from a saved sentence

Cloze picking is a separate task initiated from the sentence detail view, never as part of capture.

1. From sentence detail, the user opens the cloze-picking action.
2. The sentence is tokenized via Sudachi (Section 6). Each token is rendered as a tap target with its surface form.
3. The user taps one or more tokens to mark them as cloze positions. There is no upper bound on clozes per sentence.
4. On confirm, one `Cloze` row is created per marked position, and one `ClozeQuestion` row is created per `Cloze` (per Section 7).
5. The auto-translation request fires (see below).

#### Add more clozes later

The user can return to the cloze-picking action on a sentence that already has clozes. Existing cloze positions are visible (and not re-tappable), and additional tokens can be marked. This produces new `Cloze` and `ClozeQuestion` rows alongside the existing ones; existing cloze questions are unaffected and retain their SRS state.

There is no flow to "remove" a cloze in the MVP. To stop reviewing a cloze question, the user marks it known (Section 7) or deletes the cloze question (below).

#### Auto-translation

A sentence's Turkish translation is fetched only after at least one cloze has been picked from it. Sentences saved but never clozed never trigger an LLM call. The trigger is the cloze-confirmation step above.

Translation runs asynchronously in the background; the user is not blocked on it. On success, `Sentence.translation_tr` is populated.

Translation is best-effort and silent on failure:

- **No API key set:** no call is made; nothing is shown.
- **Network or LLM error:** at most one retry, then abandoned. Nothing is shown to the user.

There is no manual "translate now" button in the MVP.

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

No API key is required to use Phase 0. The app opens to an empty home screen with a single "Capture" CTA. No onboarding, no walkthrough.

#### First launch (Phase 1)

API key entry is part of the Phase 1 setup, but the exact onboarding mechanics — required up front vs. lazy on first translation, Keychain UX — are not yet decided. Surfaced in Section 10.

#### Settings

Reachable from the home screen. The adjustable values are stored in `UserDefaults` (per Section 8): session size, Ebisu prior values, and the LLM API key reference. The settings screen is utilitarian: a flat list of fields with current values and inline editors.

### Phase scope summary

| Flow | Phase 0 | Phase 1 |
|---|---|---|
| Capture and save sentences | yes | yes |
| Capture failure recovery | yes | yes |
| Browse saved sentences | yes | yes |
| Edit sentence text (only when un-clozed) | yes | yes |
| Delete sentence (cascading) | yes | yes |
| Pick clozes / add more clozes | — | yes |
| Auto-translation | — | yes |
| Start review session | — | yes |
| Cloze question interaction (answer, furigana toggle, known toggle) | — | yes |
| Delete cloze question | — | yes |
| Lapse re-queue | — | yes |
| Mid-session abandon | — | yes |
| All-caught-up state | — | yes |
| First-launch onboarding | minimal, no key | API-key entry (TBD, Section 10) |
| Settings | minimal | full settings |

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

> **Status:** open. Phase 0 cannot ship without resolving the questions in this section. Decisions deferred until prototype-time experimentation.

### Constraint

Phase 0's success criteria (Section 2) are entirely OCR-pipeline problems:

- Sentences spanning multiple speech bubbles must be reconstructed start-to-end
- Onomatopoeia and sound effects must be reliably distinguished from dialogue
- The saved sentence list must contain studyable sentences, not OCR garbage

manga-ocr alone solves none of these. It OCRs whatever crop is passed to it. Everything else — bubble detection, reading-order resolution, sentence reconstruction, SFX filtering — is pipeline logic built around manga-ocr.

### Engine for Phase 0

**manga-ocr** via ONNX Runtime on iOS. Pre-converted ONNX weights are available on Hugging Face (`mayocream/manga-ocr-onnx`, `l0wgear/manga-ocr-2025-onnx`). Future swap to Core ML for Neural Engine acceleration is deferred.

**No `OCREngine` protocol abstraction in Phase 0.** Direct, single concrete implementation. When and if a second engine is added (Phase 2 candidate), refactor to a protocol then. Premature interface design is a known Claude Code failure mode.

### Open questions (to resolve before / during Phase 0 prototyping)

#### 5.1 Speech bubble detection

How are bubble regions located on the page? manga-ocr expects pre-cropped bubbles, so something must find them first.

Candidates:

- **Apple Vision text-region detection.** Free, on-device, fast. Detects "text is here" but not "bubble vs. SFX vs. caption box."
- **A bundled second ML model** (e.g. comictextdetector, magi-style models). Better bubble semantics, costs another ~50–100 MB and more integration work.
- **LLM vision call.** Send the page to Claude or DeepSeek, ask for bounding boxes. High quality, slow, network-dependent, costs per call.

#### 5.2 Reading order across bubbles

Manga reads right-to-left, top-to-bottom, but layouts are irregular.

Candidates:

- **Rule-based sort** by (top edge, then right edge). Fast, fails on creative layouts.
- **LLM-driven ordering** after OCR: send detected bubbles + positions, ask for reading order.
- **Manual reordering** in the UI: show numbered bubbles, let the user fix order if wrong.
- A combination (rule-based with manual override).

#### 5.3 Sentence reconstruction across bubbles

When does "bubble A" + "bubble B" become "one sentence"? A character speaking often continues across bubbles or panels.

Candidates:

- **Punctuation-driven heuristic:** if bubble A does not end with 。！？ assume continuation into bubble B.
- **LLM-driven splitting:** send all bubble text to an LLM, ask for sentence segmentation.
- **No reconstruction:** treat every bubble as one entry; user manually merges in the picker UI.

#### 5.4 Onomatopoeia / SFX filtering

SFX in manga tends to be: outside speech bubbles, in stylized fonts manga-ocr handles poorly, often katakana-only, single short words, exclamatory.

Candidates:

- **Spatial filter:** OCR only inside detected bubble regions, ignore floating text.
- **Linguistic filter:** OCR everything, then drop entries that are short + katakana-only + no kanji + no particles.
- **LLM classifier:** per region, ask "dialogue or SFX?"
- **Combination:** spatial first (cheap), linguistic on remainder, LLM only as fallback.

#### 5.5 Picker UI output granularity

When the user reviews the page's OCR output, what do they see?

Candidates:

- **Reconstructed sentences,** one entry per merged sentence, with a "show source bubbles" detail view.
- **Per-bubble entries,** user selects bubbles and the app concatenates.
- **Raw OCR text** with paragraph breaks, user manually edits sentences out.

#### 5.6 Failure-mode UX

What does the user see when:

- No text regions are detected on the page
- manga-ocr returns nonsense for a region
- The photo is too blurry to OCR usefully

Candidates: re-shoot prompt, raw output shown for manual editing, error logged with the photo retained, or some combination.

### Cross-references

- The `CapturedPage` schema (Section 8) retains the photo regardless of OCR outcome.

---

## 6. Tokenization & Word Selection

[To be drafted]

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
| `text` | `String` | Final cleaned sentence as saved by the user. Immutable once any `Cloze` references it (per Section 3). |
| `captured_page_id` | `UUID` | FK to `CapturedPage` |
| `created_at` | `Date` | |
| `translation_tr` | `String?` | LLM-cached Turkish translation, populated on demand |

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

| Key | Type | Default | Notes |
|---|---|---|---|
| `session_size` | `Int` | 15 | Max 50, min 1 |
| `ebisu_default_alpha` | `Double` | 3.0 | |
| `ebisu_default_beta` | `Double` | 3.0 | |
| `ebisu_default_t_hours` | `Double` | 24.0 | |
| `llm_api_key_keychain_ref` | `String` | — | Identifier into Keychain |

LLM provider is hardcoded for MVP (single provider). Multi-provider dropdown is a Phase 2 candidate.

### Storage of non-SwiftData assets

| Asset | Where | Phase |
|---|---|---|
| Captured manga photos | App's documents directory, referenced by relative path | Phase 0+ |
| LLM API key | iOS Keychain | Phase 1+ |
| manga-ocr ONNX model | Bundled in app binary, read-only | Phase 0+ |

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


