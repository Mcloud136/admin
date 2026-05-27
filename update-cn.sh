#!/bin/bash
set -e

# ============================================
# 运维管理平台 - 更新脚本（国内版）
# 从 GitHub 拉取最新版本，保留数据库和用户数据
# ============================================

INSTALL_DIR="/opt/ops-platform"
BACKUP_DIR="/opt/ops-platform-backup-$(date +%Y%m%d%H%M%S)"
REPO="Mcloud136/admin"
BRANCH="main"
SERVICE_NAME="ops-platform"

echo "=========================================="
echo "  运维管理平台 - 更新脚本（国内版）"
echo "=========================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash update-cn.sh"
    exit 1
fi

# Check install dir
if [ ! -d "$INSTALL_DIR" ]; then
    echo "[ERROR] 安装目录不存在: $INSTALL_DIR"
    echo "        请先运行 install-cn.sh 安装"
    exit 1
fi

echo "[INFO] 安装目录: $INSTALL_DIR"
echo "[INFO] 备份目录: $BACKUP_DIR"
echo ""

# ============================================
echo "[1/7] 备份当前版本..."
echo "-------------------------------------------"

mkdir -p "$BACKUP_DIR"
cp "$INSTALL_DIR/ops-server" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/ops-supervisor" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$INSTALL_DIR/assets" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/index.html" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/.env" "$BACKUP_DIR/" 2>/dev/null || true
echo "[OK] 备份完成"

# ============================================
echo ""
echo "[2/7] 停止服务..."
echo "-------------------------------------------"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl stop "$SERVICE_NAME"
    echo "[OK] 服务已停止"
else
    echo "[INFO] 服务未运行，跳过"
fi

# ============================================
echo ""
echo "[3/7] 下载最新版本..."
echo "-------------------------------------------"

DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
# 国内镜像加速
MIRROR_URL="https://ghfast.top/${DOWNLOAD_URL}"
TEMP_DIR=$(mktemp -d)

echo ">> 尝试 GitHub 直连..."
if curl -fsSL --connect-timeout 10 "$DOWNLOAD_URL" -o "$TEMP_DIR/source.tar.gz" 2>/dev/null; then
    echo "[OK] GitHub 直连成功"
else
    echo ">> 直连失败，尝试镜像加速..."
    if curl -fsSL --connect-timeout 15 "$MIRROR_URL" -o "$TEMP_DIR/source.tar.gz" 2>/dev/null; then
        echo "[OK] 镜像下载成功"
    else
        echo ">> 镜像失败，尝试 ghfast.top 备用..."
        MIRROR_URL2="https://mirror.ghproxy.com/${DOWNLOAD_URL}"
        if curl -fsSL --connect-timeout 15 "$MIRROR_URL2" -o "$TEMP_DIR/source.tar.gz" 2>/dev/null; then
            echo "[OK] 备用镜像下载成功"
        else
            echo "[ERROR] 所有下载源均失败，请检查网络"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi
fi

echo ">> 解压..."
tar -xzf "$TEMP_DIR/source.tar.gz" -C "$TEMP_DIR"
EXTRACTED_DIR=$(ls -d "$TEMP_DIR"/admin-* 2>/dev/null | head -1)

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "[ERROR] 解压失败"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "[OK] 下载解压完成"

# ============================================
echo ""
echo "[4/7] 更新后端..."
echo "-------------------------------------------"

cp "$EXTRACTED_DIR/ops-server" "$INSTALL_DIR/ops-server"
chmod +x "$INSTALL_DIR/ops-server"
echo "[OK] ops-server 已更新"

cp "$EXTRACTED_DIR/ops-supervisor" "$INSTALL_DIR/ops-supervisor"
chmod +x "$INSTALL_DIR/ops-supervisor"
echo "[OK] ops-supervisor 已更新"

# ============================================
echo ""
echo "[5/7] 更新前端..."
echo "-------------------------------------------"

cp "$EXTRACTED_DIR/index.html" "$INSTALL_DIR/index.html"
rm -rf "$INSTALL_DIR/assets"
cp -r "$EXTRACTED_DIR/assets" "$INSTALL_DIR/assets"
echo "[OK] 前端文件已更新"

# 更新安装脚本
cp "$EXTRACTED_DIR/install.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$EXTRACTED_DIR/install-cn.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 清理
rm -rf "$TEMP_DIR"

# ============================================
echo ""
echo "[6/7] 验证完整性..."
echo "-------------------------------------------"

ERRORS=0

for f in ops-server ops-supervisor index.html; do
    if [ ! -f "$INSTALL_DIR/$f" ]; then
        echo "[ERROR] $f 缺失"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] $f"
    fi
done

if [ ! -d "$INSTALL_DIR/assets" ]; then
    echo "[ERROR] assets/ 缺失"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] assets/"
fi

# 验证数据保留
echo ""
echo "--- 数据保留检查 ---"

if [ -f "$INSTALL_DIR/.env" ]; then
    echo "[OK] .env 配置文件保留"
else
    echo "[WARN] .env 不存在"
fi

if [ -f "$INSTALL_DIR/.initialized" ]; then
    echo "[OK] .initialized 安装标记保留"
fi

if [ -d "$INSTALL_DIR/uploads" ]; then
    UPLOAD_COUNT=$(find "$INSTALL_DIR/uploads" -type f | wc -l)
    echo "[OK] uploads/ 保留（${UPLOAD_COUNT} 个文件）"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "[ERROR] 验证失败，回滚中..."
    cp "$BACKUP_DIR/ops-server" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-supervisor" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/index.html" "$INSTALL_DIR/" 2>/dev/null || true
    cp -r "$BACKUP_DIR/assets" "$INSTALL_DIR/" 2>/dev/null || true
    systemctl start "$SERVICE_NAME" 2>/dev/null || true
    echo "[OK] 已回滚"
    exit 1
fi

# ============================================
echo ""
echo "[7/7] 启动服务..."
echo "-------------------------------------------"

systemctl start "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "[OK] 服务启动成功"
    echo ""
    echo "=========================================="
    echo "  更新完成！"
    echo "=========================================="
    echo ""
    echo "  服务状态: running"
    echo "  备份位置: $BACKUP_DIR"
    echo ""
    echo "  回滚命令:"
    echo "    systemctl stop $SERVICE_NAME"
    echo "    cp $BACKUP_DIR/ops-server $INSTALL_DIR/"
    echo "    cp $BACKUP_DIR/ops-supervisor $INSTALL_DIR/"
    echo "    cp $BACKUP_DIR/index.html $INSTALL_DIR/"
    echo "    cp -r $BACKUP_DIR/assets $INSTALL_DIR/"
    echo "    systemctl start $SERVICE_NAME"
    echo ""
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo ""
else
    echo "[ERROR] 服务启动失败，回滚中..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-server" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-supervisor" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/index.html" "$INSTALL_DIR/" 2>/dev/null || true
    cp -r "$BACKUP_DIR/assets" "$INSTALL_DIR/" 2>/dev/null || true
    systemctl start "$SERVICE_NAME" 2>/dev/null || true
    echo "[OK] 已回滚"
    echo "[INFO] 日志: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
