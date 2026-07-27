import XCTest

@testable import Vertano

final class LocalAgreementTests: XCTestCase {
    func testFirstHypothesisConfirmsNothing() {
        var la = LocalAgreement()
        // Nothing can be confirmed until two hypotheses agree.
        XCTAssertEqual(la.insert(["hello", "world"]), [])
        XCTAssertEqual(la.confirmed, [])
        XCTAssertEqual(la.tentative, ["hello", "world"])
    }

    func testSecondAgreeingHypothesisConfirmsCommonPrefix() {
        var la = LocalAgreement()
        _ = la.insert(["hello", "world"])
        let newly = la.insert(["hello", "world", "how"])
        XCTAssertEqual(newly, ["hello", "world"])
        XCTAssertEqual(la.confirmed, ["hello", "world"])
        XCTAssertEqual(la.tentative, ["how"])
    }

    func testDivergentTailIsNotConfirmed() {
        var la = LocalAgreement()
        _ = la.insert(["the", "quick", "brown"])
        // Tail disagrees ("brown" vs "brownish"); only "the quick" agrees.
        let newly = la.insert(["the", "quick", "brownish"])
        XCTAssertEqual(newly, ["the", "quick"])
        XCTAssertEqual(la.tentative, ["brownish"])
    }

    func testGrowthReturnsOnlyTheDelta() {
        var la = LocalAgreement()
        _ = la.insert(["a", "b"])
        _ = la.insert(["a", "b", "c"])  // confirms a b
        let newly = la.insert(["a", "b", "c", "d"])  // c now agreed twice
        XCTAssertEqual(newly, ["c"])
        XCTAssertEqual(la.confirmed, ["a", "b", "c"])
    }

    func testConfirmedWordsAreNeverRevoked() {
        var la = LocalAgreement()
        _ = la.insert(["a", "b"])
        _ = la.insert(["a", "b"])  // confirm a b
        XCTAssertEqual(la.confirmed, ["a", "b"])
        // A later hypothesis that disagrees before the confirmed region must
        // not un-confirm anything.
        let newly = la.insert(["a", "x"])
        XCTAssertEqual(newly, [])
        XCTAssertEqual(la.confirmed, ["a", "b"])
    }

    func testFullText() {
        var la = LocalAgreement()
        _ = la.insert(["hello", "there"])
        _ = la.insert(["hello", "there", "friend"])
        XCTAssertEqual(la.confirmedText, "hello there")
    }
}
