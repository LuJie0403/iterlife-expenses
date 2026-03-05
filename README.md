# iterlife-expenses

`iterlife-expenses` 是后端独立工作区（FastAPI + MySQL + JWT）。
前端已拆分到独立工作区：`/Users/iter_1024/repository/iterlife-expenses-ui`。

## Config Isolation Rule

- 真实运行配置必须放在仓库外（例如 `/apps/config/iterlife-expenses/*`）。
- 仓库内只保留模板（`*.example`、`deploy/docker-compose.example.yml`）。
- 严禁提交数据库密码、生产密钥、私钥等敏感信息。

## 后端主链路

- 入口：`backend/app/main.py`
- 健康检查：`GET /health`、`GET /api/health`
- 默认数据库：`iterlife_reunion`
- 默认用户表：`iterlife_user`（可通过 `AUTH_USER_TABLE` 覆盖）

## Docker 部署（推荐）

```bash
cd /Users/iter_1024/repository/iterlife-expenses
bash deploy-expenses-stack.sh
```

`deploy-expenses-stack.sh` 会：

1. 使用 `deploy/docker-compose.example.yml` 构建并启动 API/UI 容器
2. 从仓库外加载 `backend.env`、`ui.env` 与 `ui-runtime-config.js`
3. 执行 API 与 UI 健康检查

更新部署：

```bash
bash deploy-expenses-from-github.sh
```

`deploy-expenses-from-github.sh` 会先备份双仓库代码，再同步 `origin/$DEPLOY_BRANCH` 后重建容器。

## 配置文件（仓库外）

默认路径：`/apps/config/iterlife-expenses`

- `backend.env`：后端运行配置
- `ui.env`：前端容器环境（可为空模板）
- `ui-runtime-config.js`：前端运行时 API 地址配置

## 本地后端开发（非 Docker）

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
cp .env.development.example .env.development
APP_ENV=development uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```
