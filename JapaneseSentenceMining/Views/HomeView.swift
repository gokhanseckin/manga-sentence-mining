import PhotosUI
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(LocalizationStore.self) private var loc
    @Query(filter: #Predicate<WordCard> { !$0.isKnown }, sort: \WordCard.nextReviewAt)
    private var activeCards: [WordCard]
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var showReview = false
    @State private var capturedPage: CapturedPage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: PreviewImage?
    @State private var isPreparingGallery = false
    @State private var savedToastCount: Int = 0
    @State private var showSavedToast = false

    private struct PreviewImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var dueCount: Int {
        let now = Date.now
        return activeCards.prefix { $0.nextReviewAt <= now }.count
    }

    private var captureLabel: some View {
        Label(loc.t("home.capture.button"), systemImage: "camera.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(loc.t("app.name"))
                    .font(.largeTitle.bold())

                Text(loc.t("app.tagline"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                if dueCount > 0 {
                    Button {
                        showReview = true
                    } label: {
                        Label(loc.t("home.review.due", String(dueCount)), systemImage: "rectangle.stack.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                } else if !activeCards.isEmpty {
                    Text(loc.t("home.review.allCaughtUp"))
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
                    Label(loc.t("home.gallery.button"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                NavigationLink {
                    SavedSentencesView()
                } label: {
                    Label(loc.t("home.savedSentences"), systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                NavigationLink {
                    ClozedWordsListView()
                } label: {
                    Label(loc.t("home.clozedWords", String(activeCards.count)), systemImage: "character.book.closed")
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
            .fullScreenCover(item: $previewImage) { wrapper in
                CapturePreviewView(
                    image: wrapper.image,
                    onMine: {
                        previewImage = nil
                        ingest(wrapper.image, alsoSaveToCameraRoll: settings.saveToCameraRoll)
                    },
                    onRetake: {
                        previewImage = nil
                        showCamera = true
                    }
                )
                .ignoresSafeArea()
            }
            .navigationDestination(item: $capturedPage) { page in
                ProcessingView(page: page) { savedCount in
                    capturedPage = nil
                    if savedCount > 0 {
                        savedToastCount = savedCount
                        showSavedToast = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { showSavedToast = false }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(loc.t("feedback.sentencesSaved", String(savedToastCount)))
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSavedToast)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                isPreparingGallery = true
                Task { await handleGalleryPick(item) }
            }
            .fullScreenCover(isPresented: $isPreparingGallery) {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text(loc.t("processing.readingPage"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        showCamera = false
        previewImage = PreviewImage(image: image)
    }

    private func handleGalleryPick(_ item: PhotosPickerItem) async {
        defer {
            pickerItem = nil
            isPreparingGallery = false
        }
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
