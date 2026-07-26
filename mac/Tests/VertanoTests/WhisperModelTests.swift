import XCTest

@testable import Vertano

final class WhisperModelTests: XCTestCase {
    private var names: Set<String> { Set(WhisperModel.all.map(\.filename)) }

    func testCatalogCoversEverySizeInTheLadder() {
        for family in ["tiny", "base", "small", "medium"] {
            XCTAssertTrue(names.contains("ggml-\(family).bin"), "missing \(family)")
        }
        XCTAssertTrue(names.contains("ggml-large-v1.bin"))
        XCTAssertTrue(names.contains("ggml-large-v2.bin"))
        XCTAssertTrue(names.contains("ggml-large-v3.bin"))
        XCTAssertTrue(names.contains("ggml-large-v3-turbo.bin"))
    }

    func testCatalogHasEnglishOnlyVariants() {
        XCTAssertTrue(names.contains("ggml-tiny.en.bin"))
        XCTAssertTrue(names.contains("ggml-small.en.bin"))
        XCTAssertTrue(names.contains("ggml-medium.en.bin"))
    }

    func testCatalogHasQuantizedVariants() {
        XCTAssertTrue(names.contains("ggml-tiny-q5_1.bin"))
        XCTAssertTrue(names.contains("ggml-medium-q5_0.bin"))
        XCTAssertTrue(names.contains("ggml-large-v3-turbo-q5_0.bin"))
    }

    func testCatalogIsAsLargeAsWeCan() {
        XCTAssertGreaterThanOrEqual(WhisperModel.all.count, 20)
    }

    func testAllFilenamesAreDistinct() {
        XCTAssertEqual(names.count, WhisperModel.all.count)
    }

    func testDownloadURLPointsAtWhisperCppRepo() {
        for model in WhisperModel.all {
            let url = model.downloadURL.absoluteString
            XCTAssertTrue(url.hasPrefix(
                "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"))
            XCTAssertTrue(url.hasSuffix(model.filename))
        }
    }

    func testMinimumValidSizeIsPositiveAndBelowApproxSize() {
        for model in WhisperModel.all {
            XCTAssertGreaterThan(model.minimumValidSize, 0, "\(model.filename)")
            XCTAssertLessThan(model.minimumValidSize, model.approximateBytes, "\(model.filename)")
        }
    }

    func testQuantizedVariantIsSmallerThanItsBaseModel() {
        let small = WhisperModel.named("ggml-small.bin")!
        let smallQ = WhisperModel.named("ggml-small-q5_1.bin")!
        XCTAssertLessThan(smallQ.approximateBytes, small.approximateBytes)
    }

    func testRecommendedTierModelsExistInCatalog() {
        for tier in ModelTier.allCases {
            XCTAssertTrue(names.contains(tier.filename), "tier \(tier) not in catalog")
        }
    }

    func testLookupByFilename() {
        XCTAssertEqual(WhisperModel.named("ggml-base.bin")?.filename, "ggml-base.bin")
        XCTAssertNil(WhisperModel.named("ggml-nonexistent.bin"))
    }
}
