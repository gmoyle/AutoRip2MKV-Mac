import XCTest
@testable import Spindle

/// DVD rips are now routed after their encodes; the classifier sees every
/// title on the disc. The Goonies: two 1:53 versions of the movie plus extras.
final class DVDRoutingClassificationTests: XCTestCase {
    func testGooniesDiscClassifiesAsMovie() {
        let result = ContentTypeClassifier.classify(
            titleDurationsSeconds: [6830, 6830, 29, 12, 32, 162, 725, 415, 410])
        XCTAssertEqual(result.type, .movie)
        XCTAssertGreaterThanOrEqual(result.confidence, ContentRouter.autoRouteConfidenceThreshold)
    }
}
