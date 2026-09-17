# 家庭教育科研智能研究平台 v1.0.0

**Family Education Research Platform (FERP)** — AI-Powered Research Operating System

面向教育、社会科学与创业研究人员的一体化科研操作系统。首个正式发布版本，PHASE 1—9 完整闭环均已实现。

---

## 核心闭环

```
研究设计 → 问卷构建 → 数据收集 → 数据质量检测 → 统计分析
      → AI 解释 → 研究建议 → 创业洞察 → 研究报告 → 数据导出
```

---

## 本版内容（PHASE 1—9）

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| PHASE 1 | 项目初始化、数据库、登录、JWT、研究项目、Dashboard | ✅ |
| PHASE 2 | 问卷构建器、题型、逻辑、预览、发布、版本控制 | ✅ |
| PHASE 3 | 受访者端填写 UI、数据收集、来源追踪、样本管理 | ✅ |
| PHASE 4 | 数据质量检测引擎、配额管理、动态收集建议 | ✅ |
| PHASE 5 | 统计引擎：描述、信度（α）、效度（KMO/Bartlett/EFA）、相关、回归（含有序 Logistic）、组间比较、假设检验、效应量 | ✅ |
| PHASE 6 | 可视化（柱状、饼图、李克特分布、热力图、箱线图、散点、回归图、漏斗、配额进度、来源渠道） | ✅ |
| PHASE 7 | DeepSeek AI 研究助手、Evidence Trace、四层解释分层、反幻觉数值校验 | ✅ |
| PHASE 8 | 研究报告生成器（23 章）、Excel / CSV / JSON / SPSS 导出 | ✅ |
| PHASE 9 | Competition Mode 创业洞察（九区块，有界推断） | ✅ |

---

## 技术栈与选型依据

| 期望技术 | 实测结果 | 实际采用 |
| --- | --- | --- |
| Python + FastAPI | 不可用（PyPI 与镜像站 TLS 连接失败） | **Node.js 24 + TypeScript + Express** |
| PostgreSQL | 不可用（无服务端、无 Docker） | **SQLite（Node 内置 `node:sqlite`）** |
| Docker | 不可用 | 本地脚本（build / serve / dev） |
| pandas / statsmodels / factor_analyzer | 不可用（无 PyPI） | **纯 TypeScript 统计引擎**，统计量逐一单元测试手工核对 |
| Vite | 不可用（依赖 esbuild JS API，子进程被拦截） | **esbuild CLI 打包** |
| React 19 · TS 5.9 · Tailwind 3.4 | 可用 | 已采用 |
| ECharts / Recharts | 可用但刻意未采用 | **手写零依赖 SVG 图表组件**（10 类），每个数值渲染为真实可读文本 |
| shadcn/ui | 可用但刻意未采用 | 自建 Tailwind 组件（`components/ui.tsx`） |

> 约束说明：若环境不支持某技术，则选用稳定等价方案——以上替换均属预期内的降级方案。SQL 全部写成可移植形式（TEXT/INTEGER/REAL），迁移至 PostgreSQL 时无需重写调用点。

---

## 测试

| 套件 | 数量 | 覆盖内容 |
| --- | --- | --- |
| `@ferp/shared` | 369 | 58 题模板结构、15 个核心变量、跳转逻辑、计分、变量字典、校验、质量与配额引擎、完整统计引擎 |
| `@ferp/server` | 429 | 迁移与约束、scrypt/JWT 安全边界、认证、项目 CRUD、数据隔离、构建器全题型、发布与版本控制、仪表盘、采集闭环、样本与渠道、质量与配额 API、统计分析 API、AI 助手（含反幻觉校验与降级）、报告、导出、创业洞察 |
| `@ferp/web` | 162 | jsdom 真实挂载：登录/注册交互、十种题型渲染、路由、API 错误处理、受访者端完整作答旅程（逐题 + 整页两套版式）、十类图表与八个分析控制台页、AI 助手、23 章报告页、导出页、洞察页 |
| `scripts/e2e-smoke.mjs` | 308 | 对运行中服务的真实验证，可重复运行 |

```bash
npm test        # 960 项
npm run e2e     # 308 项（需 API 运行中）
npm run verify  # typecheck + test + build
```

