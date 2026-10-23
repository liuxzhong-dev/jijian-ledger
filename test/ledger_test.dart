// 数据层集成测试：用内存 SQLite 跑真实的建表 + 增删改查 + 汇总 + 备份回环。
//
// 为什么值得写：金额和汇总算错，比界面丑严重得多——工人会少拿钱。
// 这些用例断言的是"数字对不对"，不是"代码跑不跑得动"。

import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/core/money.dart';
import 'package:jijian_ledger/data/db.dart';
import 'package:jijian_ledger/data/models.dart';
import 'package:jijian_ledger/data/repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Repo> _newRepo() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: dbVersion,
      onCreate: (d, v) => createSchema(d),
      // 关键：sqflite 会按路径缓存已打开的库，':memory:' 也一样。
      // 不关掉这个缓存，第二个用例会拿到上一个用例的库，金额就会累加。
      singleInstance: false,
    ),
  );
  return Repo(db);
}

WorkRecord _work({
  String date = '2026-10-18',
  String style = 'A1234',
  String bundle = '1',
  String size = 'L',
  int qty = 10,
  int price = 120,
}) =>
    WorkRecord(
      workDate: date,
      styleNo: style,
      bundleNo: bundle,
      size: size,
      qty: qty,
      unitPrice: price,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('记两笔：当天合计 = 两笔之和', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(qty: 10, price: 120)); // 12.00
    await repo.addWork(_work(qty: 5, price: 250)); // 12.50

    final day = await repo.dayTotal('2026-10-18');
    expect(day.pieceAmount, 2450);
    expect(day.pieceQty, 15);
  });

  test('月合计：计件 + 加班，出勤天数按日期去重', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(date: '2026-10-01', qty: 100, price: 100)); // 100.00
    await repo.addWork(_work(date: '2026-10-01', qty: 50, price: 200)); // 100.00
    await repo.addWork(_work(date: '2026-10-02', qty: 10, price: 100)); // 10.00
    // 同一天两条加班，只算一天出勤
    await repo.addOvertime(OvertimeRecord(
        workDate: '2026-10-02', minutes: 90, hourPrice: 2500, createdAt: 0)); // 37.50
    await repo.addOvertime(OvertimeRecord(
        workDate: '2026-10-03', minutes: 120, hourPrice: 2000, createdAt: 0)); // 40.00

    final t = await repo.monthTotals('2026-10');
    expect(t.pieceAmount, 21000);
    expect(t.pieceQty, 160);
    expect(t.overtimeAmount, 7750);
    expect(t.overtimeMinutes, 210);
    expect(t.workDays, 3); // 10-01、10-02、10-03
    expect(t.total, 28750);
  });

  test('按款号汇总：件数、金额、单价区间（中途调价要能看出来）', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(style: 'A1', qty: 10, price: 100));
    await repo.addWork(_work(style: 'A1', qty: 10, price: 150));
    await repo.addWork(_work(style: 'B2', qty: 5, price: 300));

    final list = await repo.styleSummary('2026-10');
    final a1 = list.firstWhere((s) => s.styleNo == 'A1');
    expect(a1.qty, 20);
    expect(a1.amount, 2500);
    expect(a1.minPrice, 100);
    expect(a1.maxPrice, 150);
    expect(a1.priceLabel, '1~1.5');
  });

  test('单价记忆：返回该款号最近一次单价', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(style: 'A1', price: 100));
    await repo.addWork(_work(style: 'A1', price: 180));
    await repo.addWork(_work(style: 'B2', price: 999));

    expect(await repo.lastPriceOfStyle('A1'), 180);
    expect(await repo.lastPriceOfStyle('B2'), 999);
    expect(await repo.lastPriceOfStyle('没记过'), isNull);
  });

  test('扎号重复提醒：统计同一天同一扎的件数', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(date: '2026-10-18', bundle: '7', qty: 20));
    await repo.addWork(_work(date: '2026-10-18', bundle: '7', qty: 15));
    await repo.addWork(_work(date: '2026-10-18', bundle: '8', qty: 99));
    await repo.addWork(_work(date: '2026-10-19', bundle: '7', qty: 40));

    expect(await repo.qtyOfBundleOnDay('2026-10-18', '7'), 35); // 跨两条累加
    expect(await repo.qtyOfBundleOnDay('2026-10-18', '8'), 99); // 不串扎
    expect(await repo.qtyOfBundleOnDay('2026-10-19', '7'), 40); // 不跨天
  });

  test('对账文本：包含关键数字，能直接发微信', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(style: 'A1234', qty: 128, price: 120)); // 153.60
    await repo.addOvertime(OvertimeRecord(
        workDate: '2026-10-18', minutes: 90, hourPrice: 2500, createdAt: 0)); // 37.50

    final text = await repo.monthReportText('2026-10');
    expect(text, contains('2026年10月'));
    expect(text, contains('128 件'));
    expect(text, contains('153.60'));
    expect(text, contains('191.10')); // 153.60 + 37.50
    expect(text, contains('A1234'));
  });

  test('备份回环：导出 → 清空 → 导入，数据全回来且重复导入不翻倍', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(qty: 10, price: 100));
    await repo.addWork(_work(bundle: '2', qty: 20, price: 150));
    await repo.addOvertime(OvertimeRecord(
        workDate: '2026-10-18', minutes: 60, hourPrice: 2000, createdAt: 0));
    final before = await repo.monthTotals('2026-10');

    final backup = await repo.exportJson();

    await repo.clearAll();
    expect((await repo.monthTotals('2026-10')).total, 0);

    final n1 = await repo.importJson(backup);
    final after = await repo.monthTotals('2026-10');
    expect(n1, 3);
    expect(after.total, before.total);
    expect(after.pieceQty, before.pieceQty);

    // 再导一次：相同记录应被跳过，金额不能翻倍
    final n2 = await repo.importJson(backup);
    expect(n2, 0);
    expect((await repo.monthTotals('2026-10')).total, before.total);
  });

  test('导入非本 App 的内容会明确报错，而不是静默写入脏数据', () async {
    final repo = await _newRepo();
    expect(() => repo.importJson('{"app":"other"}'), throwsA(isA<FormatException>()));
    expect(() => repo.importJson('不是 JSON'), throwsA(anything));
  });

  test('删改：改一条后合计跟着变，删一条后不再计入', () async {
    final repo = await _newRepo();
    final id = await repo.addWork(_work(qty: 10, price: 100));
    expect((await repo.dayTotal('2026-10-18')).pieceAmount, 1000);

    final list = await repo.workOnDay('2026-10-18');
    await repo.updateWork(WorkRecord(
      id: list.first.id,
      workDate: '2026-10-18',
      styleNo: 'A1234',
      bundleNo: '1',
      size: 'L',
      qty: 30,
      unitPrice: 100,
      createdAt: list.first.createdAt,
    ));
    expect((await repo.dayTotal('2026-10-18')).pieceAmount, 3000);

    await repo.deleteWork(id);
    expect((await repo.dayTotal('2026-10-18')).pieceAmount, 0);
  });

  test('金额不丢精度：1800 笔累加与手算一致', () async {
    final repo = await _newRepo();
    // 0.29 元/件 × 3 件，重复 300 次 = 261.00
    for (var i = 0; i < 300; i++) {
      await repo.addWork(_work(bundle: '$i', qty: 3, price: 29));
    }
    // 1.15 元/件 × 7 件，重复 300 次 = 2415.00
    for (var i = 0; i < 300; i++) {
      await repo.addWork(_work(bundle: 'b$i', qty: 7, price: 115));
    }
    final t = await repo.monthTotals('2026-10');
    expect(t.pieceAmount, 26100 + 241500);
    expect(yuanCsv(t.pieceAmount), '2676.00');
  });
}
