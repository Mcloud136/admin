#!/bin/bash
set -e

# ============================================
# 运维管理平台 - 彻底清理脚本
# 删除所有部署内容、数据库、Nginx、PostgreSQL
# ============================================

echo "=========================================="
echo "  运维管理平台 - 彻底清理脚本"
echo "=========================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash clean.sh"
    exit 1
fi

echo "[WARNING] 此操作将删除以下内容："
echo "  - ops-platform 服务和所有文件"
echo "  - PostgreSQL 数据库（含所有数据）"
echo "  - Nginx 配置和 SSL 证书"
echo "  - /opt/ops-platform/ 整个目录"
echo ""
read -p "确认执行？(y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 0
fi

echo ""
echo "[1/7] 停止服务..."
echo "-------------------------------------------"
systemctl stop ops-platform 2>/dev/null || true
systemctl stop ops-supervisor 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl disable ops-platform 2>/dev/null || true
systemctl disable ops-supervisor 2>/dev/null || true
echo "[OK] 服务已停止"

echo ""
echo "[2/7] 删除 systemd 服务文件..."
echo "-------------------------------------------"
rm -f /etc/systemd/system/ops-platform.service
rm -f /etc/systemd/system/ops-supervisor.service
systemctl daemon-reload
echo "[OK] 服务文件已删除"

echo ""
echo "[3/7] 卸载 Nginx..."
echo "-------------------------------------------"
rm -f /etc/nginx/conf.d/ops-platform*.conf
rm -rf /etc/nginx/ssl
if command -v nginx &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y nginx nginx-common nginx-full 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum -y remove nginx 2>/dev/null || true
    fi
    echo "[OK] Nginx 已卸载"
else
    echo "[OK] Nginx 未安装，跳过"
fi

echo ""
echo "[4/7] 卸载 PostgreSQL..."
echo "-------------------------------------------"
if command -v psql &>/dev/null; then
    # Drop database and user first
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ops_platform;" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS ops_platform;" 2>/dev/null || true

    if command -v apt-get &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y 'postgresql-*' 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum -y remove 'postgresql*' 2>/dev/null || true
    fi
    rm -rf /var/lib/postgresql /etc/postgresql
    echo "[OK] PostgreSQL 已卸载"
else
    echo "[OK] PostgreSQL 未安装，跳过"
fi

echo ""
echo "[5/7] 删除项目文件..."
echo "-------------------------------------------"
rm -rf /opt/ops-platform
echo "[OK] /opt/ops-platform/ 已删除"

echo ""
echo "[6/7] 清理残留配置..."
echo "-------------------------------------------"
rm -f /etc/apt/sources.list.d/pgdg*.list
rm -f /etc/apt/sources.list.d/nginx*.list
rm -f /etc/apt/keyrings/pgdg.gpg
rm -f /etc/apt/keyrings/nginx.gpg
apt-get autoremove -y 2>/dev/null || true
echo "[OK] 残留配置已清理"

echo ""
echo "[7/7] 验证清理结果..."
echo "-------------------------------------------"
CLEAN=true

if command -v nginx &>/dev/null; then
    echo "[WARN] Nginx 仍然存在"
    CLEAN=false
fi
if command -v psql &>/dev/null; then
    echo "[WARN] PostgreSQL 仍然存在"
    CLEAN=false
fi
if [ -d "/opt/ops-platform" ]; then
    echo "[WARN] /opt/ops-platform 仍然存在"
    CLEAN=false
fi
if systemctl is-active ops-platform &>/dev/null; then
    echo "[WARN] ops-platform 服务仍在运行"
    CLEAN=false
fi

if [ "$CLEAN" = true ]; then
    echo "[OK] 清理完成，服务器已恢复干净状态"
else
    echo "[WARN] 部分内容可能未完全清理，请手动检查"
fi

echo ""
echo "=========================================="
echo "  清理完成"
echo "=========================================="
