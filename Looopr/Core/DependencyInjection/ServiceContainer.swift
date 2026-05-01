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
        guard let instance = factory() as? T else {
            fatalError("Factory for \(type) returned incompatible type. Check registration in ServiceContainer+Registration.swift")
        }
        return instance
    }

    /// Returns nil instead of crashing when no registration exists for the type.
    func resolveOptional<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        if let singleton = singletons[ObjectIdentifier(type)] as? T {
            return singleton
        }
        return factories[ObjectIdentifier(type)].flatMap { $0() as? T }
    }
}
