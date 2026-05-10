# Furigana toggle, iCloud toggle, Language change — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a furigana show/hide toggle to `SavedSentencesView` and `ClozePickerView`, surface the existing iCloud sync preference as a Settings toggle, and add a language picker in Settings with a double-confirmation alert.

**Architecture:** Three independent UI additions reusing existing infrastructure: `JapaneseText`/`FuriganaToggleButton` for furigana, `SettingsStore.iCloudSyncEnabled` (already wired to `AppModelContainer`), and `SettingsStore.interfaceLanguage` (already drives both UI translation and OCR target language). New localization keys are added to `BaseStrings.entries`; `InterfaceTranslator` picks them up automatically the next time the user changes language.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, iOS 26 deployment target, XcodeGen (no Xcode project in repo — generated from `project.yml`). No automated tests in this repo; verification is `xcodebuild build` + manual UI checks per task.

**Spec:** [docs/superpowers/specs/2026-05-10-furigana-icloud-language-design.md](../specs/2026-05-10-furigana-icloud-language-design.md)

---

## Pre-flight

- [ ] **Step 0a: Generate the Xcode project**

The repo does not commit `JapaneseSentenceMining.xcodeproj`. Generate it before any build:

```bash
cd "$(git rev-parse --show-toplevel)"
xcodegen generate
```

Expected: `JapaneseSentenceMining.xcodeproj` directory now exists.

- [ ] **Step 0b: Verify a clean build before any changes**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: ends with `** BUILD SUCCEEDED **`. If it doesn't, stop and fix the baseline before continuing.

---

## Task 1: Add new localization keys to BaseStrings

**Files:**
- Modify: `JapaneseSentenceMining/Localization/BaseStrings.swift`

Existing reusable keys (no changes needed): `settings.iCloudSync`, `settings.iCloudSync.description`, `settings.language`, `furigana.show`, `furigana.hide`.

**New keys to add:**
- `settings.section.iCloudSync` — section header above the iCloud toggle.
- `settings.section.language` — section header above the language picker.
- `settings.language.confirm.title` — alert title.
- `settings.language.confirm.message` — alert body (the exact prompt the user requested).
- `settings.language.confirm.yes` — destructive confirm button.
- `settings.language.confirm.no` — cancel button.

- [ ] **Step 1.1: Add the six new entries to `BaseStrings.entries`**

Open `JapaneseSentenceMining/Localization/BaseStrings.swift` and insert these entries inside the `static let entries: [Entry] = [ ... ]` literal. Place them near the existing settings entries (after the `settings.apiKey.footer` entry around line 142 is a good spot). The exact lines to add:

```swift
        // Settings (iCloud + language)
        Entry(key: "settings.section.iCloudSync", value: "iCloud", comment: "Settings section header above the iCloud sync toggle."),
        Entry(key: "settings.section.language", value: "Language", comment: "Settings section header above the interface-language picker."),
        Entry(key: "settings.language.confirm.title", value: "Change language?", comment: "Alert title shown when the user picks a new interface language."),
        Entry(key: "settings.language.confirm.message", value: "Are you sure? This will both change the interface language and new mined sentence translations will be in the selected language.", comment: "Alert body explaining that changing the language affects both the UI and future captured-sentence translations."),
        Entry(key: "settings.language.confirm.yes", value: "Yes, Change", comment: "Confirm button on the language-change alert. Commits the change."),
        Entry(key: "settings.language.confirm.no", value: "No, Keep", comment: "Cancel button on the language-change alert. Reverts the picker to the current language."),
```

- [ ] **Step 1.2: Build to verify the additions compile**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 1.3: Commit**

```bash
git add JapaneseSentenceMining/Localization/BaseStrings.swift
git commit -m "Add localization keys for iCloud and language settings sections"
```

---

## Task 2: Furigana toggle in SavedSentencesView

**Files:**
- Modify: `JapaneseSentenceMining/Views/SavedSentencesView.swift`

The view currently renders `Text(sentence.text)` per row. Replace with `JapaneseText`, add `@State` for the toggle, and add `FuriganaToggleButton` to the toolbar.

