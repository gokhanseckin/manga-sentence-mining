import PhotosUI
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<ClozeQuestion> { !$0.isKnown }, sort: \ClozeQuestion.nextReviewAt)
    private var activeQuestions: [ClozeQuestion]
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var showReview = false
    @State private var capturedPage: CapturedPage?
    @State private var pickerItem: PhotosPickerItem?

    private var dueCount: Int {
        let now = Date.now
        return activeQuestions.prefix { $0.nextReviewAt <= now }.count
    }

    private var captureLabel: some View {
        Label("Capture", systemImage: "camera.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }

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

                if dueCount > 0 {
                    Button {
                        showReview = true
                    } label: {
                        Label("Review (\(dueCount) due)", systemImage: "rectangle.stack.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                } else if !activeQuestions.isEmpty {
                    Text("All caught up — mine more sentences")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if dueCount > 0 {
                    Button {
                        showCamera = true
                    } label: {
                        captureLabel
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal)
                } else {
                    Button {
                        showCamera = true
                    } label: {
                        captureLabel
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                }

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label("Open from gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showReview) {
                ReviewView()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    handleCapture(image)
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .navigationDestination(item: $capturedPage) { page in
                ProcessingView(page: page) {
                    capturedPage = nil
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await handleGalleryPick(item) }
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        showCamera = false
        ingest(image, alsoSaveToCameraRoll: settings.saveToCameraRoll)
    }

    private func handleGalleryPick(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            print("PhotosPicker: couldn't load selected image")
            return
        }
        // Photo already lives in the gallery — never re-save it back.
        ingest(image, alsoSaveToCameraRoll: false)
    }

    private func ingest(_ image: UIImage, alsoSaveToCameraRoll: Bool) {
        do {
            let path = try PhotoStore.write(image)
            let page = CapturedPage(photoRelativePath: path)
            modelContext.insert(page)
            try modelContext.save()
            if alsoSaveToCameraRoll {
                PhotoStore.saveToCameraRoll(image)
            }
            capturedPage = page
        } catch {
            print("PhotoStore write failed: \(error)")
        }
    }
}
