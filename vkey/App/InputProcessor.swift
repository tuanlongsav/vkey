//
//  InputProcessor.swift
//  vkey
//
//  Created by KhanhIceTea on 24/02/2024.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

// MARK: - Spellcheck & Lexicon Core

enum LexiconSource: String {
  case embedded
  case updatePackage
  case user
}

protocol Lexicon {
  var version: Int { get }
  var source: LexiconSource { get }
  func contains(_ word: String) -> Bool
}

struct InMemoryLexicon: Lexicon {
  let version: Int
  let source: LexiconSource
  let words: Set<String>

  func contains(_ word: String) -> Bool {
    words.contains(word.normalizedDictionaryToken)
  }
}

struct SuggestionCandidate: Equatable {
  let word: String
  let score: Double
}

enum SpellDecision: Equatable {
  case keepVietnamese
  case restoreRawEnglish(String)
  case keepRaw
  case suggest([SuggestionCandidate])
}

private struct EmbeddedLexiconData {
  static let version = 2

  // Bộ cơ sở dữ liệu 7.184 âm tiết tiếng Việt chuẩn được tích hợp từ dự án mã nguồn mở
  // của tác giả Luông Hiếu Thi (@hieuthi).
  // Tham chiếu: https://github.com/vietnameselanguage/syllable
  //             https://gist.github.com/hieuthi/1f5d80fca871f3642f61f7e3de883f3a
  // Cam kết tôn trọng quyền sở hữu trí tuệ và ghi nhận đóng góp đầy đủ của tác giả.
  static let vietnameseWords: Set<String> = {
    let raw = """
và
của
có
các
là
được
trong
cho
không
người
với
một
đã
công
để
những
khi
đến
về
này
tại
ở
cũng
tôi
ra
năm
nhiều
từ
việc
đồng
nhà
làm
đó
hiện
ông
vào
học
bị
trên
thể
theo
trường
như
ngày
anh
đầu
nước
phải
thành
định
bộ
nhân
sẽ
gia
quan
sự
nam
lại
chỉ
số
hàng
con
sinh
động
sau
điều
chính
dân
cơ
nhưng
việt
đi
quốc
thì
còn
biết
hội
hơn
thời
thông
an
trung
vụ
giá
viên
thực
lý
phát
nên
nhận
hành
nhất
chủ
hợp
rất
mình
đang
qua
xe
văn
trước
do
cao
mới
trình
cùng
mà
đại
vì
bạn
thế
thị
sản
em
đây
tế
đường
cả
đối
bệnh
hai
án
nói
thi
tiếp
chức
tư
hình
nghiệp
nội
tình
hà
nguyễn
tiền
dự
lượng
lên
tin
điểm
bình
cấp
báo
kinh
đề
tác
dụng
bảo
xã
tâm
xuất
tỉnh
cô
nay
thanh
bà
tài
kết
tuổi
cách
vẫn
thu
khác
đình
cầu
tăng
toàn
năng
phương
phòng
chúng
thấy
tra
tháng
doanh
giải
cần
khách
thương
tự
bản
thường
chị
chưa
ảnh
ngoài
tới
sở
quy
giao
lớn
diễn
tổ
ý
yêu
liên
lực
pháp
ăn
gian
tập
khu
ban
cuộc
sống
quyết
phạm
sĩ
hoá
mặt
triển
triệu
nào
phần
trẻ
hay
lần
bằng
chất
minh
độ
nếu
trưởng
rằng
giới
tạo
quả
nhiên
trọng
vị
quá
mẹ
bán
thủ
trị
địa
đưa
khoảng
họ
đạo
tục
tổng
tiêu
ty
thức
viện
tham
điện
tính
sử
mua
gần
cảm
huyện
hiệu
phẩm
cảnh
hệ
bên
luật
máy
sáng
kỳ
nguyên
cứu
vực
giáo
giờ
mỹ
hoạt
bắt
vậy
kiến
kiểm
đổi
xây
đất
vừa
sát
khó
nghệ
tỷ
trở
gây
hoàn
vấn
tuy
đơn
khai
tốt
mạnh
giảm
biệt
nhiệm
dựng
thống
lúc
bất
trang
vi
thứ
rồi
phố
nghị
tiếng
đều
đặc
chồng
cáo
hồ
mức
chí
chế
xử
tượng
mỗi
nhau
ta
gì
giúp
nữ
chuyển
thêm
đánh
loại
trí
tiến
khiến
chi
tìm
muốn
phụ
cá
thân
chuyện
đoàn
quyền
vợ
quản
đông
bố
chia
hoặc
sách
tích
phim
mang
sức
hoa
lời
dùng
ngân
chương
giám
nhập
ngành
từng
nạn
hết
diện
chuyên
tay
tịch
ngay
nơi
khoa
dịch
lập
giữ
lợi
chứng
hải
hộ
thiết
hướng
phó
tiên
phục
mọi
bao
xét
dẫn
truyền
biểu
phí
ca
biển
thư
bé
bỏ
lịch
trần
chung
xác
vật
rõ
giữa
giả
bài
sao
cái
y
du
ứng
tử
đẹp
xem
hoàng
hoà
dù
trả
sẻ
chiếc
đủ
dài
kiện
cổ
vàng
thay
đạt
thuộc
kế
gái
trợ
lê
ba
nhỏ
ký
chọn
chiến
câu
thuật
sơn
mất
hỏi
gặp
thái
chiều
biến
lấy
vệ
bàn
luôn
tên
phủ
xảy
danh
quận
đức
đúng
thích
dục
đảm
bởi
ấy
tiết
bác
hạn
hậu
đời
quân
ai
hưởng
cây
quảng
tranh
so
sang
đội
tố
cửa
vùng
kể
nguồn
trạng
vốn
nhóm
căn
phân
xuống
cuối
tất
cứ
bay
nghiệm
thí
chuẩn
cố
tàu
lao
mở
liệu
nữa
tướng
tối
uỷ
lưu
đăng
ít
nhạc
mắt
lãnh
ngọc
đoạn
xin
đốc
trực
đặt
trách
bắc
tuyển
vận
dương
riêng
ngoại
luận
mạng
cụ
sơ
đa
phía
đóng
tương
nông
yếu
ninh
tội
khăn
xuân
mục
nghĩa
cạnh
cháu
lớp
đào
hoạch
khẩu
long
phong
vũ
phú
nghĩ
môi
thiếu
thật
hiểu
nổi
chạy
trái
cán
thuốc
kỹ
hữu
cục
áp
cộng
thuận
tinh
nhật
chân
lòng
càng
dưới
nó
nhìn
đêm
quang
nhanh
nghiên
gửi
hỗ
châu
khá
phúc
phép
trai
tải
đảng
chơi
chết
gọi
đàn
môn
tuần
lễ
dung
góp
huy
tân
khả
hồi
hôm
biên
lan
độc
linh
cung
toán
giấy
cường
đáng
tai
tuyến
nằm
gồm
xúc
duy
sắc
giang
trao
lo
bí
buổi
thần
sân
đồ
thuỷ
cử
tây
khoẻ
nghe
rộng
vui
toà
hồng
dành
phối
kim
khoản
tấn
vai
chống
lệ
khí
vô
lương
dễ
đầy
sư
nặng
mai
trò
hương
nguy
hại
thảo
đảo
thiện
nuôi
ghi
quán
chịu
tưởng
phường
niên
tết
mong
lộ
cực
vài
bước
đô
nghiêm
đà
chấp
thuế
thoại
đứng
đôi
di
uống
phản
nghề
vọng
thấp
âm
tiện
lĩnh
thẩm
dầu
khám
màu
hát
đau
xa
hiểm
lâu
mô
kiếm
mặc
nghỉ
viết
phù
nhằm
xuyên
kỷ
ngờ
yên
mưa
hạ
nghi
kéo
khởi
ương
nâng
khẳng
cư
mẫu
trương
quý
mại
phá
chú
sai
ô
chăm
hùng
suất
sâu
tuấn
bức
đọc
lâm
nợ
khỏi
phạt
tín
vượt
đấu
thiên
thưởng
sông
sớm
dạy
cha
bổ
cải
tuyên
chỗ
áo
hạnh
tầng
da
tạm
đẩy
dưỡng
chữa
vòng
phiên
đá
mùa
vay
hôn
đâu
chứ
xanh
quê
hút
máu
hiệp
nhờ
thăm
trú
thuê
tránh
khán
chẳng
tiểu
ánh
quay
soát
nhiệt
ngôi
thắng
dũng
món
thừa
ung
cháy
khắc
ngồi
phê
họp
trì
tô
quen
vinh
miền
chợ
nhu
chắc
nền
giống
nga
nóng
thôn
phút
giai
ổn
bầu
ưu
thầy
nhớ
mắc
dấu
sóc
quanh
trời
mối
cà
tỉ
thậm
chờ
chỉnh
khánh
ma
thúc
lai
ngủ
siêu
thịt
chiếm
tức
đứa
may
nẵng
thơ
bày
song
nhiễm
hãy
đón
ấn
chuyến
khảo
phóng
can
bánh
suy
cân
đáp
vẻ
khoá
lựa
hưng
trải
truy
lái
sợ
trồng
thú
kịp
dòng
ích
lạc
tỏ
hàn
khối
tặng
suốt
khuyến
đổ
á
đỏ
phan
rút
tái
mấy
cũ
rau
nghèo
mời
gắn
thụ
cầm
tờ
tốc
buộc
cam
ước
dư
biện
quần
tim
phi
thất
thai
vong
bạc
lãi
tắc
the
khúc
sài
giác
ngữ
cắt
hài
bè
phiếu
niệm
sửa
dừng
la
thiệt
xếp
tận
tĩnh
sung
thử
đài
thẳng
to
dịp
thôi
trăm
chở
vĩnh
nhẹ
sữa
nguyện
nêu
trắng
sạch
tộc
cận
bóng
chục
ly
dần
phổ
vé
thác
sỹ
xong
lỗi
chóng
niềm
tri
gốc
đỡ
nhi
thoát
chặt
tù
a
sẵn
hãng
làng
loạt
gió
cười
vân
dạng
gòn
cưới
vững
lá
dây
hấp
nhắc
nộp
coi
liệt
nối
đỗ
kém
võ
luyện
lẽ
sắp
bến
rừng
nhấn
lạnh
hầu
tôn
huynh
cậu
cấu
chứa
cập
đám
xấu
kiên
gà
thiệu
lắng
lạ
lắm
sa
lửa
dao
sắt
sóng
tạp
đột
mê
chụp
kê
giảng
gắng
hoạ
cánh
ngăn
giàu
trụ
huyết
quỹ
đương
cuốn
tầm
ngại
tá
giản
đòi
xăng
cướp
lộc
thượng
kích
mật
kịch
ủng
rơi
tuý
cặp
núi
dinh
xung
liền
tồn
trấn
bào
đích
tuyệt
buồn
bồi
hạng
giết
ngắn
đợt
vườn
chắn
thải
cấm
miễn
phước
quà
trận
nắng
mái
mạch
bạch
bãi
trà
mơ
nắm
chữ
phẫu
rượu
buôn
phận
hơi
hy
hào
đem
nửa
trưng
mừng
khổ
tươi
trinh
khấu
ngã
băng
bây
đen
nổ
huế
xế
trúng
hoang
kêu
bữa
tùng
vết
dõi
bờ
chiếu
lượt
lào
thăng
chút
cơm
kháng
tấm
chậm
thoả
trộm
sàng
lũ
ơn
ngụ
nghìn
sạn
hằng
nỗi
ngô
âu
gương
chàng
trúc
vương
ngược
cơn
kẻ
bật
đinh
ngập
khóc
nỗ
hạt
đoạt
ngàn
thao
kính
ràng
hè
chào
bò
nhuận
huỳnh
mã
cảng
hoài
bùi
thọ
trạm
đừng
đâm
cát
hiếu
lừa
lược
mộ
kiểu
tệ
khắp
giam
kia
đàm
trùng
bậc
túi
mãi
màn
đẳng
xóm
giật
đuổi
khủng
kênh
tóc
đậu
đợi
lẫn
ngũ
thách
kiều
giỏi
dị
ví
dựa
đoán
kiệm
viêm
thuyết
bão
trốn
tang
gấp
binh
ngang
rối
não
khẩn
nhiêu
ngư
ấm
vỡ
lành
thận
tường
gói
xu
khiển
ngọt
ho
dàng
gạo
giọng
hẹn
sốt
già
ngon
mùi
hiến
chảy
thẻ
hiền
hề
lệnh
duyên
trại
rác
trưa
thuyền
chánh
bụng
mổ
giành
ngôn
ha
lối
chấn
gỗ
xương
sứ
quên
mắn
nấu
loạn
ga
chấm
nha
trừ
ruột
trật
dáng
mẽ
súng
mũi
uy
bảng
kèm
đặng
dám
dược
lẻ
miệng
rời
hứng
lục
in
chu
nhũng
đập
ép
chặn
hung
thở
đèn
béo
túc
cương
hàm
huyền
huỷ
khích
bền
khô
dụ
duyệt
phức
sàn
sổ
khen
chúc
thầu
non
thuý
dâu
bá
tuỳ
nai
khuôn
le
bia
dữ
hiếm
đãi
ôm
tật
làn
tiêm
trông
bốn
điển
lỗ
gỡ
kín
trứng
phán
mềm
tú
dâm
dày
thập
chăn
bối
ngừng
rẻ
thiểu
nhắn
nhảy
dứt
tổn
phấn
rào
quỳnh
góc
táo
ống
mệt
mạc
dậy
nhánh
chạm
mát
hư
nét
gan
căng
lô
kho
hẳn
thùng
toả
tiềm
bột
thang
đồn
cụm
hỏng
đam
hảo
khuyên
rửa
khoán
tràn
xinh
tung
van
hô
thù
ẩn
ghế
thổ
rà
bó
tông
chẽ
bếp
đáo
đấy
trịnh
doạ
tụ
tháo
trữ
lãng
tắm
cãi
xưa
lúa
mưu
tôm
ngoái
canh
hứa
ái
lắp
thạch
sắm
xứ
trầm
mỏi
loan
bổng
cựu
đỉnh
bắn
cai
tán
đua
thịnh
xâm
thảm
tốn
mỡ
thự
hộp
tran
ẩm
thép
tiếc
tam
yến
trào
bù
ngưỡng
tan
răng
nàng
nhãn
khiếu
hoảng
mực
giấu
chối
loài
tàng
cống
chùa
đền
cổng
chốt
hoan
lọc
hoả
giường
hầm
my
cột
bốc
chín
điệu
đắt
than
thuẫn
ro
đe
thạnh
gợi
rủi
thơm
niêm
va
mâu
vũng
củ
dạ
khống
hồn
thói
sôi
ven
lưới
trích
tháp
cản
lang
miếng
cất
lặng
đạp
điệp
đốt
pha
bạo
vỏ
mầm
khung
cắp
thờ
treo
huống
chừng
oan
vả
trọ
lãm
thoải
lệch
ấp
lưng
co
bơi
u
ân
mảnh
ghép
dàn
lợn
chai
giấc
cờ
cẩm
thua
giáp
xả
đắk
muối
khuẩn
váy
lít
huấn
chủng
trôi
say
heo
ngực
hối
mau
vẽ
hâm
ngừa
khoe
vất
bỏng
bớt
i
tuyết
bận
sót
bát
phỏng
bông
bang
tuân
lò
che
khát
chém
đậm
bại
tiệc
nhịp
mệnh
đống
mặn
săn
bích
đo
mây
móc
xứng
hong
viễn
chua
thả
lam
đẻ
cứng
sáu
mì
xoá
vắng
mãn
triều
cốt
su
giây
nhung
chó
tiệm
tròn
khâu
lậu
chuỗi
kiệt
bám
lạm
bom
bê
trân
hưu
vải
trăng
đựng
dọc
gánh
cỏ
thuỳ
nghiện
vở
đắc
ngộ
tre
nở
ngãi
cẩn
vĩ
lầm
tả
trục
dọn
vội
thiệp
đai
triệt
sốc
liêm
mượn
tắt
tu
bách
truyện
trống
bọn
cú
phượng
dưa
ngõ
tủ
dập
muộn
vời
chẩn
buýt
huệ
vu
ùn
tụng
mét
vang
tiễn
yết
gọn
sập
nại
chim
hôi
phổi
thuỵ
xô
nhàng
vẹn
vua
giận
chìm
nhựa
dường
rạng
ngọn
chinh
lở
nề
ngầm
trộn
pháo
lân
nhan
tha
nhậu
nồng
thợ
pham
trọn
lăng
thưa
khuyết
sánh
mắm
nhầm
đạn
chênh
bảy
lọt
khôi
xoay
nụ
hang
toạ
tách
vướng
múa
bi
e
lão
kì
gò
hi
giày
hẹp
kẹt
ốc
ảo
đắp
dính
nén
ác
hiển
bề
lồng
mốc
móng
mạn
ức
suối
uý
lí
cưỡng
nướng
bụi
khói
đói
dĩ
kiêm
mến
nhơn
tuệ
mù
đeo
khớp
gãy
vạn
thước
lấn
trắc
rèn
xách
điền
mạo
bơm
sen
phu
khoáng
gìn
tàn
nhạy
nhượng
nhẫn
chán
đớn
lạng
leo
xá
tráng
ném
thoái
soạn
nảy
khê
lạt
lây
thuần
hò
phật
bàng
com
dỡ
diệt
ruộng
diệu
rạp
phùng
đĩa
thô
thắc
tám
tràng
hổ
quyên
rét
đành
tảng
thánh
thuy
nhé
lấp
vỉa
mồ
xạ
lứa
vươn
mày
xi
sợi
nhở
bùng
liều
nguyệt
tứ
thạc
san
bế
chiêu
ám
giãn
dời
mỏ
đan
dã
trâu
thoáng
oanh
son
thâm
ngắm
vịnh
út
liêu
dắt
rộn
úc
xưởng
khổng
khanh
bẩn
dông
nát
ngạc
bể
khang
kem
bút
phái
ôn
bón
rãi
ngoan
luồng
lông
tạ
rẫy
luân
vấp
sạt
hắn
rủ
chửi
mộc
im
đằng
sâm
thoảng
nút
gũi
nấm
ngâm
lồ
bội
dừa
chúa
cua
măng
xơ
quế
củng
o
quyến
mũ
mảng
chả
ngào
tím
gom
ốm
đầm
khơi
băn
men
vây
địch
khoăn
sưu
hụt
lắk
bồ
dở
bì
trượt
đùa
ngạch
dốc
nhã
gạch
man
mông
bái
bỗng
soi
mười
khứ
sương
rũ
khéo
dồn
lộn
diễm
lỏng
khoảnh
ổ
cỡ
gối
manh
ngơi
cước
bún
hán
hòn
côn
màng
dâng
ơi
hận
mẻ
hở
tựu
dạo
ngột
hiếp
hỗn
lính
thắn
thắt
trùm
cay
luỹ
chanh
đạm
đồi
ranh
xao
tạng
chuột
bọc
ưa
hố
thầm
voi
cốc
thấu
mọc
rể
nhát
ngón
nhì
sụt
dịu
dang
phiền
rạch
thằng
rắn
lôi
rỡ
gắt
xông
ghen
tê
hoại
đứt
mò
bắp
nhí
mờ
chuyền
dệt
hãi
má
cắm
nồi
dối
rải
ớt
ham
chè
cúng
phụng
nôn
xót
ngợi
khoai
chuối
vành
hoành
nhặt
nhĩ
dò
đán
cám
trạch
na
lùi
chê
chôn
lề
cạn
nếp
đới
đuôi
dội
vy
đáy
hân
bưu
rồng
nho
ồn
no
kíp
mộng
khe
nhiếp
mỏng
kĩ
nã
ong
lật
lường
giáng
uyên
ạ
phun
vắc
xích
vịt
thỉnh
khải
cự
dán
quãng
đúc
hước
phế
lát
hái
lưỡng
lăn
cởi
vú
tẩy
ao
bưởi
be
vóc
quét
vã
buồng
hoãn
châm
chặng
cửu
xát
tần
gã
rịa
cồn
mi
cậy
cúc
bồn
lắc
khoan
thấm
ghé
buông
nhạt
đế
dan
vớt
xà
phở
chuộng
dẹp
vặt
chiên
chậu
gục
gay
điên
chật
lùng
rực
xôi
khiêm
lặn
ngất
giọt
chép
giặt
vượng
chăng
đôn
kẹo
khép
láng
kí
đọng
dại
đạc
quái
lụt
đắn
trễ
cong
kề
xôn
muỗi
bộc
dải
ngưng
thổi
lỡ
tỏi
cáp
phơi
họng
ào
xỉ
vứt
bấy
rắc
cọc
tui
huân
gác
cóc
hẻm
ngựa
giếng
trăn
nứt
tưới
cháo
nốt
tống
dỗ
khuất
lữ
mùng
cành
đuối
qui
sếp
lận
cẩu
khuê
văng
khôn
lau
lốc
khương
mụn
sướng
quầy
nhục
quát
diệp
chui
bấm
giàn
chen
hóc
cắn
rẽ
ê
lơ
trội
thắm
sáp
khái
dãy
lội
nhàn
dặn
đùi
đếm
me
khuya
nhị
thối
táng
chiết
lặp
đắng
kon
bùn
mòn
nương
cò
pa
mèo
lưỡi
ập
khoái
súc
ngỡ
sút
bôi
phì
trâm
đê
xí
thiêng
hét
lạp
tóm
xoài
rong
nghiêng
túng
mường
tao
gián
đè
khoác
tum
loa
thắp
dai
đoan
sọ
nghịch
léo
xào
lách
dồi
xen
đặn
mắng
khao
mác
tò
đính
chay
bỉ
xì
luộc
bóc
nhức
nhắm
rao
dạn
chèo
nhường
vo
mía
cuồng
bẫy
chau
tấu
sụp
nạp
chén
bóp
ướt
đèo
thám
thiêu
cấy
hốt
bú
viếng
gấu
tước
tẩu
thèm
ghét
dong
bơ
li
eo
xài
báu
xổ
giông
điêu
lột
kỉ
hao
thoa
tựa
nhọn
tấp
ben
ráo
lót
đệ
mẫn
rùa
bẩm
khoang
sưng
bính
kè
ngần
khan
hạch
lầu
xưng
bạt
quyển
mâm
chìa
chuồng
chiêm
xuôi
ti
choáng
tát
bướu
nghẹn
chì
đụng
tơ
bui
tia
quỵ
rộ
né
dê
thửa
bực
gầy
gai
đục
đệm
rung
thục
ủ
gậy
giòn
xăm
chốn
mồi
đun
ngặt
sườn
liễu
dép
quất
de
sành
neo
ủi
ráp
nghiệt
nành
ứ
xay
rụng
nàn
ngà
gầm
thới
chiểu
à
rước
rớt
hoạn
còi
kiềm
vạch
mịn
thìa
vác
lõi
nản
nhộn
hoán
nâu
quỳ
hường
tảo
nắp
rách
tom
nang
ướp
phanh
thản
sầm
nới
bới
khốc
tụi
vuông
chưng
bạ
nan
lọ
nhịn
đòn
siết
dẻo
nghênh
thòi
mập
khiếp
ngài
khỉ
triết
toa
tuyền
tịnh
trơn
sỏi
ngo
nô
ồ
quạt
nhăn
tho
run
ngậm
han
xẻ
vòi
thuyên
pin
hấu
cù
nọ
gạt
lún
toan
rốt
hoi
nấy
kiêng
ngạt
dưng
rệt
rỉ
tà
tụt
khiêu
chuông
tí
nhược
lui
quách
bong
bìa
mí
thính
râu
thiều
mài
xắn
nức
xướng
đắm
thon
háo
êm
bã
thuột
khốn
vỗ
sẹo
quynh
náo
nuốt
răn
sun
ròng
côi
lung
rang
nuối
vọt
ve
óc
bịt
xoáy
cúm
nhủ
cưng
tồi
thốn
khoả
cài
doãn
giò
chích
quật
rễ
tem
lánh
hanh
biếu
khía
lẩn
ạt
ngây
liêng
lụa
xoa
nhuộm
doan
rảnh
ki
hít
gừng
ngẫu
trêu
ngỏ
miếu
ngứa
lũng
chọc
nhồi
mươi
diễu
rụi
sét
mít
tòng
sầu
hông
keo
lộng
nêm
quấy
hức
khiếm
dì
chọi
chải
vách
thủng
đàng
sim
đũa
vắt
cớ
cày
thốt
phẳng
dào
trừng
nhiễu
oai
cào
tặc
mạ
úng
mậu
cuộn
miện
bén
vờ
ất
kha
kẽ
sam
xê
nể
té
bung
trãi
hé
xấp
đò
mương
đu
mìn
dạt
muôn
đốn
chảo
võng
miên
lén
ưng
vỹ
gặt
dầm
cọ
xé
phô
rã
nám
trèo
tẩm
lười
lanh
phàn
sừng
ngàng
chéo
nhọc
nghẽn
lóc
nhái
ván
cỗ
xịt
loét
luỵ
bồng
nóc
lẫy
cưa
nần
ghe
phác
cúi
phôi
lì
gốm
ẩu
thạo
đả
ni
gang
len
bênh
ầm
séc
thà
mỳ
tủi
nguội
ngoạn
rạn
phiêu
khiết
miêu
ngửa
ách
gieo
gõ
uốn
nạ
vét
dẫu
kìm
két
hủ
tràm
tý
kệ
phao
nạo
xỉu
tăm
quấn
búa
sấu
sào
mu
hen
sờ
loãng
chèn
day
nón
rập
đấm
am
cụt
xốp
ư
lướt
miệt
cừ
chạp
mận
gam
đái
vôi
tạt
chùm
lờ
tốp
tuỵ
giềng
ruồi
giỏ
bọt
ghê
ỏi
giã
khắt
hiên
giằng
gân
giỗ
áng
rán
hả
vun
nhai
xáo
thiêm
rưỡi
rầm
trù
chợt
cu
hăng
muỗng
xảo
dè
đăk
xám
ngả
rỗi
rơm
tuỷ
trói
nhốt
thuở
cau
vùi
chan
khoanh
mốt
roi
bẻ
lúng
niệu
ngán
lẩu
vung
ả
diều
ế
nạc
phả
uất
nhang
sô
go
phiến
váng
nhuyễn
lựu
quýt
thâu
gật
lốp
dằn
trĩ
on
trán
khử
phà
rót
méo
ngấm
nếm
ngóng
xíu
nem
mứt
sấy
khoát
mỉ
rổ
ấu
nhào
ngự
thề
uông
vụn
ten
đao
bọ
nhổ
gắm
gươm
ngùi
chà
trau
kẽm
lay
hinh
suýt
mải
trút
mỉm
năn
súp
xiếc
thềm
ray
chót
bầm
nhét
bừa
gót
cộ
quỷ
lu
mãnh
cối
mủ
trót
bứt
kẹp
níu
que
tiệp
sắn
sà
sanh
lích
khâm
cội
sòng
giơ
sảnh
trặc
ngơ
chập
sum
lán
cúp
mép
ngắt
chững
ghềnh
ươm
toản
đố
giục
nộ
cuống
quây
nguỵ
lon
chốc
si
lượn
thiền
lừng
hới
bừng
thung
hãm
giun
muống
tị
rò
nập
phồng
trứ
rưng
kiếp
tạc
xước
búp
quẩn
luyến
vẫy
ngừ
chư
trổ
điểu
lửng
vá
kiêu
củi
sạp
ngẫm
chuộc
gội
cấn
tuýp
bo
nặc
kép
tuông
nhàm
noi
bèo
nến
ôi
vàn
pu
se
loay
phượt
hoay
điếu
giêng
phẫn
lều
xua
quăng
nà
úp
chòi
toát
băm
sê
hất
đãng
ói
duẩn
đẫm
teo
lùm
cáu
gu
chắt
bửu
hoằng
giàng
min
nhạ
xuồng
tiếu
mướn
pho
duệ
giặc
lươn
cõi
then
ngó
tỉa
sưa
ngoặt
tòi
gạc
gào
phách
nghẹt
oà
kỵ
chớp
thêu
rát
chát
trơ
nòng
gọt
biếng
phai
hệt
hun
bịch
húc
cồng
vạ
điềm
ia
trệ
mẩn
rô
vãn
dí
ơ
ngao
trảng
ếch
nạt
gàng
tro
nhích
ru
phe
múc
sưởi
hãn
rỗng
đậy
tản
thy
dặm
xuyến
xoang
cạo
nhóc
nỉ
cược
ngổn
vòm
sảng
huyên
chằng
quyện
rãnh
bin
diên
cang
rốn
gáy
trọt
khinh
vơ
lư
kiểng
suôn
rượt
tỵ
bon
xiết
phình
mịt
chước
ngọ
sỉ
rằm
còng
tẻ
chướng
xùm
diêm
xộn
ngách
nậm
cằm
tớ
xỉn
ron
nhậm
ngời
găng
đực
quậy
mấu
tít
yếm
lợp
ngoãn
sỡ
thỏ
nhúng
nghiền
ngan
don
chài
tưng
bục
dìu
nhôm
rồ
hắt
nhỉ
nghé
hờ
hễ
dứa
tơi
trỗi
mồng
khay
dụm
kèn
bỉnh
ri
vựa
tuột
sụn
xệ
sặc
mẹo
thệ
sò
trũng
khuấy
sáo
quẹt
hổng
nung
ngói
chắp
hãnh
sùng
mách
riết
triền
ngủi
liu
xít
mượt
dột
quí
ngáo
cẳng
ngùng
hắc
mớ
khăng
lã
sởi
lim
khóm
đong
chảnh
bệ
sửu
xù
khét
hằn
rai
chôm
nấc
mè
vựng
vãi
dậu
gồng
dăm
dãi
ngút
ngu
gượng
bậy
vuốt
ổi
hạm
ngục
trệt
oán
cặn
ren
dấn
vò
nhâm
dấy
gắp
vặn
rêu
túm
gởi
reo
bai
thê
rơ
chàm
sục
đản
cõng
vữa
nách
nhằn
bời
rành
hốc
lút
vầy
cốp
thẳm
rùng
chao
thét
phen
kiệu
dơi
cuốc
lầy
nham
vợt
sán
múi
kén
bưng
thừng
hoai
vơi
trầy
vảy
ngạn
sá
lem
mênh
tuồng
giăng
gớm
giấm
ráng
dỏm
đùng
thán
cừu
tắn
nhựt
mẩu
mồm
hũ
sùi
phông
hờn
nhuần
rình
tã
ốt
đoòng
quai
sảo
von
tanh
lìa
khuynh
vụng
thoai
bộn
rê
bỉm
đẽ
thìn
mon
nhẹn
nhện
nắn
lượm
lẻo
vệt
bàu
nguyền
ngòi
dẫm
mướt
sạm
độn
giẽ
rầu
ruốc
tróc
hẫng
nhưỡng
nguôi
tẩn
chang
đốm
gập
chỉn
xịn
xoắn
nom
sạc
tày
nhờn
khoắn
bịa
vâng
ngót
đút
miến
tép
kềnh
oi
ngửi
át
by
giở
chội
nôi
chần
trá
điếc
quặng
dẻ
chơn
giầy
buốt
hụi
đỗi
nhoáng
lùn
lẫm
vạt
sảy
hạc
cộm
rợn
lênh
găm
phớt
thun
thỏi
gio
buồm
sả
cóp
ngợp
cạp
ỷ
nhớt
hòm
hăm
lõm
bỡ
hổi
rậm
láo
vỏn
hàu
thóc
bẹp
thớt
hợi
trớ
râm
xiêm
cằn
gỏi
hùm
chói
xói
sói
rôn
nheo
nghia
bấp
khế
siu
nặn
lức
đóm
căm
uyển
chông
câm
lăk
vừng
quàng
núp
đoá
héo
ắp
lốt
vớ
nhút
nhối
trẻo
thuấn
thong
ĩ
hòng
vén
nong
tột
trọc
nhác
bợ
bần
gi
trợn
hon
hởi
bùa
bẩy
vần
gộp
hời
dỗi
nhuệ
ngượng
vụt
bít
nhỡ
nháo
sộ
mích
den
lịm
lăm
rúng
nghè
ì
nín
phung
tào
luống
sững
tễ
chổi
đom
ná
dẳng
bô
ngốc
bầy
thỏm
lạch
hèn
gỉ
nhấp
lậy
vênh
khoét
giùm
mào
cút
moi
tuồn
tợn
ngẩn
mị
dũ
mão
he
thinh
trầu
nhõm
trồ
giồng
sủa
phất
chầu
rườm
cứa
niu
chừ
ngưu
seo
nhũ
nỡ
gióng
mó
vin
phồn
suyễn
miu
ảm
cưỡi
tè
choàng
bổn
đạ
huyệt
dùi
tráo
vãng
vía
ối
nhấc
tằm
lép
bim
chạnh
ốp
nẻo
bặm
bướm
nơ
ngớt
xẩm
trĩu
sệt
hỷ
gao
nhầy
tua
gạ
xui
xén
nôm
mễ
chiêng
nậu
vít
cạy
bành
trác
dượng
ngợm
ngậy
xoè
sần
thiếp
phím
nhẹt
hớn
nao
đéc
nhọ
sửng
ghẹ
lóng
đấng
nệm
giời
trướng
vẹo
tèo
xở
nghén
dặt
mĩ
nghĩnh
éo
bói
rông
hoóc
chít
hỉnh
hớt
thẹo
nhô
ải
sải
phộng
khít
pia
lẳng
lả
giãi
bủa
chiềng
hóm
chùi
đùm
thoi
hến
mửa
nghêu
choi
bươn
om
mút
đổng
đờn
lỏi
hột
nháy
lèo
khơ
ken
trụi
ùa
lồi
tuất
vồng
hoè
vút
bả
thoạt
lẻn
lác
én
óng
vế
sẫm
thía
tấc
mọng
tram
bảnh
tề
đay
đát
ngáy
sú
mao
thúng
chồn
viền
vẹt
lõng
xới
gấm
chớ
tong
dát
tì
luồn
kèo
xoan
mướp
mo
cốm
tỳ
khuân
loang
xiêu
xắt
khẽ
phèn
ngoai
thiu
trắm
xiên
vót
rè
khỉnh
chây
rụt
vàm
phết
nhảm
giẫm
phiện
xoăn
nấp
cọng
diết
quẫn
khiêng
càn
hót
ỉ
nực
tươm
gán
cựa
xèo
nhếch
nhả
phào
khờ
rít
ngác
nài
chuốt
thụt
cuông
rôm
chày
sàm
nhão
toái
um
pô
ny
mỗ
đờm
giũ
bở
lấm
chun
lùa
tậu
kháu
mầu
đần
khùng
cơi
hươu
sọc
ẵm
ruổi
huê
thò
loà
suông
pan
nhoà
đáu
bèn
nhói
răm
oải
ngẩm
móp
đẩu
tròng
chệch
chạc
sến
quáng
nải
rèm
cật
ừ
phăng
giỡn
chùng
mả
lố
bêu
vỉ
lạy
khoé
nhừ
cữu
húng
chuồn
lặt
nghiến
truỵ
lin
tiệt
tét
quới
giếm
dơ
dĩnh
phìn
nhợt
luông
un
nghê
nhún
bốt
mãng
ngông
lọi
duỗi
ngưởng
kham
hoe
dĩa
soái
goá
bệt
thảnh
ổng
sứa
ton
khò
hẻo
đằm
thót
mú
rẩy
víu
xối
toé
rứa
ngải
dìm
riêu
thơi
ngớ
ky
vạy
há
tía
phui
lài
moóc
thau
nết
đờ
lâng
xoong
tuôn
dấm
him
sủ
ran
nớt
tóp
gành
bướng
lặc
cui
bềnh
miết
lẽo
náu
gù
cáng
banh
rả
quệt
ngạo
chằm
quệ
hú
chực
hiu
re
khiên
nọc
bôn
bết
rú
bét
mẩy
loát
chĩa
nhá
liếng
sấp
rinh
hoắc
ắt
vẩy
khất
nấng
nái
nhẩm
lảng
sin
cữ
rục
rìa
nhăng
liếc
dền
núm
kẻo
xúi
mạt
cưu
khuỷu
búi
hích
bu
chíp
nháp
kỉnh
đểu
chong
chịt
vằn
sấm
nhổn
nhen
lừ
nhỉnh
chiu
xóc
rủa
nộm
phốt
ngát
héc
đanh
mia
vồ
dốt
đềm
sẩy
lụng
nẻ
ganh
chầm
nơm
mọt
ụ
riềng
nịnh
nhẽo
dôi
chừa
tùm
ngóc
mún
xỏ
vát
vẩn
thặng
hám
gài
loi
chưởng
nhại
muội
rạ
hớ
xẻo
nòi
luẩn
líu
xy
máng
tấy
nhảnh
gổ
cụi
ắng
trê
rớm
hóng
ú
trỏ
nép
lụi
cùi
rứt
pôn
đỉa
ố
đận
choạng
ngốn
đoái
diệm
mền
hợt
siêng
tánh
nhấm
đọ
rựa
ghẹo
đênh
sứt
nít
gẫy
cỗi
bịu
loanh
mánh
lỉnh
khư
rết
dế
xâu
nứa
nhẽ
diệc
đác
cợt
nhím
toại
bặt
cỏi
xúm
sính
mói
đùn
tru
đày
xuýt
thóp
veo
dúm
cặm
lỳ
giẻ
thỉ
rịch
phin
mếu
lự
thố
săm
khảm
pơ
ghẻ
hỉ
chợp
thảy
quặc
núc
vạc
thui
thoắt
ngỗng
nớp
mằn
thuyển
rọi
trìu
thẫn
gặng
khăm
gianh
guồng
biếm
nhúc
khấn
hấn
thẹn
quầng
lù
bập
ắc
loạng
thào
ngò
tiều
phom
mỵ
chum
gút
xéo
ứa
tuộc
trạc
phùn
phàng
rúp
ngoi
chẻ
nhọt
inh
hí
giễu
rạc
mịch
lết
cồ
náy
au
đượm
rầy
phàm
hửng
ngầu
nẹp
phũ
hù
quặn
nán
rộp
ợ
hững
tành
mân
xập
ù
trồi
trịa
ngùn
kìa
xiển
hên
sậm
mụ
gặm
dả
ngụt
mui
bống
dầy
chườm
sới
ngẩng
áy
đĩnh
lủi
en
giuộc
rợ
lẹ
hẹ
gáp
phiệt
ngước
chòm
pù
kình
khàn
nục
mố
trừu
mỉa
gả
cọp
ngấn
nãy
háng
tót
cộc
chẵn
beng
vịn
phuy
cuồn
táp
nhứt
miễu
lắt
khem
cạm
hùn
lằn
chùn
bẹn
xụp
mề
nua
hục
đẽo
thổn
hực
nuông
nu
sình
nhuế
xém
cheo
viêng
diêu
hoen
bẹ
ngấy
mé
xộc
rượi
hừng
xuể
thình
gồ
xẻng
cún
trám
thướt
oái
vánh
típ
sy
rươi
nướu
mơn
móm
chãi
tộ
thớ
nhạn
ngai
chấu
hì
rợp
nhót
ke
chồi
voọc
uổng
phiếm
phèo
đoài
gãi
uế
khấm
hộc
xo
mảy
gấc
ỳ
lòi
xoà
tắp
vông
trôm
nin
hê
bòn
nhẵn
chửa
đước
khui
chới
vèo
thỉu
te
sên
nhòm
đìa
dam
phích
đơ
biền
bẽ
ó
hạo
chớm
vón
rói
đuốc
hau
dó
thủi
nhằng
ạch
bụt
tửu
dà
uẩn
toác
quỵt
phờ
bọng
uể
ráy
đúp
dúi
díu
vù
khè
chóc
beo
tuốt
hùa
ngụm
thày
lụp
chình
soài
rên
bịp
boong
rìu
nhản
chóp
cầy
nhạo
khoi
giũa
tĩu
nhàu
nghiễm
nếnh
nùng
mót
chột
vắn
mỏm
bua
ém
rưới
báng
xốt
rởm
nườm
niềng
nghịt
rảo
lỵ
bìu
vừ
truân
quẩy
nượp
dẹt
sắng
rỗ
rần
vầng
lể
gờ
đuông
dấp
tuýt
them
thẫm
quẹo
thít
lổ
yểu
ló
lãn
khoải
loáng
kịt
bờm
xẩy
xẹp
khập
quằn
mần
loá
nhoi
diếp
tăn
kiển
rặng
quyệt
sám
sạ
giặm
bẵng
sủi
mống
chử
tầu
tằn
quánh
nhộng
nê
đoản
ăng
tếu
muồi
vái
trát
bấu
lơi
lẵng
hách
nhơ
liếm
toanh
nhốn
ngoa
ròi
biếc
úa
tưởi
xó
ửng
lợm
lềnh
tể
ngươi
yểm
rì
nầm
gẫm
cảo
sọt
nhám
nằng
gáo
chường
ớn
nhãng
lủng
túp
nuột
xốc
thênh
khiễng
điếm
đẵng
chuân
bun
hui
hói
chộp
chơ
po
loè
hua
gàu
nhuốm
nhoài
khuếch
quắt
phảng
luy
húp
cuội
bẫm
dật
nhặn
pao
xáng
khước
đoạ
bằm
thủa
quại
lình
huề
voan
nghinh
vó
pay
nhoè
dằng
bĩnh
trấu
nựng
dau
nè
vại
ớ
niêu
lợ
lêu
rim
ram
oằn
loăng
dãn
tởm
nanh
đơm
búng
hạp
ghém
ngáp
giãy
láy
nồm
lạn
nhem
nhài
chồm
bụ
xép
oăm
gờm
trề
máo
chờn
trằn
lũi
liềm
lải
khạc
gộc
chọt
ngọng
khua
xom
ria
ngòm
ngoảnh
ngoặc
nẹt
sìn
chuốc
toang
sua
nghía
lẩm
trịch
quắp
dượt
tau
ghề
sủng
dua
tạnh
sực
bự
tíu
còm
cạch
mun
tủa
lứt
kiềng
gùi
sề
phập
mùn
loã
guốc
phúng
hủi
hỡi
chác
pi
pà
mõm
nhè
mũm
mĩm
lẹt
bõm
tuế
ké
gien
quạnh
hác
thiếc
riu
nưa
thảng
noãn
bâng
soán
nịch
nhó
thăn
nũng
giụa
moong
khêu
kếch
dòi
nhũn
vẻn
nhữ
cuỗm
chửng
ngăm
boa
ươn
mớm
quơ
giương
xổm
lìm
lèn
điếng
phớ
gẫu
phỉ
ngổ
loé
diếm
dậm
đăm
chin
nhúm
kị
guy
dửng
trượng
thẩn
nhuỵ
giập
cói
bỉu
xơi
thoăn
phẩy
nhiếc
duật
ríu
hênh
truồng
nhum
nhom
nia
gợn
soa
giòi
tửng
khuây
kiếng
dụi
nệ
liệm
rọ
nhú
hiềm
ghim
thiển
đồm
khom
dùm
vối
lè
khứa
èo
doi
đoa
mạp
địu
cở
vạm
thó
tời
miều
lọng
khèn
rua
quạ
thược
rắm
ngụp
trườn
thím
cộp
thồ
gằn
bấn
xị
rớ
huổi
cùm
phủi
ngoằn
khà
hủa
sổng
peng
nghèn
xuề
nghét
lới
khố
xệch
rữa
nghếch
rúm
ngoạ
quềnh
mẫm
khong
ăm
phò
mấp
kiết
xình
lé
gàn
đảnh
ậm
trối
nhăm
nạng
dòm
chề
xỉa
rắp
viển
uột
mợ
bủn
thằn
phăn
oánh
lững
lém
gôn
ang
nạm
kiền
bân
rĩ
ngoe
lổng
hơ
vượn
thoang
bõ
thòng
som
giậm
réo
nịu
muốt
lia
ruồng
hĩnh
xum
tráp
toàng
mành
mòi
lúm
gí
xuyết
phới
chúi
tàm
sũng
phên
nhử
rỏi
hu
trảm
hập
nhe
meo
gọng
nhễ
truông
seng
rủng
vạng
sền
phầm
xổi
cũi
trọi
phia
loẹt
truất
suý
mởn
giốc
bứng
vuột
phay
ờ
khứu
kệch
xoã
rỉnh
nhép
khản
dổi
chạng
bẵm
xồng
phây
mom
lẽn
bẽn
vanh
pen
nhông
nhẹm
leng
kền
dề
vè
lẩy
rộc
nỏ
lởm
tụm
nõn
ngố
vẻo
rích
nhẻm
ghiền
đở
cóng
rặn
rám
oang
nhành
chứt
xú
thốc
thãi
rường
luộm
ghì
phẩn
pá
nhèm
thiểm
liễn
choán
bớp
tớp
sớ
mủi
đọt
cườm
chỏng
toi
tịt
guộc
đìu
đên
đốp
khuy
chiền
xúng
vê
vẳng
tréo
keng
hão
cheng
í
dom
thuộm
sỏ
sậy
lú
hớp
sém
sác
nhạnh
ngộp
mọ
gun
xoàn
vằng
toạc
rí
rằn
ngái
xuý
xính
tuốc
thây
qúa
đẫy
trớn
hòi
sờn
tuềnh
gột
lét
rin
mọn
tâng
mẹt
húi
buột
tray
quẳng
ngâu
duân
thom
ngỗ
nghệch
xôm
phang
ọp
đon
toáng
thoan
sái
nhởn
lúi
rọc
gạn
ẹp
dững
trụng
thều
rạo
nịt
ngoèo
mèn
dực
dõng
làu
kin
duyện
đung
ngoạc
tút
trờ
sì
cót
vợi
nhao
nhặng
chởm
bươu
xang
vược
vam
ngấp
xuê
nhố
bìm
véo
vảng
thàng
sồi
queo
khuâng
ươi
ngụa
ngoáy
ỉm
hậm
gằm
túa
sẩm
rọt
khuông
huyến
xắc
soạng
piêu
đật
đẫn
tủm
rủn
choẹ
xiêng
viềng
tằng
pó
xoe
ngắc
lởi
hom
ã
sồng
rụm
páo
nhảu
khựng
kháp
hoác
thọc
rắt
giắt
đỏng
tỉm
lói
khau
trùn
trạo
soóc
ới
kẻng
sượt
qủa
hỏn
chẹt
bện
téc
sõng
rén
nhùng
gầu
dặc
vức
phơ
nhõng
kềm
rền
nguệch
khưu
khấp
khảnh
hựu
tược
sia
đin
sượng
kháo
xẹt
trẩy
rón
quẫy
tênh
iu
rịn
phạc
pác
đuống
quết
phấp
pê
lớ
hâu
bòng
thin
sui
quắm
phiu
tiêng
róc
rận
muông
muồng
gui
gong
đúm
bẳn
xốn
loe
bẽo
vấy
truật
sõi
nẩy
xút
toe
tẹo
sật
rây
nui
lấu
dạc
sếu
phắt
lèng
khuỵu
cắc
ruộm
kheo
hóp
gièm
bốp
bĩ
xín
rưởi
phạ
nhổm
lống
gú
gá
vưởng
rúc
quặt
đủi
chấy
chạn
són
giát
dềnh
trét
roe
panh
lến
lằng
dộng
đít
sển
lọn
khuyển
đủng
cợn
choai
bươm
nhớp
gỏng
giựt
càu
tuẫn
tẹt
ré
nhíp
chụm
vờn
sụa
moan
choé
chỏ
cham
chá
nhùn
lất
dèm
vích
thút
rum
nhời
khoắng
heng
xeo
xè
rá
phử
phiêng
ních
nghịu
lum
lữa
gụ
chểnh
chái
búc
rệu
rái
quèn
ngấu
gon
đừ
đĩ
chộn
tồng
núng
nót
lua
khạo
giót
đòng
đẹt
trĩnh
phễu
nầy
khểnh
giê
cụng
xầm
lơn
thuồng
thoá
síp
phau
pắc
nhẩn
nghỉm
hẩm
bợm
vồn
sín
ry
phơn
pe
ngạnh
nạnh
lườm
lảm
xuyền
trui
quýnh
bấc
nâm
chuôi
bụp
rờn
què
nhắt
mèm
láu
choang
phổng
nhụt
nện
lẹm
khênh
trẽn
sướt
lảo
hoanh
bịn
bậu
vùn
trư
quít
ngoắt
ỉn
chành
thếp
nhuốc
ngoằng
ngheo
cáy
buy
lờn
toét
nhoẻn
kít
huyễn
hem
gía
cùa
ướm
quao
nhim
gô
đưng
bĩu
sẩn
hin
sây
lỏm
giầu
xuyệt
vãnh
nhón
lườn
khú
ưỡn
ruỗng
pủa
chếch
thuân
nọng
nèo
hiều
dúa
xìu
rướn
quàn
rùm
ngồn
lìn
khoáy
chúm
bơn
khốm
cỏn
choảng
chạch
váp
sãi
háu
chuý
chím
yêm
xán
thũng
tễnh
khính
gở
đễ
bía
sụ
quị
nhít
mán
huôi
huơ
hắng
ghìm
dôm
chon
bẹt
xạc
ủa
truyển
sấn
pò
nhiêm
mồn
lưa
líp
gày
đớp
đì
xịch
tuận
phụt
oẹ
oách
nặm
mỷ
mội
hển
hằm
duẫn
dũa
dô
diếc
dến
cọt
bổi
vể
tó
ình
dim
mủn
khướt
khoeo
khệ
chễ
cạ
sốp
rốc
nhẹp
gin
chòng
chỏm
xường
vập
sệ
ruy
rức
quẻ
nghen
khon
huýt
hổn
xức
quĩ
miêng
khẩm
eng
chã
bệch
xúp
roa
rẻo
ngoải
mấn
chẩm
thoong
nhíu
muôi
mõ
lịnh
ghè
vao
ui
nẫu
mưng
khuỵ
thừ
thia
ngáng
lom
dáo
dánh
phừng
nguậy
hý
huyn
dể
chổm
thõng
lũa
khoen
khều
giạ
dẹo
sởn
rem
huồi
gông
cũn
vởn
trợt
thết
ne
nau
nấn
hẵng
gừa
giăm
chếnh
rương
nhon
lếch
ghẽ
đễnh
bớ
bạng
thiềng
tệp
sộp
sẻn
phướng
phôn
păng
luyên
lịa
cỡm
bâu
tạch
sít
lởn
giảo
dơn
ché
xố
xắp
tiển
thếch
rờ
pang
nhương
nguýt
diềm
súa
ngợ
ngằn
mén
lử
loong
khẩy
chèm
xởi
liếp
dởm
bum
xạo
vốc
tron
triện
rề
lảnh
khiu
hống
try
liến
ị
hum
xiềng
rười
lúp
hõm
dạm
tiệu
thững
tém
nốc
khảng
cùn
phẩu
giáy
đụn
đét
chò
xược
vẩu
rù
nhày
mòng
đoảng
dia
cụp
chổng
biều
xồm
vẹm
tứa
thùa
nĩa
gâm
é
vói
soản
rệp
phệ
ngộn
xoàng
tiễu
rặt
ngoắc
dy
chạ
sã
oa
nhắng
ngoạm
mủng
mím
mệ
hụ
dịnh
càm
bịnh
xếch
trố
tiếm
thịch
quở
pả
mớn
lồm
chĩnh
chẽm
tun
thểu
pồ
khén
híp
đúa
dác
chẹn
luốc
khù
cồm
chổ
chét
chêm
chễm
chệ
toẹt
nhéo
lổn
hia
đển
phỉnh
phắc
ngồng
lốm
xèng
xấc
sồ
niết
nhiểu
nạy
liệp
huẩn
hoáy
xửa
xẻn
tuyn
mém
láp
din
bứa
ục
trươi
tở
suồng
nọt
khàng
hoản
dụa
vư
nhụa
nhoẹt
mứa
giong
dái
chù
chõng
suê
sũ
nhiện
loằng
è
coen
bùm
vục
thuôn
thụng
liệng
hếch
gường
dỏ
chũ
bỡn
bím
tưa
trành
thoàn
sù
rày
nguẩy
choạc
boe
triễn
thượt
rùi
nhẩy
giội
duối
dóc
yều
xái
tòm
táu
hoạnh
hiêu
deng
triêm
thúi
pí
gừ
chía
xửng
váo
trạnh
tọt
thòm
rướm
ót
nhèo
néo
hoắt
ẻo
choe
biễn
vặc
truyên
tồ
rom
riếu
quơn
phạn
nghẽo
khọt
hoắm
gum
đười
đót
diến
boi
báy
xẩu
vầu
truồi
tậm
nhín
lị
khạp
đỏi
dợ
đia
chiển
xuẩn
úm
ời
nhuân
nhiệp
meng
khắn
ẹo
deo
dằm
xổng
xoạc
xiu
rống
ró
mẩm
lỏn
lếp
kím
gôm
dỏng
vỳ
thụp
sỗ
nộn
loàn
hặc
diu
bải
ại
xoảng
vống
toong
sòm
sậu
rui
ràm
pheng
noé
nhin
lếu
khoàng
ỉa
hịch
bường
thiềm
táy
sịt
pờ
nhách
nẫng
đoàng
chỉa
trập
sểnh
rếu
pì
phét
méc
hiềng
cun
chiện
ùm
thạp
quắc
pênh
nhong
nhiễn
nghễ
xía
ùng
tọc
sèo
ngươn
kía
hợm
hoải
xênh
triêu
rộm
nghệp
nẫm
loảng
dem
cửi
bụa
ực
thuyến
thum
sừ
pẩu
đíp
biêu
ảng
vỵ
vố
véc
só
rạm
pai
nớ
nắc
loai
hoẹ
đọi
cỡn
chồ
ụp
quạch
phọt
oặt
luyn
huý
đù
dồ
chặp
ầu
thướng
pán
giắc
coong
sớt
pông
nim
lôm
hoảnh
xùa
xoành
xoạch
xộ
xan
tuynh
tuôi
ròn
py
pú
phướn
phịu
pheo
noong
nhiệu
ngoã
ỉu
huỵch
huých
hó
doe
choè
bựa
xạm
vểnh
tỏng
thòn
sòn
quờ
khuổi
hùi
diểm
chạo
chằn
cảu
via
vện
triên
trẹo
trảo
tâu
ruệ
nhột
gau
đợ
dìn
chặc
xồ
thuẩn
sại
phéng
ộp
nhỏm
nguyến
lìu
bíp
thé
sạo
quạng
púng
poe
pam
lạo
kiếu
huênh
choẹt
chõ
chẩy
bép
bau
xàm
trum
thớm
múp
lỷ
khoèo
gơ
dợt
coóng
vệnh
thưng
thèn
thát
rơn
nọi
luynh
khum
hoạc
đẻn
bam
xự
voóc
tuối
tực
thườn
thoắng
rịt
phịch
phăm
oe
oẳn
nhoạng
ngòn
liềng
gioi
giâm
gảy
dúng
dồng
chượp
bôm
xềnh
truyến
trôn
trấp
teng
quăn
pín
nhủi
nhẫy
ngủn
nả
mung
khì
hây
goi
giôn
chẩu
cẫng
xam
thếnh
tềnh
sẵng
noe
hiêng
giấp
tren
tiu
rế
nhiền
duỵ
dớn
cúa
cồi
chẫm
ành
yêng
xề
uyn
tủn
trẹm
tổi
thọt
rấm
qu
pui
nhinh
mừ
lựng
khun
ghiếc
ên
đũi
cọn
chuỳ
chô
chiếng
xoẹt
tiểng
rảng
quện
ồm
nhia
nghiêu
mơi
mầy
kếp
cum
vưu
voa
tòn
soan
rều
pồn
khé
huỳ
giậu
ễnh
đạng
cờn
bẫng
xên
ừng
tễu
sún
siên
siêm
sẳn
quặp
pua
õng
măm
liện
khào
đổm
đàu
bằn
xiều
vẳn
triêng
thoã
thiến
thè
ỏn
ỡm
ọc
lun
khịt
khắng
giu
gải
doàn
điễn
dịa
chẹo
bửng
bẳng
vôn
uân
tré
thíp
soạt
rổn
rỏ
riệu
phum
oát
nuy
nì
nhồng
ngưởi
ngầy
khin
gườm
dình
dìa
đểm
choong
chản
biêng
béc
ỹ
vim
ường
thuyện
thẻn
sột
sếnh
rỉa
phóc
ồng
ỏ
nhều
nhẳng
nháng
giau
dóng
đén
bộng
xuông
xun
tuồi
tõm
tịu
thuổng
rụp
ràn
pố
phảm
niễn
ngườm
huội
ghèn
doa
dờ
chọ
bặc
ua
quảy
pong
phính
ngóp
náng
moọc
mếch
hoằn
gịn
dăng
côm
chẻo
bíu
ây
thạt
sùm
sồn
sặt
ỏm
niền
nác
mản
lụ
lộp
khuỷ
hoong
hổm
hảng
ét
éc
đũng
đuề
đú
đôm
cháng
bộp
quắn
phám
nơn
nhiếu
nhẫm
mý
lọp
lòm
loãn
lèm
kiễng
khúm
ịch
hử
hiệt
gioăng
dẫy
dáy
đân
chận
xừ
tuếch
trỉa
thàn
sựt
rúi
pốt
phoi
phềnh
noa
lẹo
léng
hướm
dừ
củm
têm
sơm
sạnh
săng
pom
ón
oắc
nhiển
khọm
kẽo
hiệm
đui
dớp
choọng
bắng
xìn
vọp
vình
viểm
rôi
rạnh
qúi
pon
khoằm
hảnh
gụi
đỏm
dẽ
chụt
chỏi
chẹp
bỗ
biễu
uỳnh
tũn
trự
trệu
tìn
têu
tẽn
tạn
sộc
sẹc
pía
nhiểm
ngứ
mum
măn
lôn
lòn
hự
gúp
gòi
dòn
đị
chựng
chầy
biêm
xoi
thồng
rẹt
quì
ơm
nủ
khoắt
kẹ
đụp
dử
điến
bỏi
béng
vọn
thởi
thẳn
tếch
sụng
sằn
rài
páp
nình
nhoét
nhoáy
nhẩu
nghin
nghiễn
nãi
muỗm
khộp
khấy
khằm
đưới
cạc
bảm
xớt
vường
trược
trảy
trẫm
tiễng
sỉa
rũa
roong
riệp
phài
pách
nhò
nhịt
lớt
lớm
lổm
liếu
khịa
giút
ẹ
dun
đõ
cón
chẽn
chảng
cặt
biềm
xeng
trính
tộp
sằng
oản
nhội
nhãi
ngộc
lỹ
kều
hỵ
điêm
dếnh
dận
chiểm
bủng
ần
ròm
poọng
phốc
ợt
nuốc
nởi
ngam
mạy
luổng
lóp
liễng
kiệp
goa
gâu
duôi
chượt
chẳn
ẳng
xếnh
vơn
vổ
tọng
thài
quẽ
pim
phon
phiểu
phến
phéc
pết
pạc
ọ
nự
nị
nhoay
nhải
mự
mên
mế
loóng
khìn
khìa
khẹt
khạng
hoát
hiết
gới
đượng
độp
dộ
đeng
dất
đạch
cớm
choa
bương
bìn
úi
tếnh
tén
suyển
soọng
phưởng
phuông
phưng
nú
nhây
nẩu
mằng
khành
gớp
dên
dẩu
củn
cõn
chuệch
choá
bợt
bẹo
bẩu
bạnh
tủng
trằm
thềnh
thẩu
thạ
rạt
qun
pỉnh
phỏm
phèng
pèng
nhậy
ngúm
lủ
liểng
khiệm
khễnh
hầy
gọ
dỵ
đư
dợn
cõ
chũm
chệnh
cấc
xư
vửa
vồm
vên
ự
trơi
tởn
thẩy
sổi
quớ
péo
pềnh
pạ
oong
nhuy
nhúa
nhự
ngớn
ngởi
nằn
moa
mìu
mín
lủn
loàng
liễm
khướu
khừa
khị
hừ
hón
giúi
duyền
duông
dứ
choắt
chậy
xướt
trúm
tría
trỉ
sơi
sỉn
sem
pun
pốc
phốp
nen
khiểu
khệnh
húa
hể
hế
gười
gẩm
dủ
đớt
chũng
chón
chéng
bưởng
biểm
xai
thấn
tảy
quài
pứa
pư
pịa
phời
pém
nưng
nhướn
nhê
ngoạt
nghỉu
nậy
mựng
mịnh
lụn
lỉu
kheng
hèm
hẩy
giẫy
cổn
chìu
buối
bếnh
báp
vắp
ún
từa
tóng
rân
phạch
nhịu
ngúng
ngảo
mem
mảo
luồi
lũm
lợt
khồng
khẹc
kên
goong
giô
gấy
dốp
đóp
coe
bót
bển
ản
xia
veng
vảo
ướng
ử
tròm
troi
trển
trèm
tràu
tiểm
thá
sịa
sênh
rửng
roam
qùa
phực
phè
ỏng
nõ
nhưn
nhợ
ngẩy
mừu
mụi
miểng
lừu
khươi
khừng
khoòng
khim
khày
khẳm
hượu
hởn
hoét
giay
gẩy
dút
dướng
đứ
xùi
xẹo
xân
truỷ
triến
tiềng
tểnh
rụa
quèo
phinh
phấm
oét
nười
nống
niêng
ní
nhừng
nhay
ngoác
nèn
mính
loỏng
khưn
ía
hỳ
hềnh
hệch
gim
gié
diểu
điếp
đệp
chốp
chốm
chom
xim
xiểng
ượng
trỗ
tèm
tắng
rốp
rổi
quạu
pớn
phộc
nường
nhúp
nhuật
nguốn
ngưới
nguầy
nân
mốn
mởi
lốn
lọm
khiện
khặng
họt
gìa
dỹ
dum
dín
dắc
chược
chời
chiệc
chềnh
bụm
biệc
xoọng
xon
ườn
ủn
tuyễn
trụa
trây
toá
thuông
thên
sềnh
sất
rịp
phuộc
phoóc
pè
pài
óp
nủa
nhôn
nhiềm
nghéo
luý
lụm
khuống
hỗng
gữa
goòng
gám
êu
dức
diển
ầng
xêm
vự
ược
trũi
thoán
thín
thìm
tèn
súi
soọc
rẳng
quặm
phậm
ò
nùa
nư
nốp
níp
niệp
nhùi
nhóp
nhợi
nhìu
ngốt
ngồ
nảo
miềng
mâng
lẳn
lậm
khường
huần
hía
háp
gậm
ềnh
duyển
dớt
doang
doai
điệm
đêu
chuổng
chẳm
bươi
ay
xỉnh
xiếu
vèn
trốc
thoản
soong
sím
pút
púa
phâng
pếu
pét
pau
pấc
nun
nóp
nính
nhụi
nhốm
ngượi
nghẹ
ngau
ngãng
ngàm
nật
mim
lưn
hị
giạt
ghéc
đún
dú
dôn
dọi
dít
diếu
coa
chưn
chịa
chão
bư
bợn
xọp
xện
vùa
trủng
troóc
trỏng
tợi
tỉu
tều
tếp
tẹc
tãng
sỳ
sịch
sè
rột
roát
rầng
quóc
quịt
quéo
piêng
phôm
phành
nột
nhứng
nhồm
nhoàm
nhền
ngong
míp
lệt
lế
khấc
hũng
háy
hản
gỉa
dười
dọ
dích
dãnh
dắm
cũa
cọi
chiếp
chem
buỗi
xờm
tướt
trun
trộc
thuỳnh
thựu
thửng
thôm
síu
sảm
rứ
piềng
phâu
nhù
nhệch
nguyển
ngữa
ngổm
nghép
nganh
mủm
luyệt
lẻm
lày
khẻm
hưởn
hín
gờn
giộp
gát
dợm
đém
dáu
cứt
choóng
chôi
chắm
chám
chậc
buôi
bèm
ậc
xủn
xiệc
xằng
xăn
vởi
vọ
vảnh
ười
trụt
trâng
tói
thọn
thờm
séng
são
ruộc
roẹt
riệt
quày
pớ
pít
phún
phư
phóp
phoong
phoanh
phếch
pản
pằn
oạp
nững
noan
nhiu
nhìa
nguây
ngỗn
nghệm
nghế
ngật
nềnh
mợi
mõi
mẹc
luệ
lỉ
khỏ
khảy
kẹm
hươn
huối
huận
hừa
hữ
hính
hện
ghếch
ệch
đưỡng
đườn
doái
dẩn
cời
chuôn
chươi
chớn
câng
cặng
bứu
bưa
xững
xáp
vủ
voòng
vâm
trới
trến
tọ
thẽ
tặn
sừn
sôn
riều
pung
phảo
pát
oem
num
noọc
nhoong
ngừm
nghẻ
luốt
lẻng
khoài
khếnh
khề
khầu
hẹo
hẩu
ẻm
đươi
dún
dỡn
doãng
điêng
đếu
dão
dách
cuộng
chừn
choay
cẳm
buội
biếp
bẻo
ạnh
yểng
xụi
xục
xờ
xĩnh
xéc
xẵng
vều
uýnh
uỵch
uôn
tuyện
truột
trức
trớt
trổng
trịt
tria
tọp
thủm
thim
théo
tháy
sý
sáy
rún
roóng
róm
rến
rấy
quyn
poọc
phỗng
phồ
phặng
pé
pầng
păn
nuýp
nò
nhõn
nhoạm
ngoẹo
nghín
nghì
mứ
mọp
mềnh
mam
lưởng
luấn
lỡm
lóm
lản
khôm
khật
khằng
hụp
hủm
hén
hẵn
gủi
gách
ẻn
đụt
dủng
dừm
dũi
duấn
doong
đễn
dèn
dảm
cươn
cuổi
coỏng
chũi
chuếnh
chều
xỏn
vọc
vạnh
trẹt
thẻo
tẽ
sổm
sâng
roòng
roàng
quớt
quộc
quào
pưn
pùa
phưỡng
peo
pành
pàng
pàn
núa
ngum
nghển
ngạ
muých
miểu
lộm
khòm
khặn
hủng
hoẵng
hiêm
hép
ghị
duyết
dữu
duế
duần
đự
dộp
đợn
doạnh
đèm
đẩm
đách
cới
choã
chiễn
chẹm
bỉa
xoàm
xớ
xáy
xản
xạch
ưởng
tụa
truyệt
trốt
trép
trể
trằng
trài
tìa
thứu
thùm
thóng
thão
sộng
soàn
rỹ
rươm
riệc
reng
rêm
rấn
quấc
quác
poan
piu
phùa
phiềng
păm
ờn
nuôn
nừng
nùi
noọng
nỏng
nờ
niện
nhụng
nhóng
nhể
nghể
ngàu
mụt
mươn
muổi
lỗng
khức
khục
khụ
khoách
khảu
hún
hứ
hạy
hày
hăn
guyên
gôi
giớ
giào
giằm
gấn
đướng
dót
dộc
dớ
diểng
diềng
diền
dều
dảo
dạnh
cươi
coóc
chủa
chíu
chếu
chể
chặm
cạng
buốc
boăn
âng
àm
xượt
xuốt
xườn
xựng
xuấn
xợt
xơm
xốm
xòm
xoèn
xoanh
xẹc
xậy
xảnh
uộng
uôm
ừa
tưu
tứng
truốt
trũ
trợi
tró
triểu
treng
trẩu
toòng
toạn
toài
thươn
thưn
thơn
thỏn
thoạn
thịu
thén
thém
thặt
tạu
tấng
sụm
sội
sịp
sị
sí
sết
sẻng
sện
rỳ
rược
rự
rỡn
roãn
rép
rẹc
rật
quố
quo
quin
pọng
piên
phươn
phọ
phiếp
phéo
phâm
pây
õn
ộ
nhộp
nhoóng
nhoằng
nhịa
nhạp
ngựu
nguồi
ngủng
nênh
nàu
nẳng
nẫn
mớp
mẳn
mậm
luýnh
lươm
loắt
lền
kíu
khụm
khủa
khừ
khủ
khoong
khỏng
khộng
khỏn
khoàn
khẳn
khắm
khài
kẹn
kến
kếm
ín
huýnh
hưỡng
huổng
huếch
hưa
họi
hợ
hèo
hánh
gung
gữ
giửa
gioan
giỡ
giạm
ẹt
ết
ển
ẹc
dước
dứng
dui
đựa
dờn
đởm
đóc
đoanh
đoà
đớ
diêng
đía
đết
đặp
dảnh
cừa
coan
chuôm
chuổi
chuẫn
chơm
chếm
bửa
àng
àn
"""
    let list = raw.components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }
    return Set(list)
  }()

  static let englishWords: Set<String> = Set([
    "of", "if", "see", "tee", "text", "expect", "choose", "business", "address", "email",
    "long", "example", "com", "view", "list", "about", "keep", "deep", "sleep", "risk",
    "desk", "disk", "boost", "cursor", "param", "career", "beer", "peer", "sax", "toto",
    "nurses", "horses", "house", "metric", "off", "class", "pass", "staff",
    "ass", "aff", "arr", "axx", "ajj",
    "they", "them", "their", "then", "there", "these", "this", "that", "those", "than",
  ])

  static let keepVietnameseWords: Set<String> = Set([
    "lisa", "maria", "para", "sara"
  ])

  static let legacyRestorePairs: [String: String] = [
    "ò": "of",
    "ì": "if",
    "sê": "see",
    "tê": "tee",
  ]
}