- [ ] **Step 2.1: Replace SavedSentencesView contents**

Open `JapaneseSentenceMining/Views/SavedSentencesView.swift` and replace the entire file with:

```swift
import SwiftData
import SwiftUI

struct SavedSentencesView: View {
    @Query(sort: \Sentence.createdAt, order: .reverse) private var sentences: [Sentence]
    @Environment(LocalizationStore.self) private var loc
    @State private var showFurigana = false

    var body: some View {
        Group {
            if sentences.isEmpty {
                ContentUnavailableView(
                    loc.t("savedSentences.empty.title"),
                    systemImage: "text.book.closed",
                    description: Text(loc.t("savedSentences.empty.body"))
                )
            } else {
                List {
                    ForEach(sentences) { sentence in
                        NavigationLink {
                            SentenceDetailView(sentence: sentence)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                JapaneseText(text: sentence.text, showFurigana: $showFurigana, font: .body)
                                    .lineLimit(2)
                                if let tr = sentence.translation, !tr.isEmpty {
                                    Text(tr)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(sentence.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(loc.t("savedSentences.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sentences.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    FuriganaToggleButton(showFurigana: $showFurigana)
                }
            }
        }
    }
}
```

Notes:
- The toolbar item is gated on `!sentences.isEmpty` so the empty state has no orphan button.
- `JapaneseText` lazily tokenizes only when `showFurigana` flips on, so the cost is only paid once per row when the user opts in.

- [ ] **Step 2.2: Build**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.3: Manual smoke test**

Run the app on a simulator (or device). With at least one sentence saved:

1. Open Saved sentences. Tap the toolbar icon (textformat). Readings appear above kanji on every row.
2. Tap again. Readings disappear; rows render as plain text.
3. Open the empty state (delete all sentences in a fresh install). Toolbar button is hidden.

If anything is off, fix and re-build before committing.

- [ ] **Step 2.4: Commit**

```bash
git add JapaneseSentenceMining/Views/SavedSentencesView.swift
git commit -m "Add furigana toggle to Saved Sentences"
```

---

## Task 3: Furigana toggle in ClozePickerView

**Files:**
- Modify: `JapaneseSentenceMining/Views/ClozePickerView.swift`

`ClozePickerView` already has tokens with readings (from `JapaneseTokenizer`). Augment the private `TokenChip` to render reading-above-surface when the toggle is on. Add a toolbar button.

- [ ] **Step 3.1: Add `@State private var showFurigana` and wire it through**

In `JapaneseSentenceMining/Views/ClozePickerView.swift`, add the new state below the existing `@State` declarations (currently lines 11–14):

```swift
    @State private var showFurigana = false
```

- [ ] **Step 3.2: Pass `showFurigana` into each `TokenChip`**

Find the `ForEach` inside `content` (around line 61) and replace the `TokenChip(...)` call with one that includes the new parameter:

```swift
                    ForEach(Array(tokens.enumerated()), id: \.offset) { idx, token in
                        TokenChip(
                            token: token,
                            state: chipState(for: idx, token: token),
                            showFurigana: showFurigana
                        ) {
                            toggleSelection(idx, token: token)
                        }
                    }
```

- [ ] **Step 3.3: Add a furigana toggle to the toolbar**

Inside the `.toolbar { ... }` block (around line 34), add a third `ToolbarItem` with `placement: .principal` between the leading Cancel and trailing Save:

```swift
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    FuriganaToggleButton(showFurigana: $showFurigana)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(confirmLabel) {
                        confirmSelection()
                    }
                    .disabled(selectedTokenIDs.isEmpty)
                }
            }
```

- [ ] **Step 3.4: Update `TokenChip` to render furigana**

Replace the entire `TokenChip` private struct at the bottom of the file with:

