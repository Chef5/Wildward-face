# 赴山野

一款面向徒步与山野出行的 **Garmin Connect IQ 圆形表盘**：以时间为视觉核心，配合罗盘刻度与四象限可配置数据，抬腕即可把握身体状态与户外环境。

Connect IQ Store：https://apps.garmin.com/apps/1d1e570b-cb90-4ef6-96e4-2b96e55de9ee?tid=0

> **Slogan**：向山野出发，为热爱前行。适配徒步、山野出行场景。聚焦海拔、心率、电量、步数四大核心数据，抬腕即刻洞悉身体状态与户外环境，自在奔赴每一场热爱！

本仓库为表盘「赴山野」的开源参考实现，代码以 [MIT 许可证](LICENSE) 发布。

---

## 功能概览

- **时间**：突出时分，可选显示秒数  
- **日期与农历**：可分别开关；仅一项开启时自动居中；两者都关闭时时间垂直居中  
- **四象限指标（可配置）**：左上 / 右上 / 左下 / 右下可选  
  - 心率 / 电量 / 步数 / 海拔 / 不展示  
  - 同一行只展示一个指标时自动居中  
- **横线分隔**：上下两条横线可开关  
- **主题色**：多套配色可选，默认「高雅紫」  

### 默认布局

| 位置 | 默认指标 |
|------|----------|
| 左上 | 海拔 |
| 右上 | 电量 |
| 左下 | 心率 |
| 右下 | 步数 |

### 表盘设置项（`properties.xml`）

| 键名 | 说明 |
|------|------|
| `AccentColor` | 主题色 |
| `ShowSeconds` | 显示秒数 |
| `ShowDate` | 显示日期 |
| `ShowLunar` | 显示农历 |
| `ShowDividers` | 显示上下横线 |
| `TopLeftMetric` / `TopRightMetric` / `BottomLeftMetric` / `BottomRightMetric` | 四象限指标 |

---

## 项目结构

```
trailhead-face/
├── manifest.xml              # Connect IQ 应用清单（入口、目标机型、API 等）
├── monkey.jungle             # 工程与资源路径（含多分辨率启动图标覆盖）
├── source/                   # Monkey C 源码
│   ├── ChefWatchFaceApp.mc   # 应用入口
│   ├── ChefWatchFaceView.mc  # 表盘绘制与逻辑
│   ├── Background.mc         # 背景绘制
│   └── LunarCalendar.mc      # 农历计算
├── resources/                # 主资源包
│   ├── strings/strings.xml   # 应用名与设置项文案
│   ├── settings/             # 表盘设置 schema 与属性定义
│   ├── drawables/            # 矢量图标、位图字体、fonts.xml / drawables.xml
│   └── layouts/layout.xml    # 布局（若使用 XML 布局）
├── resources-launcher-*-*/   # 各机型启动图标像素规格下的 launcher 资源
├── tools/
│   └── gen_lunar_font.py     # 农历中文位图字体生成脚本（见下）
├── design.md / design.svg    # 设计备忘与矢量稿（不参与编译）
└── .vscode/                  # VS Code 调试与任务配置（可选）
```

构建产物目录 `bin/`、签名密钥等已在 [`.gitignore`](.gitignore) 中排除，请勿将 **developer key（`.der`）** 提交到公开仓库。

---

## 开发与构建

### 前置条件

1. 安装 [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)，并配置好环境变量（使 `monkeyc` 等命令可用）。  
2. 使用 **Visual Studio Code** 安装官方 **Monkey C** 扩展，便于编译、模拟器与真机调试。  
3. 在扩展中配置你的 **开发者密钥**，用于本地打包与安装（密钥文件勿入库）。

### 常用工作流

- 用命令面板执行 **「Monkey C: Edit Application」** 修改应用元数据。  
- 用 **「Monkey C: Edit Products」** / **「Set Products by Product Category」** 调整 `manifest.xml` 中的目标机型。  
- 编译、运行模拟器或安装到手表，均通过扩展提供的命令完成。  

当前 `manifest.xml` 已列出多款圆形表（如 fēnix 7/8、Forerunner、epix、Venu、Instinct 3 等）；若你新增机型，可能需要在 `monkey.jungle` 中为该机补充 `resources-launcher-*` 的 `resourcePath` 规则（与现有条目同模式）。

---

## 工具：`tools/gen_lunar_font.py`

部分 MIP 屏设备固件**不内置**可用于 `getVectorFont("NotoSansSCMedium")` 的中文字体。本脚本将日期行与农历所需的约 30 个汉字预渲染为 **AngelCode 位图字体**（`.fnt` + PNG 图集），打包进资源后各设备均可显示中文。

**依赖**

```bash
pip install pillow
```

系统需安装含所需汉字的 CJK 字体（脚本默认使用 Windows 自带的 `msyh.ttc`，其他系统请改脚本中的 `FONT_PATH`）。

**用法**（在项目根目录执行）

```bash
python tools/gen_lunar_font.py
```

**产出**

| 文件 | 说明 |
|------|------|
| `resources/drawables/lunar_zh.fnt` | AngelCode 字形描述 |
| `resources/drawables/lunar_zh_0.png` | 字形图集（建议宽度 ≤ 256 px，符合 Garmin 常见限制） |

脚本顶部可调：`FONT_SIZE`、`FONT_PATH`、`CHARS`（增字后需重跑）、`ATLAS_MAX_W`。

**资源注册**：位图字体在 `resources/drawables/fonts.xml` 中声明（不要放进 `drawables.xml`），代码中通过 `WatchUi.loadResource(Rez.Fonts.LunarFont)` 加载后作为 `Graphics.FontType` 传给 `dc.drawText()`。

---

## 参与贡献

欢迎 Issue 与 Pull Request。建议流程：

1. **Fork** 本仓库，从 `main`（或默认分支）创建功能分支。  
2. 本地修改后确保能在目标机型或模拟器上**正常编译与运行**。  
3. PR 中简要说明**动机、改动范围、测试方式**；若涉及 UI 或设置项，可附截图。  
4. 保持改动聚焦；避免无关格式化或大范围重排，便于审阅与合并。  

若你计划以不同名称或应用 ID 在商店单独上架，请自行替换 `manifest.xml` 中的应用 ID、名称字符串与图标等资源，并遵守 Garmin 开发者条款。

---

## 许可证

本项目采用 **MIT License**，详见仓库根目录 [LICENSE](LICENSE)。  

默认版权行中的「赴山野 (trailhead-face) contributors」为集体署名；若你希望以本人或组织名义持有版权，可将 `LICENSE` 文件首段 `Copyright` 行改为你的法定署名信息。

---

## 免责声明

本软件按「原样」提供，不作任何明示或暗示担保。户外出行请结合实际地形、天气与身体状况决策，表盘数据不能替代专业导航或医疗建议。