private struct LexiconUpdatePackage: Codable {
  let version: Int
  let vietnamese: [String]
  let english: [String]
  let keep: [String]
}

final class LexiconManager {
  static let shared = LexiconManager()

  private let queue = DispatchQueue(label: "dev.longht.vkey.lexicon", attributes: .concurrent)
  private var vnLexicon: InMemoryLexicon
  private var enLexicon: InMemoryLexicon
  private var keepLexicon: InMemoryLexicon

  private let updatePackageURL: URL

  init(updatePackageURL: URL? = nil) {
    let embeddedVN = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.vietnameseWords
    )
    let embeddedEN = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.englishWords
    )
    let embeddedKeep = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.keepVietnameseWords
    )

    self.vnLexicon = embeddedVN
    self.enLexicon = embeddedEN
    self.keepLexicon = embeddedKeep

    if let updatePackageURL {
      self.updatePackageURL = updatePackageURL
    } else {
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let dir = appSupport?.appendingPathComponent("vkey/lexicon", isDirectory: true)
      try? FileManager.default.createDirectory(
        at: dir ?? URL(fileURLWithPath: "/tmp"),
        withIntermediateDirectories: true,
        attributes: nil
      )
      self.updatePackageURL = (dir ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("lexicon-update.json")
    }

    reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  func reload(channel: DictionaryUpdateChannel) {
    reload(channel: channel, completion: nil)
  }

  func reload(channel: DictionaryUpdateChannel, completion: (() -> Void)?) {
    let performReload = { [weak self] in
      guard let self = self else { return }

      // Load base syllables from NSDataAsset (compiled in Assets.xcassets)
      var vnWords: Set<String> = []
      if let asset = NSDataAsset(name: "syllables"),
         let raw = String(data: asset.data, encoding: .utf8) {
        let list = raw.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
          .filter { !$0.isEmpty }
        vnWords = Set(list)
      } else {
        // Fallback to embedded list if asset load fails
        vnWords = EmbeddedLexiconData.vietnameseWords
      }

      let embeddedVN = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: vnWords
      )
      let embeddedEN = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: EmbeddedLexiconData.englishWords
      )
      let embeddedKeep = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: EmbeddedLexiconData.keepVietnameseWords
      )

      var selectedVN = embeddedVN
      var selectedEN = embeddedEN
      var selectedKeep = embeddedKeep

      if channel == .hybrid,
        let package = self.loadUpdatePackage(),
        package.version > EmbeddedLexiconData.version
      {
        selectedVN = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.vietnamese.map { $0.normalizedDictionaryToken })
        )
        selectedEN = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.english.map { $0.normalizedDictionaryToken }).union(EmbeddedLexiconData.englishWords)
        )
        selectedKeep = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.keep.map { $0.normalizedDictionaryToken }).union(EmbeddedLexiconData.keepVietnameseWords)
        )
      }

      self.queue.sync(flags: .barrier) {
        self.vnLexicon = selectedVN
        self.enLexicon = selectedEN
        self.keepLexicon = selectedKeep
      }
      completion?()
    }

    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      performReload()
    } else {
      DispatchQueue.global(qos: .userInitiated).async {
        performReload()
      }
    }
  }

  func setUpdatePackageData(_ data: Data) throws {
    let dir = updatePackageURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: dir,
      withIntermediateDirectories: true,
      attributes: nil
    )
    try data.write(to: updatePackageURL, options: .atomic)
    reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  private func loadUpdatePackage() -> LexiconUpdatePackage? {
    guard FileManager.default.fileExists(atPath: updatePackageURL.path) else { return nil }
    do {
      let data = try Data(contentsOf: updatePackageURL)
      return try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
    } catch {
      return nil
    }
  }

  func downloadAndUpdateLexicon(completion: ((Bool) -> Void)? = nil) {
    guard Defaults[.dictionaryUpdateChannel] == .hybrid else {
      completion?(false)
      return
    }
    guard Defaults[.dictionaryGitHubUpdateEnabled] else {
      completion?(false)
      return
    }

    let url = URL(string: "https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json")!
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
    
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        completion?(false)
        return
      }
      
      do {
        let package = try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
        let currentVersion = self.snapshotVersions().vn
        
        if package.version > currentVersion {
          try self.setUpdatePackageData(data)
          completion?(true)
        } else {
          completion?(false)
        }
      } catch {
        completion?(false)
      }
    }.resume()
  }

  func checkAndPromptForDictionaryUpdate(force: Bool = false) {
    guard Defaults[.dictionaryUpdateChannel] == .hybrid else { return }
    guard Defaults[.dictionaryGitHubUpdateEnabled] else { return }
    
    if !force {
      if let lastCheck = Defaults[.lastDictionaryCheckDate] {
        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours
        if lastCheck > oneDayAgo {
          return
        }
      }
    }
    
    Defaults[.lastDictionaryCheckDate] = Date()
    
    let url = URL(string: "https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json")!
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
    
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        return
      }
      
      do {
        let package = try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
        let currentVersion = self.snapshotVersions().vn
        
        if package.version > currentVersion {
          DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Cập nhật từ điển tiếng Việt"
            alert.informativeText = "Có phiên bản từ điển mới (phiên bản \(package.version)) có sẵn trên GitHub. Bạn có muốn cập nhật ngay không?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Cập nhật")
            alert.addButton(withTitle: "Để sau")
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
              do {
                try self.setUpdatePackageData(data)
                
                let successAlert = NSAlert()
                successAlert.messageText = "Thành công"
                successAlert.informativeText = "Đã cập nhật từ điển tiếng Việt lên phiên bản \(package.version) thành công!"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
              } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Lỗi"
                errorAlert.informativeText = "Không thể lưu tệp từ điển mới. Vui lòng thử lại sau."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
              }
            }
          }
        }
      } catch {
        // Silent error
      }
    }.resume()
  }

  func isVietnameseWord(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    if token.isEmpty { return false }

    if Defaults[.personalDictionaryEnabled] {
      let denied = Set(Defaults[.userDenyWords].map { $0.normalizedDictionaryToken })
      if denied.contains(token) {
        return false
      }

      let allowed = Set(Defaults[.userAllowWords].map { $0.normalizedDictionaryToken })
      if allowed.contains(token) {
        return true
      }
    }

    return queue.sync { vnLexicon.contains(token) }
  }

  func isEnglishWord(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    guard !token.isEmpty else { return false }
    return queue.sync { enLexicon.contains(token) }
  }

  func shouldKeepVietnamese(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    if token.isEmpty { return false }

    if Defaults[.personalDictionaryEnabled] {
      let userKeep = Set(Defaults[.userKeepWords].map { $0.normalizedDictionaryToken })
      if userKeep.contains(token) {
        return true
      }
    }
    return queue.sync { keepLexicon.contains(token) }
  }

  func shouldApplyLegacyRestore(transformed: String, rawInput: String) -> Bool {
    guard let expectedRaw = EmbeddedLexiconData.legacyRestorePairs[transformed.lowercased()] else {
      return false
    }
    return expectedRaw == rawInput.normalizedDictionaryToken
  }

  func vietnameseWordsSnapshot() -> [String] {
    queue.sync { Array(vnLexicon.words) }
  }

  func snapshotVersions() -> (vn: Int, en: Int, keep: Int) {
    queue.sync { (vnLexicon.version, enLexicon.version, keepLexicon.version) }
  }

  func snapshotSources() -> (vn: LexiconSource, en: LexiconSource, keep: LexiconSource) {
    queue.sync { (vnLexicon.source, enLexicon.source, keepLexicon.source) }
  }
}

