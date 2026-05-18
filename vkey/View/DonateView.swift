import SwiftUI

struct DonateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Text("Ủng hộ tác giả")
        .font(.title2)
        .fontWeight(.bold)
        .padding(.top, 24)

      Text("Cảm ơn bạn đã sử dụng vkey. Nếu bạn thấy phần mềm hữu ích, hãy ủng hộ tác giả một ly cà phê nhé!")
        .multilineTextAlignment(.center)
        .font(.body)
        .padding(.horizontal, 24)
        
      Image("donate-qr")
        .resizable()
        .scaledToFit()
        .frame(width: 300, height: 300)
        .padding(.bottom, 16)
        
      Button("Đóng") {
        NSApp.windows.filter { $0.title == "Ủng hộ tác giả" }.forEach { $0.close() }
      }
      .keyboardShortcut(.defaultAction)
      .padding(.bottom, 24)
    }
    .frame(width: 400, height: 520)
  }
}

struct DonateView_Previews: PreviewProvider {
  static var previews: some View {
    DonateView()
  }
}
