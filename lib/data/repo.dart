// 仓储层：所有 SQL 都集中在这里，界面层不写 SQL。
//
// 这么做的原因很实际：以后要改表结构或加字段时，只需要改这一层；
// 如果 SQL 散落在各个页面里，改一处漏一处是时间问题。

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/day.dart';
import '../core/money.dart';
import 'models.dart';

class Repo {
  final Database db;
  Repo(this.db);

  // ---------------- 计件记录 ----------------

  Future<int> addWork(WorkRecord r) => db.insert('work_records', r.toMap());

  Future<void> updateWork(WorkRecord r) async {
    if (r.id == null) return;
    await db.update('work_records', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteWork(int id) => db.delete('work_records', where: 'id = ?', whereArgs: [id]);

  /// 某一天的全部计件记录（按录入顺序，后录的在下面）
  Future<List<WorkRecord>> workOnDay(String date) async {
    final rows = await db.query(
      'work_records',
      where: 'work_date = ?',
      whereArgs: [date],
      orderBy: 'id ASC',
    );
    return rows.map(WorkRecord.fromMap).toList();
  }

  /// 某个月的全部计件记录
  Future<List<WorkRecord>> workInMonth(String ymStr) async {
    final rows = await db.query(
      'work_records',
      where: 'work_date LIKE ?',
      whereArgs: ['$ymStr-%'],
      orderBy: 'work_date ASC, id ASC',
    );
    return rows.map(WorkRecord.fromMap).toList();
  }

  /// 某个款号的全部计件记录（不限月份），新的在前。
  ///
  /// 给「款号速查」用：工人月底对账时最常问的一句话是
  /// "这个款我到底记了几笔、哪一扎还没记"——只看汇总回答不了这个问题。
  Future<List<WorkRecord>> workOfStyle(String styleNo) async {
    if (styleNo.trim().isEmpty) return [];
    final rows = await db.query(
      'work_records',
      where: 'style_no = ?',
      whereArgs: [styleNo],
      orderBy: 'work_date DESC, id DESC',
    );
    return rows.map(WorkRecord.fromMap).toList();
  }

  /// 某款号最近一次用的单价（分）。用于「单价记忆」：下次记同款不用再输。
  Future<int?> lastPriceOfStyle(String styleNo) async {
    if (styleNo.trim().isEmpty) return null;
    final rows = await db.query(
      'work_records',
      columns: ['unit_price'],
      where: 'style_no = ?',
      whereArgs: [styleNo.trim()],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['unit_price'] as int?;
  }

  /// 某天某扎号已经记了多少件。用于「扎号重复提醒」：
  /// 同一扎记两遍是最常见的多算/漏算来源，这里只提示不拦截——
  /// 因为一扎确实可能分两次做完（上午一半、下午一半）。
  Future<int> qtyOfBundleOnDay(String date, String bundleNo) async {
    if (bundleNo.trim().isEmpty) return 0;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(qty), 0) AS q FROM work_records WHERE work_date = ? AND bundle_no = ?',
      [date, bundleNo.trim()],
    );
    return (rows.first['q'] as int?) ?? 0;
  }

  /// 某款号在本月之外的累计（用于款号速查页）
  Future<List<StyleSum>> styleSummary(String ymStr) async {
    final rows = await db.rawQuery('''
      SELECT style_no,
             SUM(qty) AS qty,
             SUM(amount) AS amount,
             MIN(unit_price) AS min_price,
             MAX(unit_price) AS max_price,
             COUNT(*) AS cnt
      FROM work_records
      WHERE work_date LIKE ?
      GROUP BY style_no
      ORDER BY amount DESC
    ''', ['$ymStr-%']);
    return rows
        .map((m) => StyleSum(
              styleNo: (m['style_no'] ?? '') as String,
              qty: (m['qty'] as int?) ?? 0,
              amount: (m['amount'] as int?) ?? 0,
              minPrice: (m['min_price'] as int?) ?? 0,
              maxPrice: (m['max_price'] as int?) ?? 0,
              entries: (m['cnt'] as int?) ?? 0,
            ))
        .toList();
  }

  /// 全部出现过的款号 + 最近单价（不限月份），用于速查
  Future<List<StyleSum>> allStyles() async {
    final rows = await db.rawQuery('''
      SELECT style_no,
             SUM(qty) AS qty,
             SUM(amount) AS amount,
             MIN(unit_price) AS min_price,
             MAX(unit_price) AS max_price,
             COUNT(*) AS cnt
      FROM work_records
      GROUP BY style_no
      ORDER BY MAX(id) DESC
    ''');
    return rows
        .map((m) => StyleSum(
              styleNo: (m['style_no'] ?? '') as String,
              qty: (m['qty'] as int?) ?? 0,
              amount: (m['amount'] as int?) ?? 0,
              minPrice: (m['min_price'] as int?) ?? 0,
              maxPrice: (m['max_price'] as int?) ?? 0,
              entries: (m['cnt'] as int?) ?? 0,
            ))
        .toList();
  }

  // ---------------- 加班记录 ----------------

  Future<int> addOvertime(OvertimeRecord r) => db.insert('overtime_records', r.toMap());

  Future<void> updateOvertime(OvertimeRecord r) async {
    if (r.id == null) return;
    await db.update('overtime_records', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteOvertime(int id) =>
      db.delete('overtime_records', where: 'id = ?', whereArgs: [id]);

  Future<List<OvertimeRecord>> overtimeOnDay(String date) async {
    final rows = await db.query('overtime_records',
        where: 'work_date = ?', whereArgs: [date], orderBy: 'id ASC');
    return rows.map(OvertimeRecord.fromMap).toList();
  }

  Future<List<OvertimeRecord>> overtimeInMonth(String ymStr) async {
    final rows = await db.query('overtime_records',
        where: 'work_date LIKE ?', whereArgs: ['$ymStr-%'], orderBy: 'work_date ASC, id ASC');
    return rows.map(OvertimeRecord.fromMap).toList();
  }

  /// 最近一次加班单价，用于默认带出
  Future<int?> lastOvertimePrice() async {
    final rows = await db.query('overtime_records',
        columns: ['hour_price'], orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['hour_price'] as int?;
  }

  // ---------------- 汇总 ----------------

  Future<MonthTotals> monthTotals(String ymStr) async {
    final w = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS amt, COALESCE(SUM(qty), 0) AS qty
      FROM work_records WHERE work_date LIKE ?
    ''', ['$ymStr-%']);
    final o = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS amt, COALESCE(SUM(minutes), 0) AS mins
      FROM overtime_records WHERE work_date LIKE ?
    ''', ['$ymStr-%']);
    final days = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM (
        SELECT work_date FROM work_records WHERE work_date LIKE ?
        UNION
        SELECT work_date FROM overtime_records WHERE work_date LIKE ?
      )
    ''', ['$ymStr-%', '$ymStr-%']);
    return MonthTotals(
      pieceAmount: (w.first['amt'] as int?) ?? 0,
      pieceQty: (w.first['qty'] as int?) ?? 0,
      overtimeAmount: (o.first['amt'] as int?) ?? 0,
      overtimeMinutes: (o.first['mins'] as int?) ?? 0,
      workDays: (days.first['c'] as int?) ?? 0,
    );
  }

  /// 按天汇总：计件与加班合并成一行天
  Future<List<DaySum>> daySummaries(String ymStr) async {
    final w = await db.rawQuery('''
      SELECT work_date AS d, SUM(amount) AS amt, SUM(qty) AS qty
      FROM work_records WHERE work_date LIKE ?
      GROUP BY work_date
    ''', ['$ymStr-%']);
    final o = await db.rawQuery('''
      SELECT work_date AS d, SUM(amount) AS amt, SUM(minutes) AS mins
      FROM overtime_records WHERE work_date LIKE ?
      GROUP BY work_date
    ''', ['$ymStr-%']);
    final map = <String, DaySum>{};
    for (final m in w) {
      final d = m['d'] as String;
      map[d] = DaySum(d,
          pieceAmount: (m['amt'] as int?) ?? 0, pieceQty: (m['qty'] as int?) ?? 0);
    }
    for (final m in o) {
      final d = m['d'] as String;
      final cur = map[d] ?? DaySum(d);
      cur.overtimeAmount = (m['amt'] as int?) ?? 0;
      cur.overtimeMinutes = (m['mins'] as int?) ?? 0;
      map[d] = cur;
    }
    final list = map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<DaySum> dayTotal(String date) async {
    final w = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS amt, COALESCE(SUM(qty),0) AS qty FROM work_records WHERE work_date = ?',
        [date]);
    final o = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS amt, COALESCE(SUM(minutes),0) AS mins FROM overtime_records WHERE work_date = ?',
        [date]);
    return DaySum(date,
        pieceAmount: (w.first['amt'] as int?) ?? 0,
        pieceQty: (w.first['qty'] as int?) ?? 0,
        overtimeAmount: (o.first['amt'] as int?) ?? 0,
        overtimeMinutes: (o.first['mins'] as int?) ?? 0);
  }

  // ---------------- 设置 ----------------

  Future<String?> getSetting(String k) async {
    final rows = await db.query('settings', where: 'k = ?', whereArgs: [k], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  Future<void> setSetting(String k, String v) async {
    await db.insert('settings', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- 备份 / 恢复 ----------------

  /// 导出成一段 JSON 文本（不落文件，直接复制到剪贴板）。
  /// 对工人来说"复制→粘贴到微信收藏"比"找一个文件管理器导出"现实得多。
  ///
  /// schema 2 = work 行里带 photo 字段（照片文件名）。
  /// 注意：**照片文件本身不进备份**——剪贴板装不下二进制，硬塞会让
  /// 备份大到没法粘。恢复后若文件不在本机（换机/清理过），
  /// 界面显示"照片文件已丢失"，记录本身不受影响。
  /// 老版本 App 读 schema 2 备份：import 按列名取，photo 被自然忽略，不会炸。
  Future<String> exportJson() async {
    final work = await db.query('work_records', orderBy: 'id ASC');
    final ot = await db.query('overtime_records', orderBy: 'id ASC');
    final payload = {
      'app': 'jijian_ledger',
      'schema': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'work': work,
      'overtime': ot,
    };
    return const JsonEncoder.withIndent(' ').convert(payload);
  }

  /// 导入备份：合并模式，跳过完全相同的记录，返回新插入条数。
  /// 不做"清空再导入"，因为误操作代价太大（那是别人半个月的工资）。
  Future<int> importJson(String text) async {
    final data = jsonDecode(text);
    if (data is! Map || data['app'] != 'jijian_ledger') {
      throw const FormatException('这不是本 App 的备份内容');
    }
    var inserted = 0;
    final workList = (data['work'] as List?) ?? const [];
    for (final item in workList) {
      final m = (item as Map).cast<String, Object?>();
      final exists = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM work_records
        WHERE work_date = ? AND style_no = ? AND bundle_no = ? AND size = ?
          AND qty = ? AND unit_price = ?
      ''', [m['work_date'], m['style_no'], m['bundle_no'], m['size'], m['qty'], m['unit_price']]);
      if (((exists.first['c'] as int?) ?? 0) > 0) continue;
      await db.insert('work_records', {
        'work_date': m['work_date'],
        'style_no': m['style_no'],
        'bundle_no': m['bundle_no'] ?? '',
        'size': m['size'] ?? '',
        'operation': m['operation'] ?? '',
        'note': m['note'] ?? '',
        'qty': m['qty'],
        'unit_price': m['unit_price'],
        'amount': m['amount'] ?? ((m['qty'] as int) * (m['unit_price'] as int)),
        'created_at': m['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        // 老备份没有 photo 键，导入后为空——同一台手机上恢复时文件还在，
        // 只是记录想不起文件名，需要重新关联（可接受：老记录本来就没图）
        'photo': m['photo'] ?? '',
      });
      inserted++;
    }
    final otList = (data['overtime'] as List?) ?? const [];
    for (final item in otList) {
      final m = (item as Map).cast<String, Object?>();
      final exists = await db.rawQuery('''
        SELECT COUNT(*) AS c FROM overtime_records
        WHERE work_date = ? AND minutes = ? AND hour_price = ?
      ''', [m['work_date'], m['minutes'], m['hour_price']]);
      if (((exists.first['c'] as int?) ?? 0) > 0) continue;
      await db.insert('overtime_records', {
        'work_date': m['work_date'],
        'minutes': m['minutes'],
        'hour_price': m['hour_price'],
        'amount': m['amount'] ?? 0,
        'note': m['note'] ?? '',
        'created_at': m['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      });
      inserted++;
    }
    return inserted;
  }

  Future<void> clearAll() async {
    await db.delete('work_records');
    await db.delete('overtime_records');
  }

  // ---------------- 菲票照片 ----------------

  /// 全部被记录引用的照片文件名。
  /// 给「清理不再引用的照片」用：删记录时**不删照片**（防误删丢凭证），
  /// 孤儿文件靠这个集合找出来，让用户确认后再删。
  Future<Set<String>> allPhotoNames() async {
    final rows = await db.query('work_records',
        columns: ['photo'], where: "photo IS NOT NULL AND photo != ''");
    return rows.map((r) => r['photo'] as String).toSet();
  }

  // ---------------- 导出文本（对账用） ----------------

  /// 生成能直接发给组长/老板的对账文本
  Future<String> monthReportText(String ymStr) async {
    final totals = await monthTotals(ymStr);
    final styles = await styleSummary(ymStr);
    final days = await daySummaries(ymStr);
    final parts = ymStr.split('-');
    final buf = StringBuffer();
    buf.writeln('【${parts[0]}年${int.parse(parts[1])}月 计件账】');
    buf.writeln('计件：${totals.pieceQty} 件  ¥${yuanCsv(totals.pieceAmount)}');
    if (totals.overtimeMinutes > 0) {
      buf.writeln('加班：${hoursText(totals.overtimeMinutes)} 小时  ¥${yuanCsv(totals.overtimeAmount)}');
    }
    buf.writeln('合计：¥${yuanCsv(totals.total)}');
    buf.writeln('');
    buf.writeln('— 按款号 —');
    for (final s in styles) {
      buf.writeln('${s.styleNo} ｜ ${s.qty} 件 ｜ ${s.priceLabel} 元 ｜ ¥${yuanCsv(s.amount)}');
    }
    buf.writeln('');
    buf.writeln('— 按天 —');
    for (final d in days) {
      final dt = parseYmd(d.date);
      buf.writeln('${dt.month}-${two(dt.day)}  ¥${yuanCsv(d.total)}');
    }
    return buf.toString();
  }

  /// CSV（UTF-8 带 BOM 才能被 Excel 正确识别中文）
  Future<String> monthCsv(String ymStr) async {
    final rows = await workInMonth(ymStr);
    final buf = StringBuffer('\uFEFF');
    buf.writeln('日期,款号,扎号,码,工序,件数,单价,金额,备注');
    for (final r in rows) {
      buf.writeln([
        r.workDate,
        _csv(r.styleNo),
        _csv(r.bundleNo),
        _csv(r.size),
        _csv(r.operation),
        r.qty,
        yuanCsv(r.unitPrice),
        yuanCsv(r.amount),
        _csv(r.note),
      ].join(','));
    }
    final ots = await overtimeInMonth(ymStr);
    for (final o in ots) {
      buf.writeln([
        o.workDate,
        '加班',
        '',
        '',
        '',
        hoursText(o.minutes),
        yuanCsv(o.hourPrice),
        yuanCsv(o.amount),
        _csv(o.note),
      ].join(','));
    }
    return buf.toString();
  }

  String _csv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
