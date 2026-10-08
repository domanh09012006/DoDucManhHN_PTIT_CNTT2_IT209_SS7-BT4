#!/usr/bin/env bash
# ==============================================================================
# Script tự động cấu hình Nginx Reverse Proxy cho Spring Boot (Bài 4)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " [1/4] Sao chép tệp trang tĩnh vào /var/www/html/"
echo "=========================================================="
sudo mkdir -p /var/www/html
sudo cp "${SCRIPT_DIR}/index.html" /var/www/html/index.html
sudo chmod 644 /var/www/html/index.html
echo "=> Đã triển khai /var/www/html/index.html."

echo "=========================================================="
echo " [2/4] Cấu hình Nginx Server Block"
echo "=========================================================="
sudo cp "${SCRIPT_DIR}/spring-proxy.conf" /etc/nginx/sites-available/spring-proxy.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf
echo "=> Đã kích hoạt cấu hình spring-proxy.conf."

echo "=========================================================="
echo " [3/4] Kiểm tra cú pháp cấu hình Nginx"
echo "=========================================================="
sudo nginx -t

echo "=> Nạp lại cấu hình Nginx (Reload):"
sudo systemctl reload nginx

echo "=========================================================="
echo " [4/4] Kiểm tra truy vấn HTTP qua Curl"
echo "=========================================================="
echo "1. Kiểm tra trang tĩnh (Header /):"
curl -I http://localhost/

echo ""
echo "2. Kiểm tra Reverse Proxy API (Header /api/health):"
curl -I http://localhost/api/health || echo "Lưu ý: Đảm bảo Spring Boot đang chạy ở cổng 8082"
