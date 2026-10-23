// 菲票照片测试：v1→v2 迁移、photo 存取、备份回环、孤儿清理、路径穿越防护。
//
// 为什么值得写：照片是「对账凭证」。两个错误会直接伤害主人——
//   1) 迁移失败 → 老用户的账读不出来（升级即数据丢失）；
//   2) 孤儿清理误删 → 把还对得上的照片删了，凭证没了。
// 所以这两个场景必须用真实的迁移代码 + 真实文件系统断言，而不是 mock。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/core/photos.dart';
import 'package:jijian_ledger/data/db.dart';
import 'package:jijian_ledger/data/models.dart';
import 'package:jijian_ledger/data/repo.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// path_provider 的 method channel（版本 2.1.6 内部用的就是这个名字）。
/// 测试里把它指向一个临时目录，照片就写在那儿，不碰真机。
const _ppChannel = MethodChannel('plugins.flutter.io/path_provider');

/// 固定路径（不每轮新建）是刻意的：Photos.dir() 内部有静态缓存，
/// 路径不变才能让缓存指向同一个目录，setUp 里清空内容即可。
final _docsPath = p.join(Directory.systemTemp.path, 'jijian_photo_test_docs');

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

WorkRecord _work({
  String date = '2026-10-18',
  String style = 'A1234',
  String bundle = '1',
  String size = 'L',
  int qty = 10,
  int price = 120,
  String photo = '',
}) =>
    WorkRecord(
      workDate: date,
      styleNo: style,
      bundleNo: bundle,
      size: size,
      qty: qty,
      unitPrice: price,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      photo: photo,
    );

