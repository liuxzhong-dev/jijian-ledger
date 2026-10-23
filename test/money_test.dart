// 只测「钱」和「时间」的换算——这是全 App 唯一算错就会伤到人的地方。
//
// 界面测试（widget test）刻意不写：v1 还在改交互，写了就要跟着改，
// 属于假工作量。等交互定稿再补。

import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/core/money.dart';
import 'package:jijian_ledger/data/models.dart';

void main() {
  group('金额解析', () {
    test('整数与小数', () {
      expect(parseYuanToCents('1'), 100);
      expect(parseYuanToCents('1.2'), 120);
      expect(parseYuanToCents('1.25'), 125);
      expect(parseYuanToCents('12'), 1200);
      expect(parseYuanToCents('0'), 0);
    });

    test('浮点陷阱：0.29 必须是 29 分', () {
      // 如果用 double.parse('0.29') * 100 = 28.999999999999996，取整会变 28
      expect(parseYuanToCents('0.29'), 29);
      expect(parseYuanToCents('1.15'), 115);
      expect(parseYuanToCents('8.07'), 807);
    });

    test('容错：逗号、货币符号、前导点、多余小数位', () {
      expect(parseYuanToCents('1,234.5'), 123450);
      expect(parseYuanToCents('¥1.20'), 120);
      expect(parseYuanToCents('.5'), 50);
      expect(parseYuanToCents('1.005'), 101); // 四舍五入到分
      expect(parseYuanToCents(''), isNull);
      expect(parseYuanToCents('abc'), isNull);
      expect(parseYuanToCents('1.2.3'), isNull);
    });
  });

  group('金额显示', () {
    test('千分位', () {
      expect(yuanGrouped(0), '¥0.00');
      expect(yuanGrouped(5), '¥0.05');
      expect(yuanGrouped(15360), '¥153.60');
      expect(yuanGrouped(325400), '¥3,254.00');
      expect(yuanGrouped(123456789), '¥1,234,567.89');
    });

    test('无符号与 CSV 口径', () {
      expect(yuanPlain(325400), '3,254.00');
      expect(yuanCsv(1250), '12.50');
      expect(yuanCsv(5), '0.05');
    });
  });

  group('计件金额', () {
    test('件数 × 单价，全程整数', () {
      final r = WorkRecord(
        workDate: '2026-10-18',
        styleNo: 'A1234',
        bundleNo: '12',
        size: 'L',
        qty: 128,
        unitPrice: 120, // 1.20 元
        createdAt: 0,
      );
      expect(r.amount, 15360);
      expect(yuanGrouped(r.amount), '¥153.60');
    });

    test('零件或零价不会算出负数', () {
      final r = WorkRecord(
        workDate: '2026-10-18',
        styleNo: 'X',
        qty: 0,
        unitPrice: 0,
        createdAt: 0,
      );
      expect(r.amount, 0);
    });
  });

  group('加班金额', () {
    test('分钟 × 时价，四舍五入到分', () {
      // 1.5 小时 × 25 元/时 = 37.50
      final a = OvertimeRecord(workDate: '2026-10-18', minutes: 90, hourPrice: 2500, createdAt: 0);
      expect(a.amount, 3750);

      // 0.5 小时 × 33.33 元/时 = 16.665 -> 16.67（四舍五入，不能截断）
      final b = OvertimeRecord(workDate: '2026-10-18', minutes: 30, hourPrice: 3333, createdAt: 0);
      expect(b.amount, 1667);
    });

    test('小时文本互转', () {
      expect(parseHoursToMinutes('2'), 120);
      expect(parseHoursToMinutes('2.5'), 150);
      expect(parseHoursToMinutes('0.5'), 30);
      expect(parseHoursToMinutes(''), isNull);
      expect(hoursText(30), '0.5');
      expect(hoursText(90), '1.5');
      expect(hoursText(120), '2');
    });
  });
}
