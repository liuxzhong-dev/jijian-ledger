// 金额工具：全项目金额一律以「分」为单位的 int 存储与运算，绝不使用 double。
//
// 为什么：0.1 + 0.2 != 0.3 这类浮点误差在单笔上几乎看不出，但月底把
// 1800 多笔相加后，账会和手算差几分钱——工人对账时差一分就不信任这个 App。
// 所以：存储用分，显示时才除以 100。

/// 把「分」格式化成带千分位的金额字符串，例如 325400 -> "¥3,254.00"
String yuanGrouped(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final yuanPart = abs ~/ 100;
  final centPart = abs % 100;
  final s = yuanPart.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final cent = centPart.toString().padLeft(2, '0');
  return '${neg ? '-' : ''}¥$buf.$cent';
}

/// 只要数字部分，用于表格对齐：325400 -> "3,254.00"
String yuanPlain(int cents) {
  final t = yuanGrouped(cents);
  return t.startsWith('-') ? t.substring(2) : t.substring(1);
}

/// 不带千分位、便于写进 CSV / 贴进 Excel：1250 -> "12.50"
String yuanCsv(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  return '${neg ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

/// 把用户输入的「元」文本解析成「分」。支持 "1.2"、"1.25"、"12"、".5"、"1,234.5"
/// 解析失败返回 null（由调用方决定提示还是忽略）。
///
/// 注意不能用 double.parse 再 *100：0.29 * 100 = 28.999999999999996，
/// 取整会得到 28 分，凭空少一分钱。这里用字符串拆分。
int? parseYuanToCents(String raw) {
  var s = raw.trim().replaceAll(',', '').replaceAll('¥', '').replaceAll('￥', '');
  if (s.isEmpty) return null;
  var neg = false;
  if (s.startsWith('-')) {
    neg = true;
    s = s.substring(1);
  }
  if (s.isEmpty || !RegExp(r'^\d*\.?\d*$').hasMatch(s)) return null;
  final parts = s.split('.');
  if (parts.length > 2) return null;
  final intPart = parts[0].isEmpty ? 0 : int.parse(parts[0]);
  var centPart = 0;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    // 超过两位则四舍五入到分
    final frac = parts[1];
    final two = (frac.length >= 2 ? frac.substring(0, 2) : frac.padRight(2, '0'));
    centPart = int.parse(two);
    if (frac.length > 2 && int.parse(frac[2]) >= 5) centPart += 1;
  }
  final total = intPart * 100 + centPart;
  return neg ? -total : total;
}

/// 把用户输入的「小时」文本解析成分钟。支持 "2"、"2.5"、"0.5"。
/// 复用金额解析（以 1/100 为单位），避免再写一套小数解析：
/// "2.5" -> 250 -> 250*60/100 = 150 分钟
int? parseHoursToMinutes(String raw) {
  final cents = parseYuanToCents(raw);
  if (cents == null) return null;
  if (cents <= 0) return null;
  return (cents * 60 + 50) ~/ 100;
}

/// 把分钟数格式化成小时文本：30 -> "0.5"，90 -> "1.5"，120 -> "2"
String hoursText(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60}';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final frac = (m * 10 / 60).round(); // 0.5 小时的精度足够
  if (h == 0) return '0.$frac';
  return '$h.$frac';
}
