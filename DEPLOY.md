# 宝塔面板部署指南

## 一、服务器要求

| 项目 | 最低配置 | 推荐配置 |
|------|---------|---------|
| 操作系统 | CentOS 7.6+ / Ubuntu 20.04+ / Debian 11+ | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核 |
| 内存 | 2 GB | 4 GB |
| 硬盘 | 40 GB SSD | 80 GB SSD |
| 带宽 | 3 Mbps | 5 Mbps+ |

---

## 二、安装宝塔面板

### CentOS / RHEL
```bash
yum install -y wget && wget -O install.sh https://download.bt.cn/install/install_6.0.sh && sh install.sh ed8484bec
```

### Ubuntu / Debian
```bash
wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh ed8484bec
```

安装完成后记录外网面板地址、用户名、密码，登录面板。

---

## 三、宝塔应用商店安装软件

登录宝塔面板 → **软件商店** → 搜索安装以下应用：

| 序号 | 软件名称 | 版本 | 用途 |
|------|---------|------|------|
| 1 | **Nginx** | 1.24+ | 反向代理 + 前端静态文件托管 |
| 2 | **PostgreSQL** | 15 或 16 | 数据库 |
| 3 | **Node.js 版本管理器** | 最新 | 安装 Node.js 运行环境 |
| 4 | **PM2 管理器** | 最新 | Node.js 进程管理（可选） |

> 全部在宝塔软件商店内点击安装，无需手动下载或编译。

### 3.1 安装 Node.js

软件商店 → **Node.js 版本管理器** → 安装后打开：

1. 点击 **版本管理**
2. 安装 **Node.js 22.x**（LTS）
3. 设置为默认版本

验证：
```bash
node -v    # 应显示 v22.x.x
npm -v     # 应显示 10.x.x
```

### 3.2 确认 PostgreSQL 运行

软件商店 → **PostgreSQL** → 确认状态为 **运行中**

记录 PostgreSQL 的 postgres 用户密码（安装时设置的）。

---

## 四、本地编译后端（在你的电脑上操作）

服务器不需要安装 Go。在本地电脑编译好二进制文件后上传到服务器。

### 4.1 本地安装 Go

前往 https://go.dev/dl/ 下载安装 Go 1.22+

### 4.2 编译 Linux 二进制

```bash
# 进入后端项目目录
cd ops-platform

# 安装依赖
go mod tidy

# 编译 Linux AMD64 版本
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ops-server ./cmd/server/

# 编译完成后会生成 ops-server 文件（约 10-15MB）
```

> Windows 用户在 PowerShell 中执行：
> ```powershell
> $env:CGO_ENABLED="0"; $env:GOOS="linux"; $env:GOARCH="amd64"; go build -o ops-server.exe ./cmd/server/
> ```

### 4.3 上传文件到服务器

通过宝塔面板 **文件管理** 或 SFTP 上传以下文件到服务器 `/opt/ops-platform/`：

```
需要上传的文件清单：
├── ops-server                    # 编译好的二进制（约10-15MB）
├── .env.example                  # 环境配置模板
├── migrations/                   # 数据库迁移脚本
│   ├── 001_init.sql
│   ├── 002_project_enhance.sql
│   └── 003_knowledge_base.sql
└── web/                          # 前端源码（未编译）
    ├── src/
    ├── package.json
    ├── package-lock.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── tsconfig.node.json
    └── index.html
```

---

## 五、服务器端配置

### 5.1 创建项目目录

宝塔面板 → **文件** → 进入 `/opt` 目录 → 新建文件夹 `ops-platform`

### 5.2 配置环境变量

在 `/opt/ops-platform/` 下新建 `.env` 文件：

```env
SERVER_PORT=8080
GIN_MODE=release

DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=你的PostgreSQL密码
DB_NAME=ops_platform
DB_SSLMODE=disable

JWT_SECRET=替换为随机字符串（至少32位）
JWT_EXPIRE_HOUR=24
```

生成 JWT Secret：
```bash
openssl rand -base64 32
```

### 5.3 设置文件权限

```bash
chmod +x /opt/ops-platform/ops-server
mkdir -p /opt/ops-platform/uploads
chmod 755 /opt/ops-platform/uploads
```

---

## 六、创建数据库

### 6.1 宝塔面板操作