**发布前实测**：`npm test` 在干净的源码包上完整重跑通过（三个 workspace 依次执行，退出码 0；其中 `@ferp/web` 单套件 162 项全部通过、0 失败、0 跳过，耗时约 41s）。发布前的可移植性预检（大小写敏感 import、原生依赖 Linux 覆盖、硬编码 Windows 路径、Shell 行尾）亦全部通过。

---

## 数据诚信约束（代码层面强制）

- **无密钥时的诚实降级**：未配置 `DEEPSEEK_API_KEY` 时不编造输出、也不返回 500，而是返回 `mode: 'degraded'` 并给出**完全由统计引擎推导**的中文摘要（样本构成、描述统计、信度 α 及判定阈值、显著相关及效应量、组间比较、回归结果、假设结论统计），标注 `derived_by: 'statistical_engine'`、`ai_generated: false`。
- **反幻觉数值校验**：AI 输出中的数值须能在证据包中回查，否则该声明被拦截并在界面标注。
- **文献章节不编造**：离线运行、无文献数据库，第 5 章（文献与理论依据）与第 23 章（参考文献与附录）恒为「不可用 + 原因」。

---

## 已知限制（如实记录，未隐藏）

- **两份文献类章节无法生成**，需研究者自行补充。
- **`UI`（AI 使用意愿）按等距测量处理**：题级定义为李克特题，默认回归用 OLS；有序 Logistic 已实现并有端到端覆盖，如需改动请调整该题计分规则——平台不会替研究者改动测量层次。
- **箱线图用「均值 ± 1 SD」呈现**：组间比较接口未返回中位数与四分位，图表如实标注「不是四分位距」，而非画出假的四分位。
- **无头浏览器不可用**：UI 以 jsdom 真实挂载 + DOM 文本断言验证，无像素级截图验证。
- **Docker 未提供**：仓库不包含未经实测的 `docker-compose.yml`。
- **整页模式对「纯跳转」规则的处理**：仅用 `jump_to` 跳过题目、未配套显示规则的问卷，两种版式取数会不同；用跳转规则设计分支时请同时为被跳过的题设置显示条件。

---

## 快速开始

```bash
# 1. 安装依赖
npm install --ignore-scripts

# 2. 初始化数据库并写入演示账号（密码仅在终端打印一次）
npm run db:reset
npm run db:seed

# 3. 构建
npm run build

# 4. 启动（两个终端）
npm run dev:server       # API   → http://127.0.0.1:4000
npm run dev:web          # 控制台 → http://127.0.0.1:5173
```

**环境要求**：Node.js ≥ 22.5.0（`node:sqlite` 为内置模块）。

首次运行前请复制 `.env.example` 为 `.env` 并设置 `JWT_SECRET`（≥ 32 字符，生产环境未设置会拒绝启动）。

---

## 发布资产

| 文件 | 说明 |
| --- | --- |
| `family-edu-research-platform-v1.0.0.zip` | 源码包（Windows 友好） |
| `family-edu-research-platform-v1.0.0.tar.gz` | 源码包（Linux / macOS 友好） |
| `SHA256SUMS.txt` | 校验和 |

源码包**不含** `node_modules/`、构建产物 `dist/`、本地数据库 `data/` 与日志。安装前请先执行 `npm install`。

---

## 安全说明

本版本相对工作副本做了两处发布前加固：

1. `start-public.bat` 中原先硬编码的真实 `JWT_SECRET` 已移除，改为**必须由环境变量提供**，缺失时脚本报错退出；同时新增 `.env.example` 说明所有配置项。
2. 该脚本中原先写死的个人绝对路径（`C:\Users\...`）已改为基于脚本自身位置的相对路径（`cd /d "%~dp0"`），并支持 `FERP_NODE` / `FERP_CLOUDFLARED` 覆盖，使包可在任意目录运行。

> 若原工作副本中的那个 JWT 密钥曾用于对外提供服务，请**立即轮换**。

---

## 完整文档

- `README.md` — 功能、架构、API 一览、测试与已知限制
- `DEPLOY.md` — 生产部署、反向代理、环境变量与故障排查
