import Foundation

enum NetworkError: Error, Equatable {
    case noConnection
    case timeout
    case invalidResponse(statusCode: Int)
    case decodingFailed(String)
    case invalidURL

    var userFacingMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network."
        case .timeout:
            return "The request timed out. Please try again."
        case .invalidResponse(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingFailed:
            return "Could not process the response."
        case .invalidURL:
            return "Invalid request."
        }
    }
}
