import XCTest
import Defaults
@testable import vkey

/// Shared test helpers and base test case for Vietnamese typing & spell tests.
class SpellResetTestCase: XCTestCase {
  override func setUp() {
    super.setUp()
    resetSpellDefaults()
  }
}

func resetSpellDefaults() {
  Defaults.reset(.spellCheckEnabled)
  Defaults.reset(.englishAutoRestoreEnabled)
  Defaults.reset(.restorePolicy)
  Defaults.reset(.suggestionEnabled)
  Defaults.reset(.autoApplyHighConfidenceSuggestion)
  Defaults.reset(.personalDictionaryEnabled)
  Defaults.reset(.userAllowWords)
  Defaults.reset(.userKeepWords)
  Defaults.reset(.userDenyWords)
}

func telex(_ input: String) -> String {
  let p = InputProcessor(method: .Telex)
  p.newWord()
  for c in input { p.push(char: c) }
  return p.transformed
}

func vni(_ input: String) -> String {
  let p = InputProcessor(method: .VNI)
  p.newWord()
  for c in input { p.push(char: c) }
  return p.transformed
}

func transform_text_telex(for text: String) -> String {
  var result: [String] = []
  let inputProcessor = InputProcessor(method: .Telex)

  for word in text.split(separator: " ") {
    inputProcessor.newWord()
    for c in word {
      inputProcessor.push(char: c)
    }
    result.append(inputProcessor.transformed)
  }

  return result.joined(separator: " ")
}

func transform_text_vni(for text: String) -> String {
  var result: [String] = []
  let inputProcessor = InputProcessor(method: .VNI)

  for word in text.split(separator: " ") {
    inputProcessor.newWord()
    for c in word {
      inputProcessor.push(char: c)
    }
    result.append(inputProcessor.transformed)
  }

  return result.joined(separator: " ")
}

func withTonePlacement(_ newStyle: Bool, run assertions: () throws -> Void) rethrows {
  let oldValue = Defaults[.newStyleTonePlacement]
  Defaults[.newStyleTonePlacement] = newStyle
  defer { Defaults[.newStyleTonePlacement] = oldValue }
  try assertions()
}

func withZWJF(_ enabled: Bool, run assertions: () throws -> Void) rethrows {
  let old = Defaults[.allowedZWJF]
  Defaults[.allowedZWJF] = enabled
  defer { Defaults[.allowedZWJF] = old }
  try assertions()
}

func vkeyRepoRootURL() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Helpers/
    .deletingLastPathComponent()  // vkeyTests/
    .deletingLastPathComponent()  // <repo>
}