1. 软件商店 → **PostgreSQL** → 点击 **管理**
2. 进入 PostgreSQL 管理界面
3. 点击 **数据库列表** → **创建数据库**
   - 数据库名：`ops_platform`
   - 编码：`UTF8`
   - 排序规则：`en_US.UTF-8`

### 6.2 导入表结构

在宝塔 PostgreSQL 管理界面中，点击 **SQL执行器** 或使用命令行：

```bash
# 方法一：宝塔 SQL 执行器
# 分别打开以下文件内容，粘贴执行：
# /opt/ops-platform/migrations/001_init.sql
# /opt/ops-platform/migrations/002_project_enhance.sql
# /opt/ops-platform/migrations/003_knowledge_base.sql

# 方法二：命令行（如果宝塔有终端）
sudo -u postgres psql -d ops_platform -f /opt/ops-platform/migrations/001_init.sql
sudo -u postgres psql -d ops_platform -f /opt/ops-platform/migrations/002_project_enhance.sql
sudo -u postgres psql -d ops_platform -f /opt/ops-platform/migrations/003_knowledge_base.sql
```

### 6.3 插入管理员账号

```bash
# 进入宝塔 PostgreSQL 管理 → SQL执行器，执行：
INSERT INTO users (username, password, real_name, email, role, status)
VALUES ('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Admin', 'admin@example.com', 'admin', 1);
```

> 以上哈希对应密码 `admin123`，登录后请立即修改。

---

## 七、编译前端

### 7.1 宝塔终端操作

```bash
cd /opt/ops-platform/web

# 安装依赖
npm install

# 编译生产版本
npm run build
```

编译产物在 `web/dist/` 目录。

### 7.2 复制到网站目录

```bash
mkdir -p /www/wwwroot/ops-platform
cp -r /opt/ops-platform/web/dist/* /www/wwwroot/ops-platform/
```

---

## 八、配置 Nginx 网站

### 8.1 宝塔面板添加站点

1. **网站** → **添加站点**
2. 填写：
   - 域名：`你的域名` 或 `服务器IP`
   - 根目录：`/www/wwwroot/ops-platform`
   - PHP版本：**纯静态**（不需要 PHP）
3. 点击提交

### 8.2 配置反向代理

1. 点击站点名 → **反向代理** → **添加反向代理**
2. 填写：
   - 代理名称：`api`
   - 目标URL：`http://127.0.0.1:8080`
   - 发送域名：`$host`
3. 点击提交

### 8.3 编辑 Nginx 配置

点击站点名 → **配置文件**，将内容替换为：

```nginx
server {
    listen 80;
    server_name 你的域名或IP;

    # 前端静态文件
    root /www/wwwroot/ops-platform;
    index index.html;

    # 文件上传大小限制
    client_max_body_size 50m;

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Swagger 文档
    location /swagger/ {
        proxy_pass http://127.0.0.1:8080/swagger/;
        proxy_set_header Host $host;
    }

    # Vue Router history 模式
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    gzip_min_length 1024;
}
```

点击 **保存** → **重载配置**。

---

## 九、配置 systemd 服务（后端持久运行）

### 9.1 宝塔终端操作

```bash
cat > /etc/systemd/system/ops-platform.service << 'EOF'
[Unit]
Description=Ops Platform Backend
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ops-platform
ExecStart=/opt/ops-platform/ops-server
Restart=always
RestartSec=5
Environment=GIN_MODE=release

[Install]
WantedBy=multi-user.target
EOF
```

### 9.2 启动服务

```bash
systemctl daemon-reload
systemctl enable ops-platform
systemctl start ops-platform

# 检查状态
systemctl status ops-platform
```

### 9.3 查看日志

```bash
journalctl -u ops-platform -f
```

---

## 十、SSL 证书配置（推荐）

1. 宝塔面板 → **网站** → 点击站点名 → **SSL**
2. 选择 **Let's Encrypt**
3. 勾选域名 → **申请**
4. 开启 **强制 HTTPS**

---

## 十一、防火墙放行

宝塔面板 → **安全** → **防火墙** → 添加规则：

| 端口 | 说明 |
|------|------|
| 80 | HTTP |
| 443 | HTTPS |
| 8888 | 宝塔面板（建议限制 IP） |

---

## 十二、验证部署

1. 浏览器访问 `http://你的域名`
2. 应看到登录页面
3. 使用 `admin / admin123` 登录
4. 访问 `http://你的域名/swagger/index.html` 查看 API 文档

---

