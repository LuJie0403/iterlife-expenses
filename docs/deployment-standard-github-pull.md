# iterlife-expenses 标准部署指南（GitHub 合并后服务器部署）

最后更新：2026-03-04

适用项目：
- 后端：`iterlife-expenses`
- 前端：`iterlife-expenses-ui`

## 1. 标准流程（唯一）

1. 本地开发并提交到功能分支
2. push 到 GitHub 并发起 PR
3. PR 合并到发布分支（默认 `main`）
4. 登录服务器执行更新脚本（脚本内部执行 `git pull --ff-only`）
5. Docker 重建与健康检查

禁止作为标准流程：
- 禁止以 `rsync` 直接覆盖服务器代码进行常规发布
- 禁止长期在服务器手改代码后不回补 GitHub

## 2. 目录规范（服务器）

```text
/apps/
  ├─ iterlife-expenses/                  # 后端代码仓库（含部署脚本）
  ├─ iterlife-expenses-ui/               # 前端代码仓库
  ├─ config/
  │   └─ iterlife-expenses/
  │       ├─ backend.env                 # 后端配置（不入库）
  │       ├─ ui.env                      # 前端配置（不入库）
  │       └─ ui-runtime-config.js        # 前端运行时 API 地址（不入库）
  └─ openclaw-expenses/backups/          # 代码备份目录
```

## 3. 配置准备（首次）

```bash
mkdir -p /apps/config/iterlife-expenses
cp /apps/iterlife-expenses/backend/.env.production.example /apps/config/iterlife-expenses/backend.env
cp /apps/iterlife-expenses-ui/.env.example /apps/config/iterlife-expenses/ui.env
cp /apps/iterlife-expenses-ui/runtime-config.example.js /apps/config/iterlife-expenses/ui-runtime-config.js
chmod 600 /apps/config/iterlife-expenses/backend.env /apps/config/iterlife-expenses/ui.env /apps/config/iterlife-expenses/ui-runtime-config.js
```

## 4. 脚本说明

- `deploy-expenses-stack.sh`
  - 仅执行 Docker 构建/启动与健康检查
  - 不拉代码
- `deploy-expenses-from-github.sh`
  - 先更新后端与前端仓库到 `origin/$DEPLOY_BRANCH`
  - 使用 `git pull --ff-only` 防止非线性合并
  - 再调用 `deploy-expenses-stack.sh`

## 5. 发布命令

```bash
cd /apps/iterlife-expenses
DEPLOY_BRANCH=main bash deploy-expenses-from-github.sh
```

常用参数：
- `DEPLOY_BRANCH`：发布分支（默认 `main`）

- `ALLOW_DIRTY`：是否允许本地有未提交变更（默认 `false`）
- `SKIP_CODE_BACKUP`：是否跳过发布前备份（默认 `false`）

## 6. 端口与反代

默认端口绑定：
- API: `127.0.0.1:18180 -> container:8000`
- UI: `127.0.0.1:13180 -> container:80`

Nginx 反代：
- `/api/* -> 127.0.0.1:18180/api/*`
- `/* -> 127.0.0.1:13180/*`

## 7. 验证

```bash
curl -sS https://expenses.iterlife.com/api/health
curl -I https://expenses.iterlife.com
```

## 8. 回滚建议

1. GitHub 回滚到上一个稳定提交（revert）
2. 服务器重新执行：`DEPLOY_BRANCH=main bash deploy-expenses-from-github.sh`
3. 必要时结合 Docker 历史镜像回滚
