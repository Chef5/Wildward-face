# 技术设计说明

本文档记录「赴山野」表盘中关键模块的实现方案与踩坑经验。

---

## 中文日期与农历：多语言适配

日期行（月/日/星期）与农历字符串的中文显示依赖设备字体能力，代码在运行时自动检测，不依赖任何打包进 `.prg` 的位图字体文件。

### AMOLED 设备（fr265、Venu 3、fēnix 8 等）

调用 `Graphics.getVectorFont({:face => "NotoSansSCMedium", :size => ...})` 加载设备内置的可缩放 Noto Sans SC 中文矢量字体。该调用成功时 `_hasCjkFont = true`，日期行使用完整中文格式：

```
5月3日 周六     （公历日期）
三月初五         （农历，来自 LunarCalendar.format()）
```

### MIP 设备（fr255、fēnix 7 等）

MIP 设备的固件不提供 `getVectorFont` 接口（`Graphics has :getVectorFont` 返回 `false`），但当**设备语言设为中文**（简体 `LANGUAGE_CHS` 或繁体 `LANGUAGE_CHT`）时，系统字体常量（`FONT_TINY` 等）会由固件的 `apac_chn` 字体集映射到 Noto Sans SC CJK 位图字体，同样可以直接渲染中文字符。

### 检测逻辑与降级策略

| 条件 | `_hasCjkFont` | 日期格式 | 农历格式 |
|------|:---:|------|------|
| AMOLED（`getVectorFont` 成功） | `true` | `5月3日 周六` | `三月初五` |
| MIP + 系统语言为中文 | `true` | `5月3日 周六` | `三月初五` |
| MIP + 系统语言非中文 | `false` | `5.3 Sat` | `Lunar 3.5` |

检测代码位于 `ChefWatchFaceView.mc` 的 `rebuildUiFont()` 方法：

```monkey-c
var vf = (Graphics has :getVectorFont)
    ? Graphics.getVectorFont({:face => "NotoSansSCMedium", :size => targetH})
    : null;
if (vf != null) {
    _uiFont = vf;
    _hasCjkFont = true;
} else {
    var lang = System.getDeviceSettings().systemLanguage;
    _hasCjkFont = (lang == System.LANGUAGE_CHS || lang == System.LANGUAGE_CHT);
    // 按 _fontSize 档位选取系统字体常量
}
```

---

## 图标颜色：MIP 与 AMOLED 的统一方案

三个数据图标（心率、步数、海拔）的 SVG 以**纯白色**（`fill="#FFFFFF"`）绘制，运行时通过 `drawBitmap2` 的 `tintColor` 参数染成当前主题色。该方案在 MIP 和 AMOLED 上均可工作，关键在于 `automaticPalette="false"` 属性。

### 问题根源

Connect IQ 编译器默认为位图自动分配调色板（paletted 格式），而 `drawBitmap2 + tintColor` 要求位图以**设备原生色彩格式**存储（非调色板格式），否则运行时抛出 `Source must not use a color palette` 异常。

### 解决方案：`automaticPalette="false"`

在 `drawables.xml` 的 bitmap 声明中加入此属性，阻止编译器自动分配调色板：

- **fr255（MIP，ARGB2222 格式）**：位图以 8-bit 直接色格式存储，`tintColor` 生效
- **fr265 等（AMOLED）**：结合 `packingFormat="png"` 以全彩 PNG 存储，`tintColor` 同样生效

### 资源文件

**基础定义**（`resources/drawables/drawables.xml`，全机型通用）：

```xml
<bitmap id="BpmIcon"   filename="bpm.svg"      dithering="none" automaticPalette="false" />
<bitmap id="StepsIcon" filename="steps.svg"    dithering="none" automaticPalette="false" />
<bitmap id="AltIcon"   filename="altitude.svg" dithering="none" automaticPalette="false" />
```

**AMOLED 覆盖**（`resources-icons-amoled/drawables/drawables.xml`）：

```xml
<bitmap id="BpmIcon"   filename="..." dithering="none" packingFormat="png" automaticPalette="false" />
<bitmap id="StepsIcon" filename="..." dithering="none" packingFormat="png" automaticPalette="false" />
<bitmap id="AltIcon"   filename="..." dithering="none" packingFormat="png" automaticPalette="false" />
```

Connect IQ 资源系统以 `resourcePath` 中**最后声明的路径优先**，`monkey.jungle` 将 AMOLED 机型路由到覆盖目录：

```
# AMOLED 机型：末尾追加覆盖路径
fr265.resourcePath = $(fr265.resourcePath);resources-icons-amoled
venu3.resourcePath = $(venu3.resourcePath);resources-launcher-70-70;resources-icons-amoled

# MIP 机型：仅使用基础定义
fr255.resourcePath = $(fr255.resourcePath);resources-launcher-40-40
```

