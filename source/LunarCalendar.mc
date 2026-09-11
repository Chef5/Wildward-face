import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// 公历 → 农历（中文）日期换算，可选节日 / 24 节气名称覆盖。
//
// 每年编码（20 位）：
//   位 0..3   闰月序号（0 表示无闰月）
//   位 4..15  第 1..12 月的天数标志（位 15 对应正月），1 = 30 天，0 = 29 天
//   位 16     闰月天数标志（1 = 30 天，0 = 29 天），仅在有闰月时有效
//
// 基准锚点：农历 2010-01-01 == 公历 2010-02-14。
// 节日 / 节气优先：节日 > 节气 > 农历月日。闰月不当传统节日。
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

    // 农历节日：键 = 月*100+日。闰月不匹配。除夕 / 寒食另算。
    const FESTIVAL_KEYS = [
        101, 107, 115, 202, 303, 408, 505, 606,
        707, 715, 730, 815, 909, 1001, 1015, 1208, 1223, 1224
    ];
    const FESTIVAL_ZHS = [
        "春节", "人日", "元宵", "龙抬头", "上巳", "浴佛", "端午", "天贶",
        "七夕", "中元", "地藏", "中秋", "重阳", "寒衣", "下元", "腊八", "小年", "小年"
    ];
    const FESTIVAL_ZHT = [
        "春節", "人日", "元宵", "龍抬頭", "上巳", "浴佛", "端午", "天貺",
        "七夕", "中元", "地藏", "中秋", "重陽", "寒衣", "下元", "臘八", "小年", "小年"
    ];

    // 24 节气：小寒..冬至。C 值为寿星公式常数 ×10000，全程整数运算。
    const TERM_C = [
        54055, 201200, 38700, 187300, 56300, 206460, 48100, 201000,
        55200, 210400, 56780, 213700, 71080, 228300, 75000, 231300,
        76460, 230420, 83180, 234380, 74380, 223600, 71800, 219400
    ];
    const TERM_ZHS = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
        "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑",
        "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ];
    const TERM_ZHT = [
        "小寒", "大寒", "立春", "雨水", "驚蟄", "春分", "清明", "穀雨",
        "立夏", "小滿", "芒種", "夏至", "小暑", "大暑", "立秋", "處暑",
        "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ];
    // 寿星公式在 2010–2050 相对北京日期需 -1 的节气：year*100+index
    const TERM_MINUS1 = [201404, 201900, 202123, 202603, 204512, 204704];

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
        var leapHandled = false;
        var lunarMonth = 1;
        var md;

        while (lunarMonth <= 13) {
            // leapHandled 防止闰月结束后 lunarMonth 回到 leap+1 再次插入闰月。
            if (leap > 0 && lunarMonth == (leap + 1) && !leapHandled) {
                lunarMonth -= 1;
                isLeap = true;
                leapHandled = true;
                md = leapMonthDays(lunarYear);
            } else {
                md = monthDays(lunarYear, lunarMonth);
            }
            if (offset < md) {
                break;
            }
            offset -= md;
            if (isLeap) {
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

    function formatChineseFromLunar(lunar as Dictionary, traditional as Boolean) as String {
        var m = lunar[:month] as Number;
        var d = lunar[:day] as Number;
        var isLeap = lunar[:isLeap] as Boolean;
        var prefix = "";
        if (isLeap) {
            prefix = traditional ? "閏" : "闰";
        }
        var monthName = "";
        if (m >= 1 && m <= 12) {
            if (traditional && m == 12) {
                monthName = "臘月";
            } else {
                monthName = MONTH_NAMES[m - 1];
            }
        }
        var dayName = (d >= 1 && d <= 30) ? DAY_NAMES[d - 1] : "";
        return prefix + monthName + dayName;
    }

    // 中文标签，例如「三月初二」「闰六月廿一」。
    // 调用处需提供 CJK BMP 字体资源才能正确显示。
    function formatChinese(year as Number, month as Number, day as Number) as String {
        var lunar = solarToLunar(year, month, day);
        if (lunar == null) { return ""; }
        return formatChineseFromLunar(lunar as Dictionary, false);
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

    // 寿星公式：[Y*0.2422+C]-[Y/4]，C 预乘 10000。
    // 闰年 2 月 29 日尚未发生时，公式多减了 1 天：小寒..雨水（index 0..3）补 +1。
    function solarTermDay(year as Number, n as Number) as Number {
        var y = year % 100;
        var day = (y * 2422 + TERM_C[n]) / 10000 - y / 4;
        if ((year % 4) == 0 && n <= 3) {
            day += 1;
        }
        var key = year * 100 + n;
        for (var i = 0; i < TERM_MINUS1.size(); i++) {
            if (TERM_MINUS1[i] == key) {
                return day - 1;
            }
        }
        return day;
    }

    function lookupLunarFestival(lunar as Dictionary, traditional as Boolean) as String {
        if (lunar[:isLeap] as Boolean) { return ""; }
        var m = lunar[:month] as Number;
        var d = lunar[:day] as Number;
        var y = lunar[:year] as Number;
        if (m == 12 && d == monthDays(y, 12)) {
            return "除夕";
        }
        var key = m * 100 + d;
        for (var i = 0; i < FESTIVAL_KEYS.size(); i++) {
            if (FESTIVAL_KEYS[i] == key) {
                return traditional ? FESTIVAL_ZHT[i] : FESTIVAL_ZHS[i];
            }
        }
        return "";
    }

    function lookupHanshi(year as Number, month as Number, day as Number) as String {
        // 寒食 = 清明前一天；清明固定在 4 月（节气 index 6）。
        if (month != 4) { return ""; }
        if (day == (solarTermDay(year, 6) - 1)) {
            return "寒食";
        }
        return "";
    }

    function lookupSolarTerm(year as Number, month as Number, day as Number, traditional as Boolean) as String {
        if (month < 1 || month > 12) { return ""; }
        var n0 = (month - 1) * 2;
        if (solarTermDay(year, n0) == day) {
            return traditional ? TERM_ZHT[n0] : TERM_ZHS[n0];
        }
        var n1 = n0 + 1;
        if (solarTermDay(year, n1) == day) {
            return traditional ? TERM_ZHT[n1] : TERM_ZHS[n1];
        }
        return "";
    }

    // 默认：中文月日标签；showFestivals 时节日 > 节气 > 农历月日。
    function format(year as Number, month as Number, day as Number, showFestivals as Boolean, traditional as Boolean) as String {
        var lunar = solarToLunar(year, month, day);
        if (showFestivals) {
            if (lunar != null) {
                var fest = lookupLunarFestival(lunar as Dictionary, traditional);
                if (!fest.equals("")) { return fest; }
            }
            var hanshi = lookupHanshi(year, month, day);
            if (!hanshi.equals("")) { return hanshi; }
            var term = lookupSolarTerm(year, month, day, traditional);
            if (!term.equals("")) { return term; }
        }
        if (lunar == null) { return ""; }
        return formatChineseFromLunar(lunar as Dictionary, traditional);
    }
}
