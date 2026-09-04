import os

struct AppLogger: Sendable {
    private let logger: Logger
    private let category: String

    init(category: String) {
        self.category = category
        logger = Logger(subsystem: "nl.astrontech.looopr", category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        CrashReporter.breadcrumb(category: category, message: message, level: .warning)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        CrashReporter.breadcrumb(category: category, message: message, level: .error)
    }
}