## 十三、后续更新流程

### 更新后端

```bash
# 本地重新编译
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ops-server ./cmd/server/

# 上传 ops-server 覆盖服务器上的文件

# 服务器重启服务
systemctl restart ops-platform
```

### 更新前端

```bash
# 本地或服务器上重新编译
cd /opt/ops-platform/web
npm install
npm run build

# 复制到网站目录
cp -r dist/* /www/wwwroot/ops-platform/

# 无需重启，刷新浏览器即可
```

### 更新数据库

```bash
# 执行新的迁移脚本
sudo -u postgres psql -d ops_platform -f /opt/ops-platform/migrations/新文件.sql
```

---

## 十四、数据备份

### 14.1 宝塔面板备份

宝塔 → **计划任务** → 添加任务：

| 类型 | 周期 | 说明 |
|------|------|------|
| 备份数据库 | 每天 03:00 | 选择 PostgreSQL → ops_platform |
| 备份网站 | 每天 03:30 | 选择站点 → ops-platform |

### 14.2 上传文件备份

```bash
# 定时备份上传文件（添加到计划任务）
tar -czf /opt/backups/uploads_$(date +%Y%m%d).tar.gz /opt/ops-platform/uploads/
find /opt/backups -name "uploads_*.tar.gz" -mtime +30 -delete
```

---

## 十五、常见问题

### Q: 后端启动失败

```bash
# 查看日志
journalctl -u ops-platform --no-pager -n 50

# 常见原因
# 1. 数据库连接失败 → 检查 .env 中的数据库密码
# 2. 端口被占用 → netstat -tlnp | grep 8080
# 3. 权限问题 → chmod +x ops-server
```

### Q: 前端白屏

```bash
# 检查文件是否存在
ls /www/wwwroot/ops-platform/index.html

# 检查 Nginx 错误日志
tail -f /www/wwwlogs/ops-platform.error.log

# 检查 Nginx 配置
nginx -t
```

### Q: API 请求 404

```bash
# 检查后端是否运行
systemctl status ops-platform

# 检查反向代理配置
cat /www/server/panel/vhost/nginx/ops-platform.conf

# 测试后端直接访问
curl http://127.0.0.1:8080/api/login -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'
```

### Q: 文件上传失败

```bash
# 检查上传目录权限
ls -la /opt/ops-platform/uploads/
chmod 755 /opt/ops-platform/uploads/

# 检查 Nginx 上传大小限制
# 确保配置了 client_max_body_size 50m;
```

### Q: 忘记管理员密码

```bash
# 重新生成密码哈希（在本地执行）
# 或直接重置数据库密码
sudo -u postgres psql -d ops_platform -c "
UPDATE users SET password = '\$2a\$10\$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy'
WHERE username = 'admin';
"
# 重置后密码为 admin123
```

---

## 十六、部署架构图

```
用户浏览器
    │
    ▼
┌─────────────────────────────────┐
│         Nginx (宝塔)             │
│  :80 / :443                     │
│  ┌─────────────┐  ┌──────────┐  │
│  │ 静态文件     │  │ 反向代理  │  │
│  │ /www/.../    │  │ → :8080  │  │
│  └─────────────┘  └──────────┘  │
└─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────┐
│     ops-server (Go 二进制)       │
│  :8080                          │
│  systemd 管理，开机自启          │
└────────┬────────────┬───────────┘
         │            │
         ▼            ▼
┌──────────────┐  ┌──────────────┐
│ PostgreSQL   │  │  本地文件     │
│ (宝塔管理)    │  │  uploads/    │
│ ops_platform │  │              │
└──────────────┘  └──────────────┘
```

---

## 十七、快速检查清单

- [ ] 宝塔面板安装完成
- [ ] Nginx 安装并运行
- [ ] PostgreSQL 安装并运行
- [ ] Node.js 22.x 安装
- [ ] 数据库 `ops_platform` 创建
- [ ] 三份迁移脚本执行完成
- [ ] 管理员账号创建
- [ ] `.env` 配置完成
- [ ] `ops-server` 上传并设置可执行权限
- [ ] `ops-platform.service` 创建并启动
- [ ] 前端编译并部署到 Nginx 目录
- [ ] Nginx 反向代理配置完成
- [ ] SSL 证书配置（可选）
- [ ] 防火墙放行 80/443
- [ ] 登录页面可访问
- [ ] API 文档可访问 `/swagger`
