import Foundation

// Replace with real Stripe SDK call in production.
final class StripePaymentGateway: PaymentGatewayProtocol, @unchecked Sendable {

    func collectToken() async throws -> String {
        // Simulate async SDK round-trip
        try await Task.sleep(nanoseconds: 500_000_000)
        return "stripe_tok_simulated_\(UUID().uuidString)"
    }
}
