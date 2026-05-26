# 运维管理平台

成都商惠计算机系统有限公司 - 运维人员管理平台

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/Mcloud136/admin/main/install.sh | sudo bash
```

安装完成后访问 `http://服务器IP` 进入安装向导，按提示完成配置即可。

## 功能模块

- 工单管理（创建/派单/处理/完单/验收/归档）
- 项目管理（创建/整改流程/验收）
- 工程师管理（用户/团队/权限）
- 知识库（富文本编辑/文件上传/预览）
- 资产管理（IT资产登记/关联工单）
- 自动评分（多维度绩效评估）
- 系统设置（SLA/评分权重/通知/品牌定制）

## 技术栈

| 组件 | 技术 |
|------|------|
| 前端 | Vue 3 + Arco Design + TipTap + ECharts |
| 后端 | Go + Gin + sqlx |
| 数据库 | PostgreSQL |

## 文件说明

| 文件 | 说明 |
|------|------|
| `index.html` | 前端入口 |
| `assets/` | 前端资源 |
| `ops-server` | 后端服务（Linux AMD64） |
| `ops-supervisor` | 守护进程（自动重启后端） |
| `install.sh` | 一键安装脚本 |

## 手动部署

如果不使用安装脚本：

1. 安装 Nginx 和 PostgreSQL
2. 创建数据库
3. 将 `index.html` 和 `assets/` 放到 Nginx 网站目录
4. 运行 `./ops-supervisor`（会自动启动 ops-server）
5. 配置 Nginx 反向代理 `/api/` → `http://127.0.0.1:8080`
6. 访问网站，安装向导会自动引导完成配置

## License

MIT
