import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedPage: CapturedPage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Manga Mining")
                    .font(.largeTitle.bold())

                Text("Capture a printed manga page to mine sentences.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    showCamera = true
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)

                NavigationLink {
                    SavedSentencesView()
                } label: {
                    Label("Saved sentences", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                Spacer().frame(height: 16)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    handleCapture(image)
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .navigationDestination(item: $capturedPage) { page in
                ProcessingView(page: page, image: capturedImage) {
                    capturedPage = nil
                    capturedImage = nil
                }
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        showCamera = false
        do {
            let path = try PhotoStore.write(image)
            let page = CapturedPage(photoRelativePath: path)
            modelContext.insert(page)
            try modelContext.save()
            capturedImage = image
            capturedPage = page
        } catch {
            // Phase 0: silent failure on disk write is acceptable; reshoot path
            // is the recovery. Surface a real alert in Phase 1.
            print("PhotoStore write failed: \(error)")
        }
    }
}
