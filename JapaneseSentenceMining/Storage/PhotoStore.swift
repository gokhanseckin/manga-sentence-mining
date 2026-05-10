import Foundation
import Photos
import UIKit

enum PhotoStoreError: Error {
    case encodingFailed
    case writeFailed(Error)
    case missingDocumentsDirectory
}

struct PhotoStore {
    static let photosSubdir = "captures"

    static func documentsURL() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PhotoStoreError.missingDocumentsDirectory
        }
        return url
    }

    static func capturesDirectory() throws -> URL {
        let dir = try documentsURL().appending(path: photosSubdir, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a JPEG to the documents directory and returns the path relative to documents/.
    static func write(_ image: UIImage, quality: CGFloat = 0.9) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw PhotoStoreError.encodingFailed
        }
        let dir = try capturesDirectory()
        let filename = "\(UUID().uuidString).jpg"
        let url = dir.appending(path: filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PhotoStoreError.writeFailed(error)
        }
        return "\(photosSubdir)/\(filename)"
    }

    /// Saves the image to the user's Photos library. Requests add-only authorization
    /// on first use. Errors are logged but never thrown — camera-roll save is a
    /// best-effort side channel and should not block the OCR pipeline.
    static func saveToCameraRoll(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performAdd(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    performAdd(image)
                } else {
                    print("[PhotoStore] camera-roll permission denied: \(newStatus.rawValue)")
                }
            }
        default:
            print("[PhotoStore] camera-roll save skipped: not authorized (\(status.rawValue))")
        }
    }

    private static func performAdd(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if let error {
                print("[PhotoStore] camera-roll save failed: \(error)")
            } else if !success {
                print("[PhotoStore] camera-roll save reported failure with no error")
            }
        }
    }

    static func loadImage(relativePath: String) -> UIImage? {
        guard let docs = try? documentsURL() else { return nil }
        let url = docs.appending(path: relativePath)
        return UIImage(contentsOfFile: url.path)
    }
}
