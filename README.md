# Hi. Studio cho iPhone / iPad

Vỏ ứng dụng iOS (WKWebView) mở website Hi. Studio toàn màn hình. Website được cập nhật trực tiếp trên máy chủ nên **không cần build lại app khi sửa web**.

Tương thích sẵn với phần web: nhận diện `HiStudioApp` trong User-Agent, menu ứng dụng (lắc máy), đăng nhập Google qua trình duyệt hệ thống (`histudio://auth`), hộp thoại xác nhận/nhập liệu, tải tệp (PDF, ảnh, ZIP) qua bảng chia sẻ của iOS, chọn ảnh / chụp ảnh để tải lên, liên kết `tel:` / `mailto:`, mở album/thiệp/video bằng Safari trong app.

## 1. Đổi địa chỉ website mặc định
Mở `HiStudio/Site.swift`, sửa dòng:

    static let defaultAddress = "https://studioz.vn"

Người dùng cũng có thể đổi trong app: lắc máy → "Đổi địa chỉ website".

## 2. Tạo file .ipa (không cần máy Mac)
1. Tạo kho (repository) riêng tư trên GitHub, tải toàn bộ thư mục này lên (giữ nguyên `.github/workflows/build-ipa.yml`).
2. Vào tab **Actions** → **Build iOS IPA** → **Run workflow**. Chờ khoảng 5 phút.
3. Mở lần chạy vừa xong, mục **Artifacts** → tải **HiStudio-ipa** (giải nén ra `HiStudio.ipa`).

## 3. Cài đặt lên iPhone
File .ipa này **chưa ký** nên cần ký bằng Apple ID của bạn khi cài:

- **Sideloadly** (Windows/macOS, miễn phí): cắm iPhone vào máy tính → kéo `HiStudio.ipa` vào Sideloadly → nhập Apple ID → Start. Trên iPhone: *Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị* → tin cậy tài khoản. Với Apple ID miễn phí, app hết hạn sau 7 ngày (cài lại để gia hạn); tài khoản Apple Developer trả phí được 1 năm.
- **AltStore / SideStore**: cài qua AltServer, tự làm mới ngầm.
- **TrollStore** (một số phiên bản iOS cũ): cài trực tiếp file .ipa, không hết hạn.
- Phát hành chính thức qua **TestFlight / App Store** cần tài khoản Apple Developer (99 USD/năm) và ký bằng chứng chỉ của bạn trong Xcode.

## 4. Mở bằng Xcode (nếu có máy Mac)
    brew install xcodegen
    xcodegen generate
    open HiStudio.xcodeproj
Chọn Team ở mục Signing & Capabilities, đổi Bundle Identifier nếu cần, rồi Run.

## Lưu ý
- Kết nối Google Lịch (không phải đăng nhập) nên thực hiện trên trình duyệt web.
- Yêu cầu iOS 15 trở lên.