final class SuggestionService {
  static let shared = SuggestionService()

  private let lexiconManager: LexiconManager

  init(lexiconManager: LexiconManager = .shared) {
    self.lexiconManager = lexiconManager
  }

  func suggest(word: String, locale: String = "vi_VN", limit: Int = 5) -> [SuggestionCandidate] {
    let query = word.normalizedDictionaryToken
    guard !query.isEmpty, locale.lowercased().hasPrefix("vi"), limit > 0 else { return [] }

    let queryFolded = query.vietnameseFolded
    guard !queryFolded.isEmpty else { return [] }

    let candidates = lexiconManager.vietnameseWordsSnapshot()
      .map { candidate -> SuggestionCandidate in
        let foldedCandidate = candidate.vietnameseFolded
        let distance = Self.levenshtein(queryFolded, foldedCandidate)
        let prefixBonus: Double = queryFolded.first == foldedCandidate.first ? 0.12 : 0
        let suffixBonus: Double = queryFolded.last == foldedCandidate.last ? 0.08 : 0
        let lengthPenalty = abs(queryFolded.count - foldedCandidate.count) > 2 ? 0.08 : 0
        let baseScore = 1.0 / Double(distance + 1)
        let score = max(0, min(1, baseScore + prefixBonus + suffixBonus - lengthPenalty))
        return SuggestionCandidate(word: candidate, score: score)
      }
      .filter { $0.score >= 0.24 }
      .sorted {
        if abs($0.score - $1.score) > 0.0001 {
          return $0.score > $1.score
        }
        return $0.word < $1.word
      }

    return Array(candidates.prefix(limit))
  }

