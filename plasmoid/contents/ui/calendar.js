.pragma library

var FA_MONTHS = [
    "", "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
    "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"
];

var EN_MONTHS = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
];

var FA_WEEKDAYS = ["ش", "ی", "د", "س", "چ", "پ", "ج"];
var EN_WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

function gregorianToJalali(gy, gm, gd) {
    var g_days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var j_days_in_month = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];

    var gy_ = gy - 1600;
    var gm_ = gm - 1;
    var gd_ = gd - 1;

    var g_day_no = 365 * gy_ + Math.floor((gy_ + 3) / 4) - Math.floor((gy_ + 99) / 100) + Math.floor((gy_ + 399) / 400);
    for (var i = 0; i < gm_; ++i) {
        g_day_no += g_days_in_month[i];
    }
    if (gm_ > 1 && ((gy % 4 === 0 && gy % 100 !== 0) || (gy % 400 === 0))) {
        g_day_no += 1;
    }
    g_day_no += gd_;

    var j_day_no = g_day_no - 79;
    var j_np = Math.floor(j_day_no / 12053);
    j_day_no %= 12053;

    var jy = 979 + 33 * j_np + 4 * Math.floor(j_day_no / 1461);
    j_day_no %= 1461;

    if (j_day_no >= 366) {
        jy += Math.floor((j_day_no - 1) / 365);
        j_day_no = (j_day_no - 1) % 365;
    }

    for (var j = 0; j < 11; ++j) {
        if (j_day_no < j_days_in_month[j]) {
            return { jy: jy, jm: j + 1, jd: j_day_no + 1 };
        }
        j_day_no -= j_days_in_month[j];
    }
    return { jy: jy, jm: 12, jd: j_day_no + 1 };
}

function jalaliToGregorian(jy, jm, jd) {
    var g_days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var j_days_in_month = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];

    var jy_ = jy - 979;
    var jm_ = jm - 1;
    var jd_ = jd - 1;

    var j_day_no = 365 * jy_ + Math.floor(jy_ / 33) * 8 + Math.floor(((jy_ % 33) + 3) / 4);
    for (var i = 0; i < jm_; ++i) {
        j_day_no += j_days_in_month[i];
    }
    j_day_no += jd_;

    var g_day_no = j_day_no + 79;

    var gy = 1600 + 400 * Math.floor(g_day_no / 146097);
    g_day_no %= 146097;

    var leap = true;
    if (g_day_no >= 36525) {
        g_day_no -= 1;
        gy += 100 * Math.floor(g_day_no / 36524);
        g_day_no %= 36524;
        if (g_day_no >= 365) {
            g_day_no += 1;
        } else {
            leap = false;
        }
    }

    gy += 4 * Math.floor(g_day_no / 1461);
    g_day_no %= 1461;

    if (g_day_no >= 366) {
        leap = false;
        g_day_no -= 1;
        gy += Math.floor(g_day_no / 365);
        g_day_no %= 365;
    }

    for (var k = 0; k < 12; ++k) {
        var dim = g_days_in_month[k] + (k === 1 && leap ? 1 : 0);
        if (g_day_no < dim) {
            return { gy: gy, gm: k + 1, gd: g_day_no + 1 };
        }
        g_day_no -= dim;
    }
    return { gy: gy, gm: 12, gd: 31 };
}

function isJalaliLeap(jy) {
    var j_day_no = 365 * (jy - 979) + Math.floor((jy - 979) / 33) * 8 + Math.floor((((jy - 979) % 33) + 3) / 4);
    var next_no = 365 * (jy + 1 - 979) + Math.floor((jy + 1 - 979) / 33) * 8 + Math.floor((((jy + 1 - 979) % 33) + 3) / 4);
    return (next_no - j_day_no) === 366;
}

function getJalaliMonthDays(jy, jm) {
    if (jm <= 6) return 31;
    if (jm <= 11) return 30;
    return isJalaliLeap(jy) ? 30 : 29;
}

function getGregorianMonthDays(gy, gm) {
    return new Date(gy, gm, 0).getDate();
}

