import Foundation

actor CacheManager<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let expiresAt: Date
    }

    private var storage: [Key: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key], entry.expiresAt > Date() else {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        storage[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }

    func clear() {
        storage.removeAll()
    }
}
