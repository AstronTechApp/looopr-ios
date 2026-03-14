import Foundation

@propertyWrapper
struct Injected<T> {
    let wrappedValue: T

    init(_ type: T.Type = T.self) {
        wrappedValue = ServiceContainer.shared.resolve(type)
    }
}
