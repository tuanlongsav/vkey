import XCTest
@testable import vkey

class BugTests: XCTestCase {
    func testBugs() {
        let output = """
        RESULT for tuysyee: \(transform_text_telex(for: "tuysyee"))
        RESULT for tuyeset: \(transform_text_telex(for: "tuyeset"))
        RESULT for tuyetj: \(transform_text_telex(for: "tuyetj"))
        RESULT for phuwowgn: \(transform_text_telex(for: "phuwowgn"))
        RESULT for veeitj: \(transform_text_telex(for: "veeitj"))
        """
        try? output.write(to: URL(fileURLWithPath: "/tmp/vkey_test_out.txt"), atomically: true, encoding: .utf8)
    }
}
