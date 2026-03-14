import Foundation

final class UserDefaultsStore: PersistenceStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(type, from: data)
    }

    func delete(forKey key: String) throws {
        defaults.removeObject(forKey: key)
    }

    func exists(forKey key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}