  private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }

    var previous = Array(0...b.count)
    var current = Array(repeating: 0, count: b.count + 1)

    for i in 1...a.count {
      current[0] = i
      for j in 1...b.count {
        let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
        let insertion = current[j - 1] + 1
        let deletion = previous[j] + 1
        current[j] = min(substitution, insertion, deletion)
      }
      swap(&previous, &current)
    }
    return previous[b.count]
  }
}

final class SpellDecisionEngine {
  static let shared = SpellDecisionEngine()

  private let lexiconManager: LexiconManager
  private let suggestionService: SuggestionService

  private let extremelyCommonVietnameseWords: Set<String> = [
    "mẹ", "ăn", "đi", "cho", "tôi", "anh", "em", "gì", "là", "và", "có", "không", "ở", "này", 
    "của", "đã", "được", "trong", "người", "với", "một", "để", "những", "khi", "đến", "về", 
    "tại", "cũng", "ra", "năm", "nhiều", "từ", "việc", "đồng", "nhà", "làm", "đó", "hiện", 
    "ông", "vào", "học", "bị", "trên", "thể", "theo", "trường"
  ]

  init(
    lexiconManager: LexiconManager = .shared,
    suggestionService: SuggestionService = .shared
  ) {
    self.lexiconManager = lexiconManager
    self.suggestionService = suggestionService
  }

