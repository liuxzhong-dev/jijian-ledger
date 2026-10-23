// 数据模型：与数据库表一一对应。
//
// 设计要点：
// 1) amount（金额）是派生的：qty * unit_price。这里用 getter + 可选覆盖值实现，
//    而不是把它做成必填字段。好处是：新建记录时不传 amount 就等于"按公式算"，
//    从库里读历史记录时又能保留当时存的数字（公式以后改了也不会篡改旧账）。
// 2) 所有金额单位都是「分」（int），见 core/money.dart 的说明。
// 3) bundle_no 允许为空：有些款不按扎计件（整款包干），不能强制填。

/// 一条计件记录 = 某天、某款号、某扎、某码、多少件、单价多少
class WorkRecord {
  final int? id;
  final String workDate; // yyyy-MM-dd
  final String styleNo; // 款号
  final String bundleNo; // 扎号（可空）
  final String size; // 码：S/M/L/XL/XXL/均…
  final String operation; // 工序（可空）
  final String note; // 备注（可空）
  final int qty; // 件数
  final int unitPrice; // 单价（分/件）
  final int createdAt; // 毫秒时间戳，仅用于排序
  /// 菲票照片的文件名（不含目录）。空 = 没拍照。
  /// 只存文件名不存绝对路径：换机恢复、备份恢复后路径依然可推导，
  /// 存绝对路径的话恢复完必然全部指向不存在的旧位置。
  final String photo;
  final int? _storedAmount; // 库里存的小计（分）；为空则按公式算

  WorkRecord({
    this.id,
    required this.workDate,
    required this.styleNo,
    this.bundleNo = '',
    this.size = '',
    this.operation = '',
    this.note = '',
    required this.qty,
    required this.unitPrice,
    required this.createdAt,
    this.photo = '',
    int? amount,
  }) : _storedAmount = amount;

  /// 小计（分）。录入时按公式算，读库时用当时存下的值。
  int get amount => _storedAmount ?? qty * unitPrice;

  factory WorkRecord.fromMap(Map<String, Object?> m) => WorkRecord(
        id: m['id'] as int?,
        workDate: (m['work_date'] ?? '') as String,
        styleNo: (m['style_no'] ?? '') as String,
        bundleNo: (m['bundle_no'] ?? '') as String,
        size: (m['size'] ?? '') as String,
        operation: (m['operation'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        qty: (m['qty'] as int?) ?? 0,
        unitPrice: (m['unit_price'] as int?) ?? 0,
        createdAt: (m['created_at'] as int?) ?? 0,
        // 老备份（schema 1）没有这一列，老记录导入后就是空——符合预期
        photo: (m['photo'] ?? '') as String,
        amount: m['amount'] as int?,
      );

  Map<String, Object?> toMap() => {
        'work_date': workDate,
        'style_no': styleNo,
        'bundle_no': bundleNo,
        'size': size,
        'operation': operation,
        'note': note,
        'qty': qty,
        'unit_price': unitPrice,
        'amount': amount,
        'created_at': createdAt,
        'photo': photo,
      };
}

/// 一条加班记录
class OvertimeRecord {
  final int? id;
  final String workDate;
  final int minutes; // 加班分钟数（0.5 小时 = 30）
  final int hourPrice; // 加班单价（分/小时）
  final String note;
  final int createdAt;
  final int? _storedAmount;

  OvertimeRecord({
    this.id,
    required this.workDate,
    required this.minutes,
    required this.hourPrice,
    this.note = '',
    required this.createdAt,
    int? amount,
  }) : _storedAmount = amount;

  /// 加班收入（分）= 分钟 × 时价 ÷ 60，四舍五入到分。
  /// 用整数运算 + 加 30 再整除，避免浮点误差；
  /// （+30 是实现"四舍五入"，不是笔误：÷60 时余数 ≥30 就应当进位）
  int get amount => _storedAmount ?? ((minutes * hourPrice + 30) ~/ 60);

  factory OvertimeRecord.fromMap(Map<String, Object?> m) => OvertimeRecord(
        id: m['id'] as int?,
        workDate: (m['work_date'] ?? '') as String,
        minutes: (m['minutes'] as int?) ?? 0,
        hourPrice: (m['hour_price'] as int?) ?? 0,
        note: (m['note'] ?? '') as String,
        createdAt: (m['created_at'] as int?) ?? 0,
        amount: m['amount'] as int?,
      );

  Map<String, Object?> toMap() => {
        'work_date': workDate,
        'minutes': minutes,
        'hour_price': hourPrice,
        'amount': amount,
        'note': note,
        'created_at': createdAt,
      };
}

/// 月账里「按款号」的一行汇总
class StyleSum {
  final String styleNo;
  final int qty;
  final int amount;
  final int minPrice;
  final int maxPrice;
  final int entries;

  const StyleSum({
    required this.styleNo,
    required this.qty,
    required this.amount,
    required this.minPrice,
    required this.maxPrice,
    required this.entries,
  });

  /// 单价是同一个就显示一个数，中途调过价就显示区间
  String get priceLabel => minPrice == maxPrice
      ? _priceText(minPrice)
      : '${_priceText(minPrice)}~${_priceText(maxPrice)}';

  static String _priceText(int cents) {
    if (cents % 100 == 0) return '${cents ~/ 100}'; // 100 -> "1"
    if (cents % 10 == 0) return '${cents ~/ 100}.${(cents % 100) ~/ 10}'; // 120 -> "1.2"
    return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}'; // 125 -> "1.25"
  }
}

/// 某一天的合计
class DaySum {
  final String date;
  int pieceAmount; // 计件收入（分）
  int pieceQty; // 件数
  int overtimeAmount; // 加班收入（分）
  int overtimeMinutes; // 加班分钟

  DaySum(
    this.date, {
    this.pieceAmount = 0,
    this.pieceQty = 0,
    this.overtimeAmount = 0,
    this.overtimeMinutes = 0,
  });

  int get total => pieceAmount + overtimeAmount;
}

/// 一个月的合计
class MonthTotals {
  final int pieceAmount;
  final int pieceQty;
  final int overtimeAmount;
  final int overtimeMinutes;
  final int workDays;

  const MonthTotals({
    this.pieceAmount = 0,
    this.pieceQty = 0,
    this.overtimeAmount = 0,
    this.overtimeMinutes = 0,
    this.workDays = 0,
  });

  int get total => pieceAmount + overtimeAmount;
}
