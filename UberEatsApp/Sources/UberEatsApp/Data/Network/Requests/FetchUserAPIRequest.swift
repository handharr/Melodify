import Foundation

struct FetchUserAPIRequest {
    let userID: Int
    var url: URL? { URL(string: "https://api.ubereats-mock.com/v1/users/\(userID)") }
}