  func evaluate(rawInput: String, transformed: String, needsRecovery: Bool) -> SpellDecision {
    guard Defaults[.spellCheckEnabled] else { return .keepVietnamese }
    guard !rawInput.isEmpty, !transformed.isEmpty else { return .keepVietnamese }

    let rawToken = rawInput.normalizedDictionaryToken
    let transformedToken = transformed.normalizedDictionaryToken
    guard !rawToken.isEmpty, !transformedToken.isEmpty else { return .keepRaw }

    // Doubled Tone Mark Preservation: if raw input contains consecutive doubled tone marks, keep it raw
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    if doubledTones.contains(where: { rawToken.contains($0) }) {
      return .keepRaw
    }

    if lexiconManager.shouldApplyLegacyRestore(transformed: transformed, rawInput: rawInput),
      Defaults[.englishAutoRestoreEnabled]
    {
      return .restoreRawEnglish(rawInput)
    }

    if lexiconManager.shouldKeepVietnamese(transformed) {
      return .keepVietnamese
    }

    let isVietnameseWord = lexiconManager.isVietnameseWord(transformed)
    let rawIsEnglish = lexiconManager.isEnglishWord(rawInput)

    if Defaults[.englishAutoRestoreEnabled] {
      // 1. If transformed output is NOT a valid Vietnamese word
      if !isVietnameseWord {
        if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
          return .restoreRawEnglish(rawInput)
        }
        if needsRecovery && rawIsEnglish {
          return .restoreRawEnglish(rawInput)
        }
      } 
      // 2. If transformed output IS a valid Vietnamese word (checking policies for ambiguous words)
      else {
        if rawIsEnglish {
          let policy = Defaults[.restorePolicy]
          switch policy {
          case .englishFirst:
            return .restoreRawEnglish(rawInput)
          case .balanced:
            if extremelyCommonVietnameseWords.contains(transformedToken) {
              return .keepVietnamese
            } else {
              return .restoreRawEnglish(rawInput)
            }
          case .vietnameseFirst:
            return .keepVietnamese
          }
        }
      }
    }

