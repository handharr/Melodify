import Foundation

protocol PaymentGatewayProtocol: Sendable {
    func collectToken() async throws -> String
}
