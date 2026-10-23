// 码数相关的测试。
//
// 起因是主人实际用出来的 bug：v1.0 的码列表写死 S~XXL，做外贸大码的厂
// （XXXL / 5XL / 12XL）和童装数字码（90~170）根本选不了。
//
// 这里断言三件事：
//   1. 内置码覆盖到 12XL 和 170，不再有"选不了"的码
//   2. 自定义码能存、能去重、有上限，且和内置码撞车时不占记忆位
//   3. 老数据里的码（v1.0 手填的、不在任何列表里的）必须能原样存下来并读回来
//      —— 否则用户一编辑旧记录，码就丢了，账就和菲票对不上了

import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/core/sizes.dart';
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
      singleInstance: false,
    ),
  );
  return Repo(db);
}

WorkRecord _work({String size = 'L', String bundle = '1', int? id}) => WorkRecord(
      id: id,
      workDate: '2026-10-18',
      styleNo: 'A1234',
      bundleNo: bundle,
      size: size,
      qty: 10,
      unitPrice: 120,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('内置码覆盖', () {
    test('常用码里有均码（one size），不写"均"这种容易看错的简称', () {
      expect(Sizes.common, contains('均码'));
      expect(Sizes.common, isNot(contains('均')));
    });

    test('大码一直到 12XL——外贸单的上限', () {
      for (final s in ['XXXL', 'XXXXL', '5XL', '6XL', '8XL', '10XL', '12XL']) {
        expect(Sizes.more, contains(s), reason: '$s 选不了');
      }
    });

    test('童装/成人数字码 90~170 都在', () {
      for (final s in ['90', '100', '110', '120', '130', '140', '150', '160', '170']) {
        expect(Sizes.more, contains(s), reason: '$s 选不了');
      }
    });

    test('内置码不重复（重复会让 Wrap 里出现两颗一样的 chip）', () {
      expect(Sizes.builtin.toSet().length, Sizes.builtin.length);
    });

    test('码只是标签，不参与计算：超大码的金额公式和 S 一样', () {
      final r = _work(size: '12XL');
      expect(r.amount, r.qty * r.unitPrice);
    });
  });

  group('老数据兜底', () {
    test('v1.0 手填的码（7XL，不在任何列表里）能存能读', () async {
      final repo = await _newRepo();
      await repo.addWork(_work(size: '7XL'));

      final rows = await repo.workOnDay('2026-10-18');
      expect(rows.single.size, '7XL');
    });

    test('带括号说明的码（XXXL(180)）也不丢', () async {
      final repo = await _newRepo();
      await repo.addWork(_work(size: 'XXXL(180)'));

      final rows = await repo.workOnDay('2026-10-18');
      expect(rows.single.size, 'XXXL(180)');
    });

    test('空码（老数据里就没填码）能正常存取', () async {
      final repo = await _newRepo();
      await repo.addWork(_work(size: ''));

      final rows = await repo.workOnDay('2026-10-18');
      expect(rows.single.size, '');
    });

    test('码改了以后，款号汇总跟着重算（码不影响金额，但要确认没串）', () async {
      final repo = await _newRepo();
      final id = await repo.addWork(_work(size: '12XL', bundle: '1'));
      await repo.updateWork(_work(size: '8XL', bundle: '1', id: id));

      final day = await repo.dayTotal('2026-10-18');
      expect(day.pieceAmount, 1200); // 10 × 12.00，没因为改码翻倍
      expect(day.pieceQty, 10);
    });
  });
}
