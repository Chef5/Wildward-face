# 赴山野

一款面向徒步与山野出行的 **Garmin Connect IQ 圆形表盘**：以时间为视觉核心，配合罗盘刻度与四象限可配置数据，抬腕即可把握身体状态与户外环境。

Connect IQ Store：https://apps.garmin.com/apps/1d1e570b-cb90-4ef6-96e4-2b96e55de9ee?tid=0

> **Slogan**：向山野出发，为热爱前行。适配徒步、山野出行场景。聚焦海拔、心率、电量、步数四大核心数据，抬腕即刻洞悉身体状态与户外环境，自在奔赴每一场热爱！

本仓库为表盘「赴山野」的开源参考实现，代码以 [MIT 许可证](LICENSE) 发布。

---

## 功能概览

- **时间**：突出时分，可选显示秒数  
- **日期与农历**：可分别开关（农历仅在设备系统语言为简体/繁体中文时展示）；仅一项开启时自动居中；两者都关闭时时间垂直居中  
- **四象限指标（可配置）**：左上 / 右上 / 左下 / 右下各可选一项（见下表）  
  - 同一行只展示一个指标时自动居中  
- **横线分隔**：上下两条横线可开关  
- **主题色**：11 套预设配色可选（含「原野绿」），默认「高雅紫」；支持自定义 RGB 十六进制色值  
- **电量展示格式**：百分制或续航时间（≥1 天显示 `XdYh`，不足 1 天显示 `Xh`）  

#### 四象限可选数据指标

| 指标 | 说明 |
|------|------|
| 心率 | 当前心率（次/分），无数据时显示 `--` |
| 电量 | 电池百分比或续航时间（受「电量展示」设置控制） |
| 步数 | 当日累计步数 |
| 海拔 | 当前海拔（米） |
| 卡路里 | 当日活动消耗卡路里 |
| 血氧 | 最近一次血氧饱和度（%），需设备支持 |
| 大气压 | 海平面气压（hPa），附升/降趋势箭头 |
| 身体电量 | Garmin Body Battery 数值 |
| 压力值 | 当前压力指数 |
| 日出时间 | 当日日出时刻（HH:MM） |
| 日落时间 | 当日日落时刻（HH:MM） |
| 天气 | 当前天气图标 + 气温（跟随系统温标） |
| 呼吸频率 | 最近一次呼吸频率（次/分） |
| 不展示 | 该象限留空 |

### 多语言

表盘在 `manifest.xml` 中声明支持 **13 种语言**。`resources/` 为**英文默认资源包**（应用名 **Wildward**）；未单独翻译的语言会自动回退到英文。

| 代码 | 语言 | 资源目录 | 应用名 | 设置页农历开关 |
|------|------|----------|--------|----------------|
| `eng` | 英语 | `resources/`（默认） | Wildward | 无 |
| `zhs` | 简体中文 | `resources-zhs/` | 赴山野 | 有 |
| `zht` | 繁体中文 | `resources-zht/` | 赴山野 | 有 |
| `jpn` | 日语 | `resources-jpn/` | Wildward | 无 |
| `deu` | 德语 | `resources-deu/` | Wildward | 无 |
| `fre` | 法语 | `resources-fre/` | Wildward | 无 |
| `spa` | 西班牙语 | `resources-spa/` | Wildward | 无 |
| `ita` | 意大利语 | `resources-ita/` | Wildward | 无 |
| `dut` | 荷兰语 | `resources-dut/` | Wildward | 无 |
| `nob` | 挪威语 | `resources-nob/` | Wildward | 无 |
| `pol` | 波兰语 | `resources-pol/` | Wildward | 无 |
| `rus` | 俄语 | `resources-rus/` | Wildward | 无 |
| `kor` | 韩语 | `resources-kor/` | Wildward | 无 |

各语言包包含 `strings/strings.xml`（文案）与 `settings/settings.xml`（设置页布局）；属性默认值统一定义在 `resources/settings/properties.xml`。

在 VS Code 中可通过命令面板 **「Monkey C: Edit Languages」** 增删 `manifest.xml` 中的支持语言。

### 默认布局

| 位置 | 默认指标 |
|------|----------|
| 左上 | 海拔 |
| 右上 | 电量 |
| 左下 | 心率 |
| 右下 | 步数 |

### 表盘设置项（`properties.xml`）

设置页顺序：**主题色** → **四象限数据** → **显示秒数 / 日期 / 分割线**（及简体/繁体下的**农历**）→ **电量展示** → **主题色高级设置**。

