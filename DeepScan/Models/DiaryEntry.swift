import SwiftData
import UIKit

@Model
class DiaryEntry {

    // MARK: - Properties

    var date: Date
    var fishName: String
    var confidence: Double
    var location: String?
    var notes: String?

    // Filename within the app's Documents directory.
    // Storing a path rather than raw Data keeps the SwiftData store small
    // and avoids loading full images into memory on every fetch.
    var imagePath: String?

    // MARK: - Computed Properties

    var image: UIImage? {
        guard let path = imagePath,
              let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = documentsURL.appendingPathComponent(path)
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Initializer

    init(
        fishName: String,
        confidence: Double,
        imagePath: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.date = Date()
        self.fishName = fishName
        self.confidence = confidence
        self.imagePath = imagePath
        self.location = location
        self.notes = notes
    }

    // MARK: - Image File Management

    // Writes a UIImage to the Documents directory and returns the filename.
    // Call this before inserting a DiaryEntry into the store.
    static func storeImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8),
              let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = documentsURL.appendingPathComponent(filename)
        try? data.write(to: url)
        return filename
    }

    // Removes the image file from disk. Call this before deleting the entry.
    func deleteImage() {
        guard let path = imagePath,
              let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let url = documentsURL.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: url)
    }
}
