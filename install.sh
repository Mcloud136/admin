#!/bin/bash
set -e

REPO="https://github.com/Mcloud136/admin.git"
WORK_DIR=$(pwd)

echo "=========================================="
echo "  运维管理平台 - 一键安装脚本"
echo "=========================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash install.sh"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "[ERROR] 不支持的操作系统"
    exit 1
fi

echo "[1/7] 安装系统依赖..."

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update -qq
    apt-get install -y -qq nginx postgresql postgresql-client git curl > /dev/null 2>&1
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ]; then
    yum install -y -q nginx postgresql-server postgresql git curl > /dev/null 2>&1
    postgresql-setup --initdb 2>/dev/null || true
    systemctl enable postgresql
    systemctl start postgresql
else
    echo "[WARN] 未知系统，请手动安装 Nginx 和 PostgreSQL"
fi

echo "[2/7] 下载项目文件..."

# Download files from GitHub
for file in index.html ops-server ops-supervisor .env.example; do
    curl -fsSL "https://raw.githubusercontent.com/Mcloud136/admin/main/$file" -o "$WORK_DIR/$file"
done
curl -fsSL "https://raw.githubusercontent.com/Mcloud136/admin/main/assets/" -o /dev/null 2>/dev/null || true

# Download assets directory
mkdir -p "$WORK_DIR/assets"
# Get asset file list from GitHub API
ASSET_FILES=$(curl -s "https://api.github.com/repos/Mcloud136/admin/contents/assets" | grep -o '"name": *"[^"]*"' | sed 's/"name": *"//;s/"//')
for f in $ASSET_FILES; do
    curl -fsSL "https://raw.githubusercontent.com/Mcloud136/admin/main/assets/$f" -o "$WORK_DIR/assets/$f" 2>/dev/null || true
done

echo "[3/7] 设置文件权限..."

chmod +x "$WORK_DIR/ops-server"
chmod +x "$WORK_DIR/ops-supervisor"
mkdir -p "$WORK_DIR/uploads/branding"
mkdir -p "$WORK_DIR/uploads/kb"

echo "[4/7] 创建数据库..."

# Create database
sudo -u postgres psql -c "CREATE DATABASE ops_platform;" 2>/dev/null || echo "数据库已存在，跳过"

echo "[5/7] 配置 Nginx..."

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

NGINX_CONF="/etc/nginx/sites-available/ops-platform"
if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ]; then
    NGINX_CONF="/etc/nginx/conf.d/ops-platform.conf"
fi

cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    server_name _;

    root $WORK_DIR;
    index index.html;

    client_max_body_size 50m;

    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:8080/uploads/;
    }

    location /swagger/ {
        proxy_pass http://127.0.0.1:8080/swagger/;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1024;
}
NGINXEOF

# Enable site
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ops-platform 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
fi

nginx -t && systemctl reload nginx

echo "[6/7] 配置系统服务..."

cat > /etc/systemd/system/ops-platform.service << SVCEOF
[Unit]
Description=Ops Platform Supervisor
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/ops-supervisor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ops-platform
systemctl start ops-platform

echo "[7/7] 启动完成"
echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""
echo "  访问地址: http://$SERVER_IP"
echo ""
echo "  首次访问将进入安装向导，请按提示完成："
echo "  - 数据库信息（默认 postgres 用户）"
echo "  - 管理员账号密码"
echo "  - 平台名称和公司名称"
echo ""
echo "  API 文档: http://$SERVER_IP/swagger/index.html"
echo ""
echo "  服务管理:"
echo "    systemctl start ops-platform    # 启动"
echo "    systemctl stop ops-platform     # 停止"
echo "    systemctl restart ops-platform  # 重启"
echo "    systemctl status ops-platform   # 状态"
echo "    journalctl -u ops-platform -f   # 日志"
echo ""
