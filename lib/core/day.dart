// 日期工具：全局只用「本地日期字符串」yyyy-MM-dd 作为分组键。
//
// 为什么不用时间戳存日期：跨时区/夏令时换算会导致「同一天被拆成两段」，
// 而工人只关心"哪一天干了多少活"。用字符串既直观，也能直接 SQL 做前缀匹配。

String two(int n) => n.toString().padLeft(2, '0');

/// 2026-10-18
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 2026-10
String ym(DateTime d) => '${d.year}-${two(d.month)}';

/// 10月18日
String cnDay(DateTime d) => '${d.month}月${d.day}日';

/// 2026年10月
String cnMonth(DateTime d) => '${d.year}年${d.month}月';

/// 周三 / 周日
String weekdayCn(DateTime d) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[d.weekday - 1];
}

/// 把 yyyy-MM-dd 解析回 DateTime（只取年月日）
DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// 本月第一天（用于月份切换的基准）
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// 月份加减，自动处理跨年
DateTime addMonths(DateTime firstDay, int delta) =>
    DateTime(firstDay.year, firstDay.month + delta, 1);

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