    if needsRecovery {
      if isVietnameseWord {
        return .keepVietnamese
      }
      guard Defaults[.suggestionEnabled] else { return .keepRaw }
      let suggestions = suggestionService.suggest(word: transformed, locale: "vi_VN", limit: 5)
      return suggestions.isEmpty ? .keepRaw : .suggest(suggestions)
    }

    return .keepVietnamese
  }
}

private extension String {
  var normalizedDictionaryToken: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  var vietnameseFolded: String {
    let prepared = replacingOccurrences(of: "đ", with: "d")
      .replacingOccurrences(of: "Đ", with: "d")
    return prepared.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
  }

  var isASCIIAlphabeticWord: Bool {
    guard !isEmpty else { return false }
    return unicodeScalars.allSatisfy {
      let value = $0.value
      return (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
    }
  }
}

// MARK: - WordBuffer

/// WordBuffer manages the Vietnamese word state during typing.
/// It tracks the current word being typed, handles push/pop operations,
/// and manages recovery mode with a snapshot stack for multi-step rollback.
struct WordBuffer {

  struct Snapshot {
    let wordState: TiengVietState
    let keys: [Character]
    let transformed: String
    let stopProcessing: Bool
  }

  var keys: [Character] = []
  var stopProcessing = false
  var lastTransformed = ""
  var transformed = ""

