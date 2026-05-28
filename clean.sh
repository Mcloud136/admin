#!/bin/bash

# ============================================
# 运维管理平台 - 彻底清理脚本
# 清除所有安装残留，为全新安装做准备
# ============================================

echo "=========================================="
echo "  运维管理平台 - 彻底清理脚本"
echo "=========================================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash clean.sh"
    exit 1
fi

echo "  ⚠ 此脚本将清除所有运维管理平台的安装残留"
echo ""

# Detect install directory
INSTALL_DIR=""
if [ -f "/opt/ops-platform/ops-server" ]; then
    INSTALL_DIR="/opt/ops-platform"
elif [ -f "$(pwd)/ops-server" ] && [ -f "$(pwd)/index.html" ]; then
    INSTALL_DIR="$(pwd)"
fi

# Detect OS
OS="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

echo "  检测到的安装目录: ${INSTALL_DIR:-未找到}"
echo ""
read -p "  确认清理？(y/N): " CONFIRM < /dev/tty
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "已取消"
    exit 0
fi

# ============================================
echo ""
echo "[1/6] 停止并删除 systemd 服务..."
echo "-------------------------------------------"

if systemctl is-active --quiet ops-platform 2>/dev/null; then
    systemctl stop ops-platform
    echo "[OK] 服务已停止"
fi

if [ -f /etc/systemd/system/ops-platform.service ]; then
    systemctl disable ops-platform 2>/dev/null || true
    rm -f /etc/systemd/system/ops-platform.service
    systemctl daemon-reload
    echo "[OK] 服务文件已删除"
else
    echo "[INFO] 服务文件不存在"
fi

pkill -f "ops-server" 2>/dev/null && echo "[OK] 已杀死残留进程" || true
pkill -f "ops-supervisor" 2>/dev/null && echo "[OK] 已杀死残留守护进程" || true

# ============================================
echo ""
echo "[2/6] 清理 Nginx 配置..."
echo "-------------------------------------------"

NGINX_CONF=""
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    NGINX_CONF="/etc/nginx/sites-available/ops-platform"
    rm -f /etc/nginx/sites-enabled/ops-platform
else
    NGINX_CONF="/etc/nginx/conf.d/ops-platform.conf"
fi

if [ -f "$NGINX_CONF" ]; then
    rm -f "$NGINX_CONF"
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    echo "[OK] Nginx 配置已删除"
else
    echo "[INFO] Nginx 配置不存在"
fi

# ============================================
echo ""
echo "[3/6] 清理安装目录..."
echo "-------------------------------------------"

if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
    echo "  目录: $INSTALL_DIR"

    if [ -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env" /tmp/ops-env-backup-$(date +%s) 2>/dev/null
        echo "[INFO] .env 已备份到 /tmp/"
    fi

    rm -rf "$INSTALL_DIR"
    echo "[OK] 安装目录已删除: $INSTALL_DIR"
else
    echo "[INFO] 未找到安装目录"
fi

# ============================================
echo ""
echo "[4/6] 卸载 PostgreSQL 并删除所有数据库..."
echo "-------------------------------------------"

if command -v psql &> /dev/null; then
    DB_LIST=$(sudo -u postgres psql -tAc "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres'" 2>/dev/null)
    if [ -n "$DB_LIST" ]; then
        echo "  发现以下数据库："
        echo "$DB_LIST" | while read db; do echo "    - $db"; done
    fi
    echo ""
    read -p "  ⚠ 是否卸载 PostgreSQL 并删除所有数据库？(y/N): " DB_CONFIRM < /dev/tty
    if [ "$DB_CONFIRM" = "y" ] || [ "$DB_CONFIRM" = "Y" ]; then
        systemctl stop postgresql 2>/dev/null || true

        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            apt-get remove -y --purge postgresql postgresql-client postgresql-common 2>/dev/null
            apt-get autoremove -y 2>/dev/null
            rm -rf /var/lib/postgresql 2>/dev/null
            rm -rf /etc/postgresql 2>/dev/null
        elif [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
            yum remove -y postgresql-server postgresql 2>/dev/null
            rm -rf /var/lib/pgsql 2>/dev/null
        fi
        echo "[OK] PostgreSQL 已卸载，所有数据库已删除"
    else
        echo "[INFO] 保留 PostgreSQL"
    fi
else
    echo "[INFO] PostgreSQL 未安装"
fi

# ============================================
echo ""
echo "[5/6] 清理临时文件..."
echo "-------------------------------------------"

rm -rf /tmp/ops-uploads-backup 2>/dev/null
rm -rf /tmp/ops-clone 2>/dev/null
rm -rf /tmp/ops-env-backup-* 2>/dev/null
rm -rf /tmp/ops-platform-backup-* 2>/dev/null
rm -f /root/.env 2>/dev/null
rm -f /tmp/.env 2>/dev/null
echo "[OK] 临时文件已清理"

# ============================================
echo ""
echo "[6/6] 清理完成"
echo "=========================================="
echo ""
echo "  如需重新安装："
echo "    curl -fsSL https://gitee.com/wxbns/Team-Management/raw/main/install-cn.sh -o install-cn.sh"
echo "    sudo bash install-cn.sh"
echo ""