| 键名 | 说明 |
|------|------|
| `AccentColor` | 主题色预设：高雅紫、深海蓝、碧空蓝、翡翠绿、**原野绿**、柠檬黄、暖阳金、琥珀橙、朱砂红、樱花粉、月光白 |
| `CustomAccentColor` | 自定义主题色（6 位 RGB，可选 `#` 前缀；有效时优先于 `AccentColor`） |
| `TopLeftMetric` / `TopRightMetric` / `BottomLeftMetric` / `BottomRightMetric` | 四象限指标（见上表；ID：0=不展示，1=心率，2=电量，3=步数，4=海拔，5=卡路里，6=血氧，7=大气压，8=身体电量，9=压力值，10=日出，11=日落，12=天气，13=呼吸频率） |
| `ShowSeconds` | 显示秒数 |
| `ShowDate` | 显示日期 |
| `ShowLunar` | 显示农历（仅简体/繁体中文环境生效；对应语言设置页提供开关） |
| `ShowDividers` | 显示上下横线 |
| `BatteryDisplay` | 电量展示格式：`0`=百分制（默认），`1`=续航时间 |

---

## 项目结构

```
trailhead-face/
├── manifest.xml                      # Connect IQ 应用清单（入口、目标机型、支持语言等）
├── monkey.jungle                     # 工程与资源路径（含多分辨率启动图标 & 图标颜色覆盖）
├── source/                           # Monkey C 源码
│   ├── ChefWatchFaceApp.mc           # 应用入口
│   ├── ChefWatchFaceView.mc          # 表盘绘制与逻辑
│   ├── Background.mc                 # 背景绘制
│   └── LunarCalendar.mc              # 农历计算
├── resources/                        # 默认资源包（英文，未匹配语言时回退至此）
│   ├── strings/strings.xml           # 应用名 Wildward 与设置项文案
│   ├── settings/
│   │   ├── properties.xml            # 设置项默认值（各语言共用）
│   │   └── settings.xml              # 设置页布局（英文，无农历开关）
│   ├── drawables/                    # 矢量图标（SVG）与 drawables.xml
│   └── layouts/layout.xml            # 布局
├── resources-zhs/                    # 简体中文
│   ├── strings/strings.xml           # 应用名「赴山野」
│   └── settings/settings.xml         # 含农历开关
├── resources-zht/                    # 繁体中文
├── resources-jpn/                    # 日语（ja 日本語）
├── resources-deu/                    # 德语（de Deutsch）
├── resources-fre/                    # 法语（fr Français）
├── resources-spa/                    # 西班牙语（es Español）
├── resources-ita/                    # 意大利语（it Italiano）
├── resources-dut/                    # 荷兰语（nl Nederlands）
├── resources-nob/                    # 挪威语（nb Norsk）
├── resources-pol/                    # 波兰语（pl Polski）
├── resources-rus/                    # 俄语（ru Русский）
├── resources-kor/                    # 韩语（ko 한국어）
│   └── （各语言目录均含 strings/ 与 settings/，结构同上）
├── resources-icons-amoled/           # AMOLED 机型图标覆盖（packingFormat="png"）
├── resources-launcher-*-*/           # 各机型启动图标像素规格覆盖
├── docs/technical-design.md          # 技术设计备忘
├── design.md / design.svg            # 设计备忘与矢量稿（不参与编译）
└── .vscode/                          # VS Code 调试与任务配置（可选）
```

关键模块的实现细节（多语言与农历、MIP/AMOLED 图标染色方案）见 [docs/technical-design.md](docs/technical-design.md)。

---

## 开发与构建

### 前置条件

1. 安装 [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/)，并配置好环境变量（使 `monkeyc` 等命令可用）。  
2. 使用 **Visual Studio Code** 安装官方 **Monkey C** 扩展，便于编译、模拟器与真机调试。  
3. 在扩展中配置你的 **开发者密钥**，用于本地打包与安装（密钥文件勿入库）。

### 常用工作流

- 用命令面板执行 **「Monkey C: Edit Application」** 修改应用元数据。  
- 用 **「Monkey C: Edit Products」** / **「Set Products by Product Category」** 调整 `manifest.xml` 中的目标机型。  
- 编译、运行模拟器或安装到手表，均通过扩展提供的命令完成。  

当前 `manifest.xml` 已列出多款圆形表（如 fēnix 7/8、Forerunner、epix、Venu、Instinct 3 等）；若你新增机型，可能需要在 `monkey.jungle` 中为该机补充 `resources-launcher-*` 及图标覆盖路径（与现有条目同模式）。

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
