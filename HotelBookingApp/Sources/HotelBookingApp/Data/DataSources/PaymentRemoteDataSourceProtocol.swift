// Data/DataSources/PaymentRemoteDataSourceProtocol.swift

protocol PaymentRemoteDataSourceProtocol: Sendable {
    func processPayment(_ request: ProcessPaymentAPIRequest) async throws
}
