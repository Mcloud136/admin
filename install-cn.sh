#!/bin/bash
set -e

# ============================================
# 运维管理平台 - 一键安装脚本（国内版）
# ============================================

# Gitee 仓库地址（请替换为你的 Gitee 仓库地址）
GITEE_USER="你的Gitee用户名"
GITEE_REPO="admin"
RAW_BASE="https://gitee.com/${GITEE_USER}/${GITEE_REPO}/raw/main"

WORK_DIR=$(pwd)

echo "=========================================="
echo "  运维管理平台 - 一键安装脚本（国内版）"
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
    VER=$VERSION_ID
else
    echo "[ERROR] 不支持的操作系统"
    exit 1
fi

# ============================================
# [1/8] 配置国内镜像源
# ============================================
echo "[1/8] 配置国内镜像源..."

if [ "$OS" = "ubuntu" ]; then
    # 备份原源
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true

    # 使用阿里云镜像
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
    cat > /etc/apt/sources.list << APTLIST
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
APTLIST

elif [ "$OS" = "debian" ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")
    cat > /etc/apt/sources.list << APTLIST
deb http://mirrors.aliyun.com/debian/ ${CODENAME} main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ ${CODENAME}-security main contrib non-free non-free-firmware
APTLIST

elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    # 替换为阿里云镜像
    if [ -d /etc/yum.repos.d ]; then
        cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/*.repo.bak 2>/dev/null || true
        if [ "$OS" = "centos" ]; then
            sed -i 's|mirror.centos.org|mirrors.aliyun.com|g' /etc/yum.repos.d/*.repo
        fi
    fi
fi

echo "[2/8] 安装系统依赖..."

apt-get update -qq 2>/dev/null || yum makecache -q 2>/dev/null || true

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get install -y -qq nginx postgresql postgresql-client > /dev/null 2>&1
elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    yum install -y -q nginx postgresql-server postgresql > /dev/null 2>&1
    postgresql-setup --initdb 2>/dev/null || true
    systemctl enable postgresql
    systemctl start postgresql
fi

# 配置 PostgreSQL 使用 UTF-8
sudo -u postgres psql -c "UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'template0';" 2>/dev/null || true

echo "[3/8] 下载项目文件..."

download_file() {
    local url="$1"
    local dest="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$dest" 2>/dev/null; then
            return 0
        fi
        retry=$((retry + 1))
        echo "  重试 ($retry/$max_retries)..."
        sleep 2
    done

    echo "[WARN] 下载失败: $url"
    return 1
}

# 下载二进制文件
echo "  下载 ops-server..."
download_file "${RAW_BASE}/ops-server" "$WORK_DIR/ops-server"

echo "  下载 ops-supervisor..."
download_file "${RAW_BASE}/ops-supervisor" "$WORK_DIR/ops-supervisor"

echo "  下载前端文件..."
download_file "${RAW_BASE}/index.html" "$WORK_DIR/index.html"
download_file "${RAW_BASE}/.env.example" "$WORK_DIR/.env.example"

# 下载 assets 目录
mkdir -p "$WORK_DIR/assets"

# 从 Gitee API 获取文件列表
echo "  下载前端资源..."
ASSET_URL="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}/contents/assets"
ASSET_FILES=$(curl -s --connect-timeout 10 "$ASSET_URL" 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' || echo "")

if [ -n "$ASSET_FILES" ]; then
    for f in $ASSET_FILES; do
        download_file "${RAW_BASE}/assets/${f}" "$WORK_DIR/assets/${f}"
    done
else
    echo "  [WARN] 无法获取资源列表，请手动下载 assets/ 目录"
fi

echo "[4/8] 设置文件权限..."

chmod +x "$WORK_DIR/ops-server"
chmod +x "$WORK_DIR/ops-supervisor"
mkdir -p "$WORK_DIR/uploads/branding"
mkdir -p "$WORK_DIR/uploads/kb"

echo "[5/8] 创建数据库..."

# 确保 PostgreSQL 运行
systemctl start postgresql 2>/dev/null || true
sleep 2

# 创建数据库
sudo -u postgres psql -c "CREATE DATABASE ops_platform ENCODING 'UTF8';" 2>/dev/null || echo "  数据库已存在，跳过"

echo "[6/8] 配置 Nginx..."

SERVER_IP=$(hostname -I | awk '{print $1}')

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    NGINX_CONF="/etc/nginx/sites-available/ops-platform"
    SITES_ENABLED="/etc/nginx/sites-enabled"
elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    NGINX_CONF="/etc/nginx/conf.d/ops-platform.conf"
    SITES_ENABLED=""
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

if [ -n "$SITES_ENABLED" ]; then
    ln -sf "$NGINX_CONF" "$SITES_ENABLED/ops-platform" 2>/dev/null || true
    rm -f "$SITES_ENABLED/default" 2>/dev/null || true
fi

nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null

echo "[7/8] 配置系统服务..."

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

echo "[8/8] 启动完成"
echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""
echo "  访问地址: http://${SERVER_IP}"
echo ""
echo "  首次访问将进入安装向导，请按提示完成："
echo "  - 数据库信息（默认 postgres 用户）"
echo "  - 管理员账号密码"
echo "  - 平台名称和公司名称"
echo ""
echo "  服务管理:"
echo "    systemctl start ops-platform    # 启动"
echo "    systemctl stop ops-platform     # 停止"
echo "    systemctl restart ops-platform  # 重启"
echo "    systemctl status ops-platform   # 状态"
echo "    journalctl -u ops-platform -f   # 日志"
echo ""
