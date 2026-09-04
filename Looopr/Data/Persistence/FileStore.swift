import Foundation

/// File-backed persistence. Each key is one JSON file under
/// Application Support/LoooprData. Replaces UserDefaults for app data:
/// UserDefaults loads wholesale into memory at launch and is a poor fit for
/// multi-megabyte payloads like walk history with recorded GPS tracks.
///
/// Transparently migrates old data: on a read miss it checks UserDefaults
/// for the same key (where the app stored data before this class existed),
/// moves the value into a file, and removes it from UserDefaults.
final class FileStore: PersistenceStoring, @unchecked Sendable {
    private let directory: URL
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private let logger = AppLogger(category: "FileStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.directory = base.appendingPathComponent("LoooprData", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(forKey key: String) -> URL {
        // Existing keys ("looopr.walkHistory") are already filesystem-safe.
        directory.appendingPathComponent(key).appendingPathExtension("json")
    }

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        lock.lock(); defer { lock.unlock() }
        try data.write(to: fileURL(forKey: key), options: .atomic)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        lock.lock(); defer { lock.unlock() }
        if let data = try? Data(contentsOf: fileURL(forKey: key)) {
            return try decoder.decode(type, from: data)
        }
        // One-time migration from UserDefaults.
        guard let legacy = defaults.data(forKey: key) else { return nil }
        let value = try decoder.decode(type, from: legacy)
        do {
            try legacy.write(to: fileURL(forKey: key), options: .atomic)
            defaults.removeObject(forKey: key)
            logger.info("Migrated '\(key)' from UserDefaults to file storage")
        } catch {
            // Keep serving from UserDefaults until the write succeeds.
            logger.error("Migration write failed for '\(key)': \(error)")
        }
        return value
    }

    func delete(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL(forKey: key))
        defaults.removeObject(forKey: key)
    }

    func exists(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return FileManager.default.fileExists(atPath: fileURL(forKey: key).path)
            || defaults.object(forKey: key) != nil
    }
}
