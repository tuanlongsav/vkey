//
//  EmbeddedPhraseCompletions.swift
//  vkey
//
//  Cụm 2 từ tiếng Việt phổ biến → từ tiếp theo (layer 4 cho PredictionEngine).
//  Curate từ undertheseanlp/dictionary + văn phong hàng ngày / văn phòng.
//

import Foundation

enum EmbeddedPhraseCompletions {
  /// `"prev2 prev1" lowercase → [(next word, weight)]`
  static let completions: [String: [(next: String, weight: Int)]] = [
    "kính gửi": [("anh", 9), ("chị", 8), ("quý", 7), ("ông", 6), ("bà", 6)],
    "trân trọng": [("cảm", 8), ("kính", 7)],
    "cảm ơn": [("bạn", 8), ("anh", 7), ("chị", 7), ("rất", 6), ("nhiều", 5)],
    "xin chào": [("anh", 7), ("chị", 7), ("bạn", 6), ("mọi", 5)],
    "công ty": [("chúng", 6), ("cổ", 5), ("tôi", 4), ("đã", 3)],
    "thành phố": [("hồ", 7), ("hà", 6), ("đà", 5)],
    "hồ chí": [("minh", 10)],
    "hà nội": [("và", 3), ("ngày", 3)],
    "việt nam": [("và", 4), ("đã", 3), ("là", 3)],
    "theo như": [("quy", 6), ("định", 5)],
    "trong đó": [("có", 5), ("là", 4)],
    "ngoài ra": [("còn", 7), ("tôi", 4)],
    "bên cạnh": [("đó", 6), ("việc", 4)],
    "một số": [("vấn", 6), ("trường", 5), ("điểm", 4)],
    "một trong": [("những", 7), ("các", 5)],
    "theo dõi": [("và", 4), ("tiến", 4)],
    "phụ trách": [("công", 5), ("dự", 4)],
    "dự án": [("này", 5), ("đã", 4), ("của", 4)],
    "báo cáo": [("kết", 6), ("tình", 5), ("về", 4)],
    "kết quả": [("đạt", 5), ("của", 4), ("là", 3)],
    "thông tin": [("chi", 6), ("về", 5), ("liên", 4)],
    "liên hệ": [("với", 7), ("qua", 4)],
    "vui lòng": [("kiểm", 7), ("xem", 6), ("phản", 5), ("cho", 4)],
    "xin phép": [("được", 6), ("báo", 4)],
    "rất mong": [("nhận", 6), ("được", 5)],
    "như vậy": [("là", 5), ("thì", 4)],
    "do đó": [("tôi", 5), ("chúng", 4), ("cần", 4)],
    "tuy nhiên": [("tôi", 5), ("vẫn", 4), ("cần", 4)],
    "mặc dù": [("vậy", 4), ("nhưng", 3)],
    "cũng như": [("các", 5), ("những", 4)],
    "đối với": [("tôi", 4), ("khách", 4)],
    "phương pháp": [("này", 4), ("được", 3)],
    "quy trình": [("làm", 5), ("này", 4)],
    "cần thiết": [("phải", 5), ("để", 4)],
    "có thể": [("xem", 5), ("sử", 4), ("giúp", 4)],
    "không thể": [("thiếu", 4), ("bỏ", 3)],
    "đang trong": [("quá", 5), ("giai", 4)],
    "buổi sáng": [("nay", 4), ("hôm", 3)],
    "buổi chiều": [("nay", 4), ("hôm", 3)],
    "hôm nay": [("tôi", 5), ("chúng", 4), ("anh", 3)],
    "ngày mai": [("tôi", 5), ("chúng", 4), ("sẽ", 4)],
    "tuần này": [("tôi", 5), ("chúng", 4)],
    "tháng này": [("chúng", 4), ("tôi", 3)],
    "năm nay": [("chúng", 4), ("tôi", 3)],
    "ứng dụng": [("này", 5), ("của", 4), ("đã", 3)],
    "phần mềm": [("này", 4), ("đã", 3)],
    "máy tính": [("cá", 4), ("bàn", 3)],
    "điện thoại": [("di", 4), ("của", 3)],
    "dữ liệu": [("cá", 5), ("được", 4), ("này", 3)],
    "tài khoản": [("của", 5), ("này", 4)],
    "mật khẩu": [("mới", 4), ("của", 3)],
    "cảm thấy": [("rất", 5), ("như", 4)],
    "rất nhiều": [("người", 4), ("việc", 3)],
    "càng ngày": [("càng", 6)],
    "ngày càng": [("phát", 5), ("tốt", 4)],
  ]
}