```swift
private struct TokenChip: View {
    let token: JapaneseToken
    let state: ClozePickerView.ChipState
    let showFurigana: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            chipContent
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(state == .alreadyClozed)
    }

    @ViewBuilder
    private var chipContent: some View {
        if showFurigana, shouldAnnotate {
            VStack(spacing: 1) {
                Text(katakanaToHiragana(token.reading))
                    .font(.caption2)
                Text(token.surface)
                    .font(.title3)
            }
        } else {
            Text(token.surface).font(.title3)
        }
    }

    private var shouldAnnotate: Bool {
        let reading = token.reading
        guard !reading.isEmpty, reading != "*" else { return false }
        return token.surface != reading
            && token.surface.unicodeScalars.contains { scalar in
                (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
            }
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

    private var background: some ShapeStyle {
        switch state {
        case .selectable: return AnyShapeStyle(Color(.secondarySystemBackground))
        case .selected: return AnyShapeStyle(Color.accentColor.opacity(0.85))
        case .alreadyClozed: return AnyShapeStyle(Color(.tertiarySystemBackground))
        }
    }

    private var foreground: some ShapeStyle {
        switch state {
        case .selectable: return AnyShapeStyle(Color.primary)
        case .selected: return AnyShapeStyle(Color.white)
        case .alreadyClozed: return AnyShapeStyle(Color.secondary)
        }
    }
}
```

Notes:
- `shouldAnnotate` mirrors the predicate already used in `JapaneseText.FuriganaFlow.shouldAnnotate` plus a `surface != reading` guard so all-kana tokens don't show duplicate ruby.
- The katakana-to-hiragana conversion mirrors the helper in `JapaneseText.swift`. We duplicate it here (rather than make it public) because the helper is a 6-line closure and a public API surface is overkill for one extra call site. If a third usage appears later, hoist it to a shared utility then.

- [ ] **Step 3.5: Build**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.6: Manual smoke test**

1. Open a saved sentence and tap "Pick clozes." With the toolbar furigana button OFF, tokens render single-line.
2. Tap the furigana toggle. Tokens with kanji now show hiragana above the surface; pure-kana tokens stay single-line.
3. Tap a token to select it. Selection highlight still works. Already-clozed tokens are still disabled.
4. Tap Save. Cloze is created.

- [ ] **Step 3.7: Commit**

```bash
git add JapaneseSentenceMining/Views/ClozePickerView.swift
git commit -m "Add furigana toggle to Cloze Picker"
```

---

## Task 4: iCloud sync toggle in Settings

**Files:**
- Modify: `JapaneseSentenceMining/Views/SettingsView.swift`

`SettingsStore.iCloudSyncEnabled` is already persisted and consumed by `AppModelContainer` at app launch. This task only adds the UI.

- [ ] **Step 4.1: Add the iCloud toggle section to `SettingsView`**

In `JapaneseSentenceMining/Views/SettingsView.swift`, insert a new `Section` immediately after the existing OCR-provider section (after line 21, the closing brace of the first section). The block to insert:

```swift
            Section {
                Toggle(loc.t("settings.iCloudSync"), isOn: $settings.iCloudSyncEnabled)
            } header: {
                Text(loc.t("settings.section.iCloudSync"))
            } footer: {
                Text(loc.t("settings.iCloudSync.description"))
            }
```

The full Form should now read: OCR provider → **iCloud** (new) → Save to camera roll → Review → API key.

- [ ] **Step 4.2: Build**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.3: Manual smoke test**

1. Open Settings. The new "iCloud" section is visible with a toggle and footer text.
2. Toggle off, kill and relaunch the app. Confirm the SwiftData container falls back to local-only (no CloudKit logs in the console; no `NSPersistentCloudKitContainer` setup messages).
3. Toggle back on, relaunch. Sync resumes.
4. On a fresh install with iCloud signed-in, the toggle defaults to ON (unchanged behavior).

- [ ] **Step 4.4: Commit**

```bash
git add JapaneseSentenceMining/Views/SettingsView.swift
git commit -m "Add iCloud sync toggle to Settings"
```

---

## Task 5: Language picker with double-confirmation in Settings

**Files:**
- Modify: `JapaneseSentenceMining/Views/SettingsView.swift`

The picker uses a custom `Binding` so changing the selection schedules a confirmation alert rather than committing the change directly. If the user picks "No, Keep," the picker visually snaps back because the `get` closure still returns the unchanged `settings.interfaceLanguage`.

