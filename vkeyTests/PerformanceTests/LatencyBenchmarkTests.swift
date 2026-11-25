import XCTest
import Defaults
@testable import vkey

final class LatencyBenchmarkTests: SpellResetTestCase {
  func testPerformance() throws {
    // This is an example of a performance test case.
    //    self.measure {
    //      for _ in 0...1000 {
    //        telex.clear()
    //        let transformed = telex.transform_text(for: "xin chaof tatas car cacs banj")
    //        assert(transformed == "xin chào tất cả các bạn")
    //      }
    //    }
  }


  // MARK: - 2.0 (C1): Latency Benchmarks
  //
  // Đo thời gian hot-path xử lý ký tự để có baseline cho engine Swift
  // hiện tại + regression gate khi thêm tính năng / port sang Rust (C2).
  //
  // Đọc kết quả trong Xcode Test Navigator — mỗi method hiển thị baseline
  // (set baseline với ⌘+U sau khi run lần đầu để track regression > 10%).
  //
  // Mục tiêu cho 2.0:
  // - parse 1 ký tự (Telex)           ≤ 0.05 ms
  // - full word "tieengs" (7 keys)    ≤ 0.30 ms
  // - 1000 ký tự liên tục             ≤ 50 ms (≈ < 0.05 ms / char)
  // - lexicon lookup (`isEnglishWord`) ≤ 0.02 ms / từ

  func test_benchmark_telex_singleChar() {
    let processor = InputProcessor(method: .Telex)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        processor.push(char: "a")
      }
    }
  }

  func test_benchmark_telex_fullWord_tieengs() {
    // "tieengs" → "tiếng" — đầy đủ flow parse + transform + tone mark.
    let processor = InputProcessor(method: .Telex)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        for c in "tieengs" {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_vni_fullWord() {
    // "tieng61s" theo VNI cho "tiếng" — so sánh với Telex.
    let processor = InputProcessor(method: .VNI)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        for c in "tieng61s" {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_telex_1000chars_continuous() {
    // Simulate gõ liên tục 1000 ký tự — không reset newWord giữa chừng
    // ngoại trừ khi gặp ký tự ngoài. Stress test cho buffer + state.
    let processor = InputProcessor(method: .Telex)
    let text = String(repeating: "tiengs ", count: 143)  // ~1001 chars
    measure {
      processor.newWord()
      for c in text {
        if c == " " {
          processor.newWord()
        } else {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_lexicon_lookup() {
    let lexicon = LexiconManager.shared
    lexicon.reload()
    let probes = [
      "hello", "world", "tieng", "viet", "good", "morning",
      "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
    ]
    measure {
      for _ in 0..<1000 {
        for word in probes {
          _ = lexicon.isInstantRestoreEnglish(word)
        }
      }
    }
  }

  func test_benchmark_parse_only() {
    // Pure parse stage — strip wrapping I/O. So sánh với Rust core sau khi port.
    measure {
      for _ in 0..<10_000 {
        var state = TiengVietState.empty
        for c in "tieengs" {
          state = state.push(c)
        }
      }
    }
  }
}
