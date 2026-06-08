import UIKit
import MapKit

// UIView subclass wrapping MKMapView — requires direct UIKit lifecycle control.
// Ownership follows the UIKit view lifecycle; MKMapView delegate is managed here.
final class OrderMapView: UIView {
    private let mapView = MKMapView()
    private var courierAnnotation = MKPointAnnotation()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMap()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateCourierLocation(_ coordinate: CLLocationCoordinate2D) {
        mapView.removeAnnotation(courierAnnotation)
        courierAnnotation.coordinate = coordinate
        courierAnnotation.title = "Courier"
        mapView.addAnnotation(courierAnnotation)

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        mapView.setRegion(region, animated: true)
    }

    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