- [ ] **Step 5.1: Add `@State` for pending language and alert visibility**

Below the existing `@State private var savedFlash = false` (currently around line 9), add:

```swift
    @State private var pendingLanguage: SupportedLanguage?
    @State private var showLanguageConfirm = false
```

- [ ] **Step 5.2: Add the language section to the Form**

Insert this new `Section` immediately after the iCloud section added in Task 4:

```swift
            Section {
                Picker(loc.t("settings.language"), selection: Binding(
                    get: { SupportedLanguage(rawValue: settings.interfaceLanguage) ?? .english },
                    set: { newValue in
                        guard newValue.rawValue != settings.interfaceLanguage else { return }
                        pendingLanguage = newValue
                        showLanguageConfirm = true
                    }
                )) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(loc.t("settings.section.language"))
            }
```

- [ ] **Step 5.3: Attach the confirmation alert to the Form**

Add this `.alert` modifier immediately after the existing `.onChange(of: settings.providerKind) { ... }` modifier on the Form (around line 91):

```swift
        .alert(
            loc.t("settings.language.confirm.title"),
            isPresented: $showLanguageConfirm,
            presenting: pendingLanguage
        ) { lang in
            Button(loc.t("settings.language.confirm.yes"), role: .destructive) {
                settings.interfaceLanguage = lang.rawValue
                pendingLanguage = nil
            }
            Button(loc.t("settings.language.confirm.no"), role: .cancel) {
                pendingLanguage = nil
            }
        } message: { _ in
            Text(loc.t("settings.language.confirm.message"))
        }
```

Notes:
- The `presenting:` parameter ensures the alert closures only fire when `pendingLanguage` is non-nil.
- The picker's `Binding.get` returns whatever `settings.interfaceLanguage` currently is. When the user taps "No, Keep" without mutating that value, SwiftUI's next render reads the unchanged value and the picker visually snaps back to the original.
- The "Yes, Change" button is `.destructive` purely for visual emphasis (red text), matching iOS HIG for state-changing confirmations.

- [ ] **Step 5.4: Build**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5.5: Manual smoke test**

1. Open Settings. The "Language" section appears with the current language pre-selected in a menu picker.
2. Tap the picker, select a different language. The alert appears with title "Change language?" and the message: "Are you sure? This will both change the interface language and new mined sentence translations will be in the selected language." Buttons read "Yes, Change" (red) and "No, Keep".
3. Tap "No, Keep". Alert dismisses. Picker still shows the original language (no flicker into the new language).
4. Tap the picker again, select a different language, then "Yes, Change". The Settings UI re-localizes immediately into the new language (because `LocalizationStore` reacts to `interfaceLanguage`).
5. Capture a new image from the home screen. The translation comes back in the newly selected language.
6. Open an existing previously-mined sentence. Its translation stays in the language it was originally mined in (this is intentional, per spec).

- [ ] **Step 5.6: Commit**

```bash
git add JapaneseSentenceMining/Views/SettingsView.swift
git commit -m "Add language picker with confirmation to Settings"
```

---

## Final verification

- [ ] **Step 6.1: Final build**

```bash
set -o pipefail
xcodebuild build \
  -project JapaneseSentenceMining.xcodeproj \
  -scheme JapaneseSentenceMining \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6.2: End-to-end manual run**

Walk through all four user-visible flows once more on a single simulator session: furigana on Saved Sentences, furigana on Cloze Picker, iCloud toggle, language change with both Yes and No paths. Confirm there are no console warnings.

- [ ] **Step 6.3: Confirm `xcodeproj` is not staged**

```bash
git status --short
```

Expected: `JapaneseSentenceMining.xcodeproj/` is **not** listed (it's generated, not committed). If it shows up, ensure it's covered by `.gitignore`. Do not commit it.

---

## Out of scope (per spec)

- Persisting furigana toggle state across app launches.
- Furigana toggle on `CandidatePickerView` (rows are editable `TextField`s; ruby cannot render inside).
- Retranslating existing sentences when the language changes.
- Live "restart required" prompt for the iCloud toggle (footer copy is enough).
- Adding new languages to `SupportedLanguage`.
