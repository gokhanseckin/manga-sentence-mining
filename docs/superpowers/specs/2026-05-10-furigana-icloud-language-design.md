# Furigana toggle, iCloud sync toggle, language change confirmation — Design

Date: 2026-05-10
Status: Draft

## Summary

Three independent settings/UX additions:

1. Add a furigana show/hide toggle to `SavedSentencesView` and `ClozePickerView`.
2. Surface the existing iCloud sync preference as a toggle in `SettingsView` (default unchanged: ON when signed into iCloud).
3. Add an interface-language picker to `SettingsView` with a confirmation dialog before the change is committed.

`CandidatePickerView` is intentionally excluded from feature 1 — its rows are editable `TextField`s and ruby annotation doesn't render inside a text editor.

## Feature 1 — Furigana toggle

### Existing infrastructure

- `JapaneseText` view ([JapaneseSentenceMining/Views/JapaneseText.swift](../../../JapaneseSentenceMining/Views/JapaneseText.swift)) renders Japanese text with optional ruby and accepts `@Binding var showFurigana`.
- `FuriganaToggleButton` ([JapaneseText.swift:92](../../../JapaneseSentenceMining/Views/JapaneseText.swift)) is the reusable toolbar button bound to the same `Bool`.
- Existing convention (used in `SentenceDetailView`): `@State private var showFurigana = false` — local view state, not persisted across launches.

### SavedSentencesView changes

[JapaneseSentenceMining/Views/SavedSentencesView.swift](../../../JapaneseSentenceMining/Views/SavedSentencesView.swift)

- Add `@State private var showFurigana = false` to the view.
- Replace the row-level `Text(sentence.text)` (line 23) with `JapaneseText(text: sentence.text, showFurigana: $showFurigana, font: .body)`.
- Add a toolbar item containing `FuriganaToggleButton(showFurigana: $showFurigana)`.

Notes:

- The same `showFurigana` binding is shared across all rows in the list — toggling once affects every visible sentence, matching user expectation for a global "show readings" mode on a list view.
- Tokenization happens lazily inside `JapaneseText` only when the toggle is on, so cost is paid only when the user opts in.

### ClozePickerView changes

[JapaneseSentenceMining/Views/ClozePickerView.swift](../../../JapaneseSentenceMining/Views/ClozePickerView.swift)

