import Foundation

final class WalkHistoryRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let historyKey = "muter.walkHistory"

    init(store: PersistenceStoring) {
        self.store = store
    }

    func save(_ session: WalkSession) throws {
        var history = try loadAll()
        if let index = history.firstIndex(where: { $0.id == session.id }) {
            history[index] = session
        } else {
            history.append(session)
        }
        try store.save(history, forKey: historyKey)
    }

    func loadAll() throws -> [WalkSession] {
        try store.load([WalkSession].self, forKey: historyKey) ?? []
    }
}
