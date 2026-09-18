import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// 表上设置（Customize → Wildward Settings）：仅 list / boolean。
// 自由文本项（自定义色 hex、时分分隔符）仍仅在手机 Mobile Settings 中提供。

function notifyOnDeviceSettingsChanged() as Void {
    var app = Application.getApp() as ChefWatchFaceApp;
    app.onSettingsChanged();
}

function settingsStr(id as ResourceId) as String {
    return WatchUi.loadResource(id) as String;
}

function settingsPropNumber(key as String, defaultValue as Number) as Number {
    var v = Application.Properties.getValue(key);
    return v != null ? v as Number : defaultValue;
}

function settingsPropBool(key as String, defaultValue as Boolean) as Boolean {
    var v = Application.Properties.getValue(key);
    return v != null ? v as Boolean : defaultValue;
}

function settingsIsChineseLocale() as Boolean {
    var lang = System.getDeviceSettings().systemLanguage;
    return lang == System.LANGUAGE_CHS || lang == System.LANGUAGE_CHT;
}

function settingsLabelForValue(values as Array<Number>, labels as Array<ResourceId>, value as Number) as String {
    for (var i = 0; i < values.size(); i++) {
        if ((values[i] as Number) == value) {
            return settingsStr(labels[i] as ResourceId);
        }
    }
    return "";
}

function settingsAccentValues() as Array<Number> {
    return [
        0xB77CFF, 0x55AAFF, 0x00DDCC, 0x55FF99, 0x3DA855,
        0xFFEE44, 0xFFCC33, 0xFFAA55, 0xFF5566, 0xFF77BB, 0xFFFFFF
    ] as Array<Number>;
}

function settingsAccentLabels() as Array<ResourceId> {
    return [
        Rez.Strings.ColorPurple, Rez.Strings.ColorBlue, Rez.Strings.ColorCyan,
        Rez.Strings.ColorGreen, Rez.Strings.ColorFieldGreen, Rez.Strings.ColorYellow,
        Rez.Strings.ColorGold, Rez.Strings.ColorOrange, Rez.Strings.ColorRed,
        Rez.Strings.ColorPink, Rez.Strings.ColorWhite
    ] as Array<ResourceId>;
}

function settingsBackgroundValues() as Array<Number> {
    return [0x000000, 0x555555, 0xAAAAAA, 0xFFFFFF, 0x0A1628] as Array<Number>;
}

function settingsBackgroundLabels() as Array<ResourceId> {
    return [
        Rez.Strings.ColorBlack, Rez.Strings.ColorDarkGray, Rez.Strings.ColorLightGray,
        Rez.Strings.ColorWhite, Rez.Strings.ColorNavy
    ] as Array<ResourceId>;
}

function settingsMetricValues() as Array<Number> {
    return [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22
    ] as Array<Number>;
}

function settingsMetricLabels() as Array<ResourceId> {
    return [
        Rez.Strings.MetricNone, Rez.Strings.MetricHeartRate, Rez.Strings.MetricBattery,
        Rez.Strings.MetricSteps, Rez.Strings.MetricAltitude, Rez.Strings.MetricCalories,
        Rez.Strings.MetricSpO2, Rez.Strings.MetricPressure, Rez.Strings.MetricBodyBattery,
        Rez.Strings.MetricStress, Rez.Strings.MetricSunrise, Rez.Strings.MetricSunset,
        Rez.Strings.MetricWeather, Rez.Strings.MetricRespiration, Rez.Strings.MetricSunriseSunset,
        Rez.Strings.MetricWeeklyRun, Rez.Strings.MetricMonthlyRun, Rez.Strings.MetricNotifications,
        Rez.Strings.MetricRecoveryTime, Rez.Strings.MetricWeeklyIntensity,
        Rez.Strings.MetricMonthlyIntensity, Rez.Strings.MetricWeeklyVigorous,
        Rez.Strings.MetricMonthlyVigorous
    ] as Array<ResourceId>;
}

function settingsTimeFormatValues() as Array<Number> {
    return [0, 1, 2] as Array<Number>;
}

function settingsTimeFormatLabels() as Array<ResourceId> {
    return [
        Rez.Strings.TimeFormatSystem, Rez.Strings.TimeFormat12Hour, Rez.Strings.TimeFormat24Hour
    ] as Array<ResourceId>;
}

