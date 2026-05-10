import SwiftData
import SwiftUI
import UIKit

struct ProcessingView: View {
    let page: CapturedPage
    var onDone: (_ savedCount: Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(LocalizationStore.self) private var loc
    @State private var phase: Phase = .running
    @State private var candidates: [SentenceCandidate] = []
    @State private var errorMessage: String?
    @State private var needsApiKey = false
    @State private var showSettings = false

    enum Phase {
        case running
        case success
        case failure
    }

    var body: some View {
        Group {
            switch phase {
            case .running:
                runningView
            case .success:
                CandidatePickerView(candidates: candidates) { picked in
                    save(picked)
                    onDone(picked.count)
                } onCancel: {
                    onDone(0)
                }
            case .failure:
                failureView
            }
        }
        .navigationBarBackButtonHidden(phase == .running)
        .task {
            await runPipeline()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    private var runningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(loc.t("processing.readingPage"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: needsApiKey ? "key" : "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(needsApiKey ? .blue : .orange)
            ScrollView {
                Text(errorMessage ?? loc.t("processing.error.noTextDefault"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxHeight: 220)

            if needsApiKey {
                Button(loc.t("processing.openSettings")) { showSettings = true }
                    .buttonStyle(.borderedProminent)
                Button(loc.t("common.back")) { onDone(0) }
                    .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await runPipeline() }
                } label: {
                    Label(loc.t("common.retry"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                Button(loc.t("common.back")) { onDone(0) }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func runPipeline() async {
        phase = .running
        errorMessage = nil
        needsApiKey = false
        guard let image = PhotoStore.loadImage(relativePath: page.photoRelativePath) else {
            errorMessage = loc.t("processing.error.loadPhoto")
            phase = .failure
            return
        }
        let pipeline = OCRPipeline(provider: settings.makeProvider())
        do {
            let result = try await pipeline.process(image: image)
            page.documentType = result.documentType
            page.modifiedAt = .now
            try? modelContext.save()
            if result.sentences.isEmpty {
                errorMessage = loc.t("processing.error.noText")
                phase = .failure
            } else {
                candidates = result.sentences
                phase = .success
            }
        } catch OCRPipelineError.apiKeyMissing {
            needsApiKey = true
            errorMessage = loc.t("error.apiKey.missing")
            phase = .failure
        } catch OCRPipelineError.noImageData {
            errorMessage = loc.t("processing.error.readImage")
            phase = .failure
        } catch {
            errorMessage = loc.t("processing.error.ocrFailed", error.localizedDescription)
            phase = .failure
        }
    }

    private func save(_ picked: [SentenceCandidate]) {
        var inserted: [Sentence] = []
        for candidate in picked {
            let sentence = Sentence(
                text: candidate.text,
                reading: candidate.reading.isEmpty ? nil : candidate.reading,
                translation: candidate.translation.isEmpty ? nil : candidate.translation,
                translationLanguage: settings.interfaceLanguage,
                documentType: page.documentType,
                capturedPage: page
            )
            modelContext.insert(sentence)
            inserted.append(sentence)
        }
        try? modelContext.save()
        Task { await SentenceAutoLinker.autoLink(sentences: inserted, in: modelContext) }
    }
}
