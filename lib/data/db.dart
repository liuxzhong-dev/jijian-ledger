// 数据库初始化与建表。
//
// 表只有 2 张业务表 + 1 张设置表，故意保持极简：
// 收款方、账户、预算、分类这些「通用记账」概念在计件场景里全都不需要，
// 多一张表就多一处以后要迁移的地方。

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const dbFileName = 'jijian_ledger.db';
const dbVersion = 2;

/// 建表语句独立成函数，是为了让测试能拿内存数据库跑同一套 schema。
/// 测试里绝不允许出现"和线上不一样的表结构"，否则测了也白测。
Future<void> createSchema(Database db) async {
  // 计件记录
  await db.execute('''
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
      created_at INTEGER NOT NULL,
      photo TEXT NOT NULL DEFAULT ''
    )
  ''');
  // 按日期查、按月查是最频繁的操作，索引必须有，否则记录一多列表就卡
  await db.execute('CREATE INDEX idx_work_date ON work_records(work_date)');
  await db.execute('CREATE INDEX idx_work_style ON work_records(style_no)');
  await db.execute('CREATE INDEX idx_work_bundle ON work_records(work_date, bundle_no)');

  // 加班记录
  await db.execute('''
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
  await db.execute('CREATE INDEX idx_ot_date ON overtime_records(work_date)');

  // 设置：主题等少量键值，没必要为它引入 shared_preferences
  await db.execute('''
    CREATE TABLE settings (
      k TEXT PRIMARY KEY,
      v TEXT NOT NULL
    )
  ''');
}

/// 版本迁移步骤。独立成函数的理由同 createSchema：测试要能直接跑
/// 真实的迁移逻辑，而不是在测试里抄一份 ALTER TABLE——
/// 抄的那份永远和线上对不上，测了也白测。
Future<void> migrateSchema(Database db, int oldVersion, int newVersion) async {
  // v1→v2：计件记录加「菲票照片」列（存文件名，不是绝对路径）。
  // 老用户的记录全部置空——他们本来就没有照片，不需要补。
  // 以后加字段必须在这里写 ALTER TABLE，并同步提升 dbVersion
  // —— 否则老用户升级后数据读不出来。
  if (oldVersion < 2) {
    await db.execute(
        "ALTER TABLE work_records ADD COLUMN photo TEXT NOT NULL DEFAULT ''");
  }
}

Future<Database> openLedgerDb() async {
  final dir = await getDatabasesPath();
  final path = p.join(dir, dbFileName);
  return openDatabase(
    path,
    version: dbVersion,
    onCreate: (db, version) => createSchema(db),
    onUpgrade: (db, oldVersion, newVersion) =>
        migrateSchema(db, oldVersion, newVersion),
  );
}
