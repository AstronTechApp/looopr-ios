import Foundation

enum FileStoreError: Error, LocalizedError {
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Unable to locate the app's Documents directory."
        }
    }
}

actor FileStore {
    private let baseDirectory: URL

    init(subdirectory: String) throws {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileStoreError.documentsDirectoryUnavailable
        }
        self.baseDirectory = docs.appendingPathComponent(subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func save(data: Data, filename: String) throws {
        let url = baseDirectory.appendingPathComponent(filename)
        try data.write(to: url)
    }

    func load(filename: String) throws -> Data? {
        let url = baseDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(filename: String) throws {
        let url = baseDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func fileURL(for filename: String) -> URL {
        baseDirectory.appendingPathComponent(filename)
    }
}
