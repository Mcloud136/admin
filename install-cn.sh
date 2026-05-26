#!/bin/bash
set -e

# ============================================
# 运维管理平台 - 一键安装脚本（国内版）
# ============================================

GITEE_USER="wxbns"
GITEE_REPO="Team-Management"
RAW_BASE="https://gitee.com/wxbns/Team-Management/raw/main"

WORK_DIR=$(pwd)

echo "=========================================="
echo "  运维管理平台 - 一键安装脚本（国内版）"
echo "=========================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash install-cn.sh"
    exit 1
fi
echo "[OK] root 权限确认"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    echo "[OK] 检测到系统: $OS"
else
    echo "[ERROR] 不支持的操作系统"
    exit 1
fi

# ============================================
echo ""
echo "[1/8] 配置国内镜像源..."
echo "-------------------------------------------"

if [ "$OS" = "ubuntu" ]; then
    echo ">> 备份原源: /etc/apt/sources.list"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
    echo ">> 系统代号: $CODENAME"
    echo ">> 写入阿里云镜像源"
    cat > /etc/apt/sources.list << APTLIST
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
APTLIST
    echo "[OK] Ubuntu 镜像源已切换为阿里云"

elif [ "$OS" = "debian" ]; then
    echo ">> 备份原源"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")
    echo ">> 系统代号: $CODENAME"
    echo ">> 写入阿里云镜像源"
    cat > /etc/apt/sources.list << APTLIST
deb http://mirrors.aliyun.com/debian/ ${CODENAME} main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ ${CODENAME}-updates main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian/ ${CODENAME}-security main contrib non-free non-free-firmware
APTLIST
    echo "[OK] Debian 镜像源已切换为阿里云"

elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    echo ">> 备份原源"
    cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/*.repo.bak 2>/dev/null || true
    if [ "$OS" = "centos" ]; then
        echo ">> 替换为阿里云镜像"
        sed -i 's|mirror.centos.org|mirrors.aliyun.com|g' /etc/yum.repos.d/*.repo
    fi
    echo "[OK] YUM 镜像源已切换为阿里云"
fi

# ============================================
echo ""
echo "[2/8] 安装系统依赖..."
echo "-------------------------------------------"

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    echo ">> apt-get update"
    apt-get update
    echo ""
    echo ">> apt-get install nginx postgresql postgresql-client"
    apt-get install -y nginx postgresql postgresql-client
elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    echo ">> yum install nginx postgresql-server postgresql"
    yum install -y nginx postgresql-server postgresql
    echo ""
    echo ">> 初始化 PostgreSQL"
    postgresql-setup --initdb || true
    echo ">> 启动 PostgreSQL"
    systemctl enable postgresql
    systemctl start postgresql
fi
echo "[OK] 系统依赖安装完成"

# ============================================
echo ""
echo "[3/8] 下载项目文件 (Gitee)..."
echo "-------------------------------------------"

download_file() {
    local url="$1"
    local dest="$2"
    local name=$(basename "$dest")
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        echo "   >> 下载 $name"
        if curl -L --connect-timeout 15 --max-time 300 "$url" -o "$dest"; then
            echo "   [OK] $name"
            return 0
        fi
        retry=$((retry + 1))
        echo "   [RETRY] $name ($retry/$max_retries)"
        sleep 3
    done

    echo "   [FAIL] $name - $url"
    return 1
}

echo ">> 下载后端二进制"
download_file "${RAW_BASE}/ops-server" "$WORK_DIR/ops-server"

echo ">> 下载守护进程"
download_file "${RAW_BASE}/ops-supervisor" "$WORK_DIR/ops-supervisor"

echo ">> 下载前端文件"
download_file "${RAW_BASE}/index.html" "$WORK_DIR/index.html"
download_file "${RAW_BASE}/.env.example" "$WORK_DIR/.env.example"

echo ""
echo ">> 下载前端资源 assets/"
mkdir -p "$WORK_DIR/assets"

ASSET_URL="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}/contents/assets"
echo "   >> 获取文件列表: $ASSET_URL"
ASSET_FILES=$(curl -s --connect-timeout 15 "$ASSET_URL" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' || echo "")

if [ -n "$ASSET_FILES" ]; then
    COUNT=$(echo "$ASSET_FILES" | wc -w)
    echo "   >> 共 $COUNT 个文件"
    for f in $ASSET_FILES; do
        download_file "${RAW_BASE}/assets/${f}" "$WORK_DIR/assets/${f}"
    done
else
    echo "   [WARN] 无法获取资源列表，请手动下载 assets/ 目录"
fi
echo "[OK] 项目文件下载完成"

# ============================================
echo ""
echo "[4/8] 设置文件权限..."
echo "-------------------------------------------"

echo ">> chmod +x ops-server"
chmod +x "$WORK_DIR/ops-server"
echo ">> chmod +x ops-supervisor"
chmod +x "$WORK_DIR/ops-supervisor"
echo ">> 创建 uploads/ 目录"
mkdir -p "$WORK_DIR/uploads/branding"
mkdir -p "$WORK_DIR/uploads/kb"
echo "[OK] 权限设置完成"

# ============================================
echo ""
echo "[5/8] 创建数据库..."
echo "-------------------------------------------"

echo ">> 确保 PostgreSQL 运行"
systemctl start postgresql || true
sleep 2

echo ">> CREATE DATABASE ops_platform"
sudo -u postgres psql -c "CREATE DATABASE ops_platform ENCODING 'UTF8';" || echo "   数据库已存在，跳过"
echo "[OK] 数据库准备完成"

# ============================================
echo ""
echo "[6/8] 配置 Nginx..."
echo "-------------------------------------------"

SERVER_IP=$(hostname -I | awk '{print $1}')
echo ">> 服务器 IP: $SERVER_IP"

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    NGINX_CONF="/etc/nginx/sites-available/ops-platform"
elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    NGINX_CONF="/etc/nginx/conf.d/ops-platform.conf"
fi

echo ">> 写入 Nginx 配置: $NGINX_CONF"
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

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    echo ">> 创建 sites-enabled 软链接"
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ops-platform
    rm -f /etc/nginx/sites-enabled/default
fi

echo ">> 测试 Nginx 配置"
nginx -t
echo ">> 重载 Nginx"
systemctl reload nginx || systemctl restart nginx
echo "[OK] Nginx 配置完成"

# ============================================
echo ""
echo "[7/8] 配置系统服务..."
echo "-------------------------------------------"

echo ">> 写入 systemd 服务: /etc/systemd/system/ops-platform.service"
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

echo ">> systemctl daemon-reload"
systemctl daemon-reload
echo ">> systemctl enable ops-platform"
systemctl enable ops-platform
echo ">> systemctl start ops-platform"
systemctl start ops-platform
echo ">> 等待服务启动..."
sleep 3
echo ">> 检查服务状态"
systemctl status ops-platform --no-pager || true
echo "[OK] 系统服务配置完成"

# ============================================
echo ""
echo "[8/8] 安装完成"
echo "=========================================="
echo ""
echo "  访问地址: http://${SERVER_IP}"
echo ""
echo "  首次访问将进入安装向导，请按提示完成："
echo "    1. 数据库信息（默认 postgres 用户）"
echo "    2. 管理员账号密码"
echo "    3. 平台名称和公司名称"
echo ""
echo "  API 文档: http://${SERVER_IP}/swagger/index.html"
echo ""
echo "  服务管理命令:"
echo "    systemctl start ops-platform    # 启动"
echo "    systemctl stop ops-platform     # 停止"
echo "    systemctl restart ops-platform  # 重启"
echo "    systemctl status ops-platform   # 状态"
echo "    journalctl -u ops-platform -f   # 实时日志"
echo ""