function padZero(n) {
    return n < 10 ? "0" + n : "" + n;
}

function formatIsoToJalaliLabel(iso) {
    if (!iso || iso.length < 10) return "";
    var parts = iso.split("-");
    if (parts.length !== 3) return iso;
    var gy = parseInt(parts[0], 10);
    var gm = parseInt(parts[1], 10);
    var gd = parseInt(parts[2], 10);
    var j = gregorianToJalali(gy, gm, gd);
    return j.jd + " " + FA_MONTHS[j.jm] + " " + j.jy;
}

// Generate grid cells for the selected month.
// Note: empty leading cells remain present in the GridLayout (opacity 0, not visible=false)
// so that weekday column alignment is preserved.
function generateMonthGrid(year, month, isJalali, taskDatesMeta) {
    var cells = [];
    var today = new Date();
    var todayG = { gy: today.getFullYear(), gm: today.getMonth() + 1, gd: today.getDate() };
    var todayJ = gregorianToJalali(todayG.gy, todayG.gm, todayG.gd);

    if (isJalali) {
        var totalDays = getJalaliMonthDays(year, month);
        var gFirst = jalaliToGregorian(year, month, 1);
        var firstDate = new Date(gFirst.gy, gFirst.gm - 1, gFirst.gd);
        // Saturday = 0 .. Friday = 6
        var jsDay = firstDate.getDay();
        var startOffset = (jsDay + 1) % 7;

        for (var empty = 0; empty < startOffset; ++empty) {
            cells.push({
                dayNumber: "",
                subDayNumber: "",
                isoDate: "",
                jalaliDate: "",
                isCurrentMonth: false,
                isToday: false,
                taskCount: 0,
                topPriority: 4
            });
        }

        for (var d = 1; d <= totalDays; ++d) {
            var gConv = jalaliToGregorian(year, month, d);
            var iso = gConv.gy + "-" + padZero(gConv.gm) + "-" + padZero(gConv.gd);
            var isTod = (year === todayJ.jy && month === todayJ.jm && d === todayJ.jd);
            var meta = taskDatesMeta && taskDatesMeta[iso] ? taskDatesMeta[iso] : null;

            cells.push({
                dayNumber: "" + d,
                subDayNumber: "" + gConv.gd,
                isoDate: iso,
                jalaliDate: year + "/" + padZero(month) + "/" + padZero(d),
                isCurrentMonth: true,
                isToday: isTod,
                taskCount: meta ? meta.count : 0,
                topPriority: meta ? meta.topPriority : 4
            });
        }
    } else {
        var totalDaysG = getGregorianMonthDays(year, month);
        var firstDateG = new Date(year, month - 1, 1);
        // Monday = 0 .. Sunday = 6
        var startOffsetG = (firstDateG.getDay() + 6) % 7;

        for (var emptyG = 0; emptyG < startOffsetG; ++emptyG) {
            cells.push({
                dayNumber: "",
                subDayNumber: "",
                isoDate: "",
                jalaliDate: "",
                isCurrentMonth: false,
                isToday: false,
                taskCount: 0,
                topPriority: 4
            });
        }

        for (var dg = 1; dg <= totalDaysG; ++dg) {
            var jConv = gregorianToJalali(year, month, dg);
            var isoG = year + "-" + padZero(month) + "-" + padZero(dg);
            var isTodG = (year === todayG.gy && month === todayG.gm && dg === todayG.gd);
            var metaG = taskDatesMeta && taskDatesMeta[isoG] ? taskDatesMeta[isoG] : null;

            cells.push({
                dayNumber: "" + dg,
                subDayNumber: "" + jConv.jd,
                isoDate: isoG,
                jalaliDate: jConv.jy + "/" + padZero(jConv.jm) + "/" + padZero(jConv.jd),
                isCurrentMonth: true,
                isToday: isTodG,
                taskCount: metaG ? metaG.count : 0,
                topPriority: metaG ? metaG.topPriority : 4
            });
        }
    }

    return cells;
}