function settingsTimeFontStyleValues() as Array<Number> {
    return [0, 1, 2, 3, 4] as Array<Number>;
}

function settingsTimeFontStyleLabels() as Array<ResourceId> {
    return [
        Rez.Strings.TimeFontSystem, Rez.Strings.TimeFontCondensedBold, Rez.Strings.TimeFontCondensed,
        Rez.Strings.TimeFontBionic, Rez.Strings.TimeFontRoboto
    ] as Array<ResourceId>;
}

function settingsDateFontSizeValues() as Array<Number> {
    return [0, 1, 2, 3, 4, 5] as Array<Number>;
}

function settingsDateFontSizeLabels() as Array<ResourceId> {
    return [
        Rez.Strings.TimeFontSizeExtraSmall, Rez.Strings.TimeFontSizeSmall,
        Rez.Strings.TimeFontSizeMedium, Rez.Strings.TimeFontSizeLarge,
        Rez.Strings.TimeFontSizeExtraLarge, Rez.Strings.TimeFontSizeHuge
    ] as Array<ResourceId>;
}

function settingsTimeFontSizeValues() as Array<Number> {
    return [0, 1, 2, 3, 4, 5, 6, 7, 8] as Array<Number>;
}

function settingsTimeFontSizeLabels() as Array<ResourceId> {
    return [
        Rez.Strings.TimeFontSizeExtraSmall, Rez.Strings.TimeFontSizeSmall,
        Rez.Strings.TimeFontSizeMedium, Rez.Strings.TimeFontSizeLarge,
        Rez.Strings.TimeFontSizeExtraLarge, Rez.Strings.TimeFontSizeHuge,
        Rez.Strings.TimeFontSizeGiant, Rez.Strings.TimeFontSizeMassive,
        Rez.Strings.TimeFontSizeMax
    ] as Array<ResourceId>;
}

function settingsBatteryDisplayValues() as Array<Number> {
    return [0, 1] as Array<Number>;
}

function settingsBatteryDisplayLabels() as Array<ResourceId> {
    return [
        Rez.Strings.BatteryDisplayPercent, Rez.Strings.BatteryDisplayEndurance
    ] as Array<ResourceId>;
}

function settingsUpdateListSubLabel(menu as WatchUi.Menu2, key as String, values as Array<Number>, labels as Array<ResourceId>) as Void {
    var idx = menu.findItemById(key);
    var item = menu.getItem(idx);
    item.setSubLabel(settingsLabelForValue(values, labels, settingsPropNumber(key, values[0] as Number)));
    menu.updateItem(item, idx);
}

function settingsAddListItem(menu as WatchUi.Menu2, key as String, titleId as ResourceId, values as Array<Number>, labels as Array<ResourceId>) as Void {
    menu.addItem(new WatchUi.MenuItem(
        titleId,
        settingsLabelForValue(values, labels, settingsPropNumber(key, values[0] as Number)),
        key,
        null
    ));
}

function settingsAddToggleItem(menu as WatchUi.Menu2, key as String, titleId as ResourceId, defaultValue as Boolean) as Void {
    menu.addItem(new WatchUi.ToggleMenuItem(
        titleId,
        null,
        key,
        settingsPropBool(key, defaultValue),
        null
    ));
}

function settingsListTitleIdForKey(key as String) as ResourceId? {
    if (key.equals("AccentColor")) { return Rez.Strings.AccentColorTitle; }
    if (key.equals("SecondaryColor")) { return Rez.Strings.SecondaryColorTitle; }
    if (key.equals("BackgroundColor")) { return Rez.Strings.BackgroundColorTitle; }
    if (key.equals("TopLeftMetric")) { return Rez.Strings.TopLeftMetricTitle; }
    if (key.equals("TopRightMetric")) { return Rez.Strings.TopRightMetricTitle; }
    if (key.equals("BottomLeftMetric")) { return Rez.Strings.BottomLeftMetricTitle; }
    if (key.equals("BottomRightMetric")) { return Rez.Strings.BottomRightMetricTitle; }
    if (key.equals("TimeFormat")) { return Rez.Strings.TimeFormatTitle; }
    if (key.equals("TimeFontStyle")) { return Rez.Strings.TimeFontStyleTitle; }
    if (key.equals("TimeFontSize")) { return Rez.Strings.TimeFontSizeTitle; }
    if (key.equals("DateFontSize")) { return Rez.Strings.DateFontSizeTitle; }
    if (key.equals("BatteryDisplay")) { return Rez.Strings.BatteryDisplayTitle; }
    return null;
}