### 绘制代码

两种屏幕走同一路径，只检查 `dc has :drawBitmap2`：

```monkey-c
private function drawTintedBitmap(dc as Dc, x as Number, y as Number,
                                  bmp as BitmapResource) as Void {
    if (dc has :drawBitmap2) {
        dc.drawBitmap2(x, y, bmp, {:tintColor => _accent});
    } else {
        dc.drawBitmap(x, y, bmp);
    }
}
```

### 注意事项

- `packingFormat="png"` 在 MIP 设备上会产生编译警告（"not supported, default format will be used"）。通过 `resources-icons-amoled` 覆盖机制，MIP 机型的 bitmap 定义中不包含此属性，从而消除警告。
- `Graphics has :getVectorFont` 的检查必须用于**调用前的 `has` 判断**，不能以 early-return 的形式绕过，否则编译器会对不支持该符号的设备报 `Undefined symbol` 错误。

---

## 主题色：MIP 64 色板映射

设置项 `AccentColor` 存的是面向 AMOLED 的十六进制 RGB（如 `0xB77CFF`）。上线后 MIP 屏（ARGB2222 / 64 色）会出现明显色差：传入非色板内颜色时，固件会做不可控近似，观感与设计稿偏差大。

### 结论与原则

1. **AMOLED**：继续使用设置里的完整 RGB。
2. **MIP**：必须使用官方 RGB222 64 色板内的色号（每通道仅 `0x00 / 0x55 / 0xAA / 0xFF`），仍以 `0xRRGGBB` 传给 `setColor` / `tintColor`。
3. **设置值不改**：Connect IQ 设置跨机型共用同一 property；运行时按屏幕类型映射，避免 AMOLED 被降彩。
4. **MIP 判定**：与字体逻辑一致，`!(Graphics has :getVectorFont)` 视为 MIP。

```monkey-c
// 正确：色板内 RGB 色号
dc.setColor(0xAA55FF, Graphics.COLOR_BLACK);
// 错误：非色板 RGB，MIP 硬件强制近似，易严重偏色
dc.setColor(0xFF22FF, Graphics.COLOR_BLACK);
// 错误：把 0–63 索引当颜色传入 —— API 只认 RGB，索引会被当成近黑色
dc.setColor(39, Graphics.COLOR_BLACK);
```

### 实现位置

`ChefWatchFaceView.loadSettings()` → `resolveColorForDisplay()` → `toMipPaletteColor()`。

自定义色（`CustomAccentColor` / `CustomSecondaryColor` / `CustomBackgroundColor`）在 MIP 上走 `quantizeToRgb222()`，按通道量化到四档。

映射表注释同步写在 `resources/settings/settings.xml` 的 `AccentColor` 上方，便于对照。副色复用主题色预设；背景色额外映射：黑 `0x000000`、深灰 `0x555555`、浅灰 `0xAAAAAA`、藏蓝 `0x0A1628` → `0x000055`。

### 预设 → 64 色板色号

| 主题色 | 设置 RGB（AMOLED） | MIP 色号 | 说明 |
|--------|-------------------|----------|------|
| 紫 | `0xB77CFF` | `0xAA55FF` | 最近邻 |
| 蓝 | `0x55AAFF` | `0x55AAFF` | 已在色板内 |
| 青 | `0x00DDCC` | `0x00FFAA` | 最近邻 |
| 绿 | `0x55FF99` | `0x55FFAA` | 最近邻 |
| 原野绿 | `0x3DA855` | `0x55AA55` | 最近邻 |
| 黄 | `0xFFEE44` | `0xFFFF55` | 最近邻 |
| 金 | `0xFFCC33` | `0xFFAA00` | 刻意不用最近邻（见下） |
| 橙 | `0xFFAA55` | `0xFFAA55` | 已在色板内 |
| 红 | `0xFF5566` | `0xFF5555` | 最近邻 |
| 粉 | `0xFF77BB` | `0xFF55AA` | 最近邻 |
| 白 | `0xFFFFFF` | `0xFFFFFF` | 已在色板内 |

### 踩坑：纯欧氏距离会撞色

按 RGB 欧氏距离，`0xFFCC33`（金）最近邻是 `0xFFAA55`，与橙预设完全相同，MIP 上金/橙无法区分。

因此金改为 `0xFFAA00`（略远，但是色板内暖金色，且与橙 `0xFFAA55` 可区分）。以后新增预设时，映射后也要做一次**两两去重**检查。

### 相关参考

