import Foundation
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

    static func loadImage(relativePath: String) -> UIImage? {
        guard let docs = try? documentsURL() else { return nil }
        let url = docs.appending(path: relativePath)
        return UIImage(contentsOfFile: url.path)
    }
}
