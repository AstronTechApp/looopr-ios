import Foundation

final class ServiceContainer: @unchecked Sendable {
    static let shared = ServiceContainer()

    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private var singletons: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        factories[ObjectIdentifier(type)] = factory
    }

    func registerSingleton<T>(_ type: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        singletons[ObjectIdentifier(type)] = instance
    }

    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        if let singleton = singletons[ObjectIdentifier(type)] as? T {
            return singleton
        }
        guard let factory = factories[ObjectIdentifier(type)] else {
            fatalError("No registration for \(type). Register in ServiceContainer+Registration.swift")
        }
        return factory() as! T
    }
}
