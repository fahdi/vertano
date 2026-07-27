import Foundation

/// Where live recordings and their transcripts are saved. Centralized so the
/// save path and the "Open Recordings Folder" affordance stay in sync.
enum RecordingStore {
    static var defaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vertano", isDirectory: true)
    }
}
