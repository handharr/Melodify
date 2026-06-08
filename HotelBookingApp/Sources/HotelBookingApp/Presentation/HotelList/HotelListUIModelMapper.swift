import Foundation

enum HotelListUIModelMapper {
    static func toUIModel(_ model: HotelListing) -> HotelListUIModel {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        let priceText = formatter.string(from: model.price as NSDecimalNumber) ?? "$\(model.price)"

        return HotelListUIModel(
            id: model.hotelId,
            name: model.hotelId,
            location: model.location,
            priceText: priceText,
            rating: model.rating,
            thumbnailURL: model.thumbnailUrl
        )
    }
}