  var previousWordState: TiengVietState?
  var wordState = TiengVietState.empty

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  private static let impossible2LetterPrefixes: Set<String> = [
    "bl", "cl", "fl", "gl", "pl", "sl", "vl",
    "br", "cr", "dr", "fr", "gr", "pr", "wr",
    "st", "sm", "sn", "sp", "sc", "sk", "sw",
    "tw", "dw", "sh", "ps", "pn", "ts", "kn", "kr",
    "bb", "cc", "ff", "gg", "hh", "jj", "kk", "ll",
    "mm", "nn", "pp", "qq", "rr", "ss", "tt", "vv",
    "xx", "zz"
  ]

  private static let impossible3LetterPrefixes: Set<String> = [
    "str", "thr", "phr", "chr", "sch", "scr", "spr"
  ]

  func isImpossibleCluster(_ keys: [Character], engine: TypingMethod) -> Bool {
    guard !keys.isEmpty else { return false }
    
    // Rule 1: First letter cannot be f, j, z (or w for VNI) if allowed-zwjf is disabled
    if !Defaults[.allowedZWJF], let firstChar = keys.first {
      let lowerFirst = firstChar.lowercased()
      if lowerFirst == "f" || lowerFirst == "j" || lowerFirst == "z" {
        return true
      }
      
      // VNI specific: starting letter cannot be w
      if engine is VNI, lowerFirst == "w" {
        return true
      }
    }
    
    // Rule 2: Impossible 2-letter prefixes
    if keys.count >= 2 {
      let prefix2 = String(keys.prefix(2)).lowercased()
      if Self.impossible2LetterPrefixes.contains(prefix2) {
        return true
      }
    }
    
    // Rule 3: Impossible 3-letter prefixes
    if keys.count >= 3 {
      let prefix3 = String(keys.prefix(3)).lowercased()
      if Self.impossible3LetterPrefixes.contains(prefix3) {
        return true
      }
    }
    
    return false
  }

  // MARK: - Word Lifecycle

  mutating func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
      }
      wordState = .empty
    }

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if numBackspaces == 1 && diffChars.isEmpty {
        return (0, [])
      }

      return (numBackspaces, diffChars)
    }

    // Normal pop: restore previous word on empty buffer
    if wordState.isBlank, let prev = previousWordState {
      wordState = prev
      previousWordState = nil
      keys = Array(wordState.chuKhongDau)
      transformed = wordState.transformed
      lastTransformed = transformed
      stopProcessing = false
      lastValidSnapshot = nil
      return (0, [])  // Let OS handle the backspace that brought us here
    }

    // Normal pop: remove last character
    wordState = engine.pop(state: wordState)
    keys = Array(wordState.chuKhongDau)
    
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
    } else {
      stopProcessing = wordState.needsRecovery
    }

    if stopProcessing {
      transformed = String(keys)
    } else {
      transformed = wordState.transformed
    }

    lastValidSnapshot = nil

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If it's a simple 1-char deletion, let the OS handle it
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }

    return (numBackspaces, diffChars)
  }

  // MARK: - Push (New Character)

  mutating func push(char: Character, engine: TypingMethod) {
    // Save current state before mutation
    let snapshot = Snapshot(
      wordState: wordState,
      keys: keys,
      transformed: transformed,
      stopProcessing: stopProcessing
    )

    keys.append(char)
    lastTransformed = transformed

    // If stopProcessing was set, but it was ONLY because of English word restoration on the previous step
    // (i.e. the previous state did not have a real spelling matrix failure or impossible cluster),
    // we allow re-evaluation so typing 'thee' (after 'the') can transform to 'thê' correctly.
    // However, if the new keys form a doubled tone mark (like 'ss', 'ff'), we skip re-evaluation to preserve double-letter English suffixes.
    var wasOnlyEnglishRestored = false
    let keysStr = String(keys).lowercased()
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    if stopProcessing && !snapshot.wordState.needsRecovery && !isImpossibleCluster(snapshot.keys, engine: engine) {
      if !doubledTones.contains(where: { keysStr.contains($0) }) {
        wasOnlyEnglishRestored = true
      }
    }

    if stopProcessing && !wasOnlyEnglishRestored {
      transformed.append(char)
      wordState = wordState.push(char)
      return
    }

    // Doubled Tone Mark Preservation: if raw keys contains consecutive doubled tone marks, preserve it raw if it forms an English word
    if doubledTones.contains(where: { keysStr.contains($0) }),
       LexiconManager.shared.isEnglishWord(keysStr) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    // Instantaneous English word restoration: if the raw keys form a known English word, preserve it raw
    if LexiconManager.shared.isEnglishWord(keysStr) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    // Check if newly formed keys are an impossible cluster
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      // Save snapshot for rollback if we just entered recovery/stopProcessing
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    let result = engine.push(char: char, state: wordState)
    wordState = result.state

    // Check if we need to recover original input (invalid Vietnamese syllable)
    if wordState.needsRecovery {
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)

      // If we JUST entered recovery mode, save the snapshot for rollback
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
    } else {
      transformed = wordState.transformed
      // Clear snapshot when we're in valid state — no rollback needed
      lastValidSnapshot = nil
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if transformed.count == lastTransformed.count {
        transformed.append(char)
        wordState = wordState.push(char)
      }
    }
  }
}