void main() {
  // 这不是 widget 测试，但要用 method channel mock 伪装 path_provider，
  // 必须先初始化 binding，否则 setUp 里拿不到 TestDefaultBinaryMessengerBinding。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    final d = Directory(_docsPath);
    if (d.existsSync()) d.deleteSync(recursive: true);
    d.createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ppChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return _docsPath;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ppChannel, null);
  });

  tearDownAll(() {
    final d = Directory(_docsPath);
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  test('photo 存取：拍过的照片跟着记录走，改记录能换照片', () async {
    final repo = await _newRepo();
    final id = await repo.addWork(_work(photo: '1729500000000.jpg'));

    var list = await repo.workOnDay('2026-10-18');
    expect(list.single.photo, '1729500000000.jpg');

    await repo.updateWork(WorkRecord(
      id: id,
      workDate: '2026-10-18',
      styleNo: 'A1234',
      bundleNo: '1',
      size: 'L',
      qty: 10,
      unitPrice: 120,
      createdAt: list.single.createdAt,
      photo: '1729500099999.jpg',
    ));
    list = await repo.workOnDay('2026-10-18');
    expect(list.single.photo, '1729500099999.jpg');

    // 没拍照的记录默认是空串，不是 null——老数据迁移过来也必须是空串
    final id2 = await repo.addWork(_work(bundle: '2'));
    final r2 = (await repo.workOnDay('2026-10-18'))
        .firstWhere((r) => r.id == id2);
    expect(r2.photo, '');
  });

  test('v1→v2 迁移：老数据库加列成功，老记录不丢、photo 置空', () async {
    // 1. 手工造一个 v1 库（work_records 没有 photo 列）+ 一条老记录
    final path = p.join(_docsPath, 'v1.db');
    var db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          // 这是 v1.3 及以前的真实结构（逐列照抄 createSchema 去掉 photo）
          await d.execute('''
            CREATE TABLE work_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              work_date TEXT NOT NULL,
              style_no TEXT NOT NULL,
              bundle_no TEXT NOT NULL DEFAULT '',
              size TEXT NOT NULL DEFAULT '',
              operation TEXT NOT NULL DEFAULT '',
              note TEXT NOT NULL DEFAULT '',
              qty INTEGER NOT NULL,
              unit_price INTEGER NOT NULL,
              amount INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await d.execute(
              'CREATE INDEX idx_work_date ON work_records(work_date)');
          await d.execute(
              'CREATE INDEX idx_work_style ON work_records(style_no)');
          await d.execute(
              'CREATE INDEX idx_work_bundle ON work_records(work_date, bundle_no)');
          await d.execute('''
            CREATE TABLE overtime_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              work_date TEXT NOT NULL,
              minutes INTEGER NOT NULL,
              hour_price INTEGER NOT NULL,
              amount INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL
            )
          ''');
          await d.execute(
              'CREATE INDEX idx_ot_date ON overtime_records(work_date)');
          await d.execute(
              'CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
        },
        singleInstance: false,
      ),
    );
    await db.insert('work_records', {
      'work_date': '2026-10-01',
      'style_no': 'OLD',
      'bundle_no': '3',
      'size': 'XL',
      'operation': '',
      'note': '',
      'qty': 7,
      'unit_price': 200,
      'amount': 1400,
      'created_at': 1,
    });
    await db.close();

    // 2. 用**真实的迁移函数**升级到 v2
    db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (d, old, nv) => migrateSchema(d, old, nv),
        singleInstance: false,
      ),
    );

    // 3. 老记录还在，且 photo 被置成空串（不是 NULL，读出来不会炸）
    final rows = await db.query('work_records');
    expect(rows.length, 1);
    expect(rows.single['photo'], '');

    // 4. 迁移后能正常存带照片的新记录
    final repo = Repo(db);
    await repo.addWork(_work(date: '2026-10-02', photo: 'new.jpg'));
    final day = await repo.dayTotal('2026-10-02');
    expect(day.pieceAmount, 1200); // 10 × 120
    final withPhoto = await repo.workOnDay('2026-10-02');
    expect(withPhoto.single.photo, 'new.jpg');
    await db.close();
  });

  test('备份回环：photo 文件名跟着备份走，老 App 读 schema 2 备份不炸', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(photo: '1729500000000.jpg'));
    final backup = await repo.exportJson();

    // schema 必须是 2（v1.4 起）
    expect(backup, contains('"schema": 2'));

    await repo.clearAll();
    final n = await repo.importJson(backup);
    expect(n, 1);
    final list = await repo.workOnDay('2026-10-18');
    expect(list.single.photo, '1729500000000.jpg');

    // 老 App（schema 1）导出的备份没有 photo 键，导入时按空串处理，不崩
    final oldData = jsonDecode(backup) as Map<String, Object?>;
    final oldWork = (oldData['work'] as List).cast<Map<String, Object?>>();
    for (final m in oldWork) {
      m.remove('photo');
    }
    final oldBackup = const JsonEncoder().convert(oldData);
    await repo.clearAll();
    final n2 = await repo.importJson(oldBackup);
    expect(n2, 1);
    expect((await repo.workOnDay('2026-10-18')).single.photo, '');
  });

  test('allPhotoNames：只收集被引用的非空照片名', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(photo: 'a.jpg'));
    await repo.addWork(_work(bundle: '2')); // 没照片
    await repo.addWork(_work(bundle: '3', photo: 'b.jpg'));

    final names = await repo.allPhotoNames();
    expect(names, {'a.jpg', 'b.jpg'});
  });

  test('孤儿清理：被引用的照片永远不会进名单，只有真孤儿进', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(photo: 'keep1.jpg'));
    await repo.addWork(_work(bundle: '2', photo: 'keep2.jpg'));

    // 目录里放 4 个文件：2 个被引用、2 个是孤儿
    final dir = await Photos.dir();
    for (final name in ['keep1.jpg', 'keep2.jpg', 'orphan1.jpg', 'orphan2.jpg']) {
      File(p.join(dir.path, name)).writeAsStringSync('x' * 1000);
    }

    final referenced = await repo.allPhotoNames();
    final orphans = await Photos.orphans(referenced);
    expect(orphans.map((f) => p.basename(f.path)).toSet(),
        {'orphan1.jpg', 'orphan2.jpg'});

    // 占用大小 = 4 个文件
    expect(await Photos.totalBytes(), 4000);

    // 删孤儿
    for (final f in orphans) {
      if (f.existsSync()) f.deleteSync();
    }
    expect((await Photos.orphans(referenced)).length, 0);
    expect(await Photos.totalBytes(), 2000); // 只剩两个被引用的
    // 引用的照片都还在
    expect(File(p.join(dir.path, 'keep1.jpg')).existsSync(), true);
    expect(File(p.join(dir.path, 'keep2.jpg')).existsSync(), true);
  });

  test('路径穿越：备份里塞 "../outside.txt" 也逃不出照片目录', () async {
    final repo = await _newRepo();
    // 目录外放一个文件，假装是别的重要文件
    final outside = File(p.join(_docsPath, 'outside.txt'));
    outside.writeAsStringSync('重要文件');

    await repo.addWork(_work(photo: '../outside.txt'));
    final r = (await repo.workOnDay('2026-10-18')).single;
    expect(r.photo, '../outside.txt'); // 数据库里原样存（导入不做清洗）

    // 但取文件时必须被 basename 挡在目录内：feipiao/outside.txt 不存在
    final f = await Photos.file(r.photo);
    expect(f, isNull);
    // 目录外的文件没被碰到
    expect(outside.existsSync(), true);
  });

  test('照片文件丢失：记录还在但文件没了，返回 null 而不是崩', () async {
    final repo = await _newRepo();
    await repo.addWork(_work(photo: 'gone.jpg'));
    // 不创建文件，模拟换机恢复后只有名字没有文件
    expect(await Photos.file('gone.jpg'), isNull);
    // 空串（没拍过照）同样安全
    expect(await Photos.file(''), isNull);
  });
}
