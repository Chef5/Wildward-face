import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// 公历 → 农历（中文）日期换算。
//
// 每年编码（20 位）：
//   位 0..3   闰月序号（0 表示无闰月）
//   位 4..15  第 1..12 月的天数标志（位 15 对应正月），1 = 30 天，0 = 29 天
//   位 16     闰月天数标志（1 = 30 天，0 = 29 天），仅在有闰月时有效
//
// 基准锚点：农历 2010-01-01 == 公历 2010-02-14。
module LunarCalendar {

    const BASE_YEAR = 2010;
    const BASE_SOLAR_Y = 2010;
    const BASE_SOLAR_M = 2;
    const BASE_SOLAR_D = 14;

    // 2010..2050（共 41 条）
    const YEAR_INFO = [
        0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930, // 2010-2019
        0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, // 2020-2029
        0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, // 2030-2039
        0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, // 2040-2049
        0x14b63                                                                                    // 2050
    ];

    const MONTH_NAMES = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ];

    // 1..30 → 中文日名（初一..三十）
    const DAY_NAMES = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ];

    function leapMonth(year as Number) as Number {
        var idx = year - BASE_YEAR;
        if (idx < 0 || idx >= YEAR_INFO.size()) { return 0; }
        return YEAR_INFO[idx] & 0xf;
    }

    function leapMonthDays(year as Number) as Number {
        if (leapMonth(year) == 0) { return 0; }
        var idx = year - BASE_YEAR;
        return ((YEAR_INFO[idx] & 0x10000) != 0) ? 30 : 29;
    }

    // m：1..12
    function monthDays(year as Number, m as Number) as Number {
        var idx = year - BASE_YEAR;
        if (idx < 0 || idx >= YEAR_INFO.size()) { return 30; }
        var mask = 0x10000 >> m; // 正月 -> 0x8000，…，腊月 -> 0x0010
        return ((YEAR_INFO[idx] & mask) != 0) ? 30 : 29;
    }

    function yearDays(year as Number) as Number {
        var sum = 348; // 12×29（按每月 29 天累加前的基数）
        for (var i = 1; i <= 12; i++) {
            if (monthDays(year, i) == 30) { sum += 1; }
        }
        return sum + leapMonthDays(year);
    }

    function daysBetween(y1 as Number, m1 as Number, d1 as Number,
                         y2 as Number, m2 as Number, d2 as Number) as Number {
        var t1 = Gregorian.moment({ :year => y1, :month => m1, :day => d1,
                                     :hour => 12, :min => 0, :sec => 0 }).value();
        var t2 = Gregorian.moment({ :year => y2, :month => m2, :day => d2,
                                     :hour => 12, :min => 0, :sec => 0 }).value();
        return ((t2 - t1) / 86400).toNumber();
    }

    // 返回 { :year, :month, :day, :isLeap }；年份超出支持范围则返回 null。
    function solarToLunar(year as Number, month as Number, day as Number) as Dictionary? {
        var offset = daysBetween(BASE_SOLAR_Y, BASE_SOLAR_M, BASE_SOLAR_D, year, month, day);
        if (offset < 0) { return null; }

        var lunarYear = BASE_YEAR;
        var yd = yearDays(lunarYear);
        while (offset >= yd && (lunarYear - BASE_YEAR + 1) < YEAR_INFO.size()) {
            offset -= yd;
            lunarYear += 1;
            yd = yearDays(lunarYear);
        }
        if (offset >= yd) { return null; } // 超出支持范围

        var leap = leapMonth(lunarYear);
        var isLeap = false;
        var lunarMonth = 1;
        var md;

        while (lunarMonth <= 13) {
            if (leap > 0 && lunarMonth == (leap + 1) && !isLeap) {
                lunarMonth -= 1;
                isLeap = true;
                md = leapMonthDays(lunarYear);
            } else {
                md = monthDays(lunarYear, lunarMonth);
            }
            if (offset < md) {
                break;
            }
            offset -= md;
            if (isLeap && lunarMonth == leap) {
                isLeap = false;
            }
            lunarMonth += 1;
        }

        return {
            :year => lunarYear,
            :month => lunarMonth,
            :day => offset + 1,
            :isLeap => isLeap
        };
    }

    // 中文标签，例如「三月初二」「闰六月廿一」。
    // 调用处需提供 CJK BMP 字体资源才能正确显示。
    function formatChinese(year as Number, month as Number, day as Number) as String {
        var lunar = solarToLunar(year, month, day);
        if (lunar == null) { return ""; }
        var m = lunar[:month] as Number;
        var d = lunar[:day] as Number;
        var isLeap = lunar[:isLeap] as Boolean;
        var prefix = isLeap ? "闰" : "";
        var monthName = (m >= 1 && m <= 12) ? MONTH_NAMES[m - 1] : "";
        var dayName = (d >= 1 && d <= 30) ? DAY_NAMES[d - 1] : "";
        return prefix + monthName + dayName;
    }

    // 纯 ASCII 标签，例如 "Lunar 3.2" / "Leap 6.21"，任意固件均可显示。
    function formatAscii(year as Number, month as Number, day as Number) as String {
        var lunar = solarToLunar(year, month, day);
        if (lunar == null) { return ""; }
        var m = lunar[:month] as Number;
        var d = lunar[:day] as Number;
        var isLeap = lunar[:isLeap] as Boolean;
        var prefix = isLeap ? "Leap " : "Lunar ";
        return prefix + m.format("%d") + "." + d.format("%d");
    }

    // 默认：中文月日标签（调用方需使用含这些字形的字体，如设备内置 Noto Sans SC）。
    function format(year as Number, month as Number, day as Number) as String {
        return formatChinese(year, month, day);
    }
}