- 64 色板 = RGB222，通道取值 `{0x00, 0x55, 0xAA, 0xFF}` 的全部组合（共 64 色）
- SDK 命名常量（`Graphics.COLOR_*`）只是色板子集；MIP 可用任意色板内 hex，不必局限于命名常量
- `setColor` / `tintColor` **只接受 RGB**，不接受硬件色板索引；曾误用索引导致 MIP 主题色近黑不可见
- 论坛/文档：newer MIP（fenix7、fr255 等）`compiler.json` 可能不列 palette，但 `pixelFormat: ARGB2222` / `bitsPerPixel: 8` 仍对应同一套 64 色

---

## 日出日落自动切换（Metric ID 14）

四象限可选「日出日落」：根据当前时刻在日出/日落 Complication 之间自动切换图标与时刻文本。

切换规则（`ChefWatchFaceView.mc`）：

- 切换点 = 事件整点小时 + 2（例：7:35 日出 → 9:00 起显示日落；19:02 日落 → 21:00 起显示日出）
- 日出后至切换点之前：显示日出图标 + 日出时刻
- 日落后至切换点之前：显示日落图标 + 日落时刻

长按跳转：按当前展示内容映射到 `COMPLICATION_TYPE_SUNRISE` 或 `COMPLICATION_TYPE_SUNSET`。

---

## 周跑量 / 月跑量（Metric ID 15 / 16）

| 指标 | 数据来源 | 说明 |
|------|----------|------|
| 周跑量 | `Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE` | 与系统「本周跑步距离」一致 |
| 月跑量 | `UserProfile.getUserActivityHistory()` | 自然月内 `SPORT_RUNNING` 活动距离累加 |

显示：固定换算为 km，表盘不标单位；无数据为 `0`；整数不显示小数，否则保留 1 位。

月跑量性能：`onShow` / 设置变更时刷新缓存，同月内最多 30 分钟重算一次；四象限均未选月跑量时不遍历历史。

---

## 长按跳转系统 Glance

触屏设备通过 `ChefWatchFaceDelegate.onPress` → `ChefWatchFaceView.handleMetricLongPress` 实现。

1. 按触摸坐标命中四象限（`hitTestMetricAt`）
2. `getComplicationTypeForMetric` 映射到原生 Complication 类型
3. `isComplicationAvailable` 检查 `getComplication` 是否非 null
4. `Complications.exitTo` 跳转；不支持时直接返回，不降级到其他页面

需在 `manifest.xml` 声明 `ComplicationSubscriber` 权限。周/月跑量均映射到 `WEEKLY_RUN_DISTANCE`（系统无月跑量 Complication）。

支持长按的指标与 Complication 映射见 `getComplicationTypeForMetric()`。

---

## 强度分钟 / 高强度（Metric ID 19–22）

| 指标 | 数据来源 | 说明 |
|------|----------|------|
| 周强度活动时间(分钟) (19) | `COMPLICATION_TYPE_INTENSITY_MINUTES`，回退 `activeMinutesWeek.total` | 与系统「强度活动时间」一致（已加权） |
| 月强度活动时间(分钟) (20) | 今日 `activeMinutesDay.total` + `getHistory()` 本月各日 `total` | 系统无月 Complication；History 通常约最近 7 天 |
| 周高强度活动时间(分钟) (21) | `activeMinutesWeek.vigorous` | 未 ×2 的原始高强度分钟 |
| 月高强度活动时间(分钟) (22) | 今日 `vigorous` + History 本月各日 `vigorous` | 同上 History 窗口限制 |

无数据均显示 `0`。四项长按均跳转 `COMPLICATION_TYPE_INTENSITY_MINUTES` Glance。图标：`intensity.svg`。

---

## 圆环刻度与秒针

原顶部固定「北向三角」已重新定义为**秒针**（`ShowSecondHand`，默认开启），与圆环刻度（`ShowRingTicks`）可分别开关。

### 绘制（`ChefWatchFaceView.mc`）

- `drawCompassRing`：60 刻度，每 6°（含当前秒刻度）。
- `drawSecondHand`：按 `System.getClockTime().sec` 计算方位角（与刻度同一套 `sin` / `-cos` 约定，0 秒在正上方）。
  - 形状：四边形箭头——尖端 → 右底 → 内凹折角 → 左底（尖端约 43°，底边浅内凹）
  - 尖端半径 ≈ 半屏宽 − 30；底边半径 ≈ 半屏宽 − 58；折角半径 ≈ 半屏宽 − 52
  - 半宽 ≈ 11 设计单位；尖端始终由圆心指向表缘

高功耗模式下系统每秒调用 `onUpdate` 全量重绘；低功耗下整分仍走 `onUpdate`，其余秒走 `onPartialUpdate` + `setClip` 只擦写秒针旧/新包围盒与数字秒区域，以维持 1Hz。超功耗预算时 `onPowerBudgetExceeded` 会暂停局部刷新，抬腕 `onExitSleep` 后重新启用。大气压等重计算在全量刷新路径内按 TTL 缓存，避免拖垮 1Hz 预算。
