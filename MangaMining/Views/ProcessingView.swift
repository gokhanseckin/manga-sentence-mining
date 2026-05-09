import SwiftData
import SwiftUI
import UIKit

struct ProcessingView: View {
    let page: CapturedPage
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
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
                    onDone()
                } onCancel: {
                    onDone()
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
            Text("Reading the page…")
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
                Text(errorMessage ?? "No text found.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxHeight: 220)

            if needsApiKey {
                Button("Open Settings") { showSettings = true }
                    .buttonStyle(.borderedProminent)
                Button("Back") { onDone() }
                    .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await runPipeline() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                Button("Back") { onDone() }
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
            errorMessage = "Couldn't load captured photo from disk."
            phase = .failure
            return
        }
        let pipeline = OCRPipeline(provider: settings.makeProvider())
        do {
            let result = try await pipeline.process(image: image)
            if result.isEmpty {
                errorMessage = "No text found. Try re-shooting."
                phase = .failure
            } else {
                candidates = result
                phase = .success
            }
        } catch OCRPipelineError.apiKeyMissing {
            needsApiKey = true
            errorMessage = "Add your Gemini API key in Settings to recognize text."
            phase = .failure
        } catch OCRPipelineError.noImageData {
            errorMessage = "Couldn't read the image."
            phase = .failure
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            phase = .failure
        }
    }

    private func save(_ picked: [SentenceCandidate]) {
        var inserted: [Sentence] = []
        for candidate in picked {
            let sentence = Sentence(
                text: candidate.text,
                reading: candidate.reading.isEmpty ? nil : candidate.reading,
                translationTr: candidate.translationTr.isEmpty ? nil : candidate.translationTr,
                capturedPage: page
            )
            modelContext.insert(sentence)
            inserted.append(sentence)
        }
        try? modelContext.save()
        Task { await SentenceAutoLinker.autoLink(sentences: inserted, in: modelContext) }
    }
}
