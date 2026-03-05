# iterlife-expenses 后端代码解读与评审（拆分后）

本文档聚焦 `iterlife-expenses` 后端仓库。前端已拆分为独立仓库：
`/Users/iter_1024/repository/iterlife-expenses-ui`。

## 1. 仓库定位

- 职责：认证、鉴权、消费数据查询与聚合、健康检查、Docker 部署脚本
- 技术栈：FastAPI + PyMySQL + JWT（python-jose）+ Passlib(bcrypt)
- 数据库基线：`iterlife_reunion`
- 用户管理表基线：`iterlife_user`（环境变量 `AUTH_USER_TABLE`）

## 2. 后端主链路

启动与配置：

- 入口：`backend/app/main.py`
- 配置：`backend/app/core/config.py`
- 环境：按 `APP_ENV` 加载 `.env.<APP_ENV>`

API：

- 认证：`/api/auth/login`、`/api/auth/me`
- 业务：`/api/expenses/{summary,monthly,categories,payment-methods,timeline,stardust}`
- 健康：`/api/health`、`/health`

鉴权：

- OAuth2PasswordBearer + JWT
- token payload 含 `sub` 与 `user_id`
- 管理员与普通用户的数据访问范围隔离

## 3. 数据访问与风险点

现状：

- 使用 `pymysql` 直连数据库
- 用户表改为可配置（默认 `iterlife_user`）

主要风险：

1. 无连接池，峰值下连接抖动风险较高
2. SQL 与字段约束对历史脏数据容忍度有限
3. 生产配置项缺失时容易在登录链路暴露为 500

## 4. 部署流程（标准化后）

`deploy-expenses-stack.sh`：

1. 校验 Docker / Compose 与配置文件
2. 基于 `deploy/docker-compose.example.yml` 构建并启动 API/UI
3. 对 API 与 UI 进行健康检查

`deploy-expenses-from-github.sh`：

1. 备份双仓库代码到 `/home/openclaw-expenses/backups/openclaw-expenses_YYYYMMDD-HHMMSS`
2. 后端与前端分别更新到 `origin/$DEPLOY_BRANCH`
3. 采用 `git pull --ff-only`（禁止 `reset --hard origin/master` 作为标准流程）
4. 调用 `deploy-expenses-stack.sh` 重建容器

统一发布规则：

1. 必须先在 GitHub 合并（默认 `master`）
2. 服务器再执行标准更新脚本
3. `rsync` 仅可用于应急，不可作为常规发布方式

## 5. 配置隔离原则

1. 运行配置放在仓库外：`/apps/config/iterlife-expenses/*`
2. 仓库只保留模板：`backend/.env.*.example`、`deploy/docker-compose.example.yml`
3. 禁止提交真实密码、密钥、证书

## 6. 拆分后建议

1. 后端与前端通过 API 合约协作，避免跨仓库耦合改动
2. 为关键接口补齐冒烟测试（至少覆盖登录、健康检查、核心查询）
3. 引入数据库连接池（如 SQLAlchemy engine pool）降低高并发风险
