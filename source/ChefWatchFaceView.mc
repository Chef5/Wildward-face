import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Complications;
import Toybox.SensorHistory;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;
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
    // 指标图标：设计稿约 104×104（960 画布）；SVG 栅格 32×32，运行时按屏宽缩放并绘制缩放。
    private const SPEC_METRIC_ICON = 104;
    private const METRIC_ICON_MAX_PX = 32;
    // 大气压趋势：与 30 分钟前对比；差值在此阈值内视为平稳（hPa）
    private const PRESSURE_TREND_COMPARE_SEC = 1800;
    private const PRESSURE_TREND_TOLERANCE_SEC = 600;
    private const PRESSURE_STABLE_HPA = 1;
    // 月跑量：同月内重算间隔；活动 startTime 异常 epoch 修正（秒）
    private const MONTHLY_RUN_REFRESH_MIN_MS = 1800000;
    private const ACTIVITY_EPOCH_OFFSET_SEC = 631065600;
    // 长按命中区域（960 设计单位，与绘制布局对齐）
    private const SPEC_TOP_HIT_HALF_W = 140;
    private const SPEC_TOP_HIT_HALF_H = 80;
    private const SPEC_BOTTOM_HIT_HALF_W = 140;
    private const SPEC_BOTTOM_HIT_HALF_H = 120;

    // ---- 运行时状态 ----
    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _scale as Float = 1.0;
    private var _metricIconPx as Number = METRIC_ICON_MAX_PX;

    // ---- 设置 ----
    private var _accent as Number = 0xB77CFF;
    // 字体大小档位（暂时固定为 3=中，设置项已隐藏）
    private var _fontSize as Number = 3;
    private var _showSeconds as Boolean = true;
    private var _showDate as Boolean = true;
    private var _showLunar as Boolean = true;
    private var _showDividers as Boolean = true;
    // 电量展示：0=百分制  1=续航时间（8d11h / 11h）
    private var _batteryDisplay as Number = 0;
    // 各位置指标 ID：0=不展示  1=心率  2=电量  3=步数  4=海拔  5=卡路里  6=血氧
    //                  7=大气压  8=身体电量  9=压力值  10=日出  11=日落  12=天气  13=呼吸频率
    //                  14=日出日落  15=周跑量  16=月跑量  17=消息通知  18=恢复时间
    private var _topLeftMetric     as Number = 4; // 默认：海拔
    private var _topRightMetric    as Number = 2; // 默认：电量
    private var _bottomLeftMetric  as Number = 1; // 默认：心率
    private var _bottomRightMetric as Number = 3; // 默认：步数

    // ---- 图标位图（在 onLayout 中只加载一次）----
    private var _heartBmp as BitmapResource?;
    private var _stepsBmp as BitmapResource?;
    private var _altBmp   as BitmapResource?;
    private var _caloriesBmp as BitmapResource?;
    private var _spo2Bmp as BitmapResource?;
    private var _pressureBmp as BitmapResource?;
    private var _bodyBatteryBmp as BitmapResource?;
    private var _stressBmp as BitmapResource?;
    private var _sunriseBmp as BitmapResource?;
    private var _sunsetBmp as BitmapResource?;
    private var _weatherClearBmp as BitmapResource?;
    private var _weatherPartlyCloudyBmp as BitmapResource?;
    private var _weatherCloudyBmp as BitmapResource?;
    private var _weatherRainBmp as BitmapResource?;
    private var _weatherShowersBmp as BitmapResource?;
    private var _weatherThunderBmp as BitmapResource?;
    private var _weatherSnowBmp as BitmapResource?;
    private var _weatherFogBmp as BitmapResource?;
    private var _weatherWindyBmp as BitmapResource?;
    private var _weatherExtremeBmp as BitmapResource?;
    private var _respirationBmp as BitmapResource?;
    private var _runningBmp as BitmapResource?;
    private var _notificationsBmp as BitmapResource?;
    private var _recoveryBmp as BitmapResource?;
    // 月跑量缓存（米）；cacheKey = year*100+month
    private var _monthlyRunDistanceM as Float = 0.0;
    private var _monthlyRunCacheKey as Number = 0;
    private var _monthlyRunLastRefreshMs as Number = 0;

    // ---- 字体 ----
    // _baseFontH：onLayout 时缓存 FONT_XTINY 行高，作为各档位尺寸的基准。
    // _uiFont：由 rebuildUiFont() 计算，用于所有指标数值和日期/农历文字。
    // _isChineseLocale：设备系统语言为简体/繁体中文时为 true；控制中文日期格式与农历展示。
    // _systemLanguage：当前系统语言，用于本地化日期/星期格式。
    private var _baseFontH as Number = 0;
    private var _uiFont as Graphics.FontType = Graphics.FONT_XTINY;
    private var _isChineseLocale as Boolean = false;
    private var _systemLanguage as Number = System.LANGUAGE_ENG;

    // ---- 按日缓存的值 ----
    private var _lunarStr as String = "";
    private var _lunarCacheKey as Number = -1; // 打包 yyyymmdd 用于按日失效

    // Gregorian day_of_week：1=周日 … 7=周六 → 0..6
    private const WEEKDAYS_ZH = [
        "周日", "周一", "周二", "周三", "周四", "周五", "周六"
    ];
    private const WEEKDAYS_ZHT = [
        "週日", "週一", "週二", "週三", "週四", "週五", "週六"
    ];
    private const WEEKDAYS_JA = [
        "日", "月", "火", "水", "木", "金", "土"
    ];
    private const WEEKDAYS_DE = [
        "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"
    ];
    private const WEEKDAYS_FR = [
        "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"
    ];
    private const WEEKDAYS_ES = [
        "Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"
    ];
    private const WEEKDAYS_IT = [
        "Dom", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab"
    ];
    private const WEEKDAYS_NL = [
        "Zo", "Ma", "Di", "Wo", "Do", "Vr", "Za"
    ];
    private const WEEKDAYS_NO = [
        "Søn", "Man", "Tir", "Ons", "Tor", "Fre", "Lør"
    ];
    private const WEEKDAYS_PL = [
        "Nd", "Pn", "Wt", "Śr", "Cz", "Pt", "Sb"
    ];
    private const WEEKDAYS_RU = [
        "Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"
    ];
    private const WEEKDAYS_KO = [
        "일", "월", "화", "수", "목", "금", "토"
    ];
    private const WEEKDAYS_EN = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    ];
    private const LAST_ACCENT_COLOR_KEY = "lastAccentColor";

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        var p = Application.Properties;
        var v;
        var accentColor = 0xB77CFF;
        v = p.getValue("AccentColor");
        if (v != null) { accentColor = v as Number; }
        clearCustomAccentIfAccentListChanged(accentColor);
        v = p.getValue("CustomAccentColor");
        var customAccent = parseCustomAccentColor(v != null ? v as String : "");
        _accent = customAccent != null ? customAccent : accentColor;
        v = p.getValue("ShowSeconds");
        if (v != null) { _showSeconds = v as Boolean; }
        v = p.getValue("ShowDate");
        if (v != null) { _showDate = v as Boolean; }
        v = p.getValue("ShowLunar");
        if (v != null) { _showLunar = v as Boolean; }
        v = p.getValue("ShowDividers");
        if (v != null) { _showDividers = v as Boolean; }
        v = p.getValue("BatteryDisplay");
        if (v != null) { _batteryDisplay = v as Number; }
        v = p.getValue("TopLeftMetric");
        if (v != null) { _topLeftMetric = v as Number; }
        v = p.getValue("TopRightMetric");
        if (v != null) { _topRightMetric = v as Number; }
        v = p.getValue("BottomLeftMetric");
        if (v != null) { _bottomLeftMetric = v as Number; }
        v = p.getValue("BottomRightMetric");
        if (v != null) { _bottomRightMetric = v as Number; }
        // 设置变更后重新计算字体（_baseFontH 为 0 时说明 onLayout 尚未运行，跳过）
        updateLocaleFlags();
        rebuildUiFont();
        if (isMonthlyRunMetricActive()) {
            refreshMonthlyRunDistance(true);
        }
    }

    private function updateLocaleFlags() as Void {
        _systemLanguage = System.getDeviceSettings().systemLanguage;
        _isChineseLocale = (_systemLanguage == System.LANGUAGE_CHS || _systemLanguage == System.LANGUAGE_CHT);
    }

    private function shouldShowLunar() as Boolean {
        return _showLunar && _isChineseLocale;
    }

    // 用户切换主题色列表时清空自定义色，使新预设生效（用 Storage 记录上次值以跨重启检测）。
    function clearCustomAccentIfAccentListChanged(accentColor as Number) as Void {
        var lastAccent = Application.Storage.getValue(LAST_ACCENT_COLOR_KEY);
        if (lastAccent != null && (lastAccent as Number) != accentColor) {
            Application.Properties.setValue("CustomAccentColor", "");
        }
        Application.Storage.setValue(LAST_ACCENT_COLOR_KEY, accentColor);
    }

    // 解析自定义主题色（6 位十六进制，可选 # 前缀）；无效或留空返回 null。
    function parseCustomAccentColor(raw as String) as Number? {
        if (raw == null || raw.length() == 0) {
            return null;
        }
        var hex = raw;
        if (hex.substring(0, 1).equals("#")) {
            hex = hex.substring(1, hex.length());
        }
        if (hex.length() != 6) {
            return null;
        }
        hex = hex.toUpper();
        var digits = "0123456789ABCDEF";
        var value = 0;
        for (var i = 0; i < 6; i++) {
            var idx = digits.find(hex.substring(i, i + 1));
            if (idx == null || idx < 0) {
                return null;
            }
            value = (value << 4) | idx;
        }
        return value;
    }

    function onLayout(dc as Dc) as Void {
        System.println("DBG onLayout start");
        setLayout(Rez.Layouts.WatchFace(dc));
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _scale = _w / 960.0;
        updateMetricIconPx();
        System.println("DBG loading bitmaps");
        _heartBmp = WatchUi.loadResource(Rez.Drawables.BpmIcon)   as BitmapResource;
        System.println("DBG heartBmp ok");
        _stepsBmp = WatchUi.loadResource(Rez.Drawables.StepsIcon)  as BitmapResource;
        System.println("DBG stepsBmp ok");
        _altBmp   = WatchUi.loadResource(Rez.Drawables.AltIcon)    as BitmapResource;
        System.println("DBG altBmp ok");
        _caloriesBmp = WatchUi.loadResource(Rez.Drawables.CaloriesIcon) as BitmapResource;
        System.println("DBG caloriesBmp ok");
        _spo2Bmp = WatchUi.loadResource(Rez.Drawables.Spo2Icon) as BitmapResource;
        System.println("DBG spo2Bmp ok");
        _pressureBmp = WatchUi.loadResource(Rez.Drawables.PressureIcon) as BitmapResource;
        _bodyBatteryBmp = WatchUi.loadResource(Rez.Drawables.BodyBatteryIcon) as BitmapResource;
        _stressBmp = WatchUi.loadResource(Rez.Drawables.StressIcon) as BitmapResource;
        _sunriseBmp = WatchUi.loadResource(Rez.Drawables.SunriseIcon) as BitmapResource;
        _sunsetBmp = WatchUi.loadResource(Rez.Drawables.SunsetIcon) as BitmapResource;
        _weatherClearBmp = WatchUi.loadResource(Rez.Drawables.WeatherClearIcon) as BitmapResource;
        _weatherPartlyCloudyBmp = WatchUi.loadResource(Rez.Drawables.WeatherPartlyCloudyIcon) as BitmapResource;
        _weatherCloudyBmp = WatchUi.loadResource(Rez.Drawables.WeatherCloudyIcon) as BitmapResource;
        _weatherRainBmp = WatchUi.loadResource(Rez.Drawables.WeatherRainIcon) as BitmapResource;
        _weatherShowersBmp = WatchUi.loadResource(Rez.Drawables.WeatherShowersIcon) as BitmapResource;
        _weatherThunderBmp = WatchUi.loadResource(Rez.Drawables.WeatherThunderIcon) as BitmapResource;
        _weatherSnowBmp = WatchUi.loadResource(Rez.Drawables.WeatherSnowIcon) as BitmapResource;
        _weatherFogBmp = WatchUi.loadResource(Rez.Drawables.WeatherFogIcon) as BitmapResource;
        _weatherWindyBmp = WatchUi.loadResource(Rez.Drawables.WeatherWindyIcon) as BitmapResource;
        _weatherExtremeBmp = WatchUi.loadResource(Rez.Drawables.WeatherExtremeIcon) as BitmapResource;
        _respirationBmp = WatchUi.loadResource(Rez.Drawables.RespirationIcon) as BitmapResource;
        _runningBmp = WatchUi.loadResource(Rez.Drawables.RunningIcon) as BitmapResource;
        _notificationsBmp = WatchUi.loadResource(Rez.Drawables.NotificationsIcon) as BitmapResource;
        _recoveryBmp = WatchUi.loadResource(Rez.Drawables.RecoveryIcon) as BitmapResource;
        // 缓存 FONT_XTINY 行高作为字体档位的基准，然后按当前档位构建 _uiFont
        _baseFontH = dc.getFontHeight(Graphics.FONT_XTINY);
        System.println("DBG baseFontH=" + _baseFontH.format("%d"));
        rebuildUiFont();
        System.println("DBG onLayout done, isChineseLocale=" + _isChineseLocale.toString());
    }

    function onShow() as Void {
        loadSettings();
    }

    // 将规格坐标（1:960）换算为设备像素
    private function s(v as Numeric) as Number {
        return Math.round(v * _scale).toNumber();
    }

    private function sf(v as Numeric) as Float {
        return v * _scale;
    }

    // 按屏宽换算指标图标边长；小屏 MIP（255 / 7 系列等）再略缩，大屏不超过 SVG 栅格。
    private function updateMetricIconPx() as Void {
        var px = s(SPEC_METRIC_ICON);
        var factor = 1.0;
        if (_w <= 218) {
            factor = 0.88;  // fr255s / fr255sm、fenix7s 等
        } else if (_w <= 240) {
            factor = 0.90;
        } else if (_w <= 260) {
            factor = 0.92;  // fr255 / fr255m、fenix7、fr955 等
        } else if (_w <= 280) {
            factor = 0.95;
        }
        px = Math.round(px * factor).toNumber();
        if (px > METRIC_ICON_MAX_PX) { px = METRIC_ICON_MAX_PX; }
        if (px < 16) { px = 16; }
        _metricIconPx = px;
    }

    function onUpdate(dc as Dc) as Void {
        System.println("DBG onUpdate");
        if (_w == 0) {
            _w = dc.getWidth();
            _h = dc.getHeight();
            _cx = _w / 2;
            _cy = _h / 2;
            _scale = _w / 960.0;
            updateMetricIconPx();
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
        if (metric == 1) {
            var hr = getHeartRate();
            drawIconTextGroup(dc, _heartBmp, (hr == null) ? "--" : hr.format("%d"), centerX, rowCenterY);
        } else if (metric == 2) {
            var pct = System.getSystemStats().battery;
            var battText = getBatteryDisplayText(pct);
            var battValueW = dc.getTextWidthInPixels(battText, _uiFont);
            var battW = s(92);
            var battH = s(46);
            var battGap = s(24);
            var groupW = battW + battGap + battValueW;
            var battLeftX = centerX - groupW / 2;
            var battTextX = battLeftX + battW + battGap;
            drawBatteryIcon(dc, battLeftX, rowCenterY - battH / 2, battW, battH, pct);
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(battTextX, rowCenterY, _uiFont, battText,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 3) {
            var steps = getSteps();
            drawIconTextGroup(dc, _stepsBmp, (steps == null) ? "--" : steps.format("%d"), centerX, rowCenterY);
        } else if (metric == 4) {
            var alt = getAltitude();
            drawIconTextGroup(dc, _altBmp, (alt == null) ? "--" : alt.format("%d"), centerX, rowCenterY);
        } else if (metric == 5) {
            var cal = getCalories();
            drawIconTextGroup(dc, _caloriesBmp, (cal == null) ? "--" : cal.format("%d"), centerX, rowCenterY);
        } else if (metric == 6) {
            var spo2 = getSpO2();
            drawIconTextGroup(dc, _spo2Bmp, (spo2 == null) ? "--" : spo2.format("%d") + "%", centerX, rowCenterY);
        } else if (metric == 7) {
            drawIconTextGroup(dc, _pressureBmp, getBarometricPressureText(), centerX, rowCenterY);
        } else if (metric == 8) {
            var bb = getBodyBattery();
            drawIconTextGroup(dc, _bodyBatteryBmp, (bb == null) ? "--" : bb.format("%d"), centerX, rowCenterY);
        } else if (metric == 9) {
            var stress = getStress();
            drawIconTextGroup(dc, _stressBmp, (stress == null) ? "--" : stress.format("%d"), centerX, rowCenterY);
        } else if (metric == 10) {
            drawIconTextGroup(dc, _sunriseBmp, getSunriseTimeText(), centerX, rowCenterY);
        } else if (metric == 11) {
            drawIconTextGroup(dc, _sunsetBmp, getSunsetTimeText(), centerX, rowCenterY);
        } else if (metric == 14) {
            drawIconTextGroup(dc, getSunriseSunsetAutoBmp(), getSunriseSunsetAutoText(), centerX, rowCenterY);
        } else if (metric == 12) {
            drawWeatherMetricTop(dc, centerX, rowCenterY);
        } else if (metric == 13) {
            var rr = getRespirationRate();
            drawIconTextGroup(dc, _respirationBmp, (rr == null) ? "--" : rr.format("%d"), centerX, rowCenterY);
        } else if (metric == 15) {
            drawIconTextGroup(dc, _runningBmp, getWeeklyRunDistanceText(), centerX, rowCenterY);
        } else if (metric == 16) {
            drawIconTextGroup(dc, _runningBmp, getMonthlyRunDistanceText(), centerX, rowCenterY);
        } else if (metric == 17) {
            drawIconTextGroup(dc, _notificationsBmp, getNotificationCountText(), centerX, rowCenterY);
        } else if (metric == 18) {
            drawIconTextGroup(dc, _recoveryBmp, getRecoveryTimeText(), centerX, rowCenterY);
        }
    }

    private function drawWeatherMetricTop(dc as Dc, centerX as Number, rowCenterY as Number) as Void {
        var condition = getWeatherCondition();
        var icon = getWeatherIconBmp(condition);
        drawIconTextGroup(dc, icon, getWeatherTemperatureText(), centerX, rowCenterY);
    }

    // 顶部行通用绘制：指标图标在左，文字在右，整体以 centerX 居中
    private function drawIconTextGroup(dc as Dc, bmp as BitmapResource?,
                                       text as String,
                                       centerX as Number, centerY as Number) as Void {
        var iconSize = _metricIconPx;
        var iconHalf = _metricIconPx / 2;
        var iconTextGap = s(28);
        var textW  = dc.getTextWidthInPixels(text, _uiFont);
        var groupW = iconSize + iconTextGap + textW;
        var iconCenterX = centerX - groupW / 2 + iconSize / 2;
        var textLeftX   = centerX - groupW / 2 + iconSize + iconTextGap;
        if (bmp != null) {
            drawTintedBitmap(dc, iconCenterX - iconHalf, centerY - iconHalf, bmp);
        }
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textLeftX, centerY, _uiFont, text,
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

    // 电量数值：百分制，或续航时间（≥1 天 8d11h，不足 1 天 11h）。
    private function getBatteryDisplayText(pct as Float) as String {
        if (_batteryDisplay == 1) {
            var stats = System.getSystemStats();
            if (stats has :batteryInDays) {
                var days = stats.batteryInDays;
                if (days != null && days >= 1.0) {
                    var d = days.toNumber();
                    var h = ((days - d) * 24).toNumber();
                    if (h > 0) {
                        return d.format("%d") + "d" + h.format("%d") + "h";
                    }
                    return d.format("%d") + "d";
                }
                if (days != null) {
                    var hours = (days * 24).toNumber();
                    if (hours < 1) { hours = 1; }
                    return hours.format("%d") + "h";
                }
            }
        }
        return pct.format("%d") + "%";
    }

    // -------------------------------------------------------------
    // 中心时间
    // -------------------------------------------------------------

    private function drawCenterTime(dc as Dc) as Void {
        var clock = System.getClockTime();
        var is24Hour = System.getDeviceSettings().is24Hour;
        var hour = clock.hour;
        if (!is24Hour) {
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
        // HH:MM 块居中；秒数/AM·PM 置于「分」右侧（可能向右伸出）
        var blockLeft = _cx - totalW / 2;
        var showSeconds = _showSeconds;
        var showAmPm = !is24Hour;
        if (showSeconds || showAmPm) {
            blockLeft -= s(8);
        }
        // 日期行和农历均不展示时，时间垂直居中于两条分割线之间（设计单位 480）
        var hasDateContent = _showDate || shouldShowLunar();
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

        var suffixX = minX + minW + s(2);

        // 秒——分右下角；按基线对齐（用 box-bottom − descent 跨字体对齐效果差）
        if (showSeconds) {
            dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
            var secH = dc.getFontHeight(secFont);
            var descBig = Graphics.getFontDescent(bigFont);
            var descSec = Graphics.getFontDescent(secFont);
            var minBaseline = centerLineY + bigH / 2 - descBig;
            var secY = minBaseline - secH / 2 + descSec;
            dc.drawText(suffixX, secY, secFont, secStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 12 小时制：AM / PM 与时分垂直居中（跟随系统时间制，独立于秒数设置）
        if (showAmPm) {
            var ampmStr = clock.hour < 12 ? "AM" : "PM";
            var ampmFont = secFont;
            if (Graphics has :getVectorFont) {
                var secH = dc.getFontHeight(secFont);
                var smallSize = (secH * 0.7).toNumber();
                if (smallSize < 7) { smallSize = 7; }
                var vf = Graphics.getVectorFont({ :face => "RobotoCondensedRegular", :size => smallSize });
                if (vf != null) {
                    ampmFont = vf;
                }
            }
            dc.drawText(suffixX, centerLineY, ampmFont, ampmStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // -------------------------------------------------------------
    // 日期与农历（均不展示则跳过；只展示一项时居中）
    // -------------------------------------------------------------

    private function drawDateRows(dc as Dc) as Void {
        if (!_showDate && !shouldShowLunar()) { return; }

        var now = Time.now();
        // FORMAT_SHORT 将月份/星期返回为数字（FORMAT_MEDIUM 返回本地化字符串）。
        var info = Gregorian.info(now, Time.FORMAT_SHORT);

        // 更新农历缓存（按日失效；仅中文环境展示）
        var solarKey = info.year * 10000 + info.month * 100 + info.day;
        if (shouldShowLunar() && solarKey != _lunarCacheKey) {
            _lunarStr = LunarCalendar.format(info.year, info.month, info.day);
            _lunarCacheKey = solarKey;
        }

        var lunarReady = shouldShowLunar() && !_lunarStr.equals("");
        var dateY = s(SPEC_DATE_ROW_Y);
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);

        var dowIdx = info.day_of_week - 1;
        if (dowIdx < 0 || dowIdx > 6) { dowIdx = 0; }

        if (_showDate && lunarReady) {
            // 日期 + 农历并排，整体居中
            var dateStr = buildDateLineString(info.month, info.day, dowIdx);
            var gap = s(20);
            var dateW = dc.getTextWidthInPixels(dateStr, _uiFont);
            var lunarW = dc.getTextWidthInPixels(_lunarStr, _uiFont);
            var leftX = _cx - (dateW + gap + lunarW) / 2;
            dc.drawText(leftX, dateY, _uiFont, dateStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(leftX + dateW + gap, dateY, _uiFont, _lunarStr,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (_showDate) {
            // 仅日期，居中
            var dateStr = buildDateLineString(info.month, info.day, dowIdx);
            dc.drawText(_cx, dateY, _uiFont, dateStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (lunarReady) {
            // 仅农历，居中
            dc.drawText(_cx, dateY, _uiFont, _lunarStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // 按系统语言返回本地化日期字符串。
    // 欧洲语言（德/法/西/意/荷/挪/波/俄）使用日.月 格式；东亚语言保留各自月日顺序。
    private function buildDateLineString(month as Number, day as Number, dayOfWeekIdx as Number) as String {
        var m = month.format("%d");
        var d = day.format("%d");
        var lang = _systemLanguage;

        if (lang == System.LANGUAGE_CHS) {
            return m + "月" + d + "日 " + WEEKDAYS_ZH[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_CHT) {
            return m + "月" + d + "日 " + WEEKDAYS_ZHT[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_JPN) {
            // 日本語：6月5日(金)
            return m + "月" + d + "日(" + WEEKDAYS_JA[dayOfWeekIdx] + ")";
        }
        if (lang == System.LANGUAGE_KOR) {
            // 한국어：6월 5일 금
            return m + "월 " + d + "일 " + WEEKDAYS_KO[dayOfWeekIdx];
        }
        // 欧洲语言：日.月 星期缩写（日优先格式）
        if (lang == System.LANGUAGE_DEU) {
            return d + "." + m + ". " + WEEKDAYS_DE[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_FRE) {
            return d + "." + m + " " + WEEKDAYS_FR[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_SPA) {
            return d + "." + m + " " + WEEKDAYS_ES[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_ITA) {
            return d + "." + m + " " + WEEKDAYS_IT[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_DUT) {
            return d + "." + m + " " + WEEKDAYS_NL[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_NOB) {
            return d + "." + m + " " + WEEKDAYS_NO[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_POL) {
            return d + "." + m + " " + WEEKDAYS_PL[dayOfWeekIdx];
        }
        if (lang == System.LANGUAGE_RUS) {
            return d + "." + m + " " + WEEKDAYS_RU[dayOfWeekIdx];
        }
        // 默认英语及其他未适配语言
        return m + "." + d + " " + WEEKDAYS_EN[dayOfWeekIdx];
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
        var iconHalf = _metricIconPx / 2;
        if (metric == 1) {
            var hr = getHeartRate();
            if (_heartBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _heartBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (hr == null) ? "--" : hr.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 2) {
            var pct = System.getSystemStats().battery;
            var battW = s(92);
            var battH = s(46);
            drawBatteryIcon(dc, centerX - battW / 2, iconY - battH / 2, battW, battH, pct);
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getBatteryDisplayText(pct),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 3) {
            var steps = getSteps();
            if (_stepsBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _stepsBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (steps == null) ? "--" : steps.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 4) {
            var alt = getAltitude();
            if (_altBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _altBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (alt == null) ? "--" : alt.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 5) {
            var cal = getCalories();
            if (_caloriesBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _caloriesBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (cal == null) ? "--" : cal.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 6) {
            var spo2 = getSpO2();
            if (_spo2Bmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _spo2Bmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (spo2 == null) ? "--" : spo2.format("%d") + "%",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 7) {
            if (_pressureBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _pressureBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getBarometricPressureText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 8) {
            var bb = getBodyBattery();
            if (_bodyBatteryBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _bodyBatteryBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (bb == null) ? "--" : bb.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 9) {
            var stress = getStress();
            if (_stressBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _stressBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (stress == null) ? "--" : stress.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 10) {
            if (_sunriseBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _sunriseBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getSunriseTimeText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 11) {
            if (_sunsetBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _sunsetBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getSunsetTimeText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 14) {
            var autoBmp = getSunriseSunsetAutoBmp();
            if (autoBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, autoBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getSunriseSunsetAutoText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 12) {
            drawWeatherMetricBottom(dc, centerX, iconY, valueY);
        } else if (metric == 13) {
            var rr = getRespirationRate();
            if (_respirationBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _respirationBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, (rr == null) ? "--" : rr.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 15) {
            if (_runningBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _runningBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getWeeklyRunDistanceText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 16) {
            if (_runningBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _runningBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getMonthlyRunDistanceText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 17) {
            if (_notificationsBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _notificationsBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getNotificationCountText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (metric == 18) {
            if (_recoveryBmp != null) { drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, _recoveryBmp); }
            dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, valueY, _uiFont, getRecoveryTimeText(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawWeatherMetricBottom(dc as Dc, centerX as Number,
                                             iconY as Number, valueY as Number) as Void {
        var iconHalf = _metricIconPx / 2;
        var icon = getWeatherIconBmp(getWeatherCondition());
        if (icon != null) {
            drawTintedBitmap(dc, centerX - iconHalf, iconY - iconHalf, icon);
        }
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, valueY, _uiFont, getWeatherTemperatureText(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // 用主题色着色后绘制图标位图。
    // 用主题色着色后绘制图标位图。
    // 图标 SVG 以白色编译（fill="#FFFFFF"），automaticPalette="false" 确保
    // 位图以设备原生色彩格式存储（fr255: ARGB2222，fr265: PNG），
    // drawBitmap2 + tintColor 在 MIP 和 AMOLED 上均可正常工作。
    private function drawTintedBitmap(dc as Dc, x as Number, y as Number,
                                      bmp as BitmapResource) as Void {
        if (dc has :drawBitmap2) {
            var srcW = bmp.getWidth();
            if (srcW > 0 && _metricIconPx > 0 && _metricIconPx != srcW) {
                var scale = _metricIconPx.toFloat() / srcW;
                var xf = new Graphics.AffineTransform();
                xf.scale(scale, scale);
                dc.drawBitmap2(x, y, bmp, {:tintColor => _accent, :transform => xf});
            } else {
                dc.drawBitmap2(x, y, bmp, {:tintColor => _accent});
            }
        } else {
            dc.drawBitmap(x, y, bmp);
        }
    }

    // 根据 _fontSize、_baseFontH 及当前系统语言重新计算 _uiFont。
    // 在 onLayout 缓存完 _baseFontH 之后调用，以及设置变更后调用。
    private function rebuildUiFont() as Void {
        if (_baseFontH <= 0) { return; }
        System.println("DBG rebuildUiFont fontSize=" + _fontSize.format("%d"));
        updateLocaleFlags();
        // 5 档尺寸系数：极小×0.9 / 小×1.0 / 中×1.25 / 大×1.5 / 极大×1.8
        var ratio;
        if (_fontSize <= 1)      { ratio = 0.9; }
        else if (_fontSize == 2) { ratio = 1.0; }
        else if (_fontSize == 3) { ratio = 1.25; }
        else if (_fontSize == 4) { ratio = 1.5; }
        else                     { ratio = 1.8; }
        var targetH = (_baseFontH * ratio).toNumber();
        System.println("DBG targetH=" + targetH.format("%d"));

        if (Graphics has :getVectorFont) {
            // AMOLED 设备：按语言选择最佳矢量字体，以 NotoSansSCMedium 兜底。
            // `:face` 支持字符串数组，按顺序尝试直到找到设备可用的字体。
            // - 韩语：NanumGothicRegular（谚文专用字体）
            // - 俄语：RobotoCondensedRegular（Roboto 全系含西里尔字符集）
            // - 其他：NotoSansSCMedium（CJK + Latin，含简/繁中文、日语）
            var faceName;
            if (_systemLanguage == System.LANGUAGE_KOR) {
                faceName = ["NanumGothicRegular", "NotoSansSCMedium"];
            } else if (_systemLanguage == System.LANGUAGE_RUS) {
                faceName = ["RobotoCondensedRegular", "NotoSansSCMedium"];
            } else {
                faceName = "NotoSansSCMedium";
            }
            var vf = Graphics.getVectorFont({ :face => faceName, :size => targetH });
            System.println("DBG vf=" + (vf != null ? "ok" : "null"));
            if (vf != null) {
                _uiFont = vf;
                return;
            }
        }
        // MIP 设备（fr255 等）：无向量字体，退回系统字体常量
        if (_fontSize <= 2)      { _uiFont = Graphics.FONT_XTINY; }
        else if (_fontSize == 3) { _uiFont = Graphics.FONT_TINY; }
        else if (_fontSize == 4) { _uiFont = Graphics.FONT_SMALL; }
        else                     { _uiFont = Graphics.FONT_MEDIUM; }
        System.println("DBG rebuildUiFont done");
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

    private function getCalories() as Number? {
        return ActivityMonitor.getInfo().calories;
    }

    private function getSpO2() as Number? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getOxygenSaturationHistory)) {
            return null;
        }
        var iter = SensorHistory.getOxygenSaturationHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) {
            return null;
        }
        var sample = iter.next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data.toNumber();
    }

    private function getComplicationNumericValue(complicationType as Complications.Type) as Number? {
        if (!(Toybox has :Complications)) {
            return null;
        }
        var comp = Complications.getComplication(new Complications.Id(complicationType));
        if (comp == null || comp.value == null) {
            return null;
        }
        var v = comp.value;
        if (v instanceof Float) {
            return (v as Float).toNumber();
        }
        return v as Number;
    }

    private function pressurePaToNumber(pa as Numeric) as Number {
        if (pa instanceof Float) {
            return ((pa as Float) / 100.0).toNumber();
        }
        return ((pa as Number).toFloat() / 100.0).toNumber();
    }

    private function getBarometricPressureText() as String {
        var data = getBarometricPressureData();
        if (data == null) {
            return "--";
        }
        var hPa = data.get(:hpa) as Number;
        var trend = data.get(:trend) as Number;
        var text = hPa.format("%d");
        if (trend > 0) {
            text += "\u2191";
        } else if (trend < 0) {
            text += "\u2193";
        }
        return text;
    }

    private function getBarometricPressureData() as Dictionary? {
        var currentPa = null as Float?;

        if (Toybox has :Complications) {
            var comp = Complications.getComplication(
                new Complications.Id(Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE)
            );
            if (comp != null && comp.value != null) {
                if (comp.value instanceof Float) {
                    currentPa = comp.value as Float;
                } else if (comp.value instanceof Number) {
                    currentPa = (comp.value as Number).toFloat();
                }
            }
        }

        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getPressureHistory)) {
            if (currentPa == null) {
                return null;
            }
            return {:hpa => pressurePaToNumber(currentPa), :trend => 0};
        }

        var periodSec = PRESSURE_TREND_COMPARE_SEC + PRESSURE_TREND_TOLERANCE_SEC;
        var iter = SensorHistory.getPressureHistory({
            :period => periodSec,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) {
            if (currentPa == null) {
                return null;
            }
            return {:hpa => pressurePaToNumber(currentPa), :trend => 0};
        }

        var now = Time.now();
        var newestPa = currentPa;
        var pastPa = null as Float?;
        var bestAgeDiff = 999999;

        while (true) {
            var sample = iter.next();
            if (sample == null) {
                break;
            }
            if (sample.data == null || sample.when == null) {
                continue;
            }
            var paF = sample.data instanceof Float
                ? sample.data as Float
                : (sample.data as Number).toFloat();
            if (newestPa == null) {
                newestPa = paF;
            }
            var ageSec = now.subtract(sample.when).value();
            if (ageSec < 0) {
                ageSec = 0;
            }
            var ageDiff = ageSec - PRESSURE_TREND_COMPARE_SEC;
            if (ageDiff < 0) {
                ageDiff = -ageDiff;
            }
            if (ageDiff < bestAgeDiff) {
                bestAgeDiff = ageDiff;
                pastPa = paF;
            }
        }

        if (newestPa == null) {
            return null;
        }

        var hPa = pressurePaToNumber(newestPa);
        var trend = 0;
        if (pastPa != null && bestAgeDiff <= PRESSURE_TREND_TOLERANCE_SEC) {
            var delta = hPa - pressurePaToNumber(pastPa);
            if (delta > PRESSURE_STABLE_HPA) {
                trend = 1;
            } else if (delta < -PRESSURE_STABLE_HPA) {
                trend = -1;
            }
        }
        return {:hpa => hPa, :trend => trend};
    }

    private function getBodyBattery() as Number? {
        var v = getComplicationNumericValue(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        if (v != null) {
            return v;
        }
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        var iter = SensorHistory.getBodyBatteryHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) {
            return null;
        }
        var sample = iter.next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data.toNumber();
    }

    private function getStress() as Number? {
        var v = getComplicationNumericValue(Complications.COMPLICATION_TYPE_STRESS);
        if (v != null) {
            return v;
        }
        var info = ActivityMonitor.getInfo();
        if (info has :stressScore) {
            var score = info.stressScore;
            if (score != null) {
                return score;
            }
        }
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getStressHistory)) {
            return null;
        }
        var iter = SensorHistory.getStressHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) {
            return null;
        }
        var sample = iter.next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data.toNumber();
    }

    private function getRespirationRate() as Number? {
        var v = getComplicationNumericValue(Complications.COMPLICATION_TYPE_RESPIRATION_RATE);
        if (v != null) {
            return v;
        }
        var info = ActivityMonitor.getInfo();
        if (info has :respirationRate) {
            var rr = info.respirationRate;
            if (rr != null) {
                return rr;
            }
        }
        return null;
    }

    private function getNotificationCount() as Number? {
        var settings = System.getDeviceSettings();
        if (settings has :notificationCount) {
            return settings.notificationCount;
        }
        return getComplicationNumericValue(Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT);
    }

    private function getNotificationCountText() as String {
        var count = getNotificationCount();
        if (count == null) {
            return "0";
        }
        return count.format("%d");
    }

    // Complication 为分钟；ActivityMonitor.timeToRecovery 为小时
    private function getRecoveryTimeMinutes() as Number? {
        var v = getComplicationNumericValue(Complications.COMPLICATION_TYPE_RECOVERY_TIME);
        if (v != null) {
            return v;
        }
        var info = ActivityMonitor.getInfo();
        if (info has :timeToRecovery) {
            var hours = info.timeToRecovery;
            if (hours != null) {
                return hours * 60;
            }
        }
        return null;
    }

    private function getRecoveryTimeText() as String {
        var minutes = getRecoveryTimeMinutes();
        if (minutes == null) {
            return "--";
        }
        if (minutes <= 0) {
            return "0h";
        }
        var hours = minutes / 60;
        if (hours < 1) {
            return "1h";
        }
        if (hours >= 24) {
            var d = hours / 24;
            var h = hours % 24;
            if (h > 0) {
                return d.format("%d") + "d" + h.format("%d") + "h";
            }
            return d.format("%d") + "d";
        }
        return hours.format("%d") + "h";
    }

    // 与 Garmin 周跑量 Complication 一致：SPORT_RUNNING（含路跑、越野跑、跑步机等子类型）
    private function isRunningActivityType(sportType as Number) as Boolean {
        return sportType == Activity.SPORT_RUNNING;
    }

    private function isMonthlyRunMetricActive() as Boolean {
        return _topLeftMetric == 16 || _topRightMetric == 16
            || _bottomLeftMetric == 16 || _bottomRightMetric == 16;
    }

    private function normalizeActivityStartSec(startTime as Time.Moment, todayVal as Number) as Number {
        var stVal = startTime.value();
        if ((todayVal - stVal) > 315576000) {
            stVal += ACTIVITY_EPOCH_OFFSET_SEC;
        }
        return stVal;
    }

    private function formatRunDistanceKmText(meters as Float) as String {
        var tenths = Math.round(meters / 100.0).toNumber();
        if (tenths <= 0) {
            return "0";
        }
        if (tenths % 10 == 0) {
            return (tenths / 10).format("%d");
        }
        return (tenths / 10.0).format("%.1f");
    }

    private function getWeeklyRunDistanceText() as String {
        if (!(Toybox has :Complications)) {
            return "0";
        }
        var comp = Complications.getComplication(
            new Complications.Id(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE)
        );
        if (comp == null || comp.value == null) {
            return "0";
        }
        var meters = comp.value instanceof Float
            ? comp.value as Float
            : (comp.value as Number).toFloat();
        return formatRunDistanceKmText(meters);
    }

    private function getMonthlyRunDistanceText() as String {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var cacheKey = nowInfo.year * 100 + nowInfo.month;
        if (cacheKey != _monthlyRunCacheKey) {
            refreshMonthlyRunDistance(true);
        }
        return formatRunDistanceKmText(_monthlyRunDistanceM);
    }

    private function refreshMonthlyRunDistance(force as Boolean) as Void {
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var cacheKey = nowInfo.year * 100 + nowInfo.month;
        if (!force && cacheKey == _monthlyRunCacheKey) {
            var elapsed = System.getTimer() - _monthlyRunLastRefreshMs;
            if (elapsed >= 0 && elapsed < MONTHLY_RUN_REFRESH_MIN_MS) {
                return;
            }
        }

        _monthlyRunDistanceM = 0.0;
        _monthlyRunCacheKey = cacheKey;
        _monthlyRunLastRefreshMs = System.getTimer();

        if (!(Toybox has :UserProfile) || !(UserProfile has :getUserActivityHistory)) {
            return;
        }

        var itr = UserProfile.getUserActivityHistory();
        if (itr == null) {
            return;
        }

        var todayVal = Time.today().value();
        var activity = itr.next();
        while (activity != null) {
            if (activity.startTime != null && activity.distance != null && activity.type != null) {
                if (isRunningActivityType(activity.type as Number)) {
                    var stVal = normalizeActivityStartSec(activity.startTime as Time.Moment, todayVal);
                    var actInfo = Gregorian.info(new Time.Moment(stVal), Time.FORMAT_SHORT);
                    if (actInfo.year == nowInfo.year && actInfo.month == nowInfo.month) {
                        var distM = activity.distance instanceof Float
                            ? activity.distance as Float
                            : (activity.distance as Number).toFloat();
                        _monthlyRunDistanceM += distM;
                    }
                }
            }
            activity = itr.next();
        }
    }

    // 将「距午夜秒数」格式化为时:分，12/24 小时制跟随系统设置。
    private function formatTimeOfDay(secondsSinceMidnight as Number) as String {
        var totalSec = secondsSinceMidnight;
        if (totalSec < 0) {
            totalSec = 0;
        }
        var hour = totalSec / 3600;
        var minute = (totalSec % 3600) / 60;
        if (!System.getDeviceSettings().is24Hour) {
            if (hour == 0) {
                hour = 12;
            } else if (hour > 12) {
                hour -= 12;
            }
        }
        return hour.format("%02d") + ":" + minute.format("%02d");
    }

    // 日出日落自动切换：
    // 切换点 = 事件整点小时 + 2，例如 7:35 日出 → 9:00 起显示日落；19:02 日落 → 21:00 起显示日出
    private function isBetweenSunriseAndSunset() as Boolean {
        var ct = System.getClockTime();
        var nowSec = ct.hour * 3600 + ct.min * 60 + ct.sec;
        var riseSec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNRISE);
        var setSec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNSET);
        if (riseSec == null || setSec == null) { return false; }
        var switchToSunset  = ((riseSec / 3600) + 2) * 3600;
        var switchToSunrise = ((setSec  / 3600) + 2) * 3600;
        return nowSec >= switchToSunset && nowSec < switchToSunrise;
    }

    private function getSunriseSunsetAutoBmp() as BitmapResource? {
        return isBetweenSunriseAndSunset() ? _sunsetBmp : _sunriseBmp;
    }

    private function getSunriseSunsetAutoText() as String {
        if (isBetweenSunriseAndSunset()) {
            var sec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNSET);
            return sec != null ? formatTimeOfDay(sec) : "--";
        }
        var sec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNRISE);
        return sec != null ? formatTimeOfDay(sec) : "--";
    }

    private function getSunriseTimeText() as String {
        var sec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNRISE);
        if (sec == null) {
            return "--";
        }
        return formatTimeOfDay(sec);
    }

    private function getSunsetTimeText() as String {
        var sec = getComplicationNumericValue(Complications.COMPLICATION_TYPE_SUNSET);
        if (sec == null) {
            return "--";
        }
        return formatTimeOfDay(sec);
    }

    private function getWeatherCondition() as Number? {
        if (!(Toybox has :Weather)) {
            return null;
        }
        var wx = Weather.getCurrentConditions();
        if (wx == null || wx.condition == null) {
            return null;
        }
        return wx.condition as Number;
    }

    private function isTemperatureMetric() as Boolean {
        var settings = System.getDeviceSettings();
        if (settings has :temperatureUnits) {
            return settings.temperatureUnits == System.UNIT_METRIC;
        }
        return true;
    }

    private function celsiusToDisplayNumber(celsius as Float) as Number {
        if (isTemperatureMetric()) {
            return Math.round(celsius).toNumber();
        }
        return Math.round(celsius * 9.0 / 5.0 + 32.0).toNumber();
    }

    private function getWeatherTemperatureText() as String {
        if (!(Toybox has :Weather)) {
            return "--";
        }
        var wx = Weather.getCurrentConditions();
        if (wx == null || wx.temperature == null) {
            return "--";
        }
        var celsius = wx.temperature instanceof Float
            ? (wx.temperature as Float)
            : (wx.temperature as Number).toFloat();
        var displayTemp = celsiusToDisplayNumber(celsius);
        if (isTemperatureMetric()) {
            return displayTemp.format("%d") + "\u00B0C";
        }
        return displayTemp.format("%d") + "\u00B0F";
    }

    // Garmin Weather.CONDITION_* → 表盘天气图标
    private function getWeatherIconBmp(condition as Number?) as BitmapResource? {
        // 少云：无数据
        if (condition == null) {
            return _weatherPartlyCloudyBmp;
        }
        // 极端天气：冰雹、龙卷风、飓风、热带风暴
        if (condition == 10 || condition == 32 || condition == 41 || condition == 42) {
            return _weatherExtremeBmp;
        }
        // 风：大风、飑线
        if (condition == 5 || condition == 36) {
            return _weatherWindyBmp;
        }
        // 雾：雾、薄雾、轻雾、霾、扬尘、烟霾、沙尘、沙暴、火山灰
        if (condition == 8 || condition == 9 || condition == 29 || condition == 39
            || condition == 30 || condition == 33 || condition == 35 || condition == 37 || condition == 38) {
            return _weatherFogBmp;
        }
        // 雪：雪、小雪、大雪、可能下雪、阴天可能下雪、阵雪、雨雪混合、小雨夹雪、大雨夹雪、雨夹雪、可能雨夹雪、阴天可能雨夹雪、霰、冰雪、结冰
        if (condition == 4 || condition == 16 || condition == 17 || condition == 43 || condition == 46 || condition == 48
            || condition == 7 || condition == 18 || condition == 19 || condition == 21 || condition == 44 || condition == 47
            || condition == 50 || condition == 51 || condition == 34) {
            return _weatherSnowBmp;
        }
        // 雷暴：雷暴、分散雷暴、可能有雷暴
        if (condition == 6 || condition == 12 || condition == 28) {
            return _weatherThunderBmp;
        }
        // 阵雨：分散阵雨、未知降水、小阵雨、可能有阵雨、阴天可能下雨
        if (condition == 11 || condition == 13 || condition == 24 || condition == 27 || condition == 45) {
            return _weatherShowersBmp;
        }
        // 雨：雨、小雨、大雨、阵雨、大阵雨、毛毛雨、冻雨
        if (condition == 3 || condition == 14 || condition == 15 || condition == 25 || condition == 26 || condition == 31 || condition == 49) {
            return _weatherRainBmp;
        }
        // 多云：大部多云、阴
        if (condition == 2 || condition == 20) {
            return _weatherCloudyBmp;
        }
        // 晴天：晴、局部晴朗、大部晴朗、晴好
        if (condition == 0 || condition == 22 || condition == 23 || condition == 40) {
            return _weatherClearBmp;
        }
        // 少云：局部多云、薄云、未知
        if (condition == 1 || condition == 52 || condition == 53) {
            return _weatherPartlyCloudyBmp;
        }
        // 少云：未识别类型
        return _weatherPartlyCloudyBmp;
    }

    // -------------------------------------------------------------
    // 长按跳转系统 Widget（Complications.exitTo）
    // -------------------------------------------------------------

    // 由 ChefWatchFaceDelegate.onPress 调用；命中象限则 exitTo 并返回 true。
    function handleMetricLongPress(x as Number, y as Number) as Boolean {
        if (!(Toybox has :Complications)) {
            return false;
        }
        var metricId = hitTestMetricAt(x, y);
        if (metricId == null) {
            return false;
        }
        var compType = getComplicationTypeForMetric(metricId);
        if (compType == null) {
            return false;
        }
        if (!isComplicationAvailable(compType as Complications.Type)) {
            return false;
        }
        try {
            Complications.exitTo(new Complications.Id(compType as Complications.Type));
            return true;
        } catch (ex) {
            return false;
        }
    }

    private function isComplicationAvailable(compType as Complications.Type) as Boolean {
        var comp = Complications.getComplication(new Complications.Id(compType));
        return comp != null;
    }

    private function hitTestMetricAt(x as Number, y as Number) as Number? {
        var rowCenterY = s(SPEC_DIVIDER_EDGE_INSET - SPEC_TOP_METRICS_ABOVE_DIVIDER);
        var bottomDividerSpecY = 960 - SPEC_DIVIDER_EDGE_INSET;
        var bottomCenterY = s(bottomDividerSpecY +
            (SPEC_BOTTOM_ICON_BELOW_DIVIDER + SPEC_BOTTOM_VALUE_BELOW_DIVIDER) / 2);
        var topHalfW = s(SPEC_TOP_HIT_HALF_W);
        var topHalfH = s(SPEC_TOP_HIT_HALF_H);
        var bottomHalfW = s(SPEC_BOTTOM_HIT_HALF_W);
        var bottomHalfH = s(SPEC_BOTTOM_HIT_HALF_H);

        var hasTopLeft = (_topLeftMetric != 0);
        var hasTopRight = (_topRightMetric != 0);
        var topBoth = hasTopLeft && hasTopRight;
        var topLeftX = topBoth ? _cx - s(165) : _cx;
        var topRightX = topBoth ? _cx + s(165) : _cx;

        if (hasTopLeft && isPointInRect(x, y, topLeftX, rowCenterY, topHalfW, topHalfH)) {
            return _topLeftMetric;
        }
        if (hasTopRight && isPointInRect(x, y, topRightX, rowCenterY, topHalfW, topHalfH)) {
            return _topRightMetric;
        }

        var hasBottomLeft = (_bottomLeftMetric != 0);
        var hasBottomRight = (_bottomRightMetric != 0);
        var bottomBoth = hasBottomLeft && hasBottomRight;
        var bottomLeftX = bottomBoth ? _cx - s(150) : _cx;
        var bottomRightX = bottomBoth ? _cx + s(150) : _cx;

        if (hasBottomLeft && isPointInRect(x, y, bottomLeftX, bottomCenterY, bottomHalfW, bottomHalfH)) {
            return _bottomLeftMetric;
        }
        if (hasBottomRight && isPointInRect(x, y, bottomRightX, bottomCenterY, bottomHalfW, bottomHalfH)) {
            return _bottomRightMetric;
        }
        return null;
    }

    private function isPointInRect(x as Number, y as Number,
                                   centerX as Number, centerY as Number,
                                   halfW as Number, halfH as Number) as Boolean {
        return x >= centerX - halfW && x <= centerX + halfW
            && y >= centerY - halfH && y <= centerY + halfH;
    }

    private function getComplicationTypeForMetric(metricId as Number) as Complications.Type? {
        switch (metricId) {
            case 1:
                return Complications.COMPLICATION_TYPE_HEART_RATE;
            case 2:
                return Complications.COMPLICATION_TYPE_BATTERY;
            case 3:
                return Complications.COMPLICATION_TYPE_STEPS;
            case 4:
                return Complications.COMPLICATION_TYPE_ALTITUDE;
            case 5:
                return Complications.COMPLICATION_TYPE_CALORIES;
            case 6:
                return Complications.COMPLICATION_TYPE_PULSE_OX;
            case 7:
                return Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE;
            case 8:
                return Complications.COMPLICATION_TYPE_BODY_BATTERY;
            case 9:
                return Complications.COMPLICATION_TYPE_STRESS;
            case 10:
                return Complications.COMPLICATION_TYPE_SUNRISE;
            case 11:
                return Complications.COMPLICATION_TYPE_SUNSET;
            case 12:
                return Complications.COMPLICATION_TYPE_CURRENT_WEATHER;
            case 13:
                return Complications.COMPLICATION_TYPE_RESPIRATION_RATE;
            case 15:
            case 16:
                // 系统无月跑量 Complication；跑步类指标统一跳转周跑量关联的 Glance
                return Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE;
            case 17:
                return Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT;
            case 18:
                return Complications.COMPLICATION_TYPE_RECOVERY_TIME;
            case 14:
                return isBetweenSunriseAndSunset()
                    ? Complications.COMPLICATION_TYPE_SUNSET
                    : Complications.COMPLICATION_TYPE_SUNRISE;
            default:
                return null;
        }
    }
}
