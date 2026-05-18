import SwiftUI

struct ContentView: View {
  var telex = Telex()

  @State private var str = "Hello"
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(
      "Enter the text",
      text: $str
    )
    .focused($isFocused)
    .onTapGesture { isFocused = true }
    .border(.black)
    .font(.title)
    Text(transformedText)
      .font(.title)
      .padding(16)
  }

  private var transformedText: String {
    var state = TiengVietState.empty

    for char in str {
      state = telex.push(char: char, state: state).state
    }

    return state.needsRecovery ? state.originalInput : state.transformed
  }
}
