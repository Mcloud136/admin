# 运维管理平台

企业级运维工单管理系统，用于管理工单流转、工程师绩效、项目进度、团队协作、知识库沉淀等。

## 功能特性

### 工单管理
- 全生命周期：创建 → 派单 → 处理 → 完单 → 验收 → 归档
- 工单类型：故障、变更、请求、巡检
- 优先级：紧急(P0)、重大(P1)、严重(P2)、普通(P3) — 自动 SLA 计时
- 派单/转派、挂起/恢复、进度上报、流转日志
- 完单报告（解决方案、根因分析、处理结果、影响范围）
- 文件上传（类型白名单、50MB 大小限制）

### 项目管理
- 项目信息：自动编号、类型、优先级、需求方、负责人、成员、预算
- 项目成员管理、关联工单
- 状态流转：进行中 → 待验收 → 整改中 → 已完成
- 工程师仅可查看/编辑自己负责或参与的项目

### 知识库
- TipTap 富文本编辑器（粗体/斜体/标题/列表/引用/代码块/图片/对齐）
- 上传文档自动解析（Word → HTML、Excel → 表格、文本 → 原文）
- 粘贴/拖拽图片、图片缩放手柄
- 中文分类管理（8 个默认分类）
- 文件预览（Word/Excel/文本）

### 自动评分
- 响应及时性、处理效率、SLA 达成率、工单质量、知识贡献
- 评分权重可在系统设置中调整
- 月度汇总评分

### 通知中心
- 工单派发/状态变更通知
- 未读计数、全部已读、删除通知

### 系统设置
- SLA 规则配置（按优先级设置响应/解决时限）
- 评分维度权重调整
- 通知触发规则开关
- 品牌定制（平台名称、公司名称、Logo、登录背景）

### 安装向导
- 首次访问自动进入安装向导
- 自动创建数据库和表结构
- 设置管理员账号密码
- 配置品牌信息
- 安装锁定文件防重复安装

## 快速部署

### 环境要求

| 项目 | 最低 | 推荐 |
|------|------|------|
| 系统 | Ubuntu 20.04 / Debian 11 / CentOS 7 | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核 |
| 内存 | 2 GB | 4 GB |
| 硬盘 | 40 GB SSD | 80 GB SSD |
| 数据库 | PostgreSQL 12+ | PostgreSQL 15+ |

### 一键安装（推荐）

```bash
# 下载项目文件到服务器任意目录
# 国内（含国内镜像源配置）
sudo bash install-cn.sh

# 海外
sudo bash install.sh
```

安装脚本自动完成：
1. 配置国内镜像源（中文版）
2. 安装 Nginx + PostgreSQL
3. 部署项目文件到 `/opt/ops-platform`
4. 创建数据库
5. 配置 Nginx 反向代理
6. 配置 systemd 守护进程服务

安装完成后访问服务器 IP，按安装向导提示完成初始化。

### 手动部署

```bash
# 1. 创建目录
mkdir -p /opt/ops-platform/uploads/branding
mkdir -p /opt/ops-platform/uploads/kb

# 2. 上传所有文件到 /opt/ops-platform/

# 3. 设置权限
chmod +x /opt/ops-platform/ops-server
chmod +x /opt/ops-platform/ops-supervisor

# 4. 创建数据库
sudo -u postgres psql -c "CREATE DATABASE ops_platform ENCODING 'UTF8';"

# 5. 配置 Nginx（见下方配置）

# 6. 配置 systemd 服务（见下方配置）

# 7. 访问 http://你的IP 完成安装向导
```

## 配置说明

### 环境变量（.env）

```env
SERVER_PORT=8080
GIN_MODE=release

DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=你的密码
DB_NAME=ops_platform
DB_SSLMODE=disable

# 连接池（可选）
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=10
DB_MAX_LIFETIME_SEC=300
DB_MAX_IDLE_SEC=180

# JWT（生产环境必须设置，至少 32 位随机字符串）
JWT_SECRET=your-random-secret-key-here
JWT_EXPIRE_HOUR=24

# CORS（可选，默认允许 localhost:3000 和 localhost:8080）
CORS_ORIGIN_1=https://your-domain.com
CORS_ORIGIN_2=
```

### Nginx 配置

```nginx
server {
    listen 80;
    server_name 你的域名或IP;

    root /opt/ops-platform;
    index index.html;

    client_max_body_size 50m;

    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:8080/uploads/;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1024;
}
```

### systemd 服务

```ini
[Unit]
Description=Ops Platform Supervisor
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ops-platform
ExecStart=/opt/ops-platform/ops-supervisor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 更新升级

```bash
# 进入安装目录
cd /opt/ops-platform

# 国内服务器（使用镜像加速）
sudo bash update-cn.sh

# 海外服务器
sudo bash update.sh
```

更新脚本自动完成：
1. 备份当前版本到 `/opt/ops-platform-backup-时间戳/`
2. 下载最新文件
3. 仅替换二进制和前端文件
4. **保留** `.env`、`uploads/`、`.initialized`、数据库
5. 重启服务
6. 失败自动回滚

## 服务管理

```bash
systemctl start ops-platform     # 启动
systemctl stop ops-platform      # 停止
systemctl restart ops-platform   # 重启
systemctl status ops-platform    # 查看状态
journalctl -u ops-platform -f    # 实时日志
```

## 项目结构

```
├── index.html              前端入口
├── assets/                 前端编译产物（Vue 3 + Arco Design + ECharts）
│   ├── vendor-vue-*.js     Vue 生态（107KB）
│   ├── vendor-arco-*.js    UI 组件库（790KB）
│   ├── vendor-echarts-*.js 图表库（504KB）
│   ├── vendor-tiptap-*.js  富文本编辑器（361KB）
│   └── index-*.js          业务代码
├── ops-server              后端服务（Go, Linux AMD64）
├── ops-supervisor          守护进程（自动重启 + 信号处理）
├── install.sh              一键安装脚本（英文）
├── install-cn.sh           一键安装脚本（国内版）
├── update.sh               一键更新脚本（英文）
├── update-cn.sh            一键更新脚本（国内版）
└── .env.example            环境变量模板
```

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Vue 3 + Vite + Arco Design Vue + ECharts + Pinia + TipTap |
| 后端 | Go + Gin + sqlx |
| 数据库 | PostgreSQL |
| 认证 | JWT (HS256) + bcrypt |
| 部署 | Nginx + systemd + 守护进程 |

## 安全特性

- JWT 认证 + RBAC 三级权限（管理员/主管/工程师）
- XSS 防护（DOMPurify 清洗 + HTML 转义）
- 文件上传白名单 + 大小限制（50MB）
- 路径穿越防护
- SQL 参数化查询
- 密码 bcrypt 加密（cost 12）
- CORS 可配置
- 请求 ID 追踪（X-Request-ID）
- 安装锁定文件防重复安装

## 测试账号

| 用户名 | 密码 | 角色 |
|--------|------|------|
| admin | admin123 | 管理员 |

> 生产环境请立即修改默认密码

## License

MIT
