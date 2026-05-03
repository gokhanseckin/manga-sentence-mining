import SwiftData
import SwiftUI
import UIKit

struct ProcessingView: View {
    let page: CapturedPage
    let image: UIImage?
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var phase: Phase = .running
    @State private var candidates: [SentenceCandidate] = []
    @State private var errorMessage: String?

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
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(errorMessage ?? "No text found.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Back") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runPipeline() async {
        guard let image else {
            errorMessage = "Missing image."
            phase = .failure
            return
        }
        do {
            let result = try await OCRPipeline().process(image: image)
            if result.isEmpty {
                errorMessage = "No text found. Try re-shooting."
                phase = .failure
            } else {
                candidates = result
                phase = .success
            }
        } catch OCRPipelineError.noTextDetected {
            errorMessage = "No text found. Try re-shooting."
            phase = .failure
        } catch OCRPipelineError.modelUnavailable {
            errorMessage = "OCR model not bundled. Run scripts/fetch-model.sh."
            phase = .failure
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            phase = .failure
        }
    }

    private func save(_ picked: [SentenceCandidate]) {
        for candidate in picked {
            let sentence = Sentence(text: candidate.text, capturedPage: page)
            modelContext.insert(sentence)
        }
        try? modelContext.save()
    }
}
