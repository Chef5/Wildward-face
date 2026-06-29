# 技术设计说明

本文档说明「赴山野」表盘中两个关键模块的实现方案。

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