- Add `@State private var showFurigana = false` to `ClozePickerView`.
- Add a toolbar item with `FuriganaToggleButton(showFurigana: $showFurigana)` next to the Save/Cancel buttons (placement: `topBarTrailing`, ordered before the Save button, or as a separate `topBarLeading`/principal slot — implementer's choice consistent with iOS HIG).
- Modify `TokenChip` (private struct in the same file) to take `showFurigana: Bool`.
- Inside `TokenChip.body`, when `showFurigana` is true and `token.reading` is non-empty AND differs from `token.surface`, render a `VStack(spacing: 1)` with:
  - `Text(token.reading).font(.caption2)` on top
  - `Text(token.surface).font(.title3)` below
- When `showFurigana` is false (or the reading is empty/equal to surface), keep the existing single-line `Text(token.surface)` rendering.
- The selection / chip state styling (background, foreground, disabled) is unchanged.

Why not use `JapaneseText` here: each token is its own tap target, and the cloze picker already has tokenized data. Using `JapaneseText` would re-tokenize and break the per-token tap UX.

### CandidatePickerView — excluded

The candidate rows are editable `TextField`s for `text`, `reading`, and `translation`. Furigana ruby cannot render inside a `TextField`, and switching modes mid-edit would be disruptive. Out of scope.

## Feature 2 — iCloud sync toggle

### Existing infrastructure

- `SettingsStore.iCloudSyncEnabled` already exists ([JapaneseSentenceMining/Settings/SettingsStore.swift:77](../../../JapaneseSentenceMining/Settings/SettingsStore.swift)).
- Default at first launch: ON if `FileManager.default.ubiquityIdentityToken != nil`, OFF otherwise. Persisted to `UserDefaults` under `AppModelContainer.iCloudSyncEnabledKey`.
- `AppModelContainer` reads the value at launch when constructing the SwiftData store; runtime changes do not migrate the existing store.

### SettingsView changes

[JapaneseSentenceMining/Views/SettingsView.swift](../../../JapaneseSentenceMining/Views/SettingsView.swift)

Add a new `Section` (placement: after the OCR provider section, before the Camera Roll toggle, or grouped with Camera Roll — implementer's choice):

```swift
Section {
    Toggle(loc.t("settings.iCloudSync"), isOn: $settings.iCloudSyncEnabled)
} footer: {
    Text(loc.t("settings.iCloudSync.footer"))
}
```

Footer copy (English baseline): "Syncs your sentences and review history across devices via iCloud. Requires restarting the app to take effect."

Default behavior is **unchanged**: still ON when the user is signed into iCloud at first launch.

### Localization

New keys required, added to `BaseStrings` and translated for all `SupportedLanguage` cases via `InterfaceTranslator`:

- `settings.iCloudSync` — toggle label, e.g. "iCloud Sync"
- `settings.iCloudSync.footer` — explanatory footer text

## Feature 3 — Language change with confirmation

### Existing infrastructure

- `SettingsStore.interfaceLanguage` ([SettingsStore.swift:61](../../../JapaneseSentenceMining/Settings/SettingsStore.swift)) is the single source of truth driving both the UI translation (via `LocalizationStore`) and the OCR target language (via `makeProvider()` → `GeminiFlashProvider(targetLanguage:)`).
- `SupportedLanguage` enum ([JapaneseSentenceMining/Localization/SupportedLanguage.swift](../../../JapaneseSentenceMining/Localization/SupportedLanguage.swift)) provides `allCases` and display names.

### SettingsView changes

Add a new `Section` for language with a `Picker` whose binding triggers a confirmation alert before mutating `settings.interfaceLanguage`.

State additions to `SettingsView`:

```swift
@State private var pendingLanguage: SupportedLanguage?
@State private var showLanguageConfirm = false
```

Section body:

```swift
Section {
    Picker(loc.t("settings.language.label"), selection: Binding(
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
} header: {
    Text(loc.t("settings.section.language"))
}
```

Confirmation alert (attached to the Form):

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

The Picker reads from `settings.interfaceLanguage` directly via the `get` closure, so when the user taps "No, Keep" the picker visually snaps back to the current language without further code (the binding's `get` returns the unchanged value on the next render).

### Confirmation copy (English baseline)

- Title: "Change language?"
- Message: "Are you sure? This will both change the interface language and new mined sentence translations will be in the selected language."
- Confirm button: "Yes, Change"
- Cancel button: "No, Keep"

### Behavior on confirmation

- `settings.interfaceLanguage` is updated. `LocalizationStore` reactively re-renders the UI in the new language.
- New OCR captures use the new `targetLanguage` because `makeProvider()` reads `settings.interfaceLanguage` at call time.
- **Existing sentences are not retranslated.** Their `translationLanguage` and stored translation remain as-is. This is by design — out of scope.

### Localization

New keys (added to `BaseStrings`, translated for all `SupportedLanguage` cases):

- `settings.section.language`
- `settings.language.label`
- `settings.language.confirm.title`
- `settings.language.confirm.message`
- `settings.language.confirm.yes`
- `settings.language.confirm.no`

## Testing

Manual verification (no automated UI tests in repo today):

1. **Furigana — SavedSentencesView**: Toggle on → readings appear above kanji on every row. Toggle off → plain text. Verify scrolling performance with the toggle on (lazy tokenization should keep this acceptable).
2. **Furigana — ClozePickerView**: Toggle on → tokens render with reading-above-surface ruby. Tap a token → selection still works. Already-clozed tokens still appear disabled. Toggle off → single-line tokens.
3. **iCloud toggle**: Flip OFF, restart app, confirm SwiftData container falls back to local-only. Flip ON, restart, confirm sync resumes. Verify default behavior is unchanged on a fresh install.
4. **Language change**: Pick a different language → alert appears with the exact copy. Tap "No, Keep" → picker reverts, language unchanged. Tap "Yes, Change" → UI re-localizes immediately. Capture a new image → translation comes back in the new language. Open an old sentence → translation stays in the original language.

## Out of scope

- Persisting the furigana toggle across app launches.
- Adding the furigana toggle to `CandidatePickerView`.
- Migrating existing sentence translations when the language changes.
- Showing an explicit "restart required" prompt for the iCloud toggle (footer text only).
- Adding new languages to `SupportedLanguage`.
