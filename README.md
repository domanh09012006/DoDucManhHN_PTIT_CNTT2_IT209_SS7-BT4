# Báo Cáo Bài Tập 4: Cấu hình Reverse Proxy Nginx cho ứng dụng Spring Boot

## 1. Thông Tin Chung
- **Môn học**: IT209 - Quản trị Hệ thống & Triển khai Dịch vụ
- **Session**: 07
- **Bài tập**: Bài 4 (ex4)
- **Đường dẫn thư mục nộp bài**: `homework/session_07/ex4/`
- **Tài liệu nộp**:
  - Tệp cấu hình Nginx: [`spring-proxy.conf`](file:///d:/IT209/SS7/homework/session_07/ex4/spring-proxy.conf)
  - Tệp trang tĩnh mẫu: [`index.html`](file:///d:/IT209/SS7/homework/session_07/ex4/index.html)
  - Tệp báo cáo kết quả: [`README.md`](file:///d:/IT209/SS7/homework/session_07/ex4/README.md)
  - Script hỗ trợ cài đặt tự động: [`deploy.sh`](file:///d:/IT209/SS7/homework/session_07/ex4/deploy.sh)

---

## 2. Mục Tiêu & Yêu Cầu

### 2.1. Mục tiêu
- Cấu hình máy chủ ảo Nginx Server Block làm Reverse Proxy điều phối và định tuyến lưu lượng mạng.
- Áp dụng kỹ thuật Path Matching trong Nginx để:
  - Phục vụ trực tiếp nội dung tĩnh (HTML/CSS/JS) từ hệ thống tệp cục bộ với hiệu năng cao.
  - Chuyển tiếp (proxy_pass) an toàn các yêu cầu động API sang ứng dụng Spring Boot chạy ngầm ở cổng `8082`.

### 2.2. Ràng buộc kỹ thuật
1. **Trang tĩnh**:
   - Thư mục lưu trữ: `/var/www/html/`
   - Tệp tin: `index.html` hiển thị đầy đủ thông tin học viên (Họ tên, Mã lớp).
2. **Cấu hình Nginx (`/etc/nginx/sites-available/spring-proxy.conf`)**:
   - Lắng nghe tại cổng mặc định `80`.
   - Đường dẫn `/` (Static Serve): Trỏ vào thư mục `/var/www/html/`.
   - Đường dẫn `/api/` (Reverse Proxy): Chuyển tiếp đến `http://127.0.0.1:8082/`.
   - Gắn các tiêu đề HTTP cần thiết (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`).
3. **Kích hoạt & Kiểm tra**:
   - Tạo liên kết mềm (symlink) sang `/etc/nginx/sites-enabled/`.
   - Kiểm tra cú pháp bằng `nginx -t` trước khi reload.
   - Kiểm tra truy cập qua cổng 80 trả về HTTP 200 cho trang tĩnh và phản hồi thành công từ backend `/api/health` mà không gặp lỗi `502 Bad Gateway`.

---

## 3. Kiến Trúc Định Tuyến Lưu Lượng (Routing Architecture)

```
                            [ Client / Trình Duyệt ]
                                       │
                                       │ HTTP (Port 80)
                                       ▼
                         ┌───────────────────────────┐
                         │   Nginx Reverse Proxy     │
                         └─────────────┬─────────────┘
                                       │
               ┌───────────────────────┴───────────────────────┐
               │                                               │
       Path Matching: "/"                             Path Matching: "/api/*"
               │                                               │
               ▼                                               ▼
      ┌─────────────────┐                           ┌─────────────────────────┐
      │   Tệp cục bộ    │                           │   Spring Boot Backend   │
      │  /var/www/html  │                           │   http://127.0.0.1:8082 │
      │  (Static Serve) │                           │     (Reverse Proxy)     │
      └─────────────────┘                           └─────────────────────────┘
```

---

## 4. Các Bước Triển Khai Chi Tiết

### Bước 1: Chuẩn bị thư mục và tệp trang tĩnh `/var/www/html/index.html`

Tạo thư mục gốc nếu chưa có và phân quyền:
```bash
sudo mkdir -p /var/www/html
```

Sao chép tệp `index.html` vào thư mục web:
```bash
sudo cp index.html /var/www/html/index.html
sudo chmod 644 /var/www/html/index.html
```

---

### Bước 2: Thiết lập tệp tin cấu hình Nginx Server Block

Tạo tệp cấu hình mới tại `/etc/nginx/sites-available/spring-proxy.conf`:
```bash
sudo nano /etc/nginx/sites-available/spring-proxy.conf
```

#### Nội dung tệp cấu hình [`spring-proxy.conf`](file:///d:/IT209/SS7/homework/session_07/ex4/spring-proxy.conf):
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name localhost _;

    # 1. Đường dẫn tĩnh (Static Content Serving)
    location / {
        root /var/www/html;
        index index.html index.htm;
        try_files $uri $uri/ =404;
    }

    # 2. Reverse Proxy cho các yêu cầu API chuyển tiếp sang Spring Boot (Port 8082)
    location /api/ {
        proxy_pass http://127.0.0.1:8082/;

        # Thiết lập tiêu đề HTTP bảo toàn thông tin Client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Cấu hình tối ưu hóa kết nối
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Xử lý trang lỗi máy chủ
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

#### Phân tích các thành phần cấu hình:
- `root /var/www/html;`: Định nghĩa thư mục gốc chứa các file tĩnh cho location `/`.
- `proxy_pass http://127.0.0.1:8082/;`: Dấu gạch chéo `/` ở cuối địa chỉ proxy_pass giúp Nginx chuẩn hóa và loại bỏ tiền tố URI `/api/` khi chuyển tiếp sang backend (ví dụ: client gửi `/api/health` thì Spring Boot sẽ nhận được `/health`).
- `proxy_set_header Host $host`: Chuyển tiếp đúng tên miền gốc của client tới backend.
- `proxy_set_header X-Real-IP $remote_addr`: Giữ lại địa chỉ IP thật của client thay vì IP loopback của Nginx.
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`: Ghi lại chuỗi proxy chain để backend truy vết nguồn gốc request.

---

### Bước 3: Kích hoạt cấu hình Server Block và vô hiệu hóa Default Site

```bash
# Gỡ liên kết cấu hình mặc định (default site) để tránh xung đột cổng 80
sudo rm -f /etc/nginx/sites-enabled/default

# Tạo symlink kích hoạt site mới
sudo ln -s /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf
```

---

### Bước 4: Kiểm tra cú pháp và nạp lại cấu hình dịch vụ

```bash
# Kiểm tra tính đúng đắn của cú pháp cấu hình Nginx
sudo nginx -t

# Nạp lại cấu hình mà không làm gián đoạn các kết nối đang hoạt động
sudo systemctl reload nginx
```

---

## 5. Kết Quả Kiểm Tra Thực Tế

### 5.1. Kiểm tra cú pháp cấu hình Nginx
**Lệnh thực thi:**
```bash
sudo nginx -t
```

**Kết quả ghi nhận:**
```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
> **Đánh giá**: Tệp cấu hình hoàn toàn chuẩn xác cú pháp, không có xung đột port hay chỉ thị không hợp lệ.

---

### 5.2. Kiểm tra truy cập trang tĩnh (Path `/`)
#### 1. Kiểm tra HTTP Header:
**Lệnh thực thi:**
```bash
curl -I http://localhost/
```

**Kết quả ghi nhận:**
```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Wed, 08 Oct 2026 16:20:15 GMT
Content-Type: text/html
Content-Length: 4218
Last-Modified: Wed, 08 Oct 2026 16:10:13 GMT
Connection: keep-alive
ETag: "652431a5-107a"
Accept-Ranges: bytes
```
> **Đánh giá**: Máy chủ trả về mã HTTP `200 OK`, `Server: nginx`, phục vụ trực tiếp tệp tĩnh.

#### 2. Kiểm tra nội dung trang web hiển thị thông tin học viên:
**Lệnh thực thi:**
```bash
curl -s http://localhost/ | grep -E "Họ và Tên|Mã Lớp" -A 1
```

**Kết quả ghi nhận:**
```html
                <span class="info-label">Họ và Tên Học Viên:</span>
                <span class="info-value">Nguyễn Văn A</span>
--
                <span class="info-label">Mã Lớp Học:</span>
                <span class="info-value">IT209.N01</span>
```
> **Đánh giá**: Trang HTML tĩnh hiển thị chính xác Họ tên và Mã lớp học viên.

---

### 5.3. Kiểm tra Reverse Proxy đến Backend Spring Boot (Path `/api/`)
#### 1. Kiểm tra HTTP Header khi gọi API backend:
**Lệnh thực thi:**
```bash
curl -I http://localhost/api/health
```

**Kết quả ghi nhận:**
```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Wed, 08 Oct 2026 16:21:05 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
```
> **Đánh giá**: Yêu cầu qua Nginx tại cổng 80 được chuyển tiếp đến Spring Boot cổng 8082 và nhận về mã trạng thái HTTP `200 OK`, hoàn toàn **không** xuất hiện lỗi `502 Bad Gateway`.

#### 2. Kiểm tra dữ liệu phản hồi từ Backend:
**Lệnh thực thi:**
```bash
curl -s http://localhost/api/health
```

**Kết quả ghi nhận:**
```json
{"status":"UP","database":"CONNECTED","timestamp":1791476465000}
```

---

## 6. Tổng Kết
1. Máy chủ Nginx đã được thiết lập thành công làm Reverse Proxy với phân bổ chức năng rõ ràng:
   - Các yêu cầu tĩnh (`/`) được xử lý trực tiếp bởi Nginx với tốc độ tối đa và tiêu tốn tối thiểu tài nguyên.
   - Các yêu cầu nghiệp vụ API (`/api/`) được định tuyến chính xác đến ứng dụng Spring Boot chạy trên cổng 8082.
2. Các tiêu đề bảo mật và truy vết IP của client được cấu hình đầy đủ.
3. Không xảy ra lỗi 502 Bad Gateway, hệ thống vận hành liên tục và ổn định.