function settingsListValuesForKey(key as String) as Array<Number>? {
    if (key.equals("AccentColor") || key.equals("SecondaryColor")) {
        return settingsAccentValues();
    }
    if (key.equals("BackgroundColor")) {
        return settingsBackgroundValues();
    }
    if (key.equals("TopLeftMetric") || key.equals("TopRightMetric")
        || key.equals("BottomLeftMetric") || key.equals("BottomRightMetric")) {
        return settingsMetricValues();
    }
    if (key.equals("TimeFormat")) {
        return settingsTimeFormatValues();
    }
    if (key.equals("TimeFontStyle")) {
        return settingsTimeFontStyleValues();
    }
    if (key.equals("TimeFontSize")) {
        return settingsTimeFontSizeValues();
    }
    if (key.equals("DateFontSize")) {
        return settingsDateFontSizeValues();
    }
    if (key.equals("BatteryDisplay")) {
        return settingsBatteryDisplayValues();
    }
    return null;
}

function settingsListLabelsForKey(key as String) as Array<ResourceId>? {
    if (key.equals("AccentColor") || key.equals("SecondaryColor")) {
        return settingsAccentLabels();
    }
    if (key.equals("BackgroundColor")) {
        return settingsBackgroundLabels();
    }
    if (key.equals("TopLeftMetric") || key.equals("TopRightMetric")
        || key.equals("BottomLeftMetric") || key.equals("BottomRightMetric")) {
        return settingsMetricLabels();
    }
    if (key.equals("TimeFormat")) {
        return settingsTimeFormatLabels();
    }
    if (key.equals("TimeFontStyle")) {
        return settingsTimeFontStyleLabels();
    }
    if (key.equals("TimeFontSize")) {
        return settingsTimeFontSizeLabels();
    }
    if (key.equals("DateFontSize")) {
        return settingsDateFontSizeLabels();
    }
    if (key.equals("BatteryDisplay")) {
        return settingsBatteryDisplayLabels();
    }
    return null;
}

class SettingsRootMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.AppName});
        addItem(new WatchUi.MenuItem(Rez.Strings.SettingsColorsTitle, null, "cat_colors", null));
        addItem(new WatchUi.MenuItem(Rez.Strings.SettingsMetricsTitle, null, "cat_metrics", null));
        addItem(new WatchUi.MenuItem(Rez.Strings.SettingsTimeTitle, null, "cat_time", null));
        addItem(new WatchUi.MenuItem(Rez.Strings.SettingsDisplayTitle, null, "cat_display", null));
    }

}

class SettingsRootDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("cat_colors")) {
            var colorsMenu = new SettingsColorsMenu();
            WatchUi.pushView(colorsMenu, new SettingsCategoryDelegate(colorsMenu), WatchUi.SLIDE_LEFT);
        } else if (id.equals("cat_metrics")) {
            var metricsMenu = new SettingsMetricsMenu();
            WatchUi.pushView(metricsMenu, new SettingsCategoryDelegate(metricsMenu), WatchUi.SLIDE_LEFT);
        } else if (id.equals("cat_time")) {
            var timeMenu = new SettingsTimeMenu();
            WatchUi.pushView(timeMenu, new SettingsCategoryDelegate(timeMenu), WatchUi.SLIDE_LEFT);
        } else if (id.equals("cat_display")) {
            var displayMenu = new SettingsDisplayMenu();
            WatchUi.pushView(displayMenu, new SettingsCategoryDelegate(displayMenu), WatchUi.SLIDE_LEFT);
        }
    }

}

class SettingsColorsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsColorsTitle});
        settingsAddListItem(self, "AccentColor", Rez.Strings.AccentColorTitle, settingsAccentValues(), settingsAccentLabels());
        settingsAddListItem(self, "SecondaryColor", Rez.Strings.SecondaryColorTitle, settingsAccentValues(), settingsAccentLabels());
        settingsAddListItem(self, "BackgroundColor", Rez.Strings.BackgroundColorTitle, settingsBackgroundValues(), settingsBackgroundLabels());
    }

}

class SettingsMetricsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsMetricsTitle});
        var values = settingsMetricValues();
        var labels = settingsMetricLabels();
        settingsAddListItem(self, "TopLeftMetric", Rez.Strings.TopLeftMetricTitle, values, labels);
        settingsAddListItem(self, "TopRightMetric", Rez.Strings.TopRightMetricTitle, values, labels);
        settingsAddListItem(self, "BottomLeftMetric", Rez.Strings.BottomLeftMetricTitle, values, labels);
        settingsAddListItem(self, "BottomRightMetric", Rez.Strings.BottomRightMetricTitle, values, labels);
    }

}

class SettingsTimeMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTimeTitle});
        settingsAddListItem(self, "TimeFormat", Rez.Strings.TimeFormatTitle, settingsTimeFormatValues(), settingsTimeFormatLabels());
        settingsAddListItem(self, "TimeFontStyle", Rez.Strings.TimeFontStyleTitle, settingsTimeFontStyleValues(), settingsTimeFontStyleLabels());
        settingsAddListItem(self, "TimeFontSize", Rez.Strings.TimeFontSizeTitle, settingsTimeFontSizeValues(), settingsTimeFontSizeLabels());
        settingsAddListItem(self, "DateFontSize", Rez.Strings.DateFontSizeTitle, settingsDateFontSizeValues(), settingsDateFontSizeLabels());
    }

}

class SettingsDisplayMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsDisplayTitle});
        settingsAddToggleItem(self, "ShowSeconds", Rez.Strings.ShowSecondsTitle, true);
        settingsAddToggleItem(self, "ShowDate", Rez.Strings.ShowDateTitle, true);
        if (settingsIsChineseLocale()) {
            settingsAddToggleItem(self, "ShowLunar", Rez.Strings.ShowLunarTitle, true);
            settingsAddToggleItem(self, "ShowLunarFestivals", Rez.Strings.ShowLunarFestivalsTitle, true);
        }
        settingsAddToggleItem(self, "ShowDividers", Rez.Strings.ShowDividersTitle, true);
        settingsAddToggleItem(self, "ShowRingTicks", Rez.Strings.ShowRingTicksTitle, true);
        settingsAddToggleItem(self, "ShowSecondHand", Rez.Strings.ShowSecondHandTitle, true);
        settingsAddListItem(self, "BatteryDisplay", Rez.Strings.BatteryDisplayTitle, settingsBatteryDisplayValues(), settingsBatteryDisplayLabels());
    }

}

class SettingsCategoryDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;

    function initialize(menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item instanceof WatchUi.ToggleMenuItem) {
            var toggle = item as WatchUi.ToggleMenuItem;
            Application.Properties.setValue(toggle.getId() as String, toggle.isEnabled());
            notifyOnDeviceSettingsChanged();
            return;
        }

        var key = item.getId() as String;
        var titleId = settingsListTitleIdForKey(key);
        var values = settingsListValuesForKey(key);
        var labels = settingsListLabelsForKey(key);
        if (titleId == null || values == null || labels == null) {
            return;
        }

        WatchUi.pushView(
            new SettingsListPickerMenu(titleId as ResourceId, key, values as Array<Number>, labels as Array<ResourceId>),
            new SettingsListPickerDelegate(key, values as Array<Number>, labels as Array<ResourceId>, _menu),
            WatchUi.SLIDE_LEFT
        );
    }

}

class SettingsListPickerMenu extends WatchUi.Menu2 {

    function initialize(titleId as ResourceId, key as String, values as Array<Number>, labels as Array<ResourceId>) {
        Menu2.initialize({:title => titleId});
        var current = settingsPropNumber(key, values[0] as Number);
        for (var i = 0; i < values.size(); i++) {
            var value = values[i] as Number;
            var sub = (value == current) ? settingsStr(Rez.Strings.SettingsSelected) : null;
            addItem(new WatchUi.MenuItem(labels[i] as ResourceId, sub, value, null));
        }
    }

}

class SettingsListPickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;
    private var _values as Array<Number>;
    private var _labels as Array<ResourceId>;
    private var _parentMenu as WatchUi.Menu2;

    function initialize(key as String, values as Array<Number>, labels as Array<ResourceId>, parentMenu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _key = key;
        _values = values;
        _labels = labels;
        _parentMenu = parentMenu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        Application.Properties.setValue(_key, value);
        notifyOnDeviceSettingsChanged();
        settingsUpdateListSubLabel(_parentMenu, _key, _values, _labels);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

}
