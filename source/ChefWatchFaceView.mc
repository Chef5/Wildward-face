import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class ChefWatchFaceView extends WatchUi.WatchFace {

    // ---- 配色 ----
    private const WHITE = 0xFFFFFF;
    private const BLACK = 0x000000;

    // ---- 中间区域（960 设计单位；圆形表盘上 Y 随屏宽缩放）----
    private const SPEC_TIME_CENTER_Y = 440;
    private const SPEC_DATE_ROW_Y = 612;
    // 长分割线：距上/下边的距离（同值保持对称）。
    // 更小 → 线靠近表圈 → 线与中心时间/日期间距更大。
    // 更大 → 线更贴近中心内容块。
    private const SPEC_DIVIDER_EDGE_INSET = 288;
    // 顶部指标行：相对上分割线向北（表盘上方）偏移这么多设计单位。
    private const SPEC_TOP_METRICS_ABOVE_DIVIDER = 70;
    // 底部指标行：相对下分割线的距离（下分割线位于 960 − inset）。
    private const SPEC_BOTTOM_ICON_BELOW_DIVIDER = 60;
    private const SPEC_BOTTOM_VALUE_BELOW_DIVIDER = 145;
    // 横向分割线：在设备像素上两端各加长一半总长。
    private const DIVIDER_LINE_EXTRA_WIDTH_PX = 10;
    // 指标位图为 32×32（与 resources/drawables 内 SVG 栅格一致）；布局与居中使用同一数值。
    private const METRIC_ICON_PX = 32;

    // ---- 运行时状态 ----
    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _scale as Float = 1.0;
    private var _isAsleep as Boolean = false;

    // ---- 设置 ----
    private var _accent as Number = 0xB77CFF;
    private var _showSeconds as Boolean = true;
    private var _showDate as Boolean = true;
    private var _showLunar as Boolean = true;
    private var _showDividers as Boolean = true;
    // 各位置指标 ID：0=不展示  1=心率  2=电量  3=步数  4=海拔
    private var _topLeftMetric     as Number = 4; // 默认：海拔
    private var _topRightMetric    as Number = 2; // 默认：电量
    private var _bottomLeftMetric  as Number = 1; // 默认：心率
    private var _bottomRightMetric as Number = 3; // 默认：步数

    // ---- 图标位图（在 onLayout 中只加载一次）----
    private var _heartBmp as BitmapResource?;
    private var _stepsBmp as BitmapResource?;
    private var _altBmp   as BitmapResource?;

    // 日期行字体：
    //   首选：自定义位图字体（含所有所需汉字，所有设备通用，包括 FR255 等 MIP 屏）
    //   次选：固件内置矢量 NotoSansSC（AMOLED 设备）
    //   兜底：FONT_XTINY + ASCII 格式（极端情况）
    private var _dateLineFont as Graphics.FontType = Graphics.FONT_XTINY;
    private var _hasVectorDateFont as Boolean = false;

    // ---- 按日缓存的值 ----
    private var _lunarStr as String = "";
    private var _lunarCacheKey as Number = -1; // 打包 yyyymmdd 用于按日失效

    // Gregorian day_of_week：1=周日 … 7=周六 → 0..6
    private const WEEKDAYS_ZH = [
        "周日", "周一", "周二", "周三", "周四", "周五", "周六"
    ];
    private const WEEKDAYS_EN = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    ];

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        var p = Application.Properties;
        var v;
        v = p.getValue("AccentColor");
        if (v != null) { _accent = v as Number; }
        v = p.getValue("ShowSeconds");
        if (v != null) { _showSeconds = v as Boolean; }
        v = p.getValue("ShowDate");
        if (v != null) { _showDate = v as Boolean; }
        v = p.getValue("ShowLunar");
        if (v != null) { _showLunar = v as Boolean; }
        v = p.getValue("ShowDividers");
        if (v != null) { _showDividers = v as Boolean; }
        v = p.getValue("TopLeftMetric");
        if (v != null) { _topLeftMetric = v as Number; }
        v = p.getValue("TopRightMetric");
        if (v != null) { _topRightMetric = v as Number; }
        v = p.getValue("BottomLeftMetric");
        if (v != null) { _bottomLeftMetric = v as Number; }
        v = p.getValue("BottomRightMetric");
        if (v != null) { _bottomRightMetric = v as Number; }
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _scale = _w / 960.0;
        _heartBmp = WatchUi.loadResource(Rez.Drawables.BpmIcon)   as BitmapResource;
        _stepsBmp = WatchUi.loadResource(Rez.Drawables.StepsIcon)  as BitmapResource;
        _altBmp   = WatchUi.loadResource(Rez.Drawables.AltIcon)    as BitmapResource;

        // 优先加载自定义 CJK 位图字体（打包进 app，所有设备通用）。
        // 若加载失败（不应发生），再尝试固件内置矢量字体（仅 AMOLED 设备有效）。
        _hasVectorDateFont = false;
        _dateLineFont = Graphics.FONT_XTINY;
        var bitmapFont = WatchUi.loadResource(Rez.Fonts.LunarFont);
        if (bitmapFont != null) {
            _dateLineFont = bitmapFont as Graphics.FontType;
            _hasVectorDateFont = true;
        } else if (Graphics has :getVectorFont) {
            var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
            var vf = Graphics.getVectorFont({ :face => "NotoSansSCMedium", :size => xtinyH });
            if (vf != null) {
                _dateLineFont = vf;
                _hasVectorDateFont = true;
            }
        }
    }

    function onShow() as Void {
        loadSettings();
    }

    function onEnterSleep() as Void {
        _isAsleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isAsleep = false;
        WatchUi.requestUpdate();
    }

    // 将规格坐标（1:960）换算为设备像素
    private function s(v as Numeric) as Number {
        return Math.round(v * _scale).toNumber();
    }

    private function sf(v as Numeric) as Float {
        return v * _scale;
    }

    function onUpdate(dc as Dc) as Void {
        if (_w == 0) {
            _w = dc.getWidth();
            _h = dc.getHeight();
            _cx = _w / 2;
            _cy = _h / 2;
            _scale = _w / 960.0;
        }

        // 背景
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(WHITE, BLACK);
        dc.clear();

        drawCompassRing(dc);
        drawNorth(dc);
        drawTopMetrics(dc);
        var edgeInset = sf(SPEC_DIVIDER_EDGE_INSET);
        if (_showDividers) { drawHorizontalDivider(dc, edgeInset); }
        drawCenterTime(dc);
        drawDateRows(dc);
        if (_showDividers) { drawHorizontalDivider(dc, _h - edgeInset); }
        drawBottomMetrics(dc);
    }

    // -------------------------------------------------------------
    // 罗盘圈与北向指示
    // -------------------------------------------------------------

    private function drawCompassRing(dc as Dc) as Void {
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        var outerR = (_w / 2.0) - sf(2);
        var minorOuter = outerR;
        var minorInner = outerR - sf(14);
        var majorOuter = outerR + sf(2);
        var majorInner = outerR - sf(22);

        var majorPen = s(4);
        if (majorPen < 2) { majorPen = 2; }
        var minorPen = s(2);
        if (minorPen < 1) { minorPen = 1; }

        for (var i = 0; i < 60; i++) {
            // 跳过正上方刻度——北向三角标记占据该位置
            if (i == 0) { continue; }
            var rad = i * 6.0 * Math.PI / 180.0;
            var sa = Math.sin(rad);
            var ca = -Math.cos(rad);
            var isMajor = (i % 5 == 0);
            var rOut = isMajor ? majorOuter : minorOuter;
            var rIn = isMajor ? majorInner : minorInner;
            dc.setPenWidth(isMajor ? majorPen : minorPen);
            dc.drawLine((_cx + rOut * sa).toNumber(), (_cy + rOut * ca).toNumber(),
                        (_cx + rIn * sa).toNumber(), (_cy + rIn * ca).toNumber());
        }
        dc.setPenWidth(1);
    }

    private function drawNorth(dc as Dc) as Void {
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        var triTopY = s(18);
        var triBaseY = s(40);
        var halfW = s(11);
        dc.fillPolygon([
            [_cx, triTopY],
            [_cx - halfW, triBaseY],
            [_cx + halfW, triBaseY]
        ]);
    }

    // -------------------------------------------------------------
    // 顶部指标行（可配置，单侧有值时自动居中）
    // -------------------------------------------------------------

    private function drawTopMetrics(dc as Dc) as Void {
        var rowCenterY = s(SPEC_DIVIDER_EDGE_INSET - SPEC_TOP_METRICS_ABOVE_DIVIDER);
        var hasLeft  = (_topLeftMetric  != 0);
        var hasRight = (_topRightMetric != 0);
        var bothPresent = hasLeft && hasRight;
        var leftX  = bothPresent ? _cx - s(165) : _cx;
        var rightX = bothPresent ? _cx + s(165) : _cx;
        if (hasLeft)  { drawMetricTop(dc, _topLeftMetric,  leftX,  rowCenterY); }
        if (hasRight) { drawMetricTop(dc, _topRightMetric, rightX, rowCenterY); }
    }

    // 在顶部行绘制单个指标（图标+文字横排，以 centerX 为中心）
    private function drawMetricTop(dc as Dc, metric as Number, centerX as Number, rowCenterY as Number) as Void {
        var valueFont = Graphics.FONT_XTINY;
        if (metric == 1) {
            var hr = getHeartRate();
            drawIconTextGroup(dc, _heartBmp, (hr == null) ? "--" : hr.format("%d"), centerX, rowCenterY);
        } else if (metric == 2) {
            var pct = System.getSystemStats().battery;
            var battText = pct.format("%d") + "%";
            var battValueW = dc.getTextWidthInPixels(battText, valueFont);
            var battW = s(92);
            var battH = s(46);
            var battGap = s(24);
            var groupW = battW + battGap + battValueW;
            var battLeftX = centerX - groupW / 2;
            var battTextX = battLeftX + battW + battGap;
            drawBatteryIcon(dc, battLeftX, rowCenterY - battH / 2, battW, battH, pct);
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(battTextX, rowCenterY, valueFont, battText,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 3) {
            var steps = getSteps();
            drawIconTextGroup(dc, _stepsBmp, (steps == null) ? "--" : steps.format("%d"), centerX, rowCenterY);
        } else if (metric == 4) {
            var alt = getAltitude();
            drawIconTextGroup(dc, _altBmp, (alt == null) ? "--" : alt.format("%d"), centerX, rowCenterY);
        }
    }

    // 顶部行通用绘制：指标图标在左，文字在右，整体以 centerX 居中
    // FONT_XTINY（FR265 上约 16px）为最小内置字号，与图标视觉重量匹配。
    private function drawIconTextGroup(dc as Dc, bmp as BitmapResource?, text as String,
                                       centerX as Number, centerY as Number) as Void {
        var valueFont = Graphics.FONT_XTINY;
        var iconSize = METRIC_ICON_PX;
        var iconHalf = METRIC_ICON_PX / 2;
        var iconTextGap = s(28);
        var textW  = dc.getTextWidthInPixels(text, valueFont);
        var groupW = iconSize + iconTextGap + textW;
        var iconCenterX = centerX - groupW / 2 + iconSize / 2;
        var textLeftX   = centerX - groupW / 2 + iconSize + iconTextGap;
        if (bmp != null) {
            dc.drawBitmap(iconCenterX - iconHalf, centerY - iconHalf, bmp);
        }
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textLeftX, centerY, valueFont, text,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawBatteryIcon(dc as Dc, x as Number, y as Number,
                                     w as Number, h as Number, pct as Float) as Void {
        var pen = s(3);
        if (pen < 2) { pen = 2; }
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        // 外轮廓（圆角矩形近似为普通矩形——多数 CIQ 设备无 roundRect）
        dc.drawRectangle(x, y, w, h);
        // 正极凸起
        var tipW = s(8);
        var tipH = h / 2;
        dc.fillRectangle(x + w + s(2), y + (h - tipH) / 2, tipW, tipH);
        dc.setPenWidth(1);

        // 内部填充
        var inset = s(6);
        var maxFillW = w - inset * 2;
        var fillW = (maxFillW * pct / 100.0).toNumber();
        if (fillW < 0) { fillW = 0; }
        if (fillW > maxFillW) { fillW = maxFillW; }
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + inset, y + inset, fillW, h - inset * 2);
    }

    // -------------------------------------------------------------
    // 中心时间
    // -------------------------------------------------------------

    private function drawCenterTime(dc as Dc) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hour == 0) { hour = 12; }
            else if (hour > 12) { hour -= 12; }
        }
        var hourStr = hour.format("%02d");
        var minStr = clock.min.format("%02d");
        var secStr = clock.sec.format("%02d");

        // 时/分略大；冒号较小但与 HH:MM:ss 共用同一竖直中线。
        var bigFont = Graphics.FONT_NUMBER_HOT;
        var colonFont = Graphics.FONT_NUMBER_MILD;
        var secFont = Graphics.FONT_XTINY;

        var hourW = dc.getTextWidthInPixels(hourStr, bigFont);
        var colonW = dc.getTextWidthInPixels(":", colonFont);
        var minW = dc.getTextWidthInPixels(minStr, bigFont);

        // 时、冒号、分之间紧间距（模拟设计稿中 letter_spacing: -12）
        var colonGap = s(2);
        var totalW = hourW + colonGap + colonW + colonGap + minW;
        // HH:MM 块居中；秒数置于「分」的右下角（可能向右伸出）
        var blockLeft = _cx - totalW / 2;
        if (_showSeconds) {
            blockLeft -= s(8);
        }
        // 日期行和农历均不展示时，时间垂直居中于两条分割线之间（设计单位 480）
        var hasDateContent = _showDate || _showLunar;
        var centerLineY = s(hasDateContent ? SPEC_TIME_CENTER_Y : 480);
        var bigH = dc.getFontHeight(bigFont);

        // 小时
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blockLeft, centerLineY, bigFont, hourStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 冒号——较小字号；与数字共用 centerLineY（不做逐字体 Y 偏移）
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        var colonX = blockLeft + hourW + colonGap;
        dc.drawText(colonX, centerLineY, colonFont, ":",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 分钟
        var minX = colonX + colonW + colonGap;
        dc.drawText(minX, centerLineY, bigFont, minStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 秒——分右下角；按基线对齐（用 box-bottom − descent 跨字体对齐效果差）
        if (_showSeconds && !_isAsleep) {
            dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
            var secH = dc.getFontHeight(secFont);
            var descBig = Graphics.getFontDescent(bigFont);
            var descSec = Graphics.getFontDescent(secFont);
            var minBaseline = centerLineY + bigH / 2 - descBig;
            var secY = minBaseline - secH / 2 + descSec;
            var secX = minX + minW + s(2);
            dc.drawText(secX, secY, secFont, secStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // -------------------------------------------------------------
    // 日期与农历（均不展示则跳过；只展示一项时居中）
    // -------------------------------------------------------------

    private function drawDateRows(dc as Dc) as Void {
        if (!_showDate && !_showLunar) { return; }

        var now = Time.now();
        // FORMAT_SHORT 将月份/星期返回为数字（FORMAT_MEDIUM 返回本地化字符串）。
        var info = Gregorian.info(now, Time.FORMAT_SHORT);

        // 更新农历缓存（有矢量字用中文；否则 ASCII，避免方框）
        var solarKey = info.year * 10000 + info.month * 100 + info.day;
        if (_showLunar && solarKey != _lunarCacheKey) {
            if (_hasVectorDateFont) {
                _lunarStr = LunarCalendar.format(info.year, info.month, info.day);
            } else {
                _lunarStr = LunarCalendar.formatAscii(info.year, info.month, info.day);
            }
            _lunarCacheKey = solarKey;
        }

        var lunarReady = _showLunar && !_lunarStr.equals("");
        var dateFont = dateLineFontType();
        var dateY = s(SPEC_DATE_ROW_Y);
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);

        var dowIdx = info.day_of_week - 1;
        if (dowIdx < 0 || dowIdx > 6) { dowIdx = 0; }

        if (_showDate && lunarReady) {
            // 日期 + 农历并排，整体居中
            var dateStr = buildDateLineString(info.month, info.day, dowIdx);
            var gap = s(20);
            var dateW = dc.getTextWidthInPixels(dateStr, dateFont);
            var lunarW = dc.getTextWidthInPixels(_lunarStr, dateFont);
            var leftX = _cx - (dateW + gap + lunarW) / 2;
            dc.drawText(leftX, dateY, dateFont, dateStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(leftX + dateW + gap, dateY, dateFont, _lunarStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (_showDate) {
            // 仅日期，居中
            var dateStr = buildDateLineString(info.month, info.day, dowIdx);
            dc.drawText(_cx, dateY, dateFont, dateStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (lunarReady) {
            // 仅农历，居中
            dc.drawText(_cx, dateY, dateFont, _lunarStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function dateLineFontType() as Graphics.FontType {
        return _dateLineFont;
    }

    private function buildDateLineString(month as Number, day as Number, dayOfWeekIdx as Number) as String {
        if (_hasVectorDateFont) {
            return month.format("%d") + "月" + day.format("%d") + "日 " + WEEKDAYS_ZH[dayOfWeekIdx];
        }
        return month.format("%d") + "." + day.format("%d") + " " + WEEKDAYS_EN[dayOfWeekIdx];
    }

    // -------------------------------------------------------------
    // 底部指标行（可配置，单侧有值时自动居中）
    // -------------------------------------------------------------

    private function drawBottomMetrics(dc as Dc) as Void {
        var bottomDividerSpecY = 960 - SPEC_DIVIDER_EDGE_INSET;
        var iconY  = s(bottomDividerSpecY + SPEC_BOTTOM_ICON_BELOW_DIVIDER);
        var valueY = s(bottomDividerSpecY + SPEC_BOTTOM_VALUE_BELOW_DIVIDER);
        var hasLeft  = (_bottomLeftMetric  != 0);
        var hasRight = (_bottomRightMetric != 0);
        var bothPresent = hasLeft && hasRight;
        var leftX  = bothPresent ? _cx - s(150) : _cx;
        var rightX = bothPresent ? _cx + s(150) : _cx;
        if (hasLeft)  { drawMetricBottom(dc, _bottomLeftMetric,  leftX,  iconY, valueY); }
        if (hasRight) { drawMetricBottom(dc, _bottomRightMetric, rightX, iconY, valueY); }
    }

    // 在底部行绘制单个指标（图标在上，文字居中在下）
    private function drawMetricBottom(dc as Dc, metric as Number, centerX as Number,
                                      iconY as Number, valueY as Number) as Void {
        var valueFont = Graphics.FONT_XTINY;
        var iconHalf = METRIC_ICON_PX / 2;
        if (metric == 1) {
            var hr = getHeartRate();
            if (_heartBmp != null) { dc.drawBitmap(centerX - iconHalf, iconY - iconHalf, _heartBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, valueFont, (hr == null) ? "--" : hr.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 2) {
            var pct = System.getSystemStats().battery;
            var battW = s(92);
            var battH = s(46);
            drawBatteryIcon(dc, centerX - battW / 2, iconY - battH / 2, battW, battH, pct);
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, valueFont, pct.format("%d") + "%",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 3) {
            var steps = getSteps();
            if (_stepsBmp != null) { dc.drawBitmap(centerX - iconHalf, iconY - iconHalf, _stepsBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, valueFont, (steps == null) ? "--" : steps.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 4) {
            var alt = getAltitude();
            if (_altBmp != null) { dc.drawBitmap(centerX - iconHalf, iconY - iconHalf, _altBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, valueFont, (alt == null) ? "--" : alt.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // -------------------------------------------------------------
    // 通用分割线
    // -------------------------------------------------------------

    private function drawHorizontalDivider(dc as Dc, yFloat as Float) as Void {
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        var pen = s(2);
        if (pen < 1) { pen = 1; }
        dc.setPenWidth(pen);
        var halfExtra = DIVIDER_LINE_EXTRA_WIDTH_PX / 2;
        var x1 = s(150) - halfExtra;
        var x2 = _w - s(150) + halfExtra;
        if (x1 < 0) { x1 = 0; }
        if (x2 > _w) { x2 = _w; }
        var y = Math.round(yFloat).toNumber();
        dc.drawLine(x1, y, x2, y);
        dc.setPenWidth(1);
    }

    // -------------------------------------------------------------
    // 数据读取——从手表获取真实数值
    // -------------------------------------------------------------

    private function getHeartRate() as Number? {
        // 通过 Activity 取实时心率，失败则回退到最近一条历史采样
        //（低功耗模式下 Activity 可能返回 null）。
        var info = Activity.getActivityInfo();
        if (info != null) {
            var hr = info.currentHeartRate;
            if (hr != null) { return hr; }
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var iter = ActivityMonitor.getHeartRateHistory(1, true);
            if (iter != null) {
                var sample = iter.next();
                if (sample != null) {
                    var hr = sample.heartRate;
                    if (hr != null && hr != ActivityMonitor.INVALID_HR_SAMPLE) {
                        return hr;
                    }
                }
            }
        }
        return null;
    }

    private function getSteps() as Number? {
        return ActivityMonitor.getInfo().steps;
    }

    private function getAltitude() as Number? {
        // Activity.altitude 为最近的气压或 GPS 读数，
        // 文档中在表盘场景下推荐使用该入口。
        var info = Activity.getActivityInfo();
        if (info != null) {
            var alt = info.altitude;
            if (alt != null) { return alt.toNumber(); }
        }
        return null;
    }
}