// MARK: - TransformationTracker

/// TransformationTracker monitors for repeated transformation failures
/// and auto-switches the sending strategy when a pattern is detected.
/// This helps apps where the default strategy doesn't work reliably.
struct TransformationTracker {

  /// Current sending strategy for the active app
  var currentStrategy: SendingStrategy = .batch
  private var consecutiveFailures = 0
  private var consecutiveHighRiskTransforms = 0

  // MARK: - Strategy Management

  mutating func resetForApp(_ bundleId: String) {
    currentStrategy = EventSimulator.getStrategy(for: bundleId)
    consecutiveFailures = 0
    consecutiveHighRiskTransforms = 0
  }

  /// Detect transformation failures based on event creation status and
  /// repeated high-risk transforms on apps that are known to be sensitive.
  mutating func detectFailure(
    telemetry: EventSendTelemetry,
    appLikelySensitive: Bool
  ) -> Bool {
    guard telemetry.attemptedTransform else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
      return false
    }

    if telemetry.createdEvents {
      consecutiveFailures = max(0, consecutiveFailures - 1)
    } else {
      consecutiveFailures += 1
    }

    let isHighRisk = appLikelySensitive
      && !telemetry.usedAsyncQueue
      && telemetry.touchedCharacters >= 3
    if isHighRisk {
      consecutiveHighRiskTransforms += 1
    } else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
    }

    return consecutiveFailures >= 2 || consecutiveHighRiskTransforms >= 3
  }

  /// Auto-switches to step-by-step mode if failures are detected.
  mutating func autoSwitchIfNeeded(activeApp: String) {
    guard Defaults[.autoSwitchStrategy] else { return }

    // Don't auto-switch if already using step-by-step
    if case .stepByStep = currentStrategy { return }

    // Switch to step-by-step for this session
    #if DEBUG
    let appName = EventSimulator.getAppName(for: activeApp)
    print("[vkey] Auto-switched from \(currentStrategy) to step-by-step mode for \(appName) due to failures")
    #endif

    currentStrategy = .stepByStep
  }
}

// MARK: - InputProcessor

class InputProcessor {
  static let FixAutocompleteApps = [
    // Chromium-based
    "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
    "org.chromium.Chromium",
    "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
    "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary",
    "com.vivaldi.Vivaldi", "com.vivaldi.Vivaldi.snapshot",
    "ru.yandex.desktop.yandex-browser", "com.naver.Whale",

    // Opera
    "com.opera.Opera", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
    "com.operasoftware.OperaAir", "com.opera.OperaNext",

    // Firefox-based
    "org.mozilla.firefox", "org.mozilla.nightly", "org.torproject.torbrowser", "org.librewolf.LibreWolf",
    "app.zen-browser.zen",

    // Safari & WebKit-based
    "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.apple.Safari.TechnologyPreview",
    "com.kagi.kagimacOS", "com.duckduckgo.mac", "com.duckduckgo.macos.browser",

    // Arc & Others
    "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
    "com.sigmaos.sigmaos", "com.sigmaos.sigmaos.macos",
    "com.pushplaylabs.sidekick", "com.firstversionist.polypane",
    "ai.perplexity.comet", "com.electron.min",

    // Office & Legacy
    "com.microsoft.Excel", "com.microsoft.Office.Excel", "com.microsoft.edge", "com.microsoft.Edge",
  ]
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  public var keyLayout = KeyboardUS()
  public var activeApp = ""
  public private(set) var lastSuggestions: [SuggestionCandidate] = []

  private let spellDecisionEngine = SpellDecisionEngine.shared

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// Transformation tracker manages per-app strategy and failure detection
  var strategyTracker = TransformationTracker()

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  // MARK: - Convenience accessors (preserve existing API for tests)

  public var keys: [Character] {
    get { wordBuffer.keys }
    set { wordBuffer.keys = newValue }
  }

  public var stopProcessing: Bool {
    get { wordBuffer.stopProcessing }
    set { wordBuffer.stopProcessing = newValue }
  }

  public var lastTransformed: String {
    get { wordBuffer.lastTransformed }
    set { wordBuffer.lastTransformed = newValue }
  }

  public var transformed: String {
    get { wordBuffer.transformed }
    set { wordBuffer.transformed = newValue }
  }

  public var previousWordState: TiengVietState? {
    get { wordBuffer.previousWordState }
    set { wordBuffer.previousWordState = newValue }
  }

  public var wordState: TiengVietState {
    get { wordBuffer.wordState }
    set { wordBuffer.wordState = newValue }
  }

  // MARK: - Init & Configuration

  init(method: TypingMethods) {
    typingMethod = method
    engine = typingMethod == .Telex ? Telex() : VNI()
    LexiconManager.shared.reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    strategyTracker.resetForApp(app)
  }

  // MARK: - Word Operations (delegate to WordBuffer)

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
  }

  public func pop() -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let shifted = flags.contains(.maskShift) || (!keyLayout.isNumberKey(keyCode: keyCode) && flags.contains(.maskAlphaShift))

    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      return Unmanaged.passUnretained(event)
    }

    // Detect if a paste operation occurred (pasteboard changed externally)
    let currentPasteboardCount = NSPasteboard.general.changeCount
    if currentPasteboardCount != lastPasteboardChangeCount {
      lastPasteboardChangeCount = currentPasteboardCount
      newWord()
    }

    // Dispatch based on key type
    if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
      return handleTaskKey(taskKey, event: event)
    } else if let newChar = keyLayout.mapText(keyCode: keyCode, withShift: shifted) {
      return handleTextChar(newChar, event: event)
    }

    return Unmanaged.passUnretained(event)
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey, event: CGEvent) -> Unmanaged<CGEvent>? {
    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      // Only expand macros on Space — Tab/Enter often have form-submission semantics
      // we don't want to swallow.
      if taskKey == .Space, expandMacroIfMatch(endingChar: " ") {
        newWord(storePrevious: true)
        return nil
      }

      if taskKey == .Space, applySpellDecisionOnCommit(endingChar: " ", swallowEndingChar: true) {
        newWord(storePrevious: true)
        return nil
      }
      newWord(storePrevious: true)
    } else if taskKey == .Escape {
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: currentTransformed, to: orig)
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
        newWord()
        return nil // swallow ESC event
      }
      newWord()
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
        return nil
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
    }
    return Unmanaged.passUnretained(event)
  }

  private func handleTextChar(_ newChar: Character, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
      if expandMacroIfMatch(endingChar: newChar) {
        newWord(storePrevious: true)
        return nil
      }
      _ = applySpellDecisionOnCommit(endingChar: newChar, swallowEndingChar: false)
      newWord(storePrevious: true)
      return Unmanaged.passUnretained(event)
    }

    push(char: newChar)
    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return Unmanaged.passUnretained(event)
    }

    if isFixAutocompleteApp() {
      // For autocomplete-capable apps (browsers, etc.), use select-and-replace
      // instead of backspace-and-type. Shift+Left naturally extends any existing
      // inline autocomplete selection, so the typed replacement covers both the
      // autocomplete text and the characters being modified.
      let strategy = effectiveTypingStrategy(
        backspaceCount: numBackspaces,
        diffCharCount: diffChars.count
      )
      let telemetry = EventSimulator.sendSelectAndReplace(
        selectLeftCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategy
      )
      observeTelemetry(telemetry, appLikelySensitive: true)
    } else {
      let strategy = effectiveTypingStrategy(
        backspaceCount: numBackspaces,
        diffCharCount: diffChars.count
      )
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategy
      )
      observeTelemetry(telemetry, appLikelySensitive: false)
    }
    return nil
  }

  // MARK: - Helpers

  private func observeTelemetry(_ telemetry: EventSendTelemetry, appLikelySensitive: Bool) {
    if strategyTracker.detectFailure(
      telemetry: telemetry,
      appLikelySensitive: appLikelySensitive
    ) {
      strategyTracker.autoSwitchIfNeeded(activeApp: activeApp)
    }
  }

  /// For tiny diffs (common during Telex tone mutation), force immediate batch sending
  /// to avoid async reordering with the next keystroke (e.g. "push" -> "pussh").
  private func effectiveTypingStrategy(backspaceCount: Int, diffCharCount: Int) -> SendingStrategy {
    if backspaceCount <= 1 && diffCharCount <= 1 {
      return .batch
    }
    return strategyTracker.currentStrategy
  }

  /// Applies spell/restore/suggestion rules when a word commit key is pressed.
  /// - Parameters:
  ///   - endingChar: Commit key character (space or punctuation).
  ///   - swallowEndingChar: True when commit key should be emitted by vkey.
  /// - Returns: True when a replacement was sent.
  @discardableResult
  private func applySpellDecisionOnCommit(
    endingChar: Character,
    swallowEndingChar: Bool
  ) -> Bool {
    let rawInput = String(wordBuffer.keys)
    let current = wordBuffer.transformed
    guard !rawInput.isEmpty, !current.isEmpty else {
      lastSuggestions = []
      return false
    }

    guard Defaults[.spellCheckInSentenceEnabled] else {
      lastSuggestions = []
      return false
    }

    let decision = spellDecisionEngine.evaluate(
      rawInput: rawInput,
      transformed: current,
      needsRecovery: wordBuffer.wordState.needsRecovery || wordBuffer.stopProcessing
    )

    switch decision {
    case .keepVietnamese, .keepRaw:
      lastSuggestions = []
      return false

    case .restoreRawEnglish(let restoredWord):
      lastSuggestions = []
      let target = swallowEndingChar ? restoredWord + String(endingChar) : restoredWord
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true

    case .suggest(let suggestions):
      lastSuggestions = suggestions
      guard
        Defaults[.autoApplyHighConfidenceSuggestion],
        let top = suggestions.first,
        top.score >= 0.88
      else {
        return false
      }

      let target = swallowEndingChar ? top.word + String(endingChar) : top.word
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true
    }
  }

  func isFixAutocompleteApp() -> Bool {
    if Focused.isComboBoxOrSearchField() {
      return true
    }
    return InputProcessor.FixAutocompleteApps.contains { app in
      return activeApp.hasPrefix(app)
    }
  }

  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    guard !current.isEmpty else { return nil }
    guard
      let macro = macros.first(where: {
        !$0.from.isEmpty && !$0.to.isEmpty && $0.from == current
      })
    else {
      return nil
    }

    return (current.count, Array(macro.to + String(endingChar)))
  }

  /// Expands the current word using the user's macro table if it matches.
  /// When a match is found, replaces the on-screen word with the expansion plus
  /// the word-ending character, then returns true so the caller can swallow the
  /// original ending key. Returns false (no side effects) when no macro matches.
  private func expandMacroIfMatch(endingChar: Character) -> Bool {
    let current = wordBuffer.transformed
    guard
      let replacement = Self.macroReplacement(
        for: current,
        endingChar: endingChar,
        macros: Defaults[.macros]
      )
    else {
      return false
    }

    let telemetry = EventSimulator.sendReplacement(
      backspaceCount: replacement.backspaceCount,
      diffChars: replacement.diffChars,
      strategy: strategyTracker.currentStrategy
    )
    observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
    return true
  }
}
