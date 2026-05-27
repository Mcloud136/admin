#!/bin/bash
set -e

# ============================================
# 运维管理平台 - 更新脚本
# 从 GitHub 拉取最新版本，保留数据库和用户数据
# ============================================

INSTALL_DIR="/opt/ops-platform"
BACKUP_DIR="/opt/ops-platform-backup-$(date +%Y%m%d%H%M%S)"
REPO="Mcloud136/admin"
BRANCH="main"
SERVICE_NAME="ops-platform"

echo "=========================================="
echo "  运维管理平台 - 更新脚本"
echo "=========================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 权限运行: sudo bash update.sh"
    exit 1
fi

# Check install dir exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo "[ERROR] 安装目录不存在: $INSTALL_DIR"
    echo "        请先运行 install.sh 安装"
    exit 1
fi

echo "[INFO] 安装目录: $INSTALL_DIR"
echo "[INFO] 备份目录: $BACKUP_DIR"
echo ""

# ============================================
echo "[1/6] 备份当前版本..."
echo "-------------------------------------------"

mkdir -p "$BACKUP_DIR"
cp "$INSTALL_DIR/ops-server" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/ops-supervisor" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$INSTALL_DIR/assets" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/index.html" "$BACKUP_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/.env" "$BACKUP_DIR/" 2>/dev/null || true
echo "[OK] 备份完成: $BACKUP_DIR"

# ============================================
echo ""
echo "[2/6] 停止服务..."
echo "-------------------------------------------"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl stop "$SERVICE_NAME"
    echo "[OK] 服务已停止"
else
    echo "[INFO] 服务未运行，跳过"
fi

# ============================================
echo ""
echo "[3/6] 下载最新版本..."
echo "-------------------------------------------"

DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
TEMP_DIR=$(mktemp -d)

echo ">> 下载: $DOWNLOAD_URL"
if command -v curl &> /dev/null; then
    curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/source.tar.gz"
elif command -v wget &> /dev/null; then
    wget -q "$DOWNLOAD_URL" -O "$TEMP_DIR/source.tar.gz"
else
    echo "[ERROR] 需要 curl 或 wget"
    exit 1
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
echo "[4/6] 更新文件..."
echo "-------------------------------------------"

# 更新后端二进制
echo ">> 更新 ops-server"
cp "$EXTRACTED_DIR/ops-server" "$INSTALL_DIR/ops-server"
chmod +x "$INSTALL_DIR/ops-server"

echo ">> 更新 ops-supervisor"
cp "$EXTRACTED_DIR/ops-supervisor" "$INSTALL_DIR/ops-supervisor"
chmod +x "$INSTALL_DIR/ops-supervisor"

# 更新前端文件
echo ">> 更新前端文件"
cp "$EXTRACTED_DIR/index.html" "$INSTALL_DIR/index.html"
rm -rf "$INSTALL_DIR/assets"
cp -r "$EXTRACTED_DIR/assets" "$INSTALL_DIR/assets"

# 更新安装脚本（不影响运行）
cp "$EXTRACTED_DIR/install.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$EXTRACTED_DIR/install-cn.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "[OK] 文件更新完成"

# ============================================
echo ""
echo "[5/6] 验证文件..."
echo "-------------------------------------------"

ERRORS=0

if [ ! -f "$INSTALL_DIR/ops-server" ]; then
    echo "[ERROR] ops-server 不存在"
    ERRORS=$((ERRORS + 1))
fi

if [ ! -f "$INSTALL_DIR/ops-supervisor" ]; then
    echo "[ERROR] ops-supervisor 不存在"
    ERRORS=$((ERRORS + 1))
fi

if [ ! -f "$INSTALL_DIR/index.html" ]; then
    echo "[ERROR] index.html 不存在"
    ERRORS=$((ERRORS + 1))
fi

if [ ! -d "$INSTALL_DIR/assets" ]; then
    echo "[ERROR] assets 目录不存在"
    ERRORS=$((ERRORS + 1))
fi

# 验证关键文件未被覆盖
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "[WARN] .env 文件不存在（首次安装后应由安装向导生成）"
fi

if [ -f "$INSTALL_DIR/.initialized" ]; then
    echo "[OK] .initialized 存在，安装状态保留"
else
    echo "[INFO] .initialized 不存在（首次安装尚未完成）"
fi

if [ -d "$INSTALL_DIR/uploads" ]; then
    UPLOAD_COUNT=$(find "$INSTALL_DIR/uploads" -type f | wc -l)
    echo "[OK] uploads/ 目录保留（${UPLOAD_COUNT} 个文件）"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "[ERROR] 发现 $ERRORS 个错误，正在回滚..."
    cp "$BACKUP_DIR/ops-server" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-supervisor" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/index.html" "$INSTALL_DIR/" 2>/dev/null || true
    cp -r "$BACKUP_DIR/assets" "$INSTALL_DIR/" 2>/dev/null || true
    systemctl start "$SERVICE_NAME" 2>/dev/null || true
    echo "[OK] 已回滚到备份版本"
    exit 1
fi

echo "[OK] 文件验证通过"

# ============================================
echo ""
echo "[6/6] 启动服务..."
echo "-------------------------------------------"

systemctl start "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "[OK] 服务启动成功"
    echo ""
    echo "=========================================="
    echo "  更新完成"
    echo "=========================================="
    echo ""
    echo "  服务状态: $(systemctl is-active $SERVICE_NAME)"
    echo "  备份位置: $BACKUP_DIR"
    echo ""
    echo "  如需回滚:"
    echo "    systemctl stop $SERVICE_NAME"
    echo "    cp $BACKUP_DIR/ops-server $INSTALL_DIR/"
    echo "    cp $BACKUP_DIR/ops-supervisor $INSTALL_DIR/"
    echo "    cp $BACKUP_DIR/index.html $INSTALL_DIR/"
    echo "    cp -r $BACKUP_DIR/assets $INSTALL_DIR/"
    echo "    systemctl start $SERVICE_NAME"
    echo ""
    echo "  查看日志:"
    echo "    journalctl -u $SERVICE_NAME -f"
    echo ""
else
    echo "[ERROR] 服务启动失败，正在回滚..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-server" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/ops-supervisor" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/index.html" "$INSTALL_DIR/" 2>/dev/null || true
    cp -r "$BACKUP_DIR/assets" "$INSTALL_DIR/" 2>/dev/null || true
    systemctl start "$SERVICE_NAME" 2>/dev/null || true
    echo "[OK] 已回滚到备份版本"
    echo "[INFO] 请检查日志: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
