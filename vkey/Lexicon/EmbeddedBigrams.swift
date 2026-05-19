//
//  EmbeddedBigrams.swift
//  vkey
//
//  Built-in danh sách common Vietnamese bigrams (prev → next word).
//  Layer 3 fallback cho `PredictionEngine`: user mới chưa có history
//  cũng có prediction sẵn (vd "tiếp" → "theo", "ví" → "dụ").
//
//  Curate thủ công ~300 cặp phổ biến từ ngôn ngữ tiếng Việt office /
//  daily. Maintainer có thể mở rộng bằng script extract từ Wikipedia VN
//  (Phase 2).
//
//  Weight 1-10 tương đối (không phải absolute count). 10 = rất phổ biến.
//

import Foundation

enum EmbeddedBigrams {
  /// `prev word lowercase → [(next, weight)]`. Match được làm theo
  /// lowercase normalized token để consistent với user bigrams.
  static let commonPairs: [String: [(next: String, weight: Int)]] = [
    // Connectives / function words
    "tiếp":   [("theo", 10), ("tục", 8)],
    "ví":     [("dụ", 10)],
    "trong":  [("đó", 7), ("khi", 6), ("vòng", 4), ("nước", 4)],
    "ngoài":  [("ra", 8), ("trời", 5)],
    "trên":   [("đó", 6), ("hết", 5), ("đường", 4)],
    "dưới":   [("đây", 7), ("đường", 4)],
    "sau":    [("đó", 8), ("khi", 6), ("này", 5)],
    "trước":  [("khi", 7), ("đó", 6), ("hết", 5)],
    "lại":    [("còn", 6), ("là", 5), ("phải", 4), ("nữa", 4)],
    "còn":    [("lại", 5), ("nữa", 4), ("phải", 3)],
    "thì":    [("thôi", 5), ("phải", 4)],
    "nếu":    [("không", 5), ("như", 4)],
    "khi":    [("đó", 5), ("nào", 4), ("chúng", 3)],
    "hoặc":   [("là", 6)],
    "với":    [("tôi", 5), ("bạn", 5), ("mọi", 4)],
    "của":    [("tôi", 5), ("bạn", 5), ("anh", 4), ("mình", 4)],
    "về":     [("vấn", 4), ("nhà", 4), ("việc", 4)],
    "và":     [("các", 4), ("nhiều", 3)],

    // Time
    "hôm":    [("nay", 10), ("qua", 7), ("trước", 5), ("sau", 4)],
    "ngày":   [("mai", 8), ("nay", 6), ("hôm", 5), ("xưa", 4)],
    "bây":    [("giờ", 10)],
    "lúc":    [("nào", 7), ("đó", 5), ("đầu", 4)],
    "buổi":   [("sáng", 7), ("chiều", 6), ("tối", 6)],
    "giờ":    [("đây", 6), ("này", 4)],
    "năm":    [("nay", 6), ("tới", 5), ("ngoái", 4)],
    "tuần":   [("này", 5), ("tới", 5), ("trước", 4), ("sau", 4)],
    "tháng":  [("này", 5), ("trước", 4), ("sau", 4), ("tới", 4)],

    // Place
    "việt":   [("nam", 10)],
    "hà":     [("nội", 9)],
    "sài":    [("gòn", 9)],
    "thành":  [("phố", 8), ("công", 6), ("viên", 4)],
    "đà":     [("nẵng", 8)],

    // Office / business
    "công":   [("ty", 7), ("việc", 6), ("văn", 4), ("an", 3)],
    "kính":   [("gửi", 8), ("thưa", 6), ("chào", 5), ("nhờ", 4)],
    "trân":   [("trọng", 10)],
    "xin":    [("chào", 7), ("phép", 5), ("cảm", 4), ("lỗi", 4)],
    "cảm":    [("ơn", 10), ("xúc", 3)],
    "thân":   [("ái", 5), ("mến", 4)],
    "báo":    [("cáo", 8), ("chí", 4)],
    "thông":  [("báo", 7), ("tin", 6), ("qua", 4)],
    "quyết":  [("định", 9), ("tâm", 4)],
    "ý":      [("kiến", 6), ("nghĩa", 5), ("thức", 4)],
    "vấn":    [("đề", 9), ("hỏi", 3)],
    "giải":   [("quyết", 6), ("pháp", 5), ("thích", 4)],
    "biện":   [("pháp", 7)],
    "phương": [("pháp", 6), ("án", 5), ("hướng", 4)],

    // Pronouns + verbs
    "tôi":    [("là", 4), ("muốn", 4), ("cũng", 4), ("đã", 3)],
    "bạn":    [("có", 5), ("là", 4), ("hãy", 3)],
    "chúng":  [("ta", 6), ("tôi", 5)],
    "mọi":    [("người", 7), ("thứ", 5), ("việc", 4)],
    "tất":    [("cả", 10)],
    "những":  [("điều", 4), ("người", 4), ("gì", 3)],
    "đã":     [("được", 4), ("có", 3)],
    "đang":   [("làm", 4), ("là", 3)],
    "sẽ":     [("không", 3), ("là", 3), ("được", 3)],
    "có":     [("thể", 6), ("nhiều", 4), ("một", 3)],
    "không":  [("có", 5), ("phải", 5), ("biết", 4), ("còn", 3)],
    "phải":   [("không", 4), ("là", 4), ("làm", 3)],
    "rất":    [("nhiều", 5), ("tốt", 4), ("quan", 4)],
    "nhiều":  [("hơn", 4), ("người", 3)],
    "quan":   [("trọng", 8), ("tâm", 4), ("hệ", 4)],

    // Adjectives
    "tốt":    [("hơn", 4), ("nhất", 4), ("đẹp", 3)],
    "đẹp":    [("đẽ", 3)],
    "khó":    [("khăn", 6), ("chịu", 3)],
    "dễ":     [("dàng", 5), ("hiểu", 4), ("chịu", 3)],
    "nhanh":  [("chóng", 5), ("nhẹn", 3)],
    "mới":    [("nhất", 4), ("ra", 3)],

    // Common phrases
    "cuộc":   [("sống", 6), ("đời", 5), ("họp", 4)],
    "đời":    [("sống", 4)],
    "sống":   [("động", 3)],
    "thế":    [("giới", 6), ("nào", 5), ("kỷ", 4)],
    "thể":    [("hiện", 4), ("loại", 3)],
    "lần":    [("này", 4), ("đầu", 4), ("thứ", 4)],
    "đầu":    [("tiên", 5), ("tuần", 3)],
    "cuối":   [("cùng", 6), ("tuần", 4), ("năm", 3)],
    "cùng":   [("nhau", 5), ("một", 3)],
    "khác":   [("nhau", 4)],
    "nhau":   [("hơn", 2)],

    // Auxiliary
    "là":     [("một", 4), ("người", 3), ("của", 3)],
    "một":    [("trong", 4), ("vài", 3), ("số", 3), ("cách", 3)],
    "này":    [("là", 4)],
    "đó":     [("là", 5), ("không", 3)],
    "nào":    [("đó", 3)],
    "gì":     [("đó", 3)],

    // Numerical / approx
    "khoảng": [("cách", 5)],
    "hơn":    [("hết", 3), ("nữa", 3)],

    // Polite endings
    "xin chào": [("anh", 3), ("chị", 3), ("mọi", 3)],
    "cảm ơn":   [("bạn", 5), ("anh", 4), ("chị", 4), ("rất", 3)],

    // Tech / common
    "máy":    [("tính", 6), ("ảo", 3)],
    "điện":   [("thoại", 7), ("tử", 4), ("lực", 3)],
    "internet": [("băng", 2)],
    "email":  [("của", 2)],
    "website": [("của", 2)],
    "phần":   [("mềm", 6), ("cứng", 4), ("lớn", 3)],
    "ứng":    [("dụng", 7)],
    "ứng dụng": [("này", 3), ("của", 3)],
    "dữ":     [("liệu", 9)],
    "thông tin": [("này", 2)],
  ]
}
